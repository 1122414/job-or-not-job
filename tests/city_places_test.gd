extends "res://tests/city_bookshop_test.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	for actor in game.npcs: actor.set_physics_process(false)
	var original := JSON.parse_string(JSON.stringify(SaveGame.snapshot(game))) as Dictionary
	var room: CityBookshop=game.city_life.room
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"新陈设保留公共/分享/共读路线 "+str(link))
	# Real character movement, with collision, through the public circulation
	# and the bookshop. The initial position is the only fixture placement.
	game.player.position=Vector3(0,0,23)
	await frames(3)
	var metres := 0.0
	for at in [Vector3(0,0,58),Vector3(-64,0,58),Vector3(-56,0,52),Vector3(-52,0,43),Vector3(-52,0,35),Vector3(-55.7,0,30.5),Vector3(-52,0,35),Vector3(-49.2,0,29.7),Vector3(-50.5,0,35),Vector3(-52,0,35),Vector3(-52,0,43)]:
		var before: Vector3=game.player.position
		if not await walk_to(at): finish(); return
		metres+=before.distance_to(game.player.position)
		check(game.player.is_on_floor() and absf(game.player.position.y)<.08,"真实路线保留平齐地面 "+str(at))
	for x in [-55.9,-46.9]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x,1.9,40),Vector3(x,1.9,37),1)
		var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.z-38.5)<.2,"透明前窗实际阻挡身体 "+str(x))
		if not hit.is_empty():
			var panes: Array=hit.collider.find_children("*","MeshInstance3D",true,false)
			check(not panes.is_empty() and panes[0].material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"窗口碰撞所对应的实际网格使用透明材质")
	# Existing saves may put an actor where the newly authored bookcase or
	# reading chair now stands. Verify the actual post-restore floor support.
	for local in [Vector3(5.94,0,-2.5),Vector3(-4.65,0,4.35),Vector3(5.65,0,4.8)]:
		var at: Vector3=room.to_global(local)
		check(not game.position_clear(game.player,at),"旧落点确实被新家具占据")
		var saved := original.duplicate(true)
		saved.player.position=SaveGame.vector(at)
		check(SaveGame.restore(game,saved),"旧家具位置的合法JSON仍可恢复")
		await frames(70)
		check(game.position_clear(game.player,game.player.position) and game.player.position.y>=-.05 and game.player.is_on_floor(),"旧落点恢复后不夹在家具或地板中")
		check(game.player.position.distance_to(at)<3.5,"旧落点在同一房间附近安全恢复")
		check(game.props.size()==114 and game.career.employer==original.career.employer,"保留原职业及物品身份")
	var resident: CityResident=game.population.residents[5]
	var old_resident := original.duplicate(true)
	var person_data: Dictionary=old_resident.city_population.people[resident.stable_id]
	person_data.state="activity"; person_data.destination="reading_east"; person_data.from_node="reading_east"
	person_data.route=[]; person_data.crossing=""; person_data.activity_left=40
	person_data.hp=47; person_data.hits=2; person_data.met=true
	for local in [Vector3(5.94,0,-2.5),Vector3(-4.65,0,4.35),Vector3(5.65,0,4.8)]:
		person_data.position=SaveGame.vector(room.to_global(local))
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old_resident))),"旧档居民位于新增家具位置仍合法")
		await frames(70)
		check(game.position_clear(resident,resident.position) and resident.position.y>=-.05 and resident.is_on_floor(),"公共居民旧落点也要脱离新增家具并站稳")
		check(resident.position.distance_to(SaveGame.unvector(person_data.position))<3.5 and resident.hp==47 and resident.hits==2 and resident.met and resident.destination==person_data.destination,"居民本地恢复不清除身份、健康、经历或目的地")
	person_data.position=SaveGame.vector(CityPopulation.POINTS.reading_east)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old_resident))),"正常空地的居民读档")
	await frames(70)
	check(resident.position.distance_to(SaveGame.unvector(person_data.position))<.03,"没有新家具阻挡的居民保持原站位")
	# Freeze physics only for this ownership boundary: the migration itself
	# must not move a fallen resident as though their body were upright.
	resident.set_physics_process(false)
	resident.hp=1; resident.down=12; resident.state="fallen"
	resident.position=room.to_global(Vector3(5.94,0,-2.5))
	var fallen_position := resident.position
	await game.repair_migrated_positions(game.restore_revision)
	check(resident.position==fallen_position and resident.hp==1 and resident.down==12,"恢复不把倒地居民当站立人物移位或治愈")
	resident.hp=0; resident.down=0; resident.state="dead"
	await game.repair_migrated_positions(game.restore_revision)
	check(resident.position==fallen_position and resident.hp==0,"死亡居民不被站位恢复挪动或复活")
	game.payroll.minute=630
	game.city_life.sync_scene()
	for lamp in room.lamps: check(lamp.light_energy>.5,"营业时实际阅读照明开启")
	game.payroll.minute=1230
	game.city_life.sync_scene()
	for lamp in room.lamps: check(lamp.light_energy<.2,"闭馆后调暗原阅读照明")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"全过程不抓取鼠标")
	print("CITY_PLACES_METRES ",metres," player_old_positions=3 resident_old_positions=3 safe_resident=unchanged fallen_dead=unchanged actual_glazing=2")
	finish()

func finish() -> void:
	press("forward",false)
	game.queue_free()
	await process_frame
	print("CITY_PLACES_TEST failures=",failures)
	quit(failures)

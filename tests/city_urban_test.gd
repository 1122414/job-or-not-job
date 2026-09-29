extends "res://tests/city_bookshop_test.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	for actor in game.npcs+game.population.residents: actor.set_physics_process(false)
	var initial := JSON.parse_string(JSON.stringify(SaveGame.snapshot(game))) as Dictionary
	var routes := [
		[Vector3(-8,0,42),Vector3(-28,0,42)],
		[Vector3(8,0,42),Vector3(28,0,42)],
		[Vector3(-6,0,85),Vector3(-26,0,85)]
	]
	var metres := 0.0
	for route in routes:
		game.player.position=route[0]
		await frames(3)
		var start: Vector3=game.player.position
		check(game.walking.clear_segment(route[0],route[1]),"整条廊道胶囊扫掠无柱墙阻挡 "+str(route))
		if not await walk_to(route[1]): finish(); return
		metres+=start.distance_to(game.player.position)
		check(absf(game.player.position.y)<.08,"廊道地面无抬高/跌落")
		start=game.player.position
		if not await walk_to(route[0]): finish(); return
		metres+=start.distance_to(game.player.position)
		var middle: Vector3=(route[0]+route[1])/2
		var roof := PhysicsRayQueryParameters3D.create(middle+Vector3.UP*1.8,middle+Vector3.UP*4,1)
		var hit := game.get_world_3d().direct_space_state.intersect_ray(roof)
		check(not hit.is_empty() and hit.position.y>=2.85 and hit.position.y<=3,"真实屋顶覆盖廊道且净高足够")
	# Preserve the street-to-waterfront spine as an actual continuous walk.
	game.player.position=Vector3(0,0,23)
	await frames(3)
	var axis_start: Vector3=game.player.position
	if not await walk_to(Vector3(0,0,95)): finish(); return
	metres+=axis_start.distance_to(game.player.position)
	for column in [Vector3(-24.8,0,27.2),Vector3(24.8,0,27.2),Vector3(-22.8,0,69.2)]:
		check(not game.position_clear(game.player,column),"廊柱有真实碰撞而非可穿透装饰")
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"原居民/活动通路 "+str(link))
	for point in [Vector3(-18,0,32),Vector3(18,0,32),Vector3(-16,0,75)]:
		var old := initial.duplicate(true)
		old.player.position=SaveGame.vector(point)
		check(not game.position_clear(game.player,point),"旧落点确实被新增楼芯占据")
		check(SaveGame.restore(game,old),"旧档中的新增楼芯位置仍是合法数据")
		await frames(8)
		check(game.player.position.y>=-.05,"恢复不能留在地面碰撞体下方")
		check(game.position_clear(game.player,game.player.position),"读档后脱离新增楼芯碰撞")
		check(game.player.position.distance_to(point)<3.5,"在原地附近恢复，不送回公司或改变地区："+str(point)+" -> "+str(game.player.position))
		check(game.career.employer==initial.career.employer and game.props.size()==114,"位置迁移保留职业和物品")
		await frames(60)
		check(game.player.position.y>=-.05 and game.player.is_on_floor(),"恢复后持续得到实际地面支撑")
	var safe := initial.duplicate(true)
	safe.player.position=SaveGame.vector(Vector3(-18,0,42))
	check(SaveGame.restore(game,safe),"廊道内合法位置写读")
	await frames(8)
	check(game.player.position.distance_to(Vector3(-18,0,42))<.1,"安全廊道落点不被迁移")
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	var prior := streets.wave_time
	await frames(5)
	check(streets.wave_time>prior,"实际处理推进海面")
	game.panels.show_page("city")
	prior=streets.wave_time
	for i in range(5): await process_frame
	check(streets.wave_time==prior,"打开地图时海面随世界暂停")
	game.panels.show_page("")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"全过程不接管鼠标")
	print("CITY_URBAN_METRES ",metres," arcade_lots=",streets.get_meta("arcade_lots")," scenery_only_lots=",streets.get_meta("background_lots"))
	finish()

func finish() -> void:
	press("forward",false)
	game.queue_free()
	await process_frame
	print("CITY_URBAN_TEST failures=",failures)
	quit(failures)

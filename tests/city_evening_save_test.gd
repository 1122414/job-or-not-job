extends "res://tests/city_bookshop_test.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3g")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.set_process(false)
	game.social.meet(game.npc_for_role("a_friend"))
	game.social.remember(game.npc_for_role("a_friend"),"evening_migration_fixture","迁移前共同经历。",2,3)
	var original := SaveGame.snapshot(game)
	var legacy := original.duplicate(true)
	legacy.version=19
	legacy.city_population.crossings.erase("office")
	var file := "res://build/c3g/legacy-v19.json"
	var payload := JSON.stringify(legacy)
	FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify({"payload":payload,"checksum":payload.sha256_text()}))
	check(SaveGame.restore(game,SaveGame.read(file,game)),"实际v19三路口JSON迁移")
	check(game.population.crossings.office=={"people":false,"opened":false,"remaining":0.0},"新路口初始不伪造通行许可")
	check(JSON.parse_string(JSON.stringify(SaveGame.snapshot(game).social))==JSON.parse_string(JSON.stringify(original.social)),"迁移保留既有人物经历")
	for label in ["missing_current","missing_legacy","unknown","opened","remaining","type"]:
		var bad: Dictionary=original.duplicate(true)
		match label:
			"missing_current": bad.city_population.crossings.erase("office")
			"missing_legacy": bad.version=19; bad.city_population.crossings.erase("market")
			"unknown": bad.city_population.crossings.extra=bad.city_population.crossings.office
			"opened": bad.city_population.crossings.office.opened=true
			"remaining": bad.city_population.crossings.office.remaining=8
			"type": bad.city_population.crossings.office=[]
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,JSON.parse_string(JSON.stringify(bad))) and SaveGame.snapshot(game)==before,"坏路口原子拒绝 "+label)
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.payroll.minute=1140
	check(CityEvening.at_place(npc)=="","日程存在但未到场不提供偶遇")
	npc.position=CityOuting.place_position(npc,"bookshop")
	game.player.position=npc.position+Vector3(0,0,1.7)
	game.speaker=npc
	game.social.outing={"person":"b_friend","kind":"walk","venue":"garden","stage":"paused","elapsed":0.0}
	game.social.handle("people_evening_join",npc)
	check(game.social.outing.person=="b_friend" and game.social.outing.stage=="paused","偶遇不覆盖已有暂缓约定")
	game.social.outing.clear()
	game.player.position=Vector3(0,0,18)
	game.social.handle("people_evening_join",npc)
	check(game.social.outing.is_empty(),"远处不能通过动作名伪造共同到场")
	game.player.position=npc.position+Vector3(0,0,1.7)
	game.social.state(npc).fear=30
	game.social.handle("people_evening_join",npc)
	check(game.social.outing.is_empty(),"害怕玩家时不强行私人相处")
	check(game.walking.clear_segment(CityPopulation.POINTS.office_out,CityPopulation.POINTS.office_in),"斑马线实际通路无灯柱或场景障碍")
	for i in range(60):
		var from := Vector3(3.3+i*.05,0,18.1)
		var path: PackedVector3Array=game.walking.route(from,Vector3(8,0,18))
		check(not path.is_empty() and path[0].x>from.x,"离开路网端点后持续朝等候点前进 %d" % i)
	check(CityFootRoutes.in_office(Vector3(2.192742,0,5.000002)),"门前边界浮点误差不重新绕回过街入口")
	for id in CityEvening.FOYERS:
		check(CityEvening.FOYERS[id].z>=17 and game.position_clear(game.npc_for_role(id),CityEvening.FOYERS[id]),"下班等候点位于可站立步道 "+id)
	check(SaveGame.restore(game,original),"测试恢复初态")
	print("CITY_EVENING_SAVE_TEST failures=",failures," legacy=19 current=",SaveGame.VERSION," invalid_crossings=6")
	game.queue_free(); await process_frame; quit(failures)

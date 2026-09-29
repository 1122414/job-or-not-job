extends "res://tests/city_bookshop_test.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	var commons: CityCommons=game.commons
	var original := SaveGame.snapshot(game)
	var person: CityResident=game.population.residents[0]
	var bench: CityBench=commons.benches.commons_west_0
	# Seated fixture tests recovery/validation; natural approach is covered separately.
	person.plan(commons.reserve(person,bench.stable_id))
	person.route.clear(); person.position=commons.point(commons.visits[person.stable_id].slot)
	person.state="activity"
	await frames(4)
	game.player.position=bench.approach()
	commons.use_bench(bench)
	await frames(35)
	game.population.talk(person)
	commons.answer(person,"commons_street")
	game.close_interaction()
	var file := "user://city-commons-test.json"
	check(SaveGame.write(game,file)==OK,"实际写盘公共座位/共同经历")
	var saved := SaveGame.read(file,game)
	check(not saved.is_empty(),"读取有效校验封装")
	if saved.is_empty(): print("SAVE_FAIL ",SaveGame.snapshot(game)); quit(1); return
	check(SaveGame.restore(game,saved) and game.player.seated and commons.sitting(person),"写盘后恢复实际占用")
	await frames(15)
	check(game.player.is_on_floor() and person.is_on_floor(),"读档后双方持续受地面支撑")
	check(commons.sitting(person),"场景迁移恢复不能挪走仍有效落座的居民")
	game.player.look(Vector2(230,0))
	var camera_yaw: float=game.player.yaw
	game.player.pick(game.props[0])
	var held: OfficeProp=game.player.held
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) and game.player.held==held and is_equal_approx(game.player.yaw,camera_yaw),"座位读档保留自由镜头和手持物归属")
	check(SaveGame.restore(game,saved),"恢复占用基线")
	game.player.position+=Vector3(.45,0,0)
	await frames(3)
	check(commons.player_slot=="" and not game.player.seated and game.player.seat_body==null,"外力位移离开座面时释放实际占用")
	check(SaveGame.restore(game,saved),"恢复验证居民位移")
	person.position+=Vector3(0,0,.4)
	await frames(3)
	check(not commons.visits[person.stable_id].seated and SaveGame.valid(SaveGame.snapshot(game),game),"居民离开座面后回到实际靠近状态且快照有效")
	check(SaveGame.restore(game,saved),"恢复坏档测试基线")
	for corrupt in ["missing","schema","slot","side","duplicate","player_duplicate","destination","position","hp","fear","route","bool","unknown","future","topic","place","vehicle"]:
		var bad := saved.duplicate(true)
		var visit: Dictionary=bad.city_commons.visits[person.stable_id]
		match corrupt:
			"missing": bad.erase("city_commons")
			"schema": bad.city_commons.schema=2
			"slot": visit.slot="missing/0"
			"side": visit.slot="commons_west_0/2"
			"duplicate": bad.city_commons.visits[game.population.residents[1].stable_id]=visit.duplicate()
			"player_duplicate": bad.city_commons.player_slot=visit.slot
			"destination": bad.city_population.people[person.stable_id].destination="market"
			"position": bad.city_population.people[person.stable_id].position=[0,0,18]
			"hp": bad.city_population.people[person.stable_id].hp=0
			"fear": bad.city_population.people[person.stable_id].fear=1
			"route": bad.city_population.people[person.stable_id].route=[bench.stable_id]
			"bool": visit.seated=1
			"unknown": bad.city_commons.memories["unknown"]={"day":0,"topic":"quiet","place":"west"}
			"future": bad.city_commons.memories[person.stable_id].day=1
			"topic": bad.city_commons.memories[person.stable_id].topic="unknown"
			"place": bad.city_commons.memories[person.stable_id].place="unknown"
			"vehicle": bad.city_driving.active="shared_0"
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"坏关联档无部分修改 "+corrupt)
	for version in range(1,18):
		var old := original.duplicate(true)
		old.version=version; old.erase("city_commons")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))) and commons.visits.is_empty() and commons.memories.is_empty() and commons.player_slot=="","旧v%d初始化公共生活" % version)
	check(SaveGame.restore(game,saved),"恢复以验证优先级")
	await frames(5)
	# A scheduled bookshop activity takes priority without teleporting the seated guest.
	game.city_life.method="paper"; game.city_life.prepared=true
	var position: Vector3=person.position
	await frames(4)
	check(not commons.visits.has(person.stable_id) and person.destination in CityLife.PAPER and person.position.distance_to(position)<.15,"正式赴约先起身走开，不瞬移")
	check(SaveGame.restore(game,saved),"恢复以验证危险")
	await frames(5)
	person.hit(Vector3.FORWARD,.5,game.next_action(),false)
	await frames(3)
	check(not commons.visits.has(person.stable_id) and not commons.sitting(person) and not person.pastime_book.visible and person.fear>0,"危险立即中断休闲，收起书本")
	check(commons.memory_line(person).contains("人和事"),"危险不删除已有共同经历")
	check(SaveGame.restore(game,saved),"恢复以验证救助接管")
	person.hp=0; person.state="dead"; person.route.clear(); person.crossing=""
	check(game.response.report(person,"player") and not commons.visits.has(person.stable_id) and SaveGame.valid(SaveGame.snapshot(game),game),"救助接管立即释放休闲预约，不依赖此前的命中入口")
	check(SaveGame.restore(game,saved),"恢复以验证次日回访")
	game.player.stand_up()
	game.payroll.minute+=1440
	game.population.talk(person)
	check(game.conversation.text.contains("上次在榕树里"),"次日正常交談回应共同经历")
	game.close_interaction()
	# A physical object must prevent claiming its seat, without relocating the object.
	check(SaveGame.restore(game,original),"恢复空场所")
	await frames(4)
	var blockers: Array[StaticBody3D]=[]
	for side in range(2):
		var blocker := StaticBody3D.new(); game.add_child(blocker)
		blocker.position=bench.seat_point(side)+Vector3(0,.7,0)
		Shapes.collider(blocker,Vector3(.65,1.4,.65)); blockers.append(blocker)
	await frames(3)
	game.player.position=bench.approach()
	commons.use_bench(bench)
	check(not game.player.seated and commons.player_slot=="","实体阻挡座位不能强坐")
	for blocker in blockers: blocker.queue_free()
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	print("CITY_COMMONS_SAVE_TEST failures=",failures," corruptions=17 legacy_versions=17")
	game.queue_free()
	await process_frame
	quit(failures)

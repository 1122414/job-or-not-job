extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6): await physics_frame
	game.set_process(false)
	var life: CityLife=game.city_life
	game.panels.show_page("city")
	for i in range(4): await process_frame
	var button: Button=game.panels.view.buttons["city-bookshop"]
	game.panels.view.scroll.ensure_control_visible(button)
	for i in range(4): await process_frame
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position=button.get_global_rect().get_center()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=pressed
		root.push_input(click,true)
	check(life.guide=="notice" and game.navigation_target()==life.point_for("notice") and game.panels.page=="" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"真实地图点击导航到书屋且鼠标仍可见")
	life.guide=""
	var original := SaveGame.snapshot(game)
	# Boundary fixtures complement the real movement/input routes in city_bookshop_test.
	life.method="screen"; life.checked=true; life.prepared=true; life.joined=true; life.elapsed=7.5; life.guide="paper"
	life.participants.assign([game.population.residents[0].stable_id,game.population.residents[3].stable_id])
	var file := "user://city-activity-test.json"
	check(SaveGame.write(game,file)==OK,"进行中活动实际写盘")
	var saved := SaveGame.read(file,game)
	life.restore({})
	check(not saved.is_empty() and SaveGame.restore(game,saved),"校验封装并读取活动存档")
	check(life.elapsed==7.5 and life.checked and life.prepared and life.participants.size()==2,"恢复进度和实际参与身份")
	for corruption in ["missing","method","ready_screen","result","number","joined","unknown","duplicate","too_many","guide","prepared","schema"]:
		var bad := saved.duplicate(true)
		match corruption:
			"missing": bad.erase("city_life")
			"method": bad.city_life.method="money"
			"ready_screen": bad.city_life.checked=false
			"result": bad.city_life.result="garden"
			"number": bad.city_life.elapsed=INF
			"joined": bad.city_life.joined=false
			"unknown": bad.city_life.participants[0]="resident_unknown"
			"duplicate": bad.city_life.participants[1]=bad.city_life.participants[0]
			"too_many": bad.city_life.participants.append_array(["a","b"])
			"guide": bad.city_life.guide="outside"
			"prepared": bad.city_life.prepared=1
			"schema": bad.city_life.schema=2
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"拒绝坏档且完整世界不变 "+corruption)
	for version in range(1,15):
		var old := original.duplicate(true)
		old.version=version
		old.erase("city_life")
		if version<14: old.erase("city_population")
		if version<13: old.erase("city_driving")
		if version<12: old.erase("city_transit")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))) and life.method=="" and life.participants.is_empty(),"旧v%dJSON初始化场所活动" % version)
	check(SaveGame.restore(game,saved),"重新恢复活动用于完成/关系边界")
	life.elapsed=18; life.result="screen"
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.social.meet(npc)
	var before_affinity: int=npc.affinity
	game.social.handle("people_chat",npc)
	check(game.conversation.choices[0][1]=="people_bookshop","实际私人交谈入口包含已完成事件")
	game.social.handle("people_bookshop",npc)
	var affinity: int=npc.affinity
	var memories: Array=game.social.state(npc).memories.duplicate()
	game.social.handle("people_bookshop",npc)
	check(npc.affinity==affinity and game.social.state(npc).memories==memories and affinity>before_affinity,"关系记忆只计一次且不会刷奖励")
	check(game.career.stage==0 and game.career.employer=="" and game.payroll.balance==0,"分享经历不替代职业成果或工资")
	check(life.resident_line(game.population.residents[0]).contains("我记得") and not life.resident_line(game.population.residents[1]).contains("我记得"),"仅实际参与的居民记得事件")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) and game.social.state(npc).memories==memories,"完成结果与同事记忆JSON恢复")
	game.payroll.minute=1200
	var before := life.snapshot()
	life.open_point(life.point_for("notice"))
	life.answer(life.point_for("notice"),"city_plan_paper")
	check(life.snapshot()==before,"闭馆或已完成时不能覆盖事件结果")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	print("CITY_ACTIVITY_SAVE_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

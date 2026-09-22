extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func wait_frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await wait_frames(30)
	for npc in game.npcs:
		if npc.role not in ["guard","hr"]: check(npc.seated,"员工初始在工位办公："+npc.stable_id)
	check(game.office.assigned_desk()=="","未入职没有强制工位")
	for action in ["interview_hr","interview_lead","interview_boss","join_a"]: game.career.apply(action)
	check(game.office.assigned_desk()=="desk_a","实习入职分配一组工位")
	var desk: WorkStation
	for station in game.stations:
		if station.stable_id=="desk_a": desk=station
	game.player.position=desk.position+Vector3(0,0,1)
	await wait_frames(1000)
	check(game.career.facts.get("visit_state_welcome_a")=="arrived" and not game.career.facts.has("welcome_a"),"HR实际抵达不算交谈完成")
	check(game.nearest()==game.npc_for_role("a_hr"),"侧面到访的HR可直接交谈")
	game.office.answer_visit(game.npc_for_role("a_hr"),true)
	check(game.career.facts.has("welcome_a"),"确认后才完成欢迎")
	game.office.open_desk(desk)
	await wait_frames(1000)
	check(game.player.seated and game.career.facts.get("visit_state_visit_brief")=="arrived","坐下后主管实际来访")
	game.office.answer_visit(game.npc_for_role("a_lead"),false)
	check(not game.career.facts.has("visit_brief"),"稍后再聊不完成事件")
	game.office.answer_visit(game.npc_for_role("a_lead"),true)
	check(game.career.facts.has("brief"),"恢复交谈后实际交代工作")
	game.career.facts.erase("welcome_a")
	game.career.facts.visit_state_welcome_a="arrived"
	check(not game.office.pending_visits().is_empty(),"错过的欢迎仍列入可选交谈")
	check(ObjectiveGuide.current(game).id=="archive","旧欢迎不覆盖已经进入资料阶段的工作目标")
	game.career.facts.guide_visit="welcome_a"
	check(ObjectiveGuide.current(game).id=="a_hr","玩家可主动导航到错过的HR")
	game.career.facts.erase("guide_visit")
	game.office.answer_visit(game.npc_for_role("a_hr"),true)
	check(game.career.facts.has("welcome_a"),"旧欢迎仍可交谈完成")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,saved),"办公和来访结果可读档")
	check(game.career.facts.has("visit_brief"),"读档不重复首次来访")
	check(not game.player.seated,"读档恢复自由控制，不残留坐姿锁定")
	game.office.open_desk(desk)
	Input.action_press("forward")
	await wait_frames(2)
	Input.action_release("forward")
	check(not game.player.seated,"移动立即起身")
	for action in ["brief","data","prepare","shortcut","submit","no_hc","transfer"]: game.career.apply(action)
	check(game.office.assigned_desk()=="desk_a2","换组获得不同工位且保留原成果")
	check(game.career.facts.has("output_one"),"换组保留已通过成果")
	game.career.apply("backup")
	await wait_frames(2)
	for station in game.stations:
		if station.stable_id=="backup": check(station.screen.text.contains("在线"),"第二份成果必须改变设备画面")
	var boss: OfficeNPC=game.npc_for_role("a_boss")
	game.player.position=boss.position+Vector3(0,0,1)
	game.career.facts.visit_state_visit_defense="arrived"
	game.speaker=boss
	game.conversation=game.office.visit_choices(boss,OfficeDialogue.options(boss,game.career))
	check(game.conversation.choices[0][1]=="visit_confirm","答辩前先确认老板来访")
	game.choose(0)
	check(game.speaker==boss and not game.conversation.is_empty(),"确认来访后保持原交谈对象")
	var defense_found := false
	for choice in game.conversation.get("choices",[]):
		if choice[1]=="defend": defense_found=true
	check(defense_found,"来访确认后可直接答辩，不重新争抢附近交互")
	game.close_interaction()
	game.career.apply("defend")
	check(game.career.grade=="正式员工","实习两章最终真实转正")
	game.career.apply("resign")
	check(game.office.assigned_desk()=="" and game.office.visit().is_empty(),"离职清除工位归属和主动工作来访")
	print("OFFICE_LIFE_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

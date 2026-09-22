extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await physics_frame
	for action in ["interview_hr","interview_lead","interview_boss"]: game.recruitment.finish(action)
	game.recruitment.handle("rest_next"); game.recruitment.accept("a"); game.recruitment.handle("rest_next")
	var hr: OfficeNPC=game.npc_for_role("a_hr")
	game.player.position=hr.position+Vector3(0,0,1)
	game.recruitment.report("a")
	var first: String=game.conversation.text
	game.recruitment.handle("report_pause")
	game.recruitment.report("a")
	check(first==game.conversation.text and game.career.employer=="","暂停核对后仍需确认身份")
	game.choose(0)
	check(game.career.employer=="" and game.office.assigned_desk()=="","未领牌确认不能取得员工权限")
	game.choose(0)
	var card: OfficeProp=game.onboarding.badge("a")
	check(game.career.employer=="a" and game.player.inventory.has(card),"完成报到取得雇佣和实体工牌")
	check(not game.onboarding.account_ready(),"通知完成但账号组织尚未开通")
	game.player.pick(card); game.player.release(false)
	check(not game.player.inventory.has(card),"工牌可真实丢弃")
	game.speaker=hr
	game.conversation=game.onboarding.service_options(hr,{"text":"补办","choices":[]})
	for i in range(game.conversation.choices.size()):
		if game.conversation.choices[i][1]=="service_badge": game.choose(i); break
	check(game.player.inventory.has(card),"前台补办找回唯一工牌")
	game.speaker=hr
	game.onboarding.service("service_account")
	check(game.onboarding.account_ready(),"现场核对后修正账号")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"工牌归属账号状态可持久化")
	var legacy: Dictionary=saved.duplicate(true)
	legacy.version=10; legacy.erase("badge_schema"); legacy.erase("recruitment")
	legacy.props.erase("a_badge"); legacy.props.erase("b_badge")
	check(SaveGame.restore(game,legacy),"旧档仅补新增工牌，不要求旧物件缺失")
	check(game.career.employer=="a","旧在职不退回报到")
	var invalid: Dictionary=saved.duplicate(true)
	invalid.props.erase("a_keyboard")
	check(not SaveGame.valid(invalid,game),"迁移不放宽原物件完整性")
	var desk: WorkStation
	for station in game.stations:
		if station.stable_id=="desk_a": desk=station
	for prop in game.props:
		if prop.kind=="monitor" and prop.home.distance_to(desk.position)<2: prop.damaged=true; prop.durability=0
	check(game.office.desk_damaged(desk),"识别损坏的工作设备")
	game.office.repair_desk(desk)
	check(not game.office.desk_damaged(desk),"维修恢复工作入口")
	game.queue_free()
	await process_frame
	print("INTAKE_TEST failures=",failures)
	quit(failures)

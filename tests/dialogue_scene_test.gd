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
	game.interviews.schedule("interview_hr")
	var host: OfficeNPC=game.npc_for_role("a_hr")
	host.position=OfficeRooms.INTERVIEW_HOSTS.a
	game.player.position=OfficeRooms.INTERVIEW_SEATS.a
	for station in game.stations:
		if station.stable_id=="interview_a": game.speaker=station
	game.interviews.handle("interview_seat_a")
	check(game.conversation.get("scene",false) and game.conversation.text.length()<=46,"现场台词拆成短句")
	game.interact()
	var cursor: int=game.recruitment.scenes.a.line
	check(cursor==1 and game.interviews.sessions.a.step==0,"E仅推进台词，不偷偷选择")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"台词中途JSON恢复")
	check(game.recruitment.scenes.a.line==cursor,"读档保留已读句位置")
	game.interviews.handle("interview_seat_a")
	var text_before: String=game.conversation.text
	game.panels.show_page("help")
	check(paused and game.interviews.active_firm()=="","面板暂停并中断演出")
	game.panels.back()
	game.interviews.handle("interview_seat_a")
	check(game.conversation.text==text_before,"关闭帮助后续接而非重播")
	game.player.yaw=0.8
	for i in range(30): await physics_frame
	check(absf(game.player.yaw)<0.2,"交谈镜头平滑靠近目标")
	game.player.frame_remaining=0.7
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(20,0)
	if DisplayServer.get_name()=="headless": game.player.look(motion.relative)
	else: game.player._unhandled_input(motion)
	check(game.player.frame_remaining==0,"鼠标立即接管镜头")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var controlled_yaw: float=game.player.yaw
	for i in range(30): await physics_frame
	check(is_equal_approx(game.player.yaw,controlled_yaw),"接管后不再次强拉镜头")
	check(host.visual.current=="read","落座阅读动作")
	host.hit_stun=0.3
	game.interviews.tick()
	check(game.interviews.active_firm()=="" and not game.interviews.host_seated(host),"受击立即退出坐姿演出，不争抢动画")
	for value in ["read","write","message","pause"]:
		check(host.visual.animation.has_animation(value),"关键动作存在："+value)
	game.queue_free()
	await process_frame
	print("DIALOGUE_SCENE_TEST failures=",failures)
	quit(failures)

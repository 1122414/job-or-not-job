extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	for i in range(10): await physics_frame
	game.interviews.schedule("interview_b")
	var host: OfficeNPC=game.npc_for_role("b_hr")
	check(game.interviews.host_target(host)==OfficeRooms.INTERVIEW_CALLS.b,"预约后先前往面试室门口")
	var called := false
	for i in range(1200):
		if game.interviews.host_calling(host): called=true; break
		await physics_frame
	check(called,"面试官实际抵达门口并示意")
	for i in range(25): await physics_frame
	check(host.visual.current=="beckon","门口示意使用站姿骨骼动画")
	check(game.interviews.heard_cues.has("b/interview_b/call"),"叫号时触发椅子动作音效")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"候场中途保存读取可恢复叫号进度")
	check(game.interviews.sessions.b.call_stage=="calling","读档后叫号状态不丢失")
	host.position=host.home
	game.interviews.tick()
	check(game.interviews.sessions.b.call_stage=="approach","叫号者离开门口后重新到场，不在远处自动结束叫号")
	var seated := false
	for i in range(1200):
		if game.interviews.host_seated(host): seated=true; break
		await physics_frame
	check(seated,"面试官示意后实际回到座位")
	game.player.position=OfficeRooms.INTERVIEW_SEATS.b
	game.speaker=host
	game.interviews.handle("interview_seat_b")
	check(game.player.seated,"玩家能坐下开始面试")
	var session: Dictionary=game.interviews.sessions.b
	for item in game.interviews.pages("interview_b"): session.answers.append(item[1][0])
	session.step=game.interviews.pages("interview_b").size()
	session.phase="question"
	game.interviews.handle("interview_finish")
	check(session.status=="completed" and game.career.recruit.b==1,"结束交流只记录一次招聘进度")
	check(game.interviews.host_target(host)==OfficeRooms.INTERVIEW_CALLS.b,"结束后面试官起身离开座位")
	for i in range(330): await physics_frame
	check(game.interviews.host_target(host)==null,"送出场景结束后恢复正常日程")
	var older: Dictionary=SaveGame.snapshot(game)
	for key in ["call_stage","call_elapsed","exit_remaining","box_drop_done","gesture_done_step"]: older.interviews.b.erase(key)
	check(SaveGame.valid(older,game),"旧面试存档缺少演出字段仍可读取")
	game.queue_free()
	for i in range(3): await process_frame
	print("INTERVIEW_CALL_TEST failures=",failures)
	quit(failures)

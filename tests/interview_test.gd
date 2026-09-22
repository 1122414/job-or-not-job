extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	for action in InterviewFlow.ACTIONS:
		var firm := "b" if action=="interview_b" else "a"
		var before: int=game.career.recruit[firm]
		game.interviews.schedule(action)
		check(game.career.recruit[firm]==before,"预约不会直接通过面试")
		check(await preload("res://tests/scene_driver.gd").complete_interview(self,game,action,true),"实际步行、等待面试官、落座问答、中断存档继续："+action)
		check(game.career.recruit[firm]==before+1,"结束交流后推进一次")
		check(game.career.employer=="","面试不会自动入职")
	check(game.recruitment.applications.a.phase=="waiting","最终面试只能进入等待，不能提前接受或拒绝尚未收到的邀请")
	game.recruitment.handle("rest_next")
	game.recruitment.selected="a"
	game.recruitment.message_action(2)
	check(game.recruitment.applications.a.phase=="declined","收到邀请后可拒绝")
	check(game.career.employer=="" and game.career.recruit.a==3,"拒绝录用保留面试结果")
	game.recruitment.accept("a")
	game.recruitment.handle("rest_next")
	game.player.position=game.npc_for_role("a_hr").position+Vector3(0,0,1)
	game.recruitment.report("a")
	game.recruitment.handle("report_confirm_a")
	game.recruitment.handle("report_confirm_a")
	check(game.office.assigned_desk()=="desk_a","明确接受后才分配工位")
	var invalid: Dictionary=SaveGame.snapshot(game)
	invalid.interviews.a.step=100
	check(not SaveGame.valid(invalid,game),"越界面试存档拒绝")
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"恢复全新测试场景")
	game.interviews.schedule("interview_hr")
	game.interviews.sessions.a.step=1
	game.interviews.sessions.a.answers=["确认具体产出和评价标准"]
	var original: OfficeNPC=game.npc_for_role("a_hr")
	original.hit(Vector3.FORWARD,5.0,game.next_action())
	for npc in game.npcs: npc.hostile=0; npc.reaction=0
	game.staffing.tick(30)
	check(game.npc_for_role("a_hr")!=original,"面试岗位死亡后安排新人")
	check(game.interviews.sessions.a.step==1,"接替不丢弃已聊内容")
	# Resume remaining pages through the same scene helper from a fresh question count.
	game.interviews.sessions.a.step=0
	game.interviews.sessions.a.answers=[]
	check(await preload("res://tests/scene_driver.gd").complete_interview(self,game,"interview_hr"),"接替者从入口走进面试室并实际完成交流")
	check(original.dead and game.career.recruit.a==1,"原人不复活且职业线可继续")
	game.queue_free()
	await process_frame
	print("INTERVIEW_TEST failures=",failures)
	quit(failures)

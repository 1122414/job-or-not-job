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
	var lead: OfficeNPC=game.npc_for_role("a_lead")
	var session := {"action":"interview_lead","step":2,"phase":"reply","reply":0,"answers":["前段","前段","‘后面的事’是正式岗位吗"]}
	check(game.recruitment.promises.is_empty(),"新档不伪造约定")
	game.promises.heard(session,lead)
	game.promises.heard(session,lead)
	check(game.recruitment.promises.size()==1,"重播不重复记录")
	check(game.recruitment.promises[0].quote==InterviewContent.CORE.interview_lead[2][2][0],"只引用该次实际回复原文")
	for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data","prepare","shortcut","submit"]: game.career.apply(action)
	game.promises.handle("no_hc",lead)
	check(game.career.stage==3 and game.conversation.text.contains("记录"),"成果通过但HC未批，引用约定")
	game.promises.handle("promise_written",lead)
	check(game.career.facts.has("written_review") and game.career.stage==3,"书面追问不凭空产生HC")
	check(not game.promises.support_available(),"陌生同事不凭空主动支持")
	var friend: OfficeNPC=game.npc_for_role("a_friend")
	game.social.remember(friend,"joint_work","核对原文并共同完成交付",12,9)
	check(game.promises.support_available(),"共同经历允许同事主动提供支持")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"承诺、回应和成果持久化")
	lead.dead=true; lead.hp=0
	game.staffing.calm.a=30
	game.staffing.tick(0.1)
	var replacement: OfficeNPC=game.npc_for_role("a_lead")
	check(replacement!=lead,"岗位换人")
	if replacement!=lead:
		game.promises.review(replacement)
		check(game.conversation.text.contains("接手") and game.social.state(replacement).trust==0,"接替可处理岗位约定，不继承私人信任")
	check(game.career.facts.has("output_one"),"岗位更换不丢成果")
	game.queue_free()
	await process_frame
	print("PROMISES_TEST failures=",failures)
	quit(failures)

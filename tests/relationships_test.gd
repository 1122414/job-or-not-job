extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	var friend: OfficeNPC=game.npc_for_role("a_friend")
	check(game.social.describe(friend)=="陌生","新人物以描述呈现")
	game.social.meet(friend)
	game.social.handle("people_chat",friend)
	var affinity: int=friend.affinity
	for i in range(20): game.social.handle("people_chat",friend)
	check(friend.affinity==affinity,"同一天重复聊天不能刷关系")
	for kind in ["tea","lunch","walk"]:
		game.payroll.minute={"tea":600,"lunch":750,"walk":1110}[kind]
		game.social.handle("people_invite_"+kind,friend)
		check(game.social.outing.get("stage")=="walking","日常活动接受后有实际行走目标："+kind)
		check(not game.social.state(friend).days.has("outing_0"),"未到场交谈不计完成")
		friend.position=game.social.destination(friend,kind)
		game.player.position=friend.position+Vector3(1,0,0)
		game.social.handle("people_share",friend)
		check(game.conversation.choices[0][1]=="people_listen","到场后才进入具体生活话题")
		if kind!="walk": game.social.handle("people_pause",friend)
		else: game.social.handle("people_listen",friend)
	check(game.social.state(friend).days.has("outing_0"),"实际回应才记录共同经历")
	var snapshot: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,snapshot),"关系和经历可保存恢复")
	friend.hit(Vector3.RIGHT,0.5,game.next_action(),false)
	check(game.social.describe(friend).contains("戒心") and not game.social.willing(friend),"打人后戒备并拒绝私人邀约")
	game.social.handle("people_apologize",friend)
	var trust: int=game.social.state(friend).trust
	for i in range(10): game.social.handle("people_apologize",friend)
	check(game.social.state(friend).trust==trust and not game.social.willing(friend),"道歉不可刷分且不立即修复伤害")
	for action in ["interview_hr","interview_lead","interview_boss","join_a","data"]: game.career.apply(action)
	var choices: Array=OfficeDialogue.options(friend,game.career).choices
	check(choices.any(func(c): return c[1]=="shortcut"),"疏远不封锁必要工作资料")
	var malformed: Dictionary=SaveGame.snapshot(game)
	malformed.social.people[friend.stable_id].trust="bad"
	check(not SaveGame.valid(malformed,game),"拒绝损坏的关系字段")
	var old: Dictionary=snapshot.duplicate(true)
	old.version=8
	old.erase("social")
	check(SaveGame.restore(game,old) and friend.affinity==affinity+6,"旧档保留好感但不伪造共同经历")
	game.panels.show_page("people")
	var minute: int=game.payroll.minute
	for i in range(10): await process_frame
	check(paused and game.payroll.minute==minute,"人物页暂停世界")
	game.panels.back()
	game.queue_free()
	await process_frame
	print("RELATIONSHIPS_TEST failures=",failures)
	quit(failures)

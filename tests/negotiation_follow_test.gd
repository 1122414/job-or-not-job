extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	for action in ["interview_b","join_b","negotiate"]: game.career.apply(action)
	game.career.facts["welcome_b"]=true
	var friend: OfficeNPC=game.npc_for_role("b_friend")
	game.social.meet(friend)
	var trust: int=game.social.state(friend).trust
	game.social.outing={"person":friend.stable_id,"kind":"tea","stage":"offered","elapsed":58.0}
	check(game.social.npc_target(friend)==null,"待回复社交邀请不能压住工作跟随")
	game.social.tick(3.0)
	check(not game.social.outing.is_empty() and game.social.outing.elapsed==58.0,"协商期间暂停邀请过期计时")
	game.social.outing={"person":friend.stable_id,"kind":"tea","stage":"walking","elapsed":0.0}
	check(game.social.npc_target(friend)==null,"已接受同行暂让工作跟随优先，约定仍保留")
	friend.position=Vector3(18,0,0.2)
	friend.route_clock=0
	game.player.position=Vector3(8,0,-7.4)
	for i in range(900):
		if friend.position.distance_to(game.player.position)<3.0: break
		await physics_frame
	check(friend.position.distance_to(game.player.position)<3.0,"协商同事实际从入职终点走到老板附近")
	check(game.social.outing.get("stage")=="walking" and game.social.state(friend).trust==trust,"工作跟随不取消私下约定或扣信任")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) ,"同行和协商同时存在时JSON存档可恢复")
	game.career.b_event="negotiated"
	check(game.social.npc_target(friend)!=null,"协商完成后恢复原同行意图")
	game.social.outing={}
	game.career.b_event="negotiating"
	friend.position=game.player.position+Vector3(1.5,0,0)
	game.social.state(friend).days.clear()
	game.social.tick(0.1)
	check(game.social.outing.is_empty(),"正在执行协商跟随时不新增社交邀请")
	game.queue_free()
	await process_frame
	print("NEGOTIATION_FOLLOW_TEST failures=",failures)
	quit(failures)

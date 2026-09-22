extends RefCounted

static func walk(tree: SceneTree,game: Node3D,destination: Vector3) -> bool:
	game.player.stand_up()
	var route: PackedVector3Array=game.walking.route(game.player.position,destination)
	if route.is_empty(): push_warning("no route: "+str(game.player.position)+" -> "+str(destination)); return false
	for point in route:
		for i in range(120):
			var offset: Vector3=point-game.player.position
			offset.y=0
			if offset.length()<0.21: break
			game.player.yaw=atan2(-offset.x,-offset.z)
			Input.action_press("forward")
			await tree.physics_frame
	Input.action_release("forward")
	game.player.yaw=0
	return Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<0.7

static func complete_interview(tree: SceneTree,game: Node3D,action: String,exercise_resume: bool=false) -> bool:
	var firm := "b" if action=="interview_b" else "a"
	if not await walk(tree,game,OfficeRooms.INTERVIEW_SEATS[firm]): push_warning("walk blocked: "+action+" "+str(game.player.position)); return false
	var host: OfficeNPC=game.npc_for_role(InterviewFlow.HOSTS[action])
	for i in range(1200):
		if host and game.interviews.host_seated(host): break
		await tree.physics_frame
	game.interact()
	if game.conversation.is_empty() or game.conversation.choices.is_empty():
		push_error("面试交互不可用 "+action+" player="+str(game.player.position)+" host="+str(host.position)+" seated="+str(game.interviews.host_seated(host))+" nearest="+str(game.nearest())+" conversation="+str(game.conversation))
		return false
	if game.conversation.choices[0][1]!="interview_seat_"+firm:
		push_error("面试入口未选中 "+action+" "+str(game.conversation))
		return false
	game.choose(0)
	for step in range(6):
		game.choose(step%3)
		if step==0 and exercise_resume:
			var saved := SaveGame.snapshot(game)
			game.close_interaction()
			if not SaveGame.restore(game,saved): return false
			game.interact()
			game.choose(0)
		game.choose(0)
	game.choose(0)
	if game.interviews.sessions[firm].status!="completed":
		push_error("面试未完成 "+action+" player="+str(game.player.position)+" session="+str(game.interviews.sessions[firm])+" conversation="+str(game.conversation))
		return false
	return true

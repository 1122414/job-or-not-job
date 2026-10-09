extends RefCounted

static func steer_around_people(game: Node3D,direction: Vector3) -> Vector3:
	direction.y=0
	direction=direction.normalized()
	for other in game.npcs+game.population.residents:
		var away: Vector3=game.player.position-other.position
		away.y=0
		if away.length()<1.05 and away.length()>.01 and direction.dot(-away.normalized())>.1:
			var side := Vector3(-direction.z,0,direction.x)
			if away.dot(side)<0: side=-side
			direction=(direction+side*clampf((1.05-away.length())*4.0,0,2.0)).normalized()
	return direction

static func walk(tree: SceneTree,game: Node3D,destination: Vector3) -> bool:
	game.player.stand_up()
	var route: PackedVector3Array=game.walking.route(game.player.position,destination,null,game.player)
	if route.is_empty(): route=game.walking.route(game.player.position,destination)
	if route.is_empty(): push_warning("no route: "+str(game.player.position)+" -> "+str(destination)); return false
	var length: float=game.player.position.distance_to(route[0])
	for i in range(1,route.size()): length+=route[i-1].distance_to(route[i])
	var budget := ceili(length/game.player.walk_speed*60)*3+600
	var previous: Vector3=game.player.position
	var stalled := 0
	for frame in range(budget):
		while not route.is_empty() and Vector2(route[0].x-game.player.position.x,route[0].z-game.player.position.z).length()<.08: route.remove_at(0)
		if route.is_empty(): break
		stalled=stalled+1 if game.player.position.distance_to(previous)<.005 else 0
		previous=game.player.position
		if stalled>=30:
			route=game.walking.route(game.player.position,destination,null,game.player)
			if route.is_empty(): route=game.walking.route(game.player.position,destination)
			stalled=0
			continue
		var offset: Vector3=route[0]-game.player.position
		offset.y=0
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
	for step in range(5):
		if game.interviews.sessions[firm].step>=game.interviews.pages(action).size(): break
		for line in range(20):
			if not game.conversation.choices.is_empty(): break
			game.interact()
		game.choose(step%game.conversation.choices.size())
		if step==0 and exercise_resume:
			var saved := SaveGame.snapshot(game)
			game.close_interaction()
			if not SaveGame.restore(game,saved): return false
			game.interact()
			game.choose(0)
		for line in range(20):
			if game.interviews.sessions[firm].phase!="reply": break
			game.interact()
	for line in range(20):
		if game.interviews.sessions[firm].status=="completed": break
		game.interact()
	if game.interviews.sessions[firm].status!="completed":
		push_error("面试未完成 "+action+" player="+str(game.player.position)+" session="+str(game.interviews.sessions[firm])+" conversation="+str(game.conversation))
		return false
	return true

static func follow(tree: SceneTree,game: Node3D,npc: OfficeNPC,destination: Vector3,limit: int=3600) -> bool:
	var path := PackedVector3Array()
	for frame in range(limit):
		var distance: float=game.player.position.distance_to(npc.position)
		if npc.position.distance_to(destination)<0.7 and distance<2.8:
			Input.action_release("forward")
			return true
		if frame%30==0: path=game.walking.route(game.player.position,npc.position,null,game.player)
		while not path.is_empty() and game.player.position.distance_to(path[0])<0.15: path.remove_at(0)
		if distance>1.65 and not path.is_empty():
			var offset := steer_around_people(game,path[0]-game.player.position)
			game.player.yaw=atan2(-offset.x,-offset.z)
			Input.action_press("forward")
		else: Input.action_release("forward")
		await tree.physics_frame
	Input.action_release("forward")
	push_error("同行未抵达 player="+str(game.player.position)+" npc="+str(npc.position)+" destination="+str(destination))
	return false

static func computer(game: Node3D) -> bool:
	if game.panels.page!="computer": return false
	for key in [1,2,3,4,5]: game.projects.key(key)
	if game.career.employer=="a": game.projects.key(5) # offline for this route
	elif game.career.b_event=="negotiating": game.projects.key(5)
	game.projects.key(6)
	if game.career.employer=="b": game.projects.key(7)
	var s: Dictionary=game.projects.state(game.career.employer)
	var ok: bool=s.preview!="" and s.preview!="error"
	game.panels.back()
	return ok

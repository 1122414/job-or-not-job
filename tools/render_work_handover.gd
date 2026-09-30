extends "res://tools/render_city_home.gd"

var handover_before := Vector3.ZERO
var worker_metres := 0.0
var worker_max_step := 0.0
var delivery_observation := {}

func record_step(game: Node3D) -> void:
	super.record_step(game)
	var person: OfficeNPC=game.npc_for_role("b_friend")
	var step: float=person.position.distance_to(handover_before)
	worker_metres+=step;worker_max_step=maxf(worker_max_step,step);handover_before=person.position
	if game.handover.data.get("phase")=="delivered" and delivery_observation.is_empty():
		delivery_observation={"minute":game.payroll.minute,"player":SaveGame.vector(game.player.position),"outside_office":not CityFootRoutes.in_office(game.player.position)}

func press_button(viewport: SubViewport,game: Node3D,id: String) -> bool:
	for i in range(4):await process_frame
	var view: GamePageView=game.panels.view
	if not view.buttons.has(id):push_error("Missing button "+id);return false
	var button: Button=view.buttons[id]
	view.scroll.ensure_control_visible(button)
	for i in range(4):await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		viewport.push_input(event,true)
	return guard()

func perform(viewport: SubViewport,game: Node3D,id: String,action: String) -> bool:
	print("HANDOVER_ROUTE_STEP ",id," / ",action)
	var target: Node3D=game.npc_for_role(id)
	if not target:
		for station in game.stations:
			if station.stable_id==id:target=station
	if not target:return false
	game.close_interaction()
	var reached := false
	for attempt in range(8):
		if not await Driver.walk(self,game,target.position+Vector3(sin(attempt*TAU/8),0,cos(attempt*TAU/8))*1.2):continue
		var toward: Vector3=target.position-game.player.position
		game.player.yaw=atan2(-toward.x,-toward.z)
		await physics_frame
		if game.nearest()==target:reached=true;break
	if not reached:push_error("Route cannot approach "+id);return false
	key(viewport,KEY_E)
	if game.conversation.get("choices",[]).any(func(c):return c[1]=="visit_confirm"):
		if not choose(viewport,game,"visit_confirm"):return false
		if game.conversation.is_empty():key(viewport,KEY_E)
	if action=="settle":
		for i in range(900):
			if game.npc_for_role("b_friend").position.distance_to(target.position)<3.8:break
			await physics_frame
	if not choose(viewport,game,action):return false
	if action.begins_with("report_"):
		key(viewport,KEY_1);key(viewport,KEY_1)
	if action in ["tour_begin","tour_greet"]:
		if not await Driver.follow(self,game,game.onboarding.guide(),game.onboarding.destination()):return false
	if action=="interview_b":return await Driver.complete_interview(self,game,action)
	if action=="computer_open" and game.handover.data.is_empty():
		if game.panels.page!="computer":return false
		for code in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_5,KEY_6,KEY_7]:key(viewport,code)
		if not game.projects.state("b").proposal:return false
		key(viewport,KEY_ESCAPE)
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	game.player.pitch=-.08
	if not guard() or game.persistence_enabled:push_error("Unsafe route startup");quit(1);return
	if not await perform(viewport,game,"b_hr","interview_b") or not await perform(viewport,game,"rest","rest_next"):quit(1);return
	key(viewport,KEY_N)
	if not await press_button(viewport,game,"firm-b") or not await press_button(viewport,game,"reply-0"):quit(1);return
	key(viewport,KEY_ESCAPE)
	for step in [["rest","rest_next"],["b_hr","report_b"],["b_friend","tour_begin"],["b_friend","tour_greet"],["b_friend","tour_settle"],["desk_b","desk_open"],["b_hr","service_account"],["b_friend","negotiate"],["desk_b","computer_open"],["b_boss","settle"]]:
		if not await perform(viewport,game,step[0],step[1]):quit(1);return
	if game.handover.data.get("phase")!="pending" or game.career.b_event!="negotiated":push_error("Actual agreement did not schedule work");quit(1);return
	var due_at: int=game.handover.data.due_at
	var worker: OfficeNPC=game.npc_for_role("b_friend")
	player_previous=game.player.position;handover_before=worker.position
	var monitor: Callable=record_step.bind(game)
	physics_frame.connect(monitor)
	if not await shot(viewport,game,"confirmed-next-day"):quit(1);return
	travelling=true
	if not await Driver.walk(self,game,Vector3(0,0,23)):quit(1);return
	travelling=false
	if not await go(game,[Vector3(0,0,58),Vector3(-64,0,58),Vector3(-56,0,52),Vector3(-52,0,43),Vector3(-52,0,35),Vector3(-55.7,0,30.5)]):quit(1);return
	if not await interact_with(viewport,game,game.city_life.point_for("paper")) or not choose(viewport,game,"city_read"):quit(1);return
	if not await shot(viewport,game,"own-time-bookshop") or not choose(viewport,game,"city_leave"):quit(1);return
	if not await go(game,[Vector3(-52,0,35),Vector3(-52,0,43),Vector3(-56,0,52),Vector3(-64,0,58),Vector3(58,0,58),Vector3(58,0,44),Vector3(56,0,42),Vector3(56,0,37),Vector3(56,0,33.3),Vector3(53.6,0,33.3),Vector3(53.6,0,29.1),Vector3(51.95,0,29.1)]):quit(1);return
	if not await use_home(viewport,game,"home_bed") or not choose(viewport,game,"home_evening"):quit(1);return
	if not await shot(viewport,game,"home-evening"):quit(1);return
	if not await use_home(viewport,game,"home_bed") or not choose(viewport,game,"home_morning"):quit(1);return
	if game.handover.data.due_at!=due_at or game.handover.data.elapsed!=0 or game.payroll.minute!=due_at-60:push_error("Home rest fabricated work or changed agreement");quit(1);return
	if not await shot(viewport,game,"next-morning-at-home"):quit(1);return
	if SaveGame.write(game,output.path_join("morning-route.json"))!=OK:quit(1);return
	if not await go(game,[Vector3(53.6,0,29.1),Vector3(53.6,0,33.3),Vector3(56,0,33.3),Vector3(56,0,37),Vector3(56,0,42),Vector3(58,0,44),Vector3(58,0,58),Vector3(0,0,58),Vector3(0,0,23)]):quit(1);return
	travelling=true
	if not await Driver.walk(self,game,Vector3(24.4,0,-1.6)):
		push_error("Cannot reach terminal aisle from "+str(game.player.position));quit(1);return
	travelling=false
	var toward: Vector3=worker.position-game.player.position
	game.player.yaw=atan2(-toward.x,-toward.z)
	for i in range(12000):
		if game.handover.data.elapsed>3:break
		await physics_frame
	if game.handover.data.elapsed<=3:push_error("Coworker never started actual work");quit(1);return
	if not game.social.outing.is_empty():push_error("Work invented an unaccepted private commitment");quit(1);return
	toward=worker.position-game.player.position;game.player.yaw=atan2(-toward.x,-toward.z)
	for i in range(20):await physics_frame
	if not await shot(viewport,game,"coworker-sending-player-camera"):quit(1);return
	if SaveGame.write(game,output.path_join("working-route.json"))!=OK:quit(1);return
	var camera := Camera3D.new();game.add_child(camera);camera.fov=55
	camera.position=worker.position+Vector3(2,1.6,1.2);camera.look_at(worker.position+Vector3(0,1.0,-.2));camera.make_current()
	if not await shot(viewport,game,"keyboard-contact-diagnostic"):quit(1);return
	game.player.camera.make_current();camera.queue_free()
	# The player leaves while work is still active; receipt must arrive off-site.
	travelling=true
	if not await Driver.walk(self,game,Vector3(0,0,23)):quit(1);return
	travelling=false
	if not await go(game,[Vector3(0,0,58)]):quit(1);return
	for i in range(2400):
		if game.handover.data.phase=="delivered":break
		await physics_frame
	if game.handover.data.phase!="delivered" or game.handover.data.sender!=worker.stable_id or game.career.b_event!="negotiated" or game.career.facts.has("b_help"):push_error("Off-site autonomous delivery failed");quit(1);return
	key(viewport,KEY_N)
	if not await press_button(viewport,game,"firm-b") or not await shot(viewport,game,"off-site-receipt"):quit(1);return
	key(viewport,KEY_ESCAPE)
	if SaveGame.write(game,output.path_join("completed-route.json"))!=OK:quit(1);return
	if not await go(game,[Vector3(0,0,23)]):quit(1);return
	travelling=true
	if not await perform(viewport,game,"desk_b","computer_open"):quit(1);return
	travelling=false
	if not game.projects.feedback.contains("已将完整交接包") or not game.panels.view.buttons["project-4"].disabled or game.panels.view.buttons["document-0"].disabled:push_error("Completed desktop state inconsistent");quit(1);return
	if not await shot(viewport,game,"next-day-workstation"):quit(1);return
	key(viewport,KEY_1);key(viewport,KEY_4)
	if game.handover.data.phase!="delivered":push_error("Read-only receipt mutated");quit(1);return
	key(viewport,KEY_ESCAPE)
	physics_frame.disconnect(monitor)
	var result := {"images":captures,"visits":visits,"handover":game.handover.data,"delivery_observation":delivery_observation,"walking_metres":metres,"max_player_step":max_step,"worker_metres":worker_metres,"max_worker_step":worker_max_step,"background_guard":desktop_safe and guard(),"persistence":game.persistence_enabled,"fresh_career_route":true,"interview_existing_driver_commands":true,"world_choices_keyboard":true,"message_mouse_buttons":true,"no_post_agreement_teleports":true,"normal_game_fps":false,"independent_player_acceptance":false}
	if not desktop_safe or not guard() or game.persistence_enabled or metres<350 or max_step>.2 or worker_max_step>.1 or not delivery_observation.get("outside_office",false):push_error("Continuity route failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("WORK_HANDOVER_ROUTE_OK ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit()

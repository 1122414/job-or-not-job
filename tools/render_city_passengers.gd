extends SceneTree

# This same standalone probe can run against source or an exported app. It uses
# a separate viewport and never focuses the desktop window or captures the mouse.
var output := "res://build/c2c/ride"
var game: Node3D
var view: SubViewport
var images: Array[String]=[]
var transitions := []
var stages := {}
var safe := true
var foot := true
var walked := 0.0
var maximum_step := 0.0
var previous := Vector3.ZERO
var frame_number := 0
var minimum_exit_spacing := 1000.0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func monitor() -> void:
	frame_number+=1
	if foot:
		var step: float=game.player.position.distance_to(previous)
		walked+=step;maximum_step=maxf(maximum_step,step)
	previous=game.player.position;safe=safe and guard()
	var exited: Array[CityResident]=[]
	for person in game.population.residents:
		var trip: Dictionary=game.passengers.trips.get(person.stable_id,{})
		var stage: String=trip.get("stage","activity")
		if stages.get(person.stable_id,"")==stage:continue
		if stages.get(person.stable_id,"")=="riding" and stage!="riding":exited.append(person)
		stages[person.stable_id]=stage
		transitions.append({"frame":frame_number,"resident":person.stable_id,"stage":stage,"position":SaveGame.vector(person.position),"bus_stop":game.transit.current_stop})
	for a in range(exited.size()):
		for b in range(a+1,exited.size()):minimum_exit_spacing=minf(minimum_exit_spacing,exited[a].position.distance_to(exited[b].position))

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		view.push_input(event,true)

func click(id: String) -> bool:
	for i in range(5):await process_frame
	var page: GamePageView=game.panels.view
	if not page.buttons.has(id):push_error("Bus control missing "+id+" page="+game.panels.page);return false
	var button: Button=page.buttons[id]
	page.scroll.ensure_control_visible(button)
	for i in range(5):await process_frame
	if button.disabled:return false
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		view.push_input(event,true)
	return guard()

func capture(title: String) -> bool:
	var was_paused := paused
	paused=true
	for i in range(3):await process_frame;RenderingServer.force_draw(false)
	var picture := view.get_texture().get_image()
	var ok := guard() and picture!=null and not picture.is_empty() and picture.save_png(output.path_join(title+".png"))==OK
	paused=was_paused
	if ok:images.append(title)
	return ok

func walk_to(point: Vector3) -> bool:
	for i in range(1800):
		var offset: Vector3=point-game.player.position;offset.y=0
		if offset.length()<.22:Input.action_release("forward");return true
		game.player.yaw=atan2(-offset.x,-offset.z);Input.action_press("forward")
		await physics_frame
	Input.action_release("forward")
	push_error("Passenger route blocked "+str(game.player.position)+" toward "+str(point));return false

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for i in range(10):await physics_frame
	previous=game.player.position;physics_frame.connect(monitor)
	game.player.pitch=-.1
	if not await walk_to(Vector3(-15,0,14.5)) or not await walk_to(Vector3(-6,0,12.5)):quit(1);return
	game.player.yaw=0
	for i in range(10):await physics_frame
	if not await capture("platform-before-boarding"):quit(1);return
	key(KEY_E)
	if not await capture("bus-board-control"):quit(1);return
	foot=false
	if not await click("bus-board") or not game.transit.riding:push_error("Actual boarding failed");quit(1);return
	var person: CityResident=game.population.residents[4]
	var observed_shared := false
	var observed_subject := false
	var requested := false
	var arrived := false
	for frame in range(18000):
		await physics_frame
		if not observed_shared and game.population.residents.any(func(actor):return game.passengers.aboard(actor)):
			observed_shared=true
			game.player.yaw=game.transit.bus.rotation.y+PI;game.player.pitch=-.1
			for i in range(20):await physics_frame
			if not await capture("first-public-passengers"):quit(1);return
		if not observed_subject and game.passengers.aboard(person):
			observed_subject=true
			game.player.yaw=game.transit.bus.rotation.y-PI/2;game.player.pitch=-.1
			for i in range(20):await physics_frame
			if not await capture("shared-ride-player-camera"):quit(1);return
			if SaveGame.write(game,output.path_join("shared-ride.json"))!=OK:push_error("Actual shared ride save invalid");quit(1);return
			# Labelled diagnostic camera supplements, never replaces, player views.
			var camera := Camera3D.new();game.add_child(camera);camera.fov=55;camera.make_current()
			camera.position=game.transit.bus.to_global(Vector3(3.8,2.6,-4.8));camera.look_at(person.position+Vector3.UP*.85)
			if not await capture("seat-contact-diagnostic"):quit(1);return
			game.player.camera.make_current();camera.queue_free()
		if observed_subject and not requested and game.transit.current_stop<0:
			key(KEY_E)
			if not await click("bus-request") or not game.transit.requested:push_error("Actual stop request failed");quit(1);return
			requested=true
		if requested and game.transit.current_stop==1 and not game.passengers.aboard(person) and person.position.distance_to(CityLayout.STOPS[1].platform)>1.1:
			arrived=true;break
	if not arrived or not observed_shared:push_error("Natural shared journey incomplete "+JSON.stringify(transitions));quit(1);return
	if not await capture("resident-resumes-destination"):quit(1);return
	key(KEY_E)
	if not await click("bus-leave") or game.transit.riding:push_error("Actual player exit failed");quit(1);return
	previous=game.player.position;foot=true
	if not await walk_to(Vector3(-69,0,60)):quit(1);return
	game.player.yaw=PI/2
	for i in range(20):await physics_frame
	if not await capture("player-market-platform"):quit(1);return
	if SaveGame.write(game,output.path_join("after-ride.json"))!=OK:push_error("Completed route save invalid");quit(1);return
	physics_frame.disconnect(monitor)
	var build := BuildInfo.read()
	var result := {"images":images,"transitions":transitions,"walking_metres":walked,"maximum_walk_step":maximum_step,"clock":game.payroll.minute,"resident_destination":person.destination,"actual_E_and_mouse_controls":true,"natural_resident_journey":true,"bounded_seat_platform_transfers":true,"background_guard":safe and guard(),"persistence":game.persistence_enabled,"normal_game_fps":false,"independent_player_acceptance":false,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"build_id":build.get("build_id","source"),"source_sha256":build.get("source_sha256","")}
	result.minimum_same_frame_exit_spacing=minimum_exit_spacing
	if not safe or not guard() or game.persistence_enabled or maximum_step>.2 or walked<15 or person.destination!="market" or minimum_exit_spacing<.8:push_error("Passenger route validation failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CITY_PASSENGERS_GUI_OK ",JSON.stringify(result))
	view.queue_free();await process_frame;quit()

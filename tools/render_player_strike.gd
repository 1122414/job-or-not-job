extends SceneTree

var output := "res://build/attack-window-2026-10-01/render"
var captures := 0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("background_run")
func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE
func background_run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	await run()
func capture(viewport: SubViewport,game: Node3D,label: String) -> bool:
	var mode := game.process_mode;game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(3):await process_frame;RenderingServer.force_draw(false)
	var picture := viewport.get_texture().get_image()
	var ok := not picture.is_empty() and picture.save_png(output.path_join(label+".png"))==OK and guard()
	game.process_mode=mode
	if ok:captures+=1
	return ok
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new();viewport.size=Vector2i(1280,800)
	viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	for npc in game.npcs:npc.set_physics_process(false);npc.position=Vector3(40+game.npcs.find(npc)*2,0,80)
	for person in game.population.residents:person.set_physics_process(false);person.position=Vector3(-40-person.index*2,0,80)
	game.payroll.minute=630;game.update_daylight();game.audio.stop()
	var victim: OfficeNPC=game.npc_for_role("a_hr")
	var side_camera := Camera3D.new();game.add_child(side_camera);side_camera.fov=50
	side_camera.position=Vector3(2.2,1.7,45.2);side_camera.look_at(Vector3(0,1.15,43.7))
	var keyboard: OfficeProp
	for prop in game.props:
		if prop.kind=="keyboard":keyboard=prop;break
	var records := []
	for scenario in ["normal-near","side-near","side-remote","side-wall","side-keyboard"]:
		game.player.store_held();game.player.cancel_strike();game.player.cooldown=0
		game.player.position=Vector3(0,0,44);game.player.yaw=0;game.player.pitch=-.12
		game.player.visual.rotation=Vector3.ZERO;game.player.velocity=Vector3.ZERO
		victim.position=Vector3(0,0,42.5 if scenario=="side-remote" else 43.25)
		victim.home=victim.position;victim.hp=100;victim.dead=false;victim.down=0;victim.care_state="awake";victim.reaction=0;victim.hostile=0;victim.hit_stun=0;victim.hit_push=Vector3.ZERO;victim.last_hit=-1
		victim.sync_care();victim.set_physics_process(true)
		var wall: Node3D
		if scenario=="side-wall":wall=Shapes.solid(game,Vector3(1.5,2,.03),Vector3(0,1,43.58),Color("838990"))
		if scenario=="side-keyboard":game.player.pick(keyboard)
		if scenario=="normal-near":game.player.camera.make_current()
		else:side_camera.make_current()
		for i in range(12):await physics_frame
		if not await capture(viewport,game,scenario+"-before"):quit(1);return
		for pressed in [true,false]:
			var event := InputEventAction.new();event.action="attack";event.pressed=pressed;viewport.push_input(event,true)
		var samples := [];var first_hit := -1.0;var photographed_hit := false
		for frame in range(38):
			await physics_frame
			var phase: float=game.player.visual.animation.current_animation_position
			samples.append({"frame":frame,"phase":phase,"hp":victim.hp,"player":SaveGame.vector(game.player.position),"victim":SaveGame.vector(victim.position),"palm":SaveGame.vector(game.player.visual.contacts.palm("R").origin),"pending":game.player.strike_action})
			if frame==3:
				if victim.hp!=100:push_error("Damage precedes windup");quit(1);return
				if not await capture(viewport,game,scenario+"-windup"):quit(1);return
			if victim.hp<100 and not photographed_hit:
				first_hit=phase;photographed_hit=true
				if not await capture(viewport,game,scenario+"-contact"):quit(1);return
				if scenario=="side-near":
					var camera_frame := side_camera.transform
					var palm: Vector3=game.player.visual.contacts.palm("R").origin
					side_camera.position=palm+Vector3(.40,.14,.35);side_camera.look_at(palm)
					if not await capture(viewport,game,"fist-close"):quit(1);return
					side_camera.transform=camera_frame
			if frame==16 and not photographed_hit and not await capture(viewport,game,scenario+"-miss"):quit(1);return
		if not await capture(viewport,game,scenario+"-return"):quit(1);return
		var expected := 100 if scenario in ["side-remote","side-wall"] else 88
		if victim.hp!=expected or not guard() or game.persistence_enabled:push_error("Strike render scenario mismatch "+scenario+" hp="+str(victim.hp));quit(1);return
		records.append({"scenario":scenario,"first_hit_phase":first_hit,"final_hp":victim.hp,"samples":samples})
		victim.set_physics_process(false)
		if is_instance_valid(wall):wall.queue_free()
		await physics_frame
	var result := {"images":captures,"records":records,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"background_guard":guard(),"persistence":game.persistence_enabled,"normal_player_camera_included":true,"scenario_placement_fixture":true,"captures_freeze_between_physics_steps":true,"normal_game_fps":false,"independent_player_acceptance":false}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
	print("PLAYER_STRIKE_RENDER_OK images=",captures," background_guard=",guard()," persistence=",game.persistence_enabled)
	viewport.queue_free();await process_frame;quit()

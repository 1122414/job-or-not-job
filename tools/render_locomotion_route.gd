extends "res://tools/render_city_home.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output);root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	# Initial location/time are fixtures. Subsequent movement uses the existing
	# analog/full-strength actions and Shift, at unchanged controller speeds.
	game.player.position=Vector3(-34,0,44);game.player.yaw=PI;game.player.pitch=-.12
	game.payroll.minute=1080;game.update_daylight()
	player_previous=game.player.position;travelling=true
	var monitor: Callable=record_step.bind(game);physics_frame.connect(monitor)
	var samples := []
	for part in [["walk-out",.7,false,100],["walk-full-out",1.0,false,140],["run-out",1.0,true,100],["walk-return",.7,false,80],["walk-full-return",1.0,false,100],["stop",0.0,false,30]]:
		if part[0]=="walk-return":game.player.yaw=0
		Input.action_release("forward");Input.action_release("run")
		if part[1]>0:Input.action_press("forward",part[1])
		if part[2]:Input.action_press("run")
		for frame in range(part[3]):
			await physics_frame
			if frame>=10:
				var speed := Vector2(game.player.velocity.x,game.player.velocity.z).length()
				var expected := "idle" if part[1]==0 else "run" if part[2] else "walk"
				if game.player.visual.current!=expected:push_error("Locomotion route clip mismatch "+part[0]);quit(1);return
				samples.append({"section":part[0],"frame":frame,"speed":speed,"clip":game.player.visual.current,"phase":game.player.visual.animation.current_animation_position,"player":SaveGame.vector(game.player.position)})
		if not await shot(viewport,game,part[0]):push_error("Route capture guard: "+str([root.mode,root.has_focus(),root.get_flag(Window.FLAG_NO_FOCUS),root.is_input_disabled(),Input.mouse_mode]));quit(1);return
	Input.action_release("forward");Input.action_release("run")
	physics_frame.disconnect(monitor)
	var result := {"images":captures,"visits":visits,"samples":samples,"walking_metres":metres,"walking_max_step":max_step,"background_guard":desktop_safe and guard(),"persistence":game.persistence_enabled,"normal_player_camera":true,"simulated_analog_input":true,"normal_game_fps":false,"independent_player_acceptance":false}
	if not desktop_safe or not guard() or game.persistence_enabled or metres<20 or max_step>.15:push_error("Locomotion route failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("LOCOMOTION_ROUTE_OK images=",captures," metres=",metres," max_step=",max_step," background_guard=true persistence=false")
	viewport.queue_free();await process_frame;quit()

extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.set_disable_input(true)
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	# Set the fixture's starting point once; the entire traversal uses movement
	# input and the player's own spring-arm camera, with autonomous actors live.
	game.player.position=Vector3(0,0,23)
	game.player.yaw=PI
	game.payroll.minute=540
	game.update_daylight()
	for i in range(4): await physics_frame
	var before: Vector3=game.player.position
	var metres := 0.0
	var max_step := 0.0
	var samples := []
	var captured := {}
	var destination := Vector3(0,0,95)
	for frame in range(3600):
		var offset: Vector3=destination-game.player.position
		offset.y=0
		if offset.length()<.2: break
		game.player.yaw=atan2(-offset.x,-offset.z)
		Input.action_press("forward")
		await physics_frame
		var step: float=game.player.position.distance_to(before)
		metres+=step
		max_step=maxf(max_step,step)
		before=game.player.position
		await process_frame
		RenderingServer.force_draw(false)
		if root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
			Input.action_release("forward")
			push_error("Nature traversal lost background protection"); quit(1); return
		if frame%30==0:
			samples.append({"position":SaveGame.vector(game.player.position),"minute":game.payroll.minute,"primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
		for mark in [24,45,70,94]:
			if game.player.position.z>=mark and not captured.has(mark):
				var picture := viewport.get_texture().get_image()
				if picture==null or picture.save_png(output.path_join("walk-"+str(mark)+".png"))!=OK:
					Input.action_release("forward"); quit(1); return
				captured[mark]=true
	Input.action_release("forward")
	if game.player.position.distance_to(destination)>.3 or metres<71 or max_step>.2 or game.payroll.minute<=540 or game.persistence_enabled:
		push_error("Incomplete nature traversal: "+str([game.player.position,metres,max_step,game.payroll.minute])); quit(1); return
	var report := {"samples":samples,"metres":metres,"max_step":max_step,"end":SaveGame.vector(game.player.position),"start_minute":540,"end_minute":game.payroll.minute,"background_guard_passed":true,"player_camera":true,"normal_game_fps":false,"independent_player_acceptance":false}
	FileAccess.open(output.path_join("walk.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("CITY_NATURE_WALK_OK metres=",metres," max_step=",max_step," minute=",game.payroll.minute," captures=",captured.size())
	viewport.queue_free()
	await process_frame
	quit()

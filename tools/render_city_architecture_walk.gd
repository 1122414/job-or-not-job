extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10):await physics_frame
	# Only the starting point is a fixture; all subsequent movement is player input.
	game.player.position=Vector3(0,0,23)
	game.player.pitch=-.05
	game.payroll.minute=540;game.update_daylight()
	for i in range(4):await physics_frame
	var previous: Vector3=game.player.position
	var metres := 0.0
	var maximum := 0.0
	var samples := []
	var points := [Vector3(0,0,42),Vector3(-8,0,42),Vector3(-28,0,42),Vector3(-28,0,58),Vector3(0,0,58),Vector3(27,0,58),Vector3(27,0,42),Vector3(8,0,42),Vector3(0,0,42),Vector3(0,0,58),Vector3(0,0,85),Vector3(-6,0,85),Vector3(-26,0,85),Vector3(-26,0,94),Vector3(0,0,94)]
	for index in range(points.size()):
		var reached := false
		for frame in range(2400):
			var offset: Vector3=points[index]-game.player.position
			offset.y=0
			if offset.length()<.22:reached=true;break
			game.player.yaw=atan2(-offset.x,-offset.z)
			Input.action_press("forward")
			await physics_frame
			var step: float=game.player.position.distance_to(previous)
			metres+=step;maximum=maxf(maximum,step);previous=game.player.position
			if root.mode!=Window.MODE_MINIMIZED or root.has_focus() or not root.get_flag(Window.FLAG_NO_FOCUS) or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
				Input.action_release("forward");push_error("Architecture walk lost desktop protection");quit(1);return
		Input.action_release("forward")
		if not reached:
			push_error("Architecture walk blocked at "+str(game.player.position));quit(1);return
		for frame in range(8):await physics_frame
		previous=game.player.position
		samples.append({"waypoint":index,"position":SaveGame.vector(game.player.position),"minute":game.payroll.minute})
		if index in [1,2,6,7,11,12,14]:
			if not await capture(viewport,"walk-"+str(index)):quit(1);return
	if metres<260 or maximum>.2 or game.persistence_enabled or game.payroll.minute<=540:
		push_error("Architecture walk incomplete or persistence enabled");quit(1);return
	var report := {"waypoints":samples,"metres":metres,"max_step":maximum,"start_minute":540,"end_minute":game.payroll.minute,"player_camera":true,"all_three_galleries":true,"background_guard":true,"normal_game_fps":false,"independent_player_acceptance":false}
	FileAccess.open(output.path_join("walk.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("CITY_ARCHITECTURE_WALK_OK ",JSON.stringify(report))
	viewport.queue_free();await process_frame
	quit()

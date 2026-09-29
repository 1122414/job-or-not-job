extends "res://tools/render_city_bookshop.gd"

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.player.position=Vector3(0,0,23)
	game.payroll.minute=630
	game.player.pitch=-.05
	game.update_daylight()
	for i in range(4): await physics_frame
	var start: Vector3=game.player.position
	var previous: Vector3=start
	var metres := 0.0
	var maximum := 0.0
	var observations := []
	var points := [Vector3(0,0,58),Vector3(-64,0,58),Vector3(-56,0,52),Vector3(-52,0,43),Vector3(-52,0,35),Vector3(-55.7,0,30.5),Vector3(-52,0,35),Vector3(-52,0,43)]
	for index in range(points.size()):
		var reached := false
		for frame in range(3600):
			var offset: Vector3=points[index]-game.player.position
			offset.y=0
			if offset.length()<.22: reached=true; break
			game.player.yaw=atan2(-offset.x,-offset.z)
			Input.action_press("forward")
			await physics_frame
			var step: float=game.player.position.distance_to(previous)
			metres+=step; maximum=maxf(maximum,step); previous=game.player.position
			if not guard(): push_error("Places traversal lost desktop protection"); quit(1); return
		Input.action_release("forward")
		if not reached: push_error("Places traversal blocked at "+str(game.player.position)); quit(1); return
		for frame in range(8): await physics_frame
		previous=game.player.position
		if index<points.size()-1:
			var toward: Vector3=points[index+1]-game.player.position
			game.player.yaw=atan2(-toward.x,-toward.z)
		for frame in range(8): await physics_frame
		if not await capture(viewport,"route-"+str(index)): quit(1); return
		observations.append({"index":index,"position":SaveGame.vector(game.player.position),"minute":game.payroll.minute})
		if index==5:
			var point: CityActivityPoint=game.city_life.point_for("paper")
			var toward: Vector3=point.position-game.player.position
			game.player.yaw=atan2(-toward.x,-toward.z)
			for frame in range(5): await physics_frame
			key(viewport,KEY_E)
			if game.speaker!=point: push_error("Actual paper interaction missed"); quit(1); return
			key(viewport,KEY_1)
			if not game.conversation.text.begins_with("图册背面的手写记录"):
				push_error("Actual reading did not open"); quit(1); return
			if not await capture(viewport,"actual-reading"): quit(1); return
			key(viewport,KEY_1)
	if not guard() or game.persistence_enabled or metres<140 or maximum>.2:
		push_error("Places traversal incomplete or unsafe"); quit(1); return
	var data := {"start":SaveGame.vector(start),"waypoints":observations,"metres":metres,"max_step":maximum,"actual_reading":true,"start_minute":630,"end_minute":game.payroll.minute,"root_minimized":true,"root_unfocusable":true,"root_focused":false,"pointer_visible":true,"normal_player_camera":true,"normal_game_fps":false,"independent_player_acceptance":false}
	FileAccess.open(output.path_join("walk.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("CITY_PLACES_WALK ",JSON.stringify(data))
	viewport.queue_free(); await process_frame
	quit()

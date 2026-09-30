extends "res://tools/render_city_home.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	# One initial fixture placement; every subsequent position comes from input.
	game.player.position=Vector3(-64,0,54);game.player.pitch=-.06
	game.payroll.minute=1110;game.update_daylight()
	player_previous=game.player.position
	var monitor: Callable=record_step.bind(game)
	physics_frame.connect(monitor)
	var sections := [
		["old-front",[Vector3(-64,0,44),Vector3(-34,0,44),Vector3(-34,0,38.5)]],
		["old-side",[Vector3(-34,0,44),Vector3(-34,0,58),Vector3(-84,0,58),Vector3(-84,0,32),Vector3(-88.9,0,32)]],
		["old-north",[Vector3(-84,0,32),Vector3(-84,0,58),Vector3(-34,0,58),Vector3(-34,0,74.9)]],
		["gallery-back",[Vector3(-34,0,58),Vector3(-27,0,58),Vector3(-27,0,28),Vector3(-18,0,28)]],
		["home-front",[Vector3(-27,0,28),Vector3(-27,0,58),Vector3(36,0,58),Vector3(36,0,39.5)]],
		["home-north",[Vector3(36,0,58),Vector3(36,0,74.5)]],
		["home-side",[Vector3(36,0,58),Vector3(86,0,58),Vector3(86,0,32),Vector3(88.5,0,32)]],
		["home-entry",[Vector3(86,0,32),Vector3(86,0,58),Vector3(58,0,58),Vector3(58,0,44),Vector3(56,0,42),Vector3(56,0,37)]]
	]
	for section in sections:
		if not await go(game,section[1]) or not await shot(viewport,game,section[0]):quit(1);return
	physics_frame.disconnect(monitor)
	var result := {"images":captures,"visits":visits,"walking_metres":metres,"walking_max_step":max_step,"clock_from":1110,"clock_to":game.payroll.minute,"background_guard":desktop_safe and guard(),"persistence":game.persistence_enabled,"normal_player_camera":true,"normal_game_fps":false,"independent_player_acceptance":false}
	if not desktop_safe or not guard() or game.persistence_enabled or metres<450 or max_step>.2:push_error("Frontage walk failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("walk.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CITY_FRONTAGE_WALK_OK ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit()

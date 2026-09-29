extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.set_disable_input(true)
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false)
	game.transit.set_physics_process(false)
	game.player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=58
	for view in [
		["district-overview",Vector3(110,100,150),Vector3(0,0,52)],
		["office-platform",Vector3(3,3,19),Vector3(-6,1.5,8)],
		["market-street",Vector3(-70,2,66),Vector3(-53,2,53)],
		["waterfront",Vector3(6,2,113),Vector3(-10,1,124)],
		["residential",Vector3(69,2,58),Vector3(47,3,62)]]:
		camera.position=view[1]
		camera.look_at(view[2])
		game.player.position=Vector3(view[1].x,0,view[1].z)
		if not await capture(viewport,view[0]): quit(1); return
	game.player.position=CityLayout.STOPS[0].platform
	game.transit.board(0)
	game.transit.dwell=0
	game.player.set_physics_process(true)
	for i in range(90):
		game.transit.tick(0.1)
		await physics_frame
	camera.position=game.transit.bus.position+Vector3(6,3,5)
	camera.look_at(game.transit.bus.position+Vector3.UP*1.5)
	if not await capture(viewport,"bus-passenger"): quit(1); return
	game.player.camera.make_current()
	if not await capture(viewport,"passenger-camera"): quit(1); return
	camera.make_current()
	game.panels.show_page("city")
	if not await capture(viewport,"city-map"): quit(1); return
	game.panels.show_page("transit")
	if not await capture(viewport,"bus-controls"): quit(1); return
	game.panels.show_page("")
	viewport.queue_free()
	await process_frame
	print("CITY_TRANSIT_RENDER images=",captures," pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	quit()

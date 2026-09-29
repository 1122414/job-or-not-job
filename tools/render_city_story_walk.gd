extends "res://tools/render_city_bookshop.gd"

func safe_window() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(8): await physics_frame
	game.set_process(false)
	if not safe_window(): push_error("Story capture window guard failed"); quit(1); return
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=65
	var walk: CityStoryWalk=game.city_life.walk
	for stop in ["market","seaside","lin-qiao-seaside"]:
		var saved := SaveGame.read("res://build/c3c/"+stop+".json",game)
		if saved.is_empty() or not SaveGame.restore(game,saved): push_error("Missing real route snapshot "+stop); quit(1); return
		for i in range(6): await physics_frame
		var person := walk.person_for(walk.partner)
		game.population.talk(person)
		for i in range(45): await physics_frame
		camera.position=person.position+Vector3(4,2.9,5)
		camera.look_at(person.position+Vector3(0,1.15,0))
		if not await capture(viewport,stop+"-conversation"): quit(1); return
		game.close_interaction()
	var completed := SaveGame.read("res://build/c3c/walk-completed.json",game)
	if completed.is_empty() or not SaveGame.restore(game,completed): push_error("Missing completed route snapshot"); quit(1); return
	for i in range(6): await physics_frame
	camera.position=Vector3(-50.7,2.3,38)
	camera.look_at(Vector3(-46,1.8,35))
	game.close_interaction()
	if not await capture(viewport,"wall-exhibition"): quit(1); return
	game.city_life.open_point(game.city_life.point_for("walk"))
	if not await capture(viewport,"wall-reading"): quit(1); return
	game.close_interaction()
	var alternative := SaveGame.read("res://build/c3c/lin-qiao-walk-completed.json",game)
	if alternative.is_empty() or not SaveGame.restore(game,alternative): push_error("Missing second completed route snapshot"); quit(1); return
	for i in range(6): await physics_frame
	camera.position=Vector3(-49.2,2,38.3)
	camera.look_at(Vector3(-47,1.1,36))
	if not await capture(viewport,"album-exhibition"): quit(1); return
	game.city_life.open_point(game.city_life.point_for("walk"))
	if not await capture(viewport,"album-reading"): quit(1); return
	game.close_interaction()
	game.panels.show_page("city")
	if not await capture(viewport,"city-map"): quit(1); return
	game.panels.show_page("")
	if not safe_window(): push_error("Story capture lost window guard"); quit(1); return
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify({"images":captures,"root_minimized":root.mode==Window.MODE_MINIMIZED,"root_unfocusable":root.get_flag(Window.FLAG_NO_FOCUS),"root_focused":root.has_focus(),"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"source":"Both guide conversations and wall/album outcomes restored from actual continuous input routes","note":"Fixed review camera, not a continuous play recording or final visual acceptance."},"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("CITY_STORY_RENDER images=",captures," safe_window=",safe_window())
	quit()

extends "res://tools/render_character_candidates.gd"

func key(viewport: SubViewport,code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		viewport.push_input(event,true)

func use_point(viewport: SubViewport,game: Node3D,id: String,index: int,at: Vector3) -> bool:
	game.player.position=at
	var point: CityActivityPoint=game.city_life.point_for(id)
	var direction: Vector3=point.position-at
	game.player.yaw=atan2(-direction.x,-direction.z)
	for i in range(3): await physics_frame
	key(viewport,KEY_E)
	if game.speaker!=point: push_error("Graphical interaction missed "+id); return false
	key(viewport,KEY_1+index)
	return true

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
	var original := SaveGame.snapshot(game)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=65
	game.player.position=Vector3(-52,0,43)
	camera.position=Vector3(-43,5,49)
	camera.look_at(Vector3(-52,1.8,34))
	if not await capture(viewport,"bookshop-entrance"): quit(1); return
	var results := {}
	for method in CityLife.METHODS:
		if not SaveGame.restore(game,original.duplicate(true)): quit(1); return
		for i in range(6): await physics_frame
		if not await use_point(viewport,game,"notice",CityLife.METHODS.keys().find(method),Vector3(-50,0,42)): quit(1); return
		var at: Vector3={"screen":Vector3(-49.2,0,29.7),"paper":Vector3(-55.7,0,30.5),"garden":Vector3(38,0,55.2)}[method]
		if not await use_point(viewport,game,method,0,at): quit(1); return
		if method=="screen":
			camera.position=Vector3(-52,2.7,36)
			camera.look_at(Vector3(-50,1.4,29))
			if not await capture(viewport,"screen-diagnosis"): quit(1); return
			key(viewport,KEY_1)
		game.player.position=game.city_life.center()+Vector3(0,0,3)
		if method=="garden":
			camera.position=Vector3(45,3.4,64)
			camera.look_at(Vector3(38,1.3,55))
		else:
			camera.position=Vector3(-52,3,37)
			camera.look_at(Vector3(-52,1.4,29))
		var shown := false
		for i in range(18000):
			await physics_frame
			if not shown and game.city_life.elapsed>7:
				if not await capture(viewport,method+"-sharing"): quit(1); return
				shown=true
			if game.city_life.result!="": break
		if game.city_life.result!=method or not shown: push_error("Graphical activity failed "+method); quit(1); return
		results[method]=game.city_life.snapshot()
		if not await capture(viewport,method+"-completed"): quit(1); return
	game.payroll.minute=1200
	game.update_daylight()
	for i in range(3600): await physics_frame
	game.player.position=Vector3(-52,0,43)
	camera.position=Vector3(-48,3,44)
	camera.look_at(Vector3(-52,1.8,35))
	if not await capture(viewport,"bookshop-closed"): quit(1); return
	game.panels.show_page("city")
	if not await capture(viewport,"bookshop-map"): quit(1); return
	game.panels.show_page("")
	var data := {"images":captures,"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"root_hidden":not root.visible,"results":results,"note":"Player positioned near interaction points for capture; residents walk naturally. Continuous player routes verified separately in city_bookshop_test. Offscreen rendering is not final visual/performance acceptance."}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("CITY_BOOKSHOP_RENDER images=",captures," pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE," natural_attendance=3_methods")
	quit()

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
	for frame in range(8): await physics_frame
	game.set_process(false)
	game.payroll.minute=630
	game.update_daylight()
	var original := SaveGame.snapshot(game)
	var life: CityLife=game.city_life
	var camera := Camera3D.new()
	game.add_child(camera); camera.fov=55
	var records := []
	for method in CityLife.METHODS:
		if not SaveGame.restore(game,original.duplicate(true)): quit(1); return
		life.set_physics_process(true)
		for frame in range(5): await physics_frame
		if not await use_point(viewport,game,"notice",CityLife.METHODS.keys().find(method),Vector3(-50,0,42)): quit(1); return
		var at: Vector3={"screen":Vector3(-49.2,0,29.7),"paper":Vector3(-55.7,0,30.5),"garden":Vector3(38,0,55.2)}[method]
		if not await use_point(viewport,game,method,0,at): quit(1); return
		if method=="screen": key(viewport,KEY_1)
		game.player.position=Vector3(0,0,18)
		for frame in range(20000):
			await physics_frame
			if life.performance.attending().size()==3: break
		if life.performance.attending().size()!=3: push_error("Three residents never arrived: "+method); quit(1); return
		life.set_physics_process(false)
		game.player.position=life.center()+Vector3(0,0,3)
		camera.make_current()
		camera.position=Vector3(43,3.0,61) if method=="garden" else Vector3(-51,2.5,35.8)
		camera.look_at(Vector3(38,1.25,56) if method=="garden" else Vector3(-54,1.25,29.8))
		for moment in [1.4,5.6,7.4]:
			life._physics_process(moment-life.elapsed)
			for frame in range(80): await physics_frame
			if not guard(): push_error("Share capture lost desktop guard"); quit(1); return
			if not await capture(viewport,method+"-"+str(moment)): quit(1); return
			records.append({"method":method,"time":moment,"narrator":life.performance.narrator().stable_id,"caption":life.caption()})
		if method=="paper":
			for index in CityLife.AUDIENCE:
				var person: CityResident=game.population.residents[index]
				camera.position=person.visual.to_global(Vector3(.8,1.8,-1.0))
				camera.look_at(person.visual.to_global(Vector3(0,1.17,-.3)))
				if not await capture(viewport,"reading-"+person.visual.outfit): quit(1); return
			game.player.camera.make_current()
			game.player.yaw=atan2(-(life.center().x-game.player.position.x),-(life.center().z-game.player.position.z))
			for frame in range(20): await physics_frame
			if not await capture(viewport,"paper-player-camera"): quit(1); return
			camera.make_current()
		var speaker := life.performance.narrator()
		game.population.talk(speaker)
		for frame in range(40): await physics_frame
		if life.performance.narrator()==speaker: push_error("Conversation failed to interrupt presenter"); quit(1); return
		game.close_interaction()
		life.set_physics_process(true)
		for frame in range(1800):
			await physics_frame
			if life.result==method: break
		if life.result!=method: push_error("Sharing did not finish: "+method); quit(1); return
	if not SaveGame.restore(game,original.duplicate(true)): quit(1); return
	if not await use_point(viewport,game,"paper",0,Vector3(-55.7,0,30.5)): quit(1); return
	game.player.camera.make_current()
	if not await capture(viewport,"player-browse-first"): quit(1); return
	key(viewport,KEY_2)
	for frame in range(24): await physics_frame
	camera.make_current(); camera.position=Vector3(-55.0,1.9,29.3); camera.look_at(life.room.album.global_position)
	if not await capture(viewport,"player-page-turn"): quit(1); return
	for frame in range(35): await physics_frame
	game.player.camera.make_current()
	if not await capture(viewport,"player-browse-second"): quit(1); return
	key(viewport,KEY_1)
	for frame in range(8): await physics_frame
	if game.speaker!=null or life.reading_page!=-1 or not guard(): push_error("Reading did not release control"); quit(1); return
	var data := {"images":captures,"records":records,"residents_arrive_naturally":true,"player_placement":"near-point fixtures; ordinary camera captured separately","pose_clock":"fixed to labelled times for diagnostic captures","root_minimized":true,"root_unfocusable":true,"root_focused":false,"pointer_visible":true,"independent_player_acceptance":false,"normal_game_fps":false}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("CITY_SHARE_RENDER ",JSON.stringify(data))
	viewport.queue_free(); await process_frame; quit()

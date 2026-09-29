extends "res://tools/render_character_candidates.gd"

# Inherits the hidden NO_FOCUS window and visible-pointer setup.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,800)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.set_disable_input(true)
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled or game.player.capture_permitted(): quit(1); return
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.fov=50
	game.player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for firm in ["a","b"]:
		var host: OfficeNPC=game.npc_for_role(firm+"_hr")
		if host.visual.cast_id!=("lin_lan" if firm=="a" else "a_cheng"): quit(1); return
		game.player.position=OfficeRooms.point(game,firm,"interview_seat")
		game.player.visual.hide()
		camera.make_current()
		for pose in ["standing","seated"]:
			host.position=OfficeRooms.point(game,firm,"interview_host")
			host.visual.rotation.y=PI
			host.visual.position=host.visual.seated_offset if pose=="seated" else Vector3.ZERO
			host.visual.pose(0,false,false,false,pose=="seated",false,true)
			host.visual.animation.advance(0.8)
			host.visual.set_attention(game.player.position+Vector3(0,1.3,0),true)
			var target := host.visual.face_position()-Vector3(0,0.15,0)
			camera.position=target+Vector3(0.75,0.1,2.5)
			camera.look_at(target)
			if not await capture(viewport,firm+"-cast-"+pose): quit(1); return
		game.player.visual.show()
		game.player.position=Vector3(-14 if firm=="a" else 14,0,5)
		game.player.yaw=0
		game.player.pitch=-0.08
		game.player.visual.pose(0,false,false)
		game.player.pivot.rotation=Vector3(-0.08,0,0)
		game.player.camera.make_current()
		if not await capture(viewport,firm+"-cast-player-camera"): quit(1); return
	viewport.queue_free()
	await process_frame
	print("CAST_IN_WORLD images=",captures," pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	quit()

extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output := "res://build/environment-preview"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled: quit(1); return
	var detail_camera := Camera3D.new()
	game.add_child(detail_camera)
	detail_camera.fov=65
	for firm in ["a","b"]:
		var center := -14.0 if firm=="a" else 14.0
		for view in ["street","reception","waiting"]:
			if not SaveGame.restore(game,game.initial_state.duplicate(true)): quit(1); return
			game.player.position=Vector3(center,0,5)
			game.player.yaw=0
			game.player.pitch=-0.08
			game.player.camera.make_current()
			for i in range(10): await physics_frame
			game.player.set_physics_process(false)
			if view!="street":
				game.player.visual.hide()
				var target: Vector3=OfficeRooms.RECEPTIONS[firm]+Vector3(0,1.15,0) if view=="reception" else Vector3(center+4,0.75,1.2)
				detail_camera.global_position=target+Vector3(1.3,0.75,1.9) if view=="reception" else target+Vector3(-1.7,0.9,-2.0)
				detail_camera.look_at(target)
				detail_camera.make_current()
			for i in range(6): await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(output.path_join(firm+"-"+view+".png"))!=OK: quit(1); return
			game.player.visual.show()
			game.player.set_physics_process(true)
	game.queue_free()
	await process_frame
	print("ENVIRONMENT_CAPTURED ",output)
	quit()

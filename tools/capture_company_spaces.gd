extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output := "res://build/company-preview"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled: quit(1); return
	var detail := Camera3D.new()
	game.add_child(detail)
	detail.fov=65
	var shots := {
		"facade":[Vector3(0,1.7,15),Vector3(0,3.4,0)],
		"entry":[Vector3(0,0,5),Vector3.ZERO],
		"reception":[Vector3(-0.7,1.7,1.9),Vector3(-2.8,1.35,-0.7)],
		"work":[Vector3(0,1.7,-1.8),Vector3(5.5,1.35,-8)],
		"interview":[Vector3(-7,1.65,-11.5),Vector3(-7,1.2,-15)],
		"tea":[Vector3(6.0,1.7,-11.7),Vector3(8.2,1.4,-15.4)]
	}
	for firm in ["a","b"]:
		var origin := Vector3(-14 if firm=="a" else 14,0,0)
		for title in shots:
			game.player.position=origin+Vector3(0,0,5)
			game.player.yaw=0
			game.player.pitch=-0.08
			game.player.visual.visible=title=="entry"
			if title=="entry": game.player.camera.make_current()
			else:
				detail.global_position=origin+shots[title][0]
				detail.look_at(origin+shots[title][1])
				detail.make_current()
			for i in range(6): await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(output.path_join(firm+"-"+title+".png"))!=OK: quit(1); return
	game.queue_free()
	await process_frame
	print("COMPANY_CAPTURED ",output," views=12")
	quit()

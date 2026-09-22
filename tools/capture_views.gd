extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := "res://docs/evidence/2026-09-22-after"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.size=Vector2i(1280,800)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for action in ["interview_hr","interview_lead","interview_boss","join_a"]: game.career.apply(action)
	for view in ["street","office","work","interview"]:
		game.player.position={"street":Vector3(-14,0,5),"office":Vector3(-14,0,0.5),"work":Vector3(-8,0,0.3),"interview":OfficeRooms.INTERVIEW_SEATS.a+Vector3(0,0,0.25)}[view]
		if view=="interview": game.interviews.schedule("interview_hr")
		game.player.yaw=0
		game.player.pitch=-0.08
		for i in range(360 if view=="interview" else 30): await physics_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output.path_join(view+".png"))
		if error!=OK: quit(1); return
	print("CAPTURED ",output)
	game.queue_free()
	await process_frame
	quit()

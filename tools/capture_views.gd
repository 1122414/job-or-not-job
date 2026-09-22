extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := "res://docs/evidence/2026-09-22-after"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	for view in ["street","office","work","interview"]:
		# Reset visits and career between views without registering input actions twice.
		if not SaveGame.restore(game,game.initial_state.duplicate(true)): quit(1); return
		for i in range(10): await physics_frame
		game.player.position={"street":Vector3(-14,0,5),"office":Vector3(-14,0,0.5),"work":Vector3(-8,0,0.3),"interview":OfficeRooms.INTERVIEW_SEATS.a+Vector3(0,0,0.25)}[view]
		if view=="work":
			for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data"]: game.career.apply(action)
			game.career.facts.welcome_a=true
			game.career.facts.visit_brief=true
			for station in game.stations:
				if station.stable_id=="desk_a": game.office.open_desk(station)
		if view=="interview":
			game.interviews.schedule("interview_hr")
			for i in range(1200):
				if game.interviews.host_seated(game.npc_for_role("a_hr")): break
				await physics_frame
			if not game.interviews.host_seated(game.npc_for_role("a_hr")):
				push_error("面试截图夹具：面试官尚未到位")
				quit(1)
				return
			for station in game.stations:
				if station.stable_id=="interview_a": game.speaker=station
			game.interviews.handle("interview_seat_a")
		game.player.yaw=0
		game.player.pitch=-0.08
		for i in range(30): await physics_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output.path_join(view+".png"))
		if error!=OK: quit(1); return
	game.queue_free()
	await process_frame
	print("CAPTURED ",output)
	quit()

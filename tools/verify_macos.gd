extends SceneTree

# Run from outside the project with --main-pack and this external script.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var build := BuildInfo.read()
	if build.is_empty() or build.save_schema!=SaveGame.VERSION:
		push_error("Package identity or save schema missing")
		quit(1)
		return
	for excluded in ["res://tests/world_test.gd", "res://tools/package_macos.py", "res://docs/progress.md", "res://build/p0-source-identity.json"]:
		if FileAccess.file_exists(excluded) or ResourceLoader.exists(excluded):
			push_error("Development files leaked into package: "+excluded)
			quit(1)
			return
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled or game.npcs.size()!=10 or game.props.size()!=114:
		push_error("Package scene or persistence isolation changed")
		quit(1)
		return
	game.toggle_menu()
	if DisplayServer.get_name()!="headless":
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--screenshot="):
				var error := root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
				if error!=OK: quit(1); return
	print("PACKAGED_SMOKE_OK build=",build.build_id," label=",BuildInfo.label()," npcs=",game.npcs.size()," props=",game.props.size()," persistence=",game.persistence_enabled)
	paused=false
	game.queue_free()
	await process_frame
	quit()

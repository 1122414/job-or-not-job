extends SceneTree

# External probe: invoke the app's TodayOff launcher, never a source project.
var output := ""
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.mode=Window.MODE_MINIMIZED
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true); root.mode=Window.MODE_MINIMIZED
	var build := BuildInfo.read()
	if output.is_empty() or build.is_empty() or FileAccess.file_exists("res://tests/city_daylight_test.gd") or RenderingServer.get_current_rendering_method()!="forward_plus":
		push_error("Require isolated package and its default Forward+ renderer"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	game.add_child(camera); camera.fov=65; camera.make_current()
	var images := []
	for shot in [
		["day-walk",Vector3(0,1.75,23),Vector3(0,2.2,78),540],
		["night-garden",Vector3(43,1.7,57),Vector3(41.2,1.4,54),1230],
		["night-company-a",Vector3(-14,1.7,-1.8),Vector3(-8.5,1.35,-8),1230]
	]:
		game.payroll.minute=shot[3]; game.update_daylight()
		camera.position=shot[1]; camera.look_at(shot[2])
		for i in range(3):
			await process_frame
			RenderingServer.force_draw(false)
		var picture := viewport.get_texture().get_image()
		if not guard() or game.persistence_enabled or picture==null or picture.is_empty() or picture.save_png(output.path_join(shot[0]+".png"))!=OK:
			push_error("Package visual probe failed or desktop protection lost"); quit(1); return
		images.append(shot[0])
	var data := {"build_id":build.build_id,"source_sha256":build.source_sha256,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"images":images,"background_guard":guard(),"persistence":game.persistence_enabled,"normal_game_fps":false}
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("PACKAGED_LIGHTING_OK ",JSON.stringify(data))
	viewport.queue_free(); await process_frame; quit()

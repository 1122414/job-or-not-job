extends SceneTree

var output := ""
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	if output=="":push_error("Package frontage output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var build := BuildInfo.read()
	if build.is_empty() or build.save_schema!=22:push_error("Package identity missing");quit(1);return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	var mounted := 0
	for batch in streets.find_children("*","MultiMeshInstance3D",true,false):
		if not batch.multimesh.mesh.resource_path.ends_with("industrial_wall_lamp.res"):continue
		for i in range(batch.multimesh.instance_count):
			var pose: Transform3D=batch.global_transform*batch.multimesh.get_instance_transform(i)
			var normal: Vector3=pose.basis*Vector3(0,0,1)
			var ray := PhysicsRayQueryParameters3D.create(pose.origin+normal*.03,pose.origin-normal*.03,1)
			if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():push_error("Packaged fixture lacks physical support");quit(1);return
			mounted+=1
	if mounted!=26 or streets.get_meta("street_frontages",0)!=10:push_error("Packaged street instances missing");quit(1);return
	game.set_process(false);game.process_mode=Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new();game.add_child(camera);camera.fov=65;camera.make_current()
	var images := []
	for view in [["old-day",Vector3(-35,1.75,44),Vector3(-34,1.7,37),540],["old-night",Vector3(-35,1.75,44),Vector3(-34,1.7,37),1230],["home-night",Vector3(40,1.75,69),Vector3(36,1.7,76),1230]]:
		game.payroll.minute=view[3];game.update_daylight()
		camera.position=view[1];camera.look_at(view[2])
		for i in range(3):await process_frame;RenderingServer.force_draw(false)
		var picture := viewport.get_texture().get_image()
		if not guard() or picture==null or picture.is_empty() or picture.save_png(output.path_join(view[0]+".png"))!=OK:push_error("Package image or desktop guard failed");quit(1);return
		images.append(view[0])
	var result := {"build_id":build.build_id,"source_sha256":build.source_sha256,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"images":images,"mounted_fixtures":mounted,"frontages":streets.get_meta("street_frontages"),"background_guard":guard(),"persistence":game.persistence_enabled,"views_are_fixtures":true,"normal_game_fps":false}
	if not guard() or game.persistence_enabled:push_error("Packaged desktop isolation failed");quit(1);return
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("PACKAGED_FRONTAGES_GUI_OK ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit()

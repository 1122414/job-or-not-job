extends "res://tools/probe_indirect_lighting.gd"

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Refresh control needs graphics");quit(1);return
	root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(480,320);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new();viewport.add_child(stage)
	var floor_mesh := make_box(stage,Vector3(8,.2,8),Vector3.ZERO,Color.WHITE)
	floor_mesh.material_override.metallic=1;floor_mesh.material_override.roughness=.06
	var wall := make_box(stage,Vector3(8,4,.3),Vector3(0,2,-4),Color.RED)
	wall.layers=1<<19
	wall.material_override.emission_enabled=true;wall.material_override.emission=Color.RED
	var world := WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color.BLACK
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.4
	world.environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	stage.add_child(world)
	var probe := ReflectionProbe.new();probe.position=Vector3(0,2,0);probe.size=Vector3(8,6,8)
	probe.box_projection=true;probe.interior=true;probe.cull_mask=1<<19
	stage.add_child(probe)
	var camera := Camera3D.new();stage.add_child(camera)
	camera.position=Vector3(3,3,4);camera.look_at(Vector3(0,.3,0));camera.cull_mask=1;camera.current=true
	RenderingServer.frame_post_draw.connect(on_draw)
	var pictures: Array[Image]=[]
	for state in ["red","stale","green"]:
		if state=="stale":
			wall.material_override.albedo_color=Color.GREEN
			wall.material_override.emission=Color.GREEN
		if state=="green": probe.update_mode=ReflectionProbe.UPDATE_ONCE
		for frame in range(48):
			await process_frame;RenderingServer.force_draw(false)
		if not background_guard():push_error("Refresh background guard");quit(1);return
		var picture := viewport.get_texture().get_image()
		picture.save_png(output.path_join(state+".png"));pictures.append(picture)
	var unchanged := pictures[0].get_data()==pictures[1].get_data()
	var changed := pictures[1].get_data()!=pictures[2].get_data()
	FileAccess.open(output.path_join("refresh.json"),FileAccess.WRITE).store_string(JSON.stringify({"stale_is_identical":unchanged,"node_refresh_changes_reflection":changed,"guard":background_guard(),"completed_draws":completed},"\t")+"\n")
	if not unchanged or not changed:push_error("Reflection refresh did not match controls")
	viewport.queue_free();await process_frame
	print("REFLECTION_REFRESH_CONTROL stale_identical=",unchanged," refreshed_changed=",changed)
	quit(0 if unchanged and changed else 1)

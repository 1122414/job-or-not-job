extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1100,900);viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	if "--full-mesh" in OS.get_cmdline_user_args():viewport.mesh_lod_threshold=0
	root.add_child(viewport)
	var stage := Node3D.new();viewport.add_child(stage)
	var world := WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("899daa")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("d2dce4");world.environment.ambient_light_energy=.5
	world.environment.tonemap_mode=Environment.TONE_MAPPER_ACES;stage.add_child(world)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0)
	sun.shadow_enabled=true;sun.light_energy=1.4;stage.add_child(sun)
	var camera := Camera3D.new();camera.fov=45;camera.current=true;stage.add_child(camera)
	for id in ["rollershutter_door","plastic_crate_01","potted_plant_02","industrial_wall_lamp"]:
		if "--lamp-only" in OS.get_cmdline_user_args() and id!="industrial_wall_lamp":continue
		var mesh: ArrayMesh=load("res://assets/city_street/"+id+".res")
		var bounds := mesh.get_aabb()
		var span := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		var model := MeshInstance3D.new();model.mesh=mesh;stage.add_child(model)
		var ground := Shapes.box(stage,Vector3(span*4,.02,span*4),Vector3(0,bounds.position.y-.02,0),Color("9e9b88"))
		for shot in [["front",Vector3(.15,.12,2.4)],["oblique",Vector3(1.5,.8,1.7)]]:
			camera.position=bounds.get_center()+shot[1]*span;camera.look_at(bounds.get_center())
			if not await capture(viewport,id+"-"+shot[0]):quit(1);return
		model.queue_free();ground.queue_free();await process_frame
	if root.mode!=Window.MODE_MINIMIZED or root.has_focus() or not root.get_flag(Window.FLAG_NO_FOCUS) or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Street asset review lost desktop protection");quit(1);return
	viewport.queue_free();await process_frame
	print("STREET_ASSET_VIEWS_OK images=",captures," background_guard=true");quit()

extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1200,900)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("8fa9ba")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("c3d8e5")
	world.environment.ambient_light_energy=.55
	world.environment.tonemap_mode=Environment.TONE_MAPPER_ACES
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.shadow_enabled=true
	sun.light_energy=1.2
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=50
	for variant in ["centered_large_02","centered_double_02","centered_small_03"]:
		var module := MeshInstance3D.new()
		module.mesh=load("res://assets/city_architecture/"+variant+".res")
		stage.add_child(module)
		# A real recessed back wall makes source glass transparency observable.
		var backing := Shapes.box(stage,Vector3(3,3,.08),Vector3(0,1.5,-1),Color("b3a68e"))
		for shot in [["front",Vector3(0,1.5,4.5)],["oblique",Vector3(2.5,2.1,3.5)]]:
			camera.position=shot[1]
			camera.look_at(Vector3(0,1.5,0))
			if not await capture(viewport,variant+"-"+shot[0]):quit(1);return
		backing.queue_free();module.queue_free()
		await process_frame
	if root.mode!=Window.MODE_MINIMIZED or root.has_focus() or not root.get_flag(Window.FLAG_NO_FOCUS) or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Architecture preview lost background protection");quit(1);return
	viewport.queue_free()
	await process_frame
	print("ARCHITECTURE_PREVIEW_OK images=",captures," source_windows=true background_guard=true")
	quit()

extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1000,1000)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov=50
	camera.current=true
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("809ba9")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_energy=.55
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-40,-35,0)
	key.light_energy=1.0
	key.shadow_enabled=true
	stage.add_child(key)
	Shapes.box(stage,Vector3(80,.03,80),Vector3(0,-.025,0),Color("9b9b84"))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file("res://production/environment/polyhaven_nature/tree_small_02/tree_small_02_2k.gltf",state)!=OK: quit(1); return
	var source_mesh: ImporterMesh=state.get_meshes()[0].mesh
	source_mesh.generate_lods(60,25,[])
	var alpha := Image.load_from_file("res://production/environment/polyhaven_nature/tree_small_02/textures/tree_small_02_leaves_alpha_2k.png")
	alpha.convert(Image.FORMAT_L8)
	var alpha_data := alpha.get_data()
	var leaf: Image=source_mesh.get_surface_material(1).albedo_texture.get_image()
	leaf.convert(Image.FORMAT_RGBA8)
	var leaf_data := leaf.get_data()
	for i in range(alpha_data.size()): leaf_data[i*4+3]=alpha_data[i]
	leaf=Image.create_from_data(leaf.get_width(),leaf.get_height(),false,Image.FORMAT_RGBA8,leaf_data)
	leaf.generate_mipmaps()
	var leaf_texture := ImageTexture.create_from_image(leaf)
	var counts := {}
	for variant in [{"name":"source","lods":[-1,-1,-1]},{"name":"medium","lods":[1,1,1]},{"name":"compact","lods":[2,2,2]},{"name":"islands-0","baked":0},{"name":"islands-1","baked":1},{"name":"islands-2","baked":2}]:
		var model := MeshInstance3D.new()
		model.mesh=ArrayMesh.new()
		var triangles := 0
		var baked: ArrayMesh
		if variant.has("baked"): baked=load("res://build/c4d-tree-production/tree_lod%d.res"%variant.baked)
		for i in range(source_mesh.get_surface_count()):
			var arrays := baked.surface_get_arrays(i) if baked else source_mesh.get_surface_arrays(i)
			if not baked and variant.lods[i]>=0: arrays[Mesh.ARRAY_INDEX]=source_mesh.get_surface_lod_indices(i,variant.lods[i])
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			model.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var material: StandardMaterial3D=source_mesh.get_surface_material(i).duplicate()
			material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
			if i==1:
				material.albedo_texture=leaf_texture
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold=.4
				material.backlight_enabled=true
				material.backlight=Color(.28,.32,.18)
			model.mesh.surface_set_material(i,material)
		stage.add_child(model)
		counts[variant.name]=triangles
		for distance in [7,16,35]:
			camera.position=Vector3(0,2.2,distance)
			camera.look_at(Vector3(0,2.2,0))
			if not await capture(viewport,variant.name+"-"+str(distance)): quit(1); return
		model.queue_free()
		await process_frame
	if root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Tree review window guard failed"); quit(1); return
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify({"triangles":counts,"root_minimized":true,"root_focused":false,"root_unfocusable":true,"pointer_visible":true,"normal_game_performance":false},"\t"))
	print("TREE_CANDIDATES ",counts)
	viewport.queue_free()
	await process_frame
	quit()

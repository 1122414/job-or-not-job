extends "res://tools/render_character_candidates.gd"

# Real rendering verifies adjacent distance ranges never leave a hole or draw
# two complete trees. It does not judge perceptual LOD popping or normal FPS.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1000,700)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var tree := CityTree.new()
	stage.add_child(tree)
	tree.scale=Vector3.ONE*1.24
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("809ba9")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_energy=.7
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov=65
	camera.current=true
	var counts := []
	for instance in tree.lods:
		var triangles := 0
		for surface in range(instance.mesh.get_surface_count()):
			triangles+=instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
		counts.append(triangles)
	var records := []
	var seen := {}
	for direction in ["out","in"]:
		for step in range(165):
			var distance: float=7+step*.25 if direction=="out" else 48-step*.25
			camera.position=Vector3(0,2.8,distance)
			camera.look_at(Vector3(0,2.8,0))
			for warmup in range(3):
				await process_frame
				RenderingServer.force_draw(false)
			if root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
				push_error("Tree LOD probe lost background protection"); quit(1); return
			var primitives := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
			var level := counts.find(primitives)
			if level<0:
				push_error("Tree detail gap/overlap at distance %s: %s, expected one of %s"%[distance,primitives,counts]); quit(1); return
			seen[level]=true
			records.append({"direction":direction,"distance":distance,"level":level,"primitives":primitives})
			if direction=="out" and distance in [7.0,20.25,20.5,40.25,40.5,48.0]:
				if not await capture(viewport,"distance-%.2f"%distance): quit(1); return
	if seen.size()!=3: push_error("Not all tree levels were actually rendered"); quit(1); return
	FileAccess.open(output.path_join("lod-sweep.json"),FileAccess.WRITE).store_string(JSON.stringify({"samples":records,"levels":counts,"background_guard_passed":true,"normal_game_fps":false,"perceptual_transition_accepted":false},"\t")+"\n")
	print("TREE_LOD_SWEEP_OK samples=",records.size()," levels=",counts," gaps=0 overlaps=0 pointer_visible=true")
	viewport.queue_free()
	await process_frame
	quit()

extends "res://tools/probe_indirect_lighting.gd"

func run() -> void:
	var ambient_energy := .4
	for argument in OS.get_cmdline_user_args():
		if argument=="--zero-ambient": ambient_energy=0
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
		push_error("Reflection control requires real Forward+ graphics"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var view := SubViewport.new()
	view.size=Vector2i(800,600)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var floor_mesh := make_box(stage,Vector3(8,.2,8),Vector3(0,-.1,0),Color.WHITE)
	floor_mesh.material_override.metallic=1
	floor_mesh.material_override.roughness=.06
	for item in [[Vector3(.3,4,8),Vector3(-4,2,0),Color(1,0,0)],[Vector3(8,4,.3),Vector3(0,2,-4),Color(0,0,1)],[Vector3(1,2,1),Vector3(2,1,0),Color(0,1,0)]]:
		var mesh := make_box(stage,item[0],item[1],item[2])
		mesh.layers|=1<<19
		mesh.material_override.emission_enabled=true
		mesh.material_override.emission=item[2]
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color.BLACK
	# Nonzero ambient prevents the renderer's specular-occlusion term from
	# suppressing reflections. The fully metallic floor has no diffuse term.
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=ambient_energy
	world.environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	stage.add_child(world)
	var probe := ReflectionProbe.new()
	probe.position=Vector3(0,2,0)
	probe.size=Vector3(8,6,8)
	probe.box_projection=true
	probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
	probe.interior=true
	probe.cull_mask=1<<19
	stage.add_child(probe)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(4,3,5)
	camera.look_at(Vector3(-.5,.5,0))
	camera.current=true
	RenderingServer.frame_post_draw.connect(on_draw)
	var pictures: Array[Image]=[]
	var completions := []
	for intensity in [0.0,1.0]:
		probe.intensity=intensity
		probe.position.y+=.0001
		for frame in range(128):
			await process_frame
			var before := completed
			RenderingServer.force_draw(false)
			for pending in range(3):
				if completed>before: break
				await process_frame
			completions.append(completed-before)
			if completed<=before or not background_guard():
				push_error("Reflection background guard failed: completions="+str(completed-before)+" guard="+str(background_guard())); quit(1); return
		var picture := view.get_texture().get_image()
		if picture==null or picture.is_empty() or picture.save_png(output.path_join("intensity-"+str(intensity)+".png"))!=OK:
			push_error("Missing reflection control image"); quit(1); return
		pictures.append(picture)
	var changed := 0
	var total := Vector3.ZERO
	for y in range(600):
		for x in range(800):
			var a := pictures[0].get_pixel(x,y)
			var b := pictures[1].get_pixel(x,y)
			if a!=b: changed+=1
			total+=Vector3(absf(b.r-a.r),absf(b.g-a.g),absf(b.b-a.b))
	var data := {"engine":Engine.get_version_info(),"driver":RenderingServer.get_current_rendering_driver_name(),"ambient_energy":ambient_energy,"guard":background_guard(),"draws":completed,"completion_deltas":completions,"changed_pixels":changed,"mean_absolute_rgb":[total.x/480000,total.y/480000,total.z/480000]}
	FileAccess.open(output.path_join("control.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	view.queue_free()
	for cleanup in range(3):
		await process_frame
		RenderingServer.force_draw(false)
	print("LOCAL_REFLECTION_CONTROL_OK changed_pixels=",changed)
	quit()

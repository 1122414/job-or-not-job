extends "res://tools/render_character_candidates.gd"

# Background-only controlled GPU experiment; timings are not gameplay FPS.
var completed := 0

func background_guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func make_box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size=size
	mesh.mesh=shape
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.9
	mesh.material_override=material
	mesh.position=position
	mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(mesh)
	return mesh

func on_draw() -> void:
	completed+=1

func region_mean(picture: Image, region: Rect2i) -> Array:
	var total := Vector3.ZERO
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var color := picture.get_pixel(x,y)
			total+=Vector3(color.r,color.g,color.b)
	total/=region.size.x*region.size.y
	return [total.x,total.y,total.z]

func run() -> void:
	var mode := "baseline"
	var indirect := 1.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
		if argument.begins_with("--indirect="): indirect=float(argument.trim_prefix("--indirect="))
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus" or mode not in ["baseline","sdfgi","ssil","voxel"] or not is_finite(indirect) or indirect<0 or indirect>4:
		push_error("Require real Forward+ graphics and baseline/sdfgi/ssil/voxel mode"); quit(1); return
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
	make_box(stage,Vector3(10,.4,10),Vector3(0,-.2,0),Color(.7,.7,.7))
	make_box(stage,Vector3(.4,5,10),Vector3(-5,2.5,0),Color(.7,.08,.04))
	make_box(stage,Vector3(10,5,.4),Vector3(0,2.5,-5),Color(.7,.7,.7))
	make_box(stage,Vector3(2,2,2),Vector3(0,1,0),Color(.7,.7,.7))
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	var env := world.environment
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(.03,.03,.03)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_white=6.0
	env.sdfgi_enabled=mode=="sdfgi"
	env.sdfgi_read_sky_light=false
	env.sdfgi_cascades=4
	env.sdfgi_min_cell_size=.1
	env.sdfgi_use_occlusion=true
	env.ssil_enabled=mode=="ssil"
	env.ssil_radius=3.0
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-55,-40,0)
	light.light_energy=2.0
	light.light_indirect_energy=indirect
	light.light_bake_mode=Light3D.BAKE_DYNAMIC
	light.shadow_enabled=true
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(7,4.5,8)
	camera.look_at(Vector3(-1,1,0))
	camera.current=true
	camera.fov=55
	if mode=="voxel":
		var probe := VoxelGI.new()
		probe.size=Vector3(12,8,12)
		probe.position=Vector3(0,3,0)
		probe.subdiv=VoxelGI.SUBDIV_128
		stage.add_child(probe)
		await process_frame
		probe.bake(stage)
		if probe.data==null:
			push_error("Missing voxel data after bake"); quit(1); return
		probe.data.interior=true
	RenderingServer.frame_post_draw.connect(on_draw)
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	var times := []
	for index in range(160):
		await process_frame
		var start := Time.get_ticks_usec()
		var before := completed
		RenderingServer.force_draw(false)
		var wall := (Time.get_ticks_usec()-start)/1000.0
		for pending in range(3):
			if completed>before: break
			await process_frame
		if completed-before!=1 or not background_guard():
			push_error("Invalid background rendering sample"); quit(1); return
		if index>=128: times.append(wall)
	var picture := view.get_texture().get_image()
	if picture==null or picture.is_empty() or picture.save_png(output.path_join("probe.png"))!=OK:
		push_error("Missing GI image"); quit(1); return
	var data := {"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"mode":mode,"indirect_energy":indirect,"warmup":128,"samples":32,"force_draw_wall_ms":times,"normal_game_fps":false,"draws":completed,"guard":background_guard(),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())}
	data.regions={"cube_shadow":{"rect":[455,310,30,30],"mean_rgb":region_mean(picture,Rect2i(455,310,30,30))},"wall_shadow":{"rect":[180,180,60,50],"mean_rgb":region_mean(picture,Rect2i(180,180,60,50))}}
	FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	stage.queue_free()
	await process_frame
	print("INDIRECT_LIGHT_PROBE_OK mode=",mode," indirect=",indirect," draws=",completed)
	quit()

extends SceneTree

# Isolated GPU rendering: hidden unfocusable window, no game scene or pointer lock.
var output := "res://build/character-candidate-images"
var source := "res://build/character-candidates"
var extended := false
var captures := 0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--source="): source=argument.trim_prefix("--source=")
		if argument=="--extended": extended=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(900,1000)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov=32
	camera.current=true
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("303844")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=0.55
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-30,-25,0)
	key.light_energy=1.2
	stage.add_child(key)
	Shapes.box(stage,Vector3(4,0.03,4),Vector3(0,-0.025,0),Color("4c5662"))
	for person in ["protagonist","lin_lan","a_cheng"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(source.path_join(person+".glb"),state)!=OK: quit(1); return
		var model := document.generate_scene(state)
		stage.add_child(model)
		var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		for side in ["L","R"]:
			skeleton.set_bone_pose_rotation(skeleton.find_bone("upperarm01."+side),Quaternion(Vector3.FORWARD,0.62 if side=="L" else -0.62))
		var heights := {"front":[Vector3(0,1.1,3.8),Vector3(0,0.92,0)],"side":[Vector3(3.8,1.1,0),Vector3(0,0.92,0)],"back":[Vector3(0,1.1,-3.8),Vector3(0,0.92,0)]}
		for view in heights:
			camera.position=heights[view][0]
			camera.look_at(heights[view][1])
			if not await capture(viewport,person+"-"+view): quit(1); return
		var head_y := skeleton.get_bone_global_rest(skeleton.find_bone("head")).origin.y+0.09
		camera.position=Vector3(0,head_y,1.03)
		camera.look_at(Vector3(0,head_y,0))
		for expression in ["neutral","blink","brow_raise","brow_lower","mouth_open"]:
			for mesh in model.find_children("*","MeshInstance3D",true,false):
				for id in range(mesh.get_blend_shape_count()): mesh.set_blend_shape_value(id,1.0 if String(mesh.mesh.get_blend_shape_name(id))==expression else 0.0)
			if not await capture(viewport,person+"-"+expression): quit(1); return
		if extended:
			for expression in ["blink","brow_raise","brow_lower","mouth_open"]:
				for weight in [0.25,0.5,0.75]:
					set_expression(model,{expression:weight})
					if not await capture(viewport,person+"-"+expression+"-"+str(weight)): quit(1); return
			for pose in ["surprise","frown"]:
				set_expression(model,{"mouth_open":0.6,"brow_raise":0.7} if pose=="surprise" else {"blink":0.5,"brow_lower":0.7})
				if not await capture(viewport,person+"-"+pose): quit(1); return
			for view in ["portrait-side","portrait-three-quarter"]:
				camera.position=Vector3(1.03,head_y,0) if view=="portrait-side" else Vector3(0.65,head_y,0.8)
				camera.look_at(Vector3(0,head_y,0))
				for pose in ["neutral","mouth_open"]:
					set_expression(model,{pose:1.0})
					if not await capture(viewport,person+"-"+view+"-"+pose): quit(1); return
		model.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	print("OFFSCREEN_CHARACTERS images=",captures," pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	quit()

func set_expression(model: Node,values: Dictionary) -> void:
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for id in range(mesh.get_blend_shape_count()):
			mesh.set_blend_shape_value(id,float(values.get(String(mesh.mesh.get_blend_shape_name(id)),0.0)))

func capture(viewport: SubViewport,title: String) -> bool:
	for i in range(3):
		await process_frame
		RenderingServer.force_draw(false)
	var picture := viewport.get_texture().get_image()
	var success := picture!=null and not picture.is_empty() and picture.save_png(output.path_join(title+".png"))==OK
	if success: captures+=1
	return success

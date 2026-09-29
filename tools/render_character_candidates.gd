extends SceneTree

# Isolated GPU rendering: minimized unfocusable root, no desktop pointer lock.
var output := "res://build/character-candidate-images"
var source := "res://build/character-candidates"
var extended := false
var captures := 0
var imported := false
var msaa := 0
var motion := false
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--source="): source=argument.trim_prefix("--source=")
		if argument=="--extended": extended=true
		if argument=="--imported": imported=true
		if argument=="--motion": motion=true
		if argument.begins_with("--msaa="): msaa=int(argument.trim_prefix("--msaa="))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("background_run")

func background_run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.mode=Window.MODE_MINIMIZED
	await run()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(900,1000)
	viewport.own_world_3d=true
	viewport.msaa_3d=msaa
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
		var model: Node3D
		if motion:
			model=HumanVisual.new()
			model.cast_id=person
			model.rotation.y=PI
		elif imported:
			model=load(source.path_join(person+".glb")).instantiate()
		else:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(source.path_join(person+".glb"),state)!=OK: quit(1); return
			model=document.generate_scene(state)
		stage.add_child(model)
		if motion:
			if not await capture_motion(viewport,camera,model,person): quit(1); return
			model.queue_free()
			await process_frame
			continue
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

func capture_motion(viewport: SubViewport,camera: Camera3D,human: HumanVisual,person: String) -> bool:
	human.set_process(false)
	human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var poses := {"idle":0.6,"talk":0.8,"walk":0.25,"run":0.125,"work":0.4,"sit":0.4,"carry":0.25,"carry_idle":0.4,"strike":0.22,"recoil":0.15,"fallen":0.4}
	for clip in poses:
		human.position=human.seated_offset if clip in ["work","sit"] else Vector3.ZERO
		human.animation.stop()
		human.skeleton.reset_bone_poses()
		human.animation.play(clip)
		human.animation.seek(poses[clip],true)
		human.animation.advance(0)
		camera.position=Vector3(2.0,1.1,3.2)
		camera.look_at(Vector3(0,0.92,0))
		if not await capture(viewport,person+"-motion-"+clip): return false
		if clip in ["work","sit","carry_idle"]:
			camera.position=Vector3(3.8,1.1,0)
			camera.look_at(Vector3(0,0.92,0))
			if not await capture(viewport,person+"-motion-"+clip+"-side"): return false
	return true

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

extends SceneTree

const Adapter = preload("res://tools/character_retarget.gd")
const SOURCE := "res://production/quaternius/standard-2025-06-10/"
const OUTPUT := "res://build/character-retarget-preview/"
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"provenance.json"))
	for file in provenance.files: check(FileAccess.get_sha256(SOURCE+file)==provenance.files[file].sha256,"Source checksum: "+file)
	if failures: quit(1); return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(SOURCE+"glTF/AnimationLibrary_Godot_Standard.gltf",state)!=OK: quit(1); return
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var source: Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer=scene.find_children("*","AnimationPlayer",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	scene.visible=false
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var graphical := DisplayServer.get_name()!="headless"
	if graphical: make_stage()
	var report := {"scope":"Offline MakeHuman adapter preview; not approved for runtime or contact quality","source_commit":provenance.mirror_commit,"samples":[]}
	for outfit in ["casual","office","office_female"]:
		var human := HumanVisual.new()
		human.outfit=outfit
		root.add_child(human)
		human.get_node("Model").rotation.y=0
		human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var adapter := Adapter.new()
		check(adapter.setup(source,human.skeleton)==OK,"Bone map: "+outfit)
		if failures: human.queue_free(); break
		print("MAP ",outfit," entries=",adapter.mapping.size()," source_transform=",source.global_transform," scale=",adapter.hip_scale)
		for clip_name in ["A_TPose","Idle_Loop","Idle_Talking_Loop","Walk_Loop","Sitting_Idle_Loop","PickUp_Table"]:
			var source_clip := player.get_animation(clip_name)
			var max_length_error := 0.0
			var min_foot_y := INF
			for sample in range(61):
				var time := source_clip.length*float(sample)/60.0
				player.stop(); source.reset_bone_poses(); player.play(clip_name); player.seek(time,true); player.advance(0)
				human.animation.stop(); human.skeleton.reset_bone_poses()
				adapter.apply_pose()
				for id in range(human.skeleton.get_bone_count()):
					var pose := human.skeleton.get_bone_pose(id)
					check(pose.is_finite(),"Finite retarget pose: "+outfit+clip_name)
					if human.skeleton.get_bone_parent(id)>=0:
						max_length_error=maxf(max_length_error,absf(pose.origin.length()-human.skeleton.get_bone_rest(id).origin.length()))
				for side in ["L","R"]:
					min_foot_y=minf(min_foot_y,human.skeleton.get_bone_global_pose(human.skeleton.find_bone("foot."+side)).origin.y)
				if graphical and sample==30:
					for frame in range(3): await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUTPUT+outfit+"_"+clip_name+".png")
			check(max_length_error<0.00001,"Preserve target bone lengths: "+outfit+clip_name)
			report.samples.append({"outfit":outfit,"clip":clip_name,"sample_count":61,"mapped_bones":adapter.mapping.size(),"max_local_length_error_m":max_length_error,"min_ankle_y_m":min_foot_y})
		human.queue_free()
		await process_frame
	report["failures"]=failures
	var file := FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	scene.queue_free()
	await process_frame
	print("RETARGET_PREVIEW_TEST failures=",failures," samples=",report.samples.size())
	quit(failures)

func make_stage() -> void:
	root.size=Vector2i(960,720)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position=Vector3(2,1.5,3.4)
	camera.look_at(Vector3(0,0.95,0))
	camera.current=true
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees=Vector3(-50,-30,0)
	light.light_energy=1.5
	var world := WorldEnvironment.new()
	root.add_child(world)
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("242e38")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=0.65
	var floor_root := Node3D.new()
	root.add_child(floor_root)
	Shapes.box(floor_root,Vector3(5,0.04,5),Vector3(0,-0.02,0),Color("525e67"))

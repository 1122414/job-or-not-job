extends SceneTree

const SOURCE := "res://production/quaternius/standard-2025-06-10/"
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
	if scene==null: push_error("Source scene generation failed"); quit(1); return
	root.add_child(scene)
	var skeletons := scene.find_children("*","Skeleton3D",true,false)
	var players := scene.find_children("*","AnimationPlayer",true,false)
	if skeletons.size()!=1 or players.size()!=1: push_error("Expected one source skeleton and player"); scene.free(); quit(1); return
	var skeleton: Skeleton3D=skeletons[0]
	var player: AnimationPlayer=players[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var names := player.get_animation_list()
	check(skeleton.get_bone_count()==53,"Expected 53 source bones")
	var report := {"author":provenance.author,"mirror_commit":provenance.mirror_commit,"bones":[],"animations":[],"extent_space":"Skeleton global pose; model-space metres, 13 samples, not continuous extrema","scope":"Production source only; no retargeting or runtime replacement validated"}
	for i in range(skeleton.get_bone_count()): report.bones.append({"name":skeleton.get_bone_name(i),"parent":skeleton.get_bone_parent(i)})
	for name in names:
		if name=="RESET": continue
		var clip := player.get_animation(name)
		check(clip.length>0,"Clip duration: "+name)
		var root_min := Vector3(INF,INF,INF)
		var root_max := Vector3(-INF,-INF,-INF)
		var hip_min := root_min
		var hip_max := root_max
		var keys := 0
		for track in range(clip.get_track_count()):
			for key in range(clip.track_get_key_count(track)):
				var time := clip.track_get_key_time(track,key)
				check(is_finite(time) and time>=0 and time<=clip.length+0.001,"Key time: "+name)
				var value: Variant=clip.track_get_key_value(track,key)
				if value is Vector3 or value is Quaternion: check(value.is_finite(),"Finite animation value: "+name)
				keys+=1
		for step in range(13):
			player.play(name)
			player.seek(clip.length*step/12.0,true)
			player.advance(0)
			for bone in range(skeleton.get_bone_count()): check(skeleton.get_bone_global_pose(bone).is_finite(),"Finite source pose: "+name)
			var root_point := skeleton.get_bone_global_pose(skeleton.find_bone("root")).origin
			var hip_point := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hips")).origin
			root_min=root_min.min(root_point); root_max=root_max.max(root_point)
			hip_min=hip_min.min(hip_point); hip_max=hip_max.max(hip_point)
		report.animations.append({"name":name,"seconds":clip.length,"tracks":clip.get_track_count(),"keys":keys,"sample_count":13,"root_extent_m":[root_max.x-root_min.x,root_max.y-root_min.y,root_max.z-root_min.z],"hips_extent_m":[hip_max.x-hip_min.x,hip_max.y-hip_min.y,hip_max.z-hip_min.z]})
	check(report.animations.size()==46,"Expected 46 Standard clips including T-pose")
	for required in ["Idle_Loop","Walk_Loop","Sitting_Idle_Loop","PickUp_Table"]: check(player.has_animation(required),"Required sample: "+required)
	DirAccess.make_dir_recursive_absolute("res://build/animation-source-preview")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(960,720)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position=Vector3(2,1.6,3)
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
		for entry in [["Idle_Loop",0.5],["Walk_Loop",0.25],["Sitting_Idle_Loop",0.5],["PickUp_Table",0.55]]:
			player.play(entry[0]); player.seek(player.get_animation(entry[0]).length*entry[1],true); player.advance(0)
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/animation-source-preview/"+entry[0]+".png")
		world.queue_free(); light.queue_free(); camera.queue_free()
	report["failures"]=failures
	var file := FileAccess.open("res://build/animation-source-preview/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	scene.queue_free()
	await process_frame
	print("ANIMATION_SOURCE_TEST failures=",failures," bones=",report.bones.size()," clips=",report.animations.size())
	quit(failures)

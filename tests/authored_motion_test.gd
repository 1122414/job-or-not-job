extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func paths(clip: Animation) -> Array[String]:
	var result: Array[String]=[]
	for track in range(clip.get_track_count()): result.append(str(clip.track_get_path(track))+"/"+str(clip.track_get_type(track)))
	result.sort()
	return result
func sample(human: HumanVisual,clip: String,time: float) -> void:
	human.animation.stop()
	human.skeleton.reset_bone_poses()
	human.animation.play(clip)
	human.animation.seek(time,true)
	human.animation.advance(0)
func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/provenance.json"))
	check(FileAccess.get_sha256("res://assets/animations/quaternius_upper_body.res")==provenance.library_sha256,"Baked resource provenance")
	for outfit in ["casual","office","office_female","protagonist","lin_lan","a_cheng"]:
		if outfit in ["protagonist","lin_lan","a_cheng"]:
			var cast_provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/cast/"+outfit+"-provenance.json"))
			check(FileAccess.get_sha256("res://assets/characters/cast/"+outfit+".glb")==cast_provenance.target_files["cast/"+outfit],"New proportions require own bake")
			check(FileAccess.get_sha256("res://assets/animations/cast/"+outfit+".res")==cast_provenance.library_sha256,"Cast animation provenance")
		else:
			check(FileAccess.get_sha256("res://assets/characters/"+outfit+".glb")==provenance.target_files[outfit],"Target rig must be rebaked after asset change")
		var human := HumanVisual.new()
		if outfit in ["protagonist","lin_lan","a_cheng"]: human.cast_id=outfit
		else: human.outfit=outfit
		root.add_child(human)
		human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var reference := HumanVisual.new()
		if outfit in ["protagonist","lin_lan","a_cheng"]: reference.cast_id=outfit
		else: reference.outfit=outfit
		root.add_child(reference)
		reference.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var expected := paths(human.animation.get_animation("idle"))
		for clip in human.animation.get_animation_list(): check(paths(human.animation.get_animation(clip))==expected,"All clips reset shared tracks: "+clip)
		for clip in ["walk","run"]:
			var procedural := human.make_clip(clip)
			reference.animation.get_animation_library("").add_animation("support_"+clip,procedural)
			var maximum_support_error := 0.0
			var shoulder_motion := 0.0
			var initial_shoulder := Quaternion.IDENTITY
			for frame in range(67):
				var time := float(frame)/66.0
				sample(human,clip,time);sample(reference,"support_"+clip,time)
				for side in ["L","R"]:
					for joint in ["upperleg01.","lowerleg01.","foot."]:
						var bone := human.skeleton.find_bone(joint+side)
						maximum_support_error=maxf(maximum_support_error,human.skeleton.get_bone_global_pose(bone).origin.distance_to(reference.skeleton.get_bone_global_pose(bone).origin))
				var shoulder := human.skeleton.get_bone_pose_rotation(human.skeleton.find_bone("clavicle.R"))
				if frame==0:initial_shoulder=shoulder
				shoulder_motion=maxf(shoulder_motion,shoulder.angle_to(initial_shoulder))
			check(maximum_support_error<.0001,"Authored upper body retains physical leg support: "+outfit+clip)
			check(shoulder_motion>.01,"Walking/running includes authored shoulder coordination: "+outfit+clip)
			print("AUTHORED_GAIT ",outfit," ",clip," support_error_m=",maximum_support_error," shoulder_motion_rad=",shoulder_motion)
		for clip in ["idle","talk"]:
			var duration := human.animation.get_animation(clip).length
			var max_foot_drift := 0.0
			var wrist_min := Vector3(INF,INF,INF)
			var wrist_max := Vector3(-INF,-INF,-INF)
			sample(human,clip,0)
			var feet := []
			for side in ["L","R"]: feet.append(human.skeleton.get_bone_global_pose(human.skeleton.find_bone("foot."+side)).origin)
			for frame in range(61):
				sample(human,clip,duration*frame/60.0)
				for bone in range(human.skeleton.get_bone_count()): check(human.skeleton.get_bone_global_pose(bone).is_finite(),"Finite authored pose")
				for i in range(2):
					var foot := human.skeleton.get_bone_global_pose(human.skeleton.find_bone("foot."+["L","R"][i])).origin
					max_foot_drift=maxf(max_foot_drift,foot.distance_to(feet[i]))
				var wrist := human.skeleton.get_bone_global_pose(human.skeleton.find_bone("wrist.R")).origin
				wrist_min=wrist_min.min(wrist); wrist_max=wrist_max.max(wrist)
			check(max_foot_drift<0.0001,"Standing feet stay planted: "+outfit+clip)
			check(wrist_max.distance_to(wrist_min)>(0.05 if clip=="talk" else 0.002),"Visible authored motion: "+outfit+clip)
			print("AUTHORED ",outfit," ",clip," foot_drift_m=",max_foot_drift," wrist_extent_m=",wrist_max.distance_to(wrist_min))
		# Cross-fade out of a new gesture into every existing interaction.
		for clip in human.animation.get_animation_list():
			if clip in ["idle","talk"]: continue
			sample(human,"talk",0.8)
			human.animation.play(clip,0.2)
			for frame in range(15): human.animation.advance(1.0/60.0)
			sample(reference,clip,0.25)
			var max_rotation_error := 0.0
			var max_position_error := 0.0
			for bone in range(human.skeleton.get_bone_count()):
				max_rotation_error=maxf(max_rotation_error,human.skeleton.get_bone_pose_rotation(bone).angle_to(reference.skeleton.get_bone_pose_rotation(bone)))
				max_position_error=maxf(max_position_error,human.skeleton.get_bone_pose_position(bone).distance_to(reference.skeleton.get_bone_pose_position(bone)))
			check(max_rotation_error<0.003,"No gesture rotation residue: "+outfit+clip+str(max_rotation_error))
			check(max_position_error<0.0001,"No gesture position residue: "+outfit+clip)
		human.queue_free(); reference.queue_free()
		await process_frame
	print("AUTHORED_MOTION_TEST failures=",failures)
	quit(failures)

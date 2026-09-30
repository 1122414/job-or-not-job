extends SceneTree

const Adapter = preload("res://tools/character_retarget.gd")
const SOURCE := "res://production/quaternius/standard-2025-06-10/"
var output := "res://assets/animations/"
var cast_id := ""
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cast="): cast_id=argument.trim_prefix("--cast=")
	if not cast_id.is_empty():
		check(cast_id in ["protagonist","lin_lan","a_cheng"],"Known cast identity")
		output+="cast/"
	if failures: quit(1); return
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
	var human := HumanVisual.new()
	human.cast_id=cast_id
	human.use_authored_motion=false
	root.add_child(human)
	human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var adapter := Adapter.new()
	check(adapter.setup(source,human.skeleton)==OK,"Complete bone mapping")
	if failures: scene.queue_free(); human.queue_free(); await process_frame; quit(1); return
	# Existing outfits currently share a rig. Refuse silent reuse if proportions change.
	for outfit in (["office","office_female"] if cast_id.is_empty() else []):
		var model: Node=load("res://assets/characters/"+outfit+".glb").instantiate()
		root.add_child(model)
		var other: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		check(other.get_bone_count()==human.skeleton.get_bone_count(),"Shared target bone count")
		for bone in range(other.get_bone_count()):
			var id := human.skeleton.find_bone(other.get_bone_name(bone))
			check(id>=0 and other.get_bone_rest(bone).is_equal_approx(human.skeleton.get_bone_rest(id)),"Shared target rest: "+outfit+other.get_bone_name(bone))
		model.queue_free()
	if failures: scene.queue_free(); human.queue_free(); await process_frame; quit(1); return
	var library := AnimationLibrary.new()
	var metadata := {"author":"Quaternius","license":"CC0-1.0","source_commit":provenance.mirror_commit,"scope":"Authored idle, talk and phase-aligned walking/running upper body; proportion-correct planted legs, root and specialized interactions retained","sample_rate_hz":60,"clips":[],"source_files":provenance.files,"target_files":{}}
	for outfit in (["casual","office","office_female"] if cast_id.is_empty() else ["cast/"+cast_id]): metadata.target_files[outfit]=FileAccess.get_sha256("res://assets/characters/"+outfit+".glb")
	for pair in [["idle","Idle_Loop"],["talk","Idle_Talking_Loop"],["walk","Walk_Loop"],["run","Jog_Fwd_Loop"]]:
		var locomotion: bool=pair[0] in ["walk","run"]
		var base := human.make_clip(pair[0] if locomotion else "idle")
		var base_name: String="bake_"+pair[0]
		human.animation.get_animation_library("").add_animation(base_name,base)
		var source_duration := player.get_animation(pair[1]).length
		# Both target gaits start at left heel strike. Align the source's forward
		# left foot to that event, rather than pairing unrelated arm/leg phases.
		var source_phase := forward_left_phase(source,player,pair[1]) if locomotion else 0.0
		var clip := Animation.new()
		clip.length=1.0 if locomotion else source_duration
		clip.loop_mode=Animation.LOOP_LINEAR
		var track_bones: Array[int]=[]
		for entry in adapter.mapping:
			var name: String=entry.target_name
			if name=="root" or name.begins_with("upperleg") or name.begins_with("lowerleg") or name.begins_with("foot"): continue
			track_bones.append(entry.target)
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track,NodePath(str(human.get_path_to(human.skeleton))+":"+name))
		# Include all base tracks so transitions out of a pose cannot leave old legs/root.
		for track in range(base.get_track_count()):
			if clip.find_track(base.track_get_path(track),base.track_get_type(track))<0: base.copy_track(track,clip)
		# Standing clips retain a constant planted base. Moving clips keep every
		# original support key and the one-second cycle used by speed/footsteps.
		if not locomotion:
			for track in range(track_bones.size(),clip.get_track_count()):
				var value: Variant=clip.track_get_key_value(track,0)
				while clip.track_get_key_count(track)>0: clip.track_remove_key(track,0)
				clip.track_insert_key(track,0,value)
				clip.track_insert_key(track,clip.length,value)
		var frame_count := ceili(clip.length*60)
		var first_rotations: Array[Quaternion]=[]
		var seam := 0.0
		for frame in range(frame_count+1):
			var time := clip.length*float(frame)/frame_count
			var source_time := fposmod(time/clip.length+source_phase,1.0)*source_duration if locomotion else time
			player.stop(); source.reset_bone_poses(); player.play(pair[1]); player.seek(source_time,true); player.advance(0)
			human.animation.stop(); human.skeleton.reset_bone_poses()
			human.animation.play(base_name); human.animation.seek(time if locomotion else 0.0,true); human.animation.advance(0)
			adapter.apply_pose(true)
			for track in range(track_bones.size()):
				var q := human.skeleton.get_bone_pose_rotation(track_bones[track])
				check(q.is_finite() and is_equal_approx(q.length(),1.0),"Finite unit quaternion")
				if frame==0: first_rotations.append(q)
				if frame==frame_count: seam=maxf(seam,q.angle_to(first_rotations[track]))
				clip.rotation_track_insert_key(track,time,q)
		check(seam<0.02,"Source loop seam below 0.02 radians: "+pair[0]+str(seam))
		library.add_animation(pair[0],clip)
		metadata.clips.append({"name":pair[0],"source":pair[1],"seconds":clip.length,"source_seconds":source_duration,"source_phase":source_phase,"frames":frame_count+1,"tracks":clip.get_track_count(),"max_loop_seam_radians":seam})
	if failures==0:
		DirAccess.make_dir_recursive_absolute(output)
		var resource_name := "quaternius_upper_body" if cast_id.is_empty() else cast_id
		check(ResourceSaver.save(library,output+resource_name+".res")==OK,"Save baked library")
		metadata["library_sha256"]=FileAccess.get_sha256(output+resource_name+".res")
		var file := FileAccess.open(output+("provenance" if cast_id.is_empty() else cast_id+"-provenance")+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(metadata,"\t"))
	scene.queue_free(); human.queue_free()
	await process_frame
	print("BAKE_CHARACTER_ANIMATIONS failures=",failures," clips=",metadata.clips)
	quit(failures)

func forward_left_phase(source: Skeleton3D,player: AnimationPlayer,clip: String) -> float:
	var foot := source.find_bone("DEF-foot.L")
	var hip := source.find_bone("DEF-hips")
	var duration := player.get_animation(clip).length
	var furthest := -INF
	var phase := 0.0
	for sample in range(240):
		player.stop();source.reset_bone_poses();player.play(clip)
		player.seek(duration*sample/240.0,true);player.advance(0)
		var forward := source.get_bone_global_pose(foot).origin.z-source.get_bone_global_pose(hip).origin.z
		if forward>furthest:furthest=forward;phase=sample/240.0
	return phase

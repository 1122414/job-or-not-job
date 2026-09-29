extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var directory := "res://build/character-candidates"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): directory=argument.trim_prefix("--source=")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("candidates.json")))
	var report := {"scope":"headless structural checks only; appearance, contacts, LOD and runtime integration unaccepted","characters":[]}
	for character in manifest.characters:
		var path: String=directory.path_join(character.id+".glb")
		check(FileAccess.get_sha256(path)==character.sha256,"候选摘要："+character.id)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file(path,state)==OK,"候选GLB解析："+character.id)
		var model := document.generate_scene(state)
		root.add_child(model)
		var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		for bone in ["root","head","wrist.R","wrist.L","upperleg01.L","foot.L","eye.L","eye.R","jaw"]:
			check(skeleton.find_bone(bone)>=0,"必需骨骼："+character.id+"/"+bone)
		for id in range(skeleton.get_bone_count()):
			check(skeleton.get_bone_global_rest(id).is_finite(),"有限静止骨骼")
		var expressions := []
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if String(mesh.name)=="eyes":
				var eye_material: StandardMaterial3D=mesh.get_active_material(0)
				check(eye_material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"眼球透明外层不遮挡虹膜")
			if String(mesh.name)=="body":
				for id in range(mesh.get_blend_shape_count()):
					expressions.append(String(mesh.mesh.get_blend_shape_name(id)))
					mesh.set_blend_shape_value(id,1.0)
					check(mesh.get_blend_shape_value(id)==1.0,"表情权重可驱动")
					mesh.set_blend_shape_value(id,0.0)
			check(mesh.get_aabb().size.length()<3 and mesh.get_aabb().size.length()>0,"网格尺寸合理："+String(mesh.name))
		for name in ["blink","brow_raise","brow_lower","mouth_open"]: check(expressions.has(name),"表情形变存在："+character.id+"/"+name)
		report.characters.append({"id":character.id,"bones":skeleton.get_bone_count(),"expressions":expressions,"sha256":character.sha256})
		model.queue_free()
		await process_frame
	report["failures"]=failures
	FileAccess.open(directory.path_join("inspection.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CHARACTER_CANDIDATES failures=",failures)
	quit(failures)

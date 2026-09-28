extends RefCounted

# Offline adapter for the checked-in Quaternius source and MakeHuman target only.
# Keep target rests, weights and local translations; bake rotation tracks instead.
var source: Skeleton3D
var target: Skeleton3D
var mapping: Array[Dictionary] = []
var ordered_bones: Array[int] = []
var hip_scale := 1.0

func setup(source_skeleton: Skeleton3D,target_skeleton: Skeleton3D) -> Error:
	source=source_skeleton
	target=target_skeleton
	mapping.clear()
	ordered_bones.clear()
	var pairs := [
		["root","DEF-hips","", ""],
		["spine05","DEF-spine.001","", ""],
		["spine03","DEF-spine.002","", ""],
		["spine01","DEF-spine.003","", ""],
		["neck01","DEF-neck","", ""],
		["head","DEF-head","", ""]]
	for side in ["L","R"]:
		pairs.append_array([
			["clavicle."+side,"DEF-shoulder."+side,"upperarm01."+side,"DEF-upper_arm."+side],
			["upperarm01."+side,"DEF-upper_arm."+side,"lowerarm01."+side,"DEF-forearm."+side],
			["lowerarm01."+side,"DEF-forearm."+side,"wrist."+side,"DEF-hand."+side],
			["wrist."+side,"DEF-hand."+side,"finger3-1."+side,"DEF-f_middle.01."+side],
			["upperleg01."+side,"DEF-thigh."+side,"lowerleg01."+side,"DEF-shin."+side],
			["lowerleg01."+side,"DEF-shin."+side,"foot."+side,"DEF-foot."+side],
			["foot."+side,"DEF-foot."+side,"toe1-1."+side,"DEF-toe."+side]])
		for finger in range(1,6):
			var source_finger: String=["thumb","f_index","f_middle","f_ring","f_pinky"][finger-1]
			for joint in range(1,4):
				var target_name := "finger%d-%d.%s"%[finger,joint,side]
				var source_name := "DEF-%s.%02d.%s"%[source_finger,joint,side]
				pairs.append([target_name,source_name,"finger%d-%d.%s"%[finger,joint+1,side] if joint<3 else "","DEF-%s.%02d.%s"%[source_finger,joint+1,side] if joint<3 else ""])
	for pair in pairs:
		var target_id := target.find_bone(pair[0])
		var source_id := source.find_bone(pair[1])
		if target_id<0 or source_id<0:
			push_error("Missing mapped bone: "+str(pair))
			return ERR_INVALID_DATA
		var target_rest := target.get_bone_global_rest(target_id)
		var source_rest := source.get_bone_global_rest(source_id)
		var align := Basis.IDENTITY
		if pair[2]!="":
			var target_child := target.find_bone(pair[2])
			var source_child := source.find_bone(pair[3])
			if target_child<0 or source_child<0:
				push_error("Missing reference joint: "+str(pair))
				return ERR_INVALID_DATA
			var target_direction := (target.get_bone_global_rest(target_child).origin-target_rest.origin).normalized()
			var source_direction := (source.get_bone_global_rest(source_child).origin-source_rest.origin).normalized()
			align=Basis(Quaternion(target_direction,source_direction))
		mapping.append({"target":target_id,"source":source_id,"target_name":pair[0],"source_name":pair[1],"correction":source_rest.basis.inverse()*align*target_rest.basis})
	for id in target.get_parentless_bones(): append_branch(id)
	hip_scale=target.get_bone_global_rest(target.find_bone("root")).origin.y/source.get_bone_global_rest(source.find_bone("DEF-hips")).origin.y
	return OK

func append_branch(id: int) -> void:
	ordered_bones.append(id)
	for child in target.get_bone_children(id): append_branch(child)

func apply_pose(upper_body_only: bool=false) -> void:
	# Call after applying a target base pose when baking upper-body clips.
	var rotations := {}
	for entry in mapping:
		if upper_body_only and (entry.target_name=="root" or entry.target_name.begins_with("upperleg") or entry.target_name.begins_with("lowerleg") or entry.target_name.begins_with("foot")): continue
		rotations[entry.target]=(source.get_bone_global_pose(entry.source).basis*entry.correction).orthonormalized()
	for id in ordered_bones:
		if not rotations.has(id): continue
		var parent := target.get_bone_parent(id)
		var parent_basis := target.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
		var local: Basis=parent_basis.inverse()*rotations[id]
		target.set_bone_pose_rotation(id,local.orthonormalized().get_rotation_quaternion())
	if not upper_body_only:
		var source_hip := source.find_bone("DEF-hips")
		var target_hip := target.find_bone("root")
		var displacement := source.get_bone_global_pose(source_hip).origin-source.get_bone_global_rest(source_hip).origin
		target.set_bone_pose_position(target_hip,target.get_bone_rest(target_hip).origin+displacement*hip_scale)

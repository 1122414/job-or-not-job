class_name HandContact
extends RefCounted

# Palm frames come from each imported body's bones and skin, not a wrist offset
# shared by differently sized characters. +Y points to the fingers, +Z out of skin.
var skeleton: Skeleton3D
var palms := {}

func _init(human: HumanVisual) -> void:
	skeleton=human.skeleton
	var body: MeshInstance3D=human.find_children("body","MeshInstance3D",true,false)[0]
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for side in ["L","R"]:
		var wrist := skeleton.find_bone("wrist."+side)
		var rest := skeleton.get_bone_global_rest(wrist)
		var middle := skeleton.get_bone_global_rest(skeleton.find_bone("finger3-1."+side)).origin
		var index := skeleton.get_bone_global_rest(skeleton.find_bone("finger2-1."+side)).origin
		var little := skeleton.get_bone_global_rest(skeleton.find_bone("finger5-1."+side)).origin
		var along := (middle-rest.origin).normalized()
		var normal := along.cross(index-little).normalized()
		if normal.y>0: normal=-normal
		var across := along.cross(normal).normalized()
		var center := rest.origin.lerp(middle,0.55)
		var depth := -INF
		var surface := center
		for i in vertices.size():
			var vertex := vertices[i]
			var offset := vertex-center
			if offset.length()>0.055: continue
			if absf(offset.dot(across))>0.035 or absf(offset.dot(along))>0.025: continue
			var palm_weight := 0.0
			for slot in range(4):
				var name := String(body.skin.get_bind_name(arrays[Mesh.ARRAY_BONES][i*4+slot]))
				if name=="wrist."+side or name.begins_with("metacarpal") and name.ends_with("."+side):
					palm_weight+=arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
			if palm_weight<0.98: continue
			if offset.dot(normal)>depth:
				depth=offset.dot(normal)
				surface=vertex
		palms[side]=rest.affine_inverse()*Transform3D(Basis(across,along,normal),surface)

func palm(side: String) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("wrist."+side))*palms[side]

# Two-bone reach with a stable elbow pole. Intermediate twist bones retain their
# imported lengths; unreachable targets clamp instead of stretching the arm.
func reach(side: String,target: Transform3D,weight: float=1.0) -> void:
	if weight<=0: return
	var upper := skeleton.find_bone("upperarm01."+side)
	var lower := skeleton.find_bone("lowerarm01."+side)
	var wrist := skeleton.find_bone("wrist."+side)
	var desired: Transform3D=skeleton.global_transform.affine_inverse()*target*palms[side].affine_inverse()
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(lower).origin
	var hand := skeleton.get_bone_global_pose(wrist).origin
	var first := shoulder.distance_to(elbow)
	var second := elbow.distance_to(hand)
	var vector := desired.origin-shoulder
	var length := clampf(vector.length(),absf(first-second)+0.001,first+second-0.002)
	var direction := vector.normalized()
	var pole := Vector3(1 if side=="L" else -1,-0.6,-0.3)
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var projection := (first*first+length*length-second*second)/(2*length)
	var solved_elbow := shoulder+direction*projection+bend*sqrt(maxf(0,first*first-projection*projection))
	var original_upper := skeleton.get_bone_pose_rotation(upper)
	var original_lower := skeleton.get_bone_pose_rotation(lower)
	var original_wrist := skeleton.get_bone_pose_rotation(wrist)
	align_bone(upper,elbow-shoulder,solved_elbow-shoulder)
	elbow=skeleton.get_bone_global_pose(lower).origin
	hand=skeleton.get_bone_global_pose(wrist).origin
	align_bone(lower,hand-elbow,shoulder+direction*length-elbow)
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(wrist)).basis
	skeleton.set_bone_pose_rotation(wrist,(parent.inverse()*desired.basis).get_rotation_quaternion())
	for pair in [[upper,original_upper],[lower,original_lower],[wrist,original_wrist]]:
		skeleton.set_bone_pose_rotation(pair[0],pair[1].slerp(skeleton.get_bone_pose_rotation(pair[0]),weight))

func align_bone(bone: int,from: Vector3,to: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
	var basis := Basis(Quaternion(from.normalized(),to.normalized()))*pose.basis
	skeleton.set_bone_pose_rotation(bone,(parent.inverse()*basis).get_rotation_quaternion())

func fingers(side: String,curl: float,weight: float=1.0) -> void:
	var axis: Vector3=palms[side].basis.x
	for finger in range(2,6):
		for joint in range(1,4):
			var bone := skeleton.find_bone("finger%d-%d.%s"%[finger,joint,side])
			var angle := curl*(0.55 if joint==1 else 1.0 if joint==2 else 0.70)
			skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(Quaternion(axis,angle),weight))
	if curl<0:
		var thumb := skeleton.find_bone("finger1-1."+side)
		skeleton.set_bone_pose_rotation(thumb,Quaternion.IDENTITY)
		var tip := skeleton.find_bone("finger1-3."+side)
		var direction := skeleton.get_bone_global_pose(tip).origin-skeleton.get_bone_global_pose(thumb).origin
		var normal: Vector3=(skeleton.global_basis.inverse()*palm(side).basis).z
		var tangent := (direction-normal*direction.dot(normal)).normalized()
		align_bone(thumb,direction,tangent-normal*0.7)

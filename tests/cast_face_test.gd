extends SceneTree

var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for person in ["protagonist","lin_lan","a_cheng"]:
		var human := HumanVisual.new()
		human.cast_id=person
		root.add_child(human)
		human.set_process(false)
		human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var other := HumanVisual.new()
		other.cast_id=person
		root.add_child(other)
		other.set_process(false)
		human.set_facial_expression({"brow_lower":1.5,"mouth_open":NAN})
		human.face_clock=1.0
		human.update_face(0.01)
		check(human.facial_expression.brow_lower==1.0 and human.facial_expression.mouth_open==0,"Expression input is finite and bounded")
		for mesh in human.face_meshes:
			var id := mesh.find_blend_shape_by_name("brow_lower")
			if id>=0: check(mesh.get_blend_shape_value(id)==1.0,"Every facial attachment follows expression")
		for mesh in other.face_meshes:
			for id in range(mesh.get_blend_shape_count()): check(mesh.get_blend_shape_value(id)==0.0,"Expression cannot leak to shared instances")
		human.set_facial_expression({})
		human.face_clock=0.09
		human.update_face(0)
		for mesh in human.face_meshes:
			var id := mesh.find_blend_shape_by_name("blink")
			if id>=0: check(mesh.get_blend_shape_value(id)>0.99,"Blink closes eyes and follows attached meshes")
		human.pose(0,false,false,false,false,false,true)
		human.face_clock=1.0
		human.update_face(0.01)
		for mesh in human.face_meshes:
			var id := mesh.find_blend_shape_by_name("mouth_open")
			if id>=0: check(mesh.get_blend_shape_value(id)==0.0,"Silent text conversation keeps mouth neutral")
		var eye := human.skeleton.find_bone("eye.L")
		var eye_pos := human.skeleton.get_bone_global_rest(eye).origin
		human.set_attention(human.skeleton.to_global(eye_pos+Vector3(2,1,2)),true)
		human.update_face(1.0)
		var q := human.skeleton.get_bone_pose_rotation(eye)
		check(q.is_finite() and q.get_euler().y>0.1 and q.get_euler().y<=0.251,"World target follows eye yaw limit")
		check(absf(q.get_euler().x)<=0.151,"Eye pitch remains bounded")
		human.set_attention(human.skeleton.to_global(eye_pos+Vector3(0,0,-2)),true)
		human.update_face(1.0)
		check(human.skeleton.get_bone_pose_rotation(eye).angle_to(Quaternion.IDENTITY)<0.001,"Target behind head returns gaze to neutral")
		human.set_facial_expression({"mouth_open":0.8,"brow_raise":0.6})
		human.pose(0,false,true)
		human.update_face(1.0)
		for mesh in human.face_meshes:
			for id in range(mesh.get_blend_shape_count()): check(mesh.get_blend_shape_value(id)==0.0,"Fallen state clears live expressions")
		human.pose(0,false,false)
		human.face_clock=1.0
		human.update_face(0)
		check(human.facial_expression.is_empty(),"Recovery cannot resume an interrupted mouth cue")
		check(human.grip.get_parent() is BoneAttachment3D,"Held item remains attached to wrist")
		human.queue_free(); other.queue_free()
		await process_frame
	print("CAST_FACE_TEST failures=",failures)
	quit(failures)

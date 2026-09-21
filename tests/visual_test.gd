extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func run() -> void:
	for outfit in ["casual","office","office_female"]:
		var human := HumanVisual.new()
		human.outfit=outfit
		root.add_child(human)
		check(human.skeleton!=null,"人物必须有骨骼："+outfit)
		check(human.find_children("*","MeshInstance3D",true,false).size()>=4,"身体、衣服、头发、鞋独立蒙皮")
		check(human.grip.get_parent() is BoneAttachment3D,"道具必须附着手腕骨骼")
		var bone := human.skeleton.find_bone("upperleg01.L")
		human.pose(3,false,false)
		for frame in range(15): await process_frame
		var walking := human.skeleton.get_bone_pose_rotation(bone)
		check(not walking.is_equal_approx(Quaternion.IDENTITY),"走路应驱动腿部，而不是平移静态人物")
		human.pose(0,true,false)
		human.animation.advance(0.2)
		check(human.animation.current_animation=="strike","挥击使用骨骼动作")
		human.pose(0,false,true)
		human.animation.advance(0.3)
		check(human.animation.current_animation=="fallen","倒地应切换独立躺姿而非冻结挥击")
		check(human.skeleton.get_bone_pose_rotation(bone).is_equal_approx(Quaternion.IDENTITY),"倒地腿部不能保留坐姿或步行动作")
		human.pose(0,false,false)
		check(human.animation.is_playing(),"恢复后重新播放动作")
		human.queue_free()
		await process_frame
	print("VISUAL_TEST failures=",failures)
	quit(failures)

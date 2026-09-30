extends SceneTree

var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func run() -> void:
	var transitions := 0
	var maximum_phase_error := 0.0
	for outfit in ["casual","office","office_female","protagonist","lin_lan","a_cheng"]:
		var human := HumanVisual.new()
		if outfit in ["protagonist","lin_lan","a_cheng"]:human.cast_id=outfit
		else:human.outfit=outfit
		root.add_child(human)
		human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for pair in [["walk","run"],["run","walk"],["walk","carry"],["carry","run"]]:
			for phase in [.07,.29,.51,.73,.94]:
				human.animation.stop();human.skeleton.reset_bone_poses()
				human.current=pair[0];human.carrying=pair[0]=="carry"
				human.animation.play(pair[0]);human.animation.seek(phase,true);human.animation.advance(0)
				human.carrying=pair[1]=="carry"
				human.pose(5.0 if pair[1]=="run" else 2.0,false,false)
				var actual := human.animation.current_animation_position/human.animation.current_animation_length
				var error := absf(actual-phase)
				maximum_phase_error=maxf(maximum_phase_error,error)
				check(error<.001,"移动动作切换保留周期："+outfit+" "+str(pair)+" phase="+str(phase)+" actual="+str(actual))
				for frame in range(18):
					human.animation.advance(1.0/60.0)
					for bone in range(human.skeleton.get_bone_count()):check(human.skeleton.get_bone_global_pose(bone).is_finite(),"移动混合骨骼有限")
				transitions+=1
		human.carrying=false
		human.pose(0,false,true);human.animation.advance(0)
		check(human.current=="fallen" and human.animation.speed_scale==1.0,"倒地取消步态及混合")
		human.pose(0,false,false);human.animation.advance(.4)
		check(human.current=="idle","停止后恢复站立")
		human.queue_free();await process_frame
	print("LOCOMOTION_BLEND_TEST failures=",failures," transitions=",transitions," max_phase_error=",maximum_phase_error)
	quit(failures)

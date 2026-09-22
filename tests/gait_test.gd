extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for outfit in ["casual","office","office_female"]:
		var human := HumanVisual.new()
		human.outfit=outfit
		root.add_child(human)
		for clip in ["walk","run"]:
			var stride := 1.48 if clip=="walk" else 3.44
			var stance := 0.5 if clip=="walk" else 0.25
			var max_drift := 0.0
			var max_lift := 0.0
			for side in ["L","R"]:
				var foot := human.skeleton.find_bone("foot."+side)
				var rest_height := human.skeleton.get_bone_global_rest(foot).origin.y
				var first := Vector3.ZERO
				for sample in range(33):
					var phase := float(sample)/32.0
					if side=="R": phase+=0.5
					human.position.z=-stride*phase
					human.animation.play(clip)
					human.animation.seek(fposmod(phase,1.0),true)
					human.animation.advance(0)
					var point := human.skeleton.global_transform*human.skeleton.get_bone_global_pose(foot).origin
					check(point.y>=rest_height-0.012,"脚踝不得穿入地面："+outfit+clip+side)
					max_lift=maxf(max_lift,point.y-rest_height)
					if sample==0: first=point
					if float(sample)/32.0<=stance:
						max_drift=maxf(max_drift,point.distance_to(first))
			check(max_drift<0.012,"支撑脚世界滑移<1.2cm："+outfit+clip+str(max_drift))
			check(max_lift>0.08,"摆动脚必须抬离地面："+outfit+clip)
			print("GAIT ",outfit," ",clip," drift_m=",max_drift," lift_m=",max_lift)
		human.queue_free()
		await process_frame
	print("GAIT_TEST failures=",failures)
	quit(failures)

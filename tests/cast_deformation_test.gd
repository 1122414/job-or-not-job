extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func run():
	var report := {}
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var h=HumanVisual.new();h.cast_id="lin_lan";root.add_child(h);h.set_process(false)
	h.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var m=h.find_children("female_elegantsuit01","MeshInstance3D",true,false)[0]
	var a=m.mesh.surface_get_arrays(0);var v=a[Mesh.ARRAY_VERTEX];var ids=a[Mesh.ARRAY_INDEX];var b=a[Mesh.ARRAY_BONES];var w=a[Mesh.ARRAY_WEIGHTS]
	for clip in ["walk","run","work","sit","strike"]:
		var max_ratio=0.0
		for f in range(129):
			h.animation.stop();h.animation.play(clip);h.animation.seek(h.animation.get_animation(clip).length*f/129.,true);h.animation.advance(0)
			var transforms=[]
			for i in m.skin.get_bind_count():
				var id=h.skeleton.find_bone(m.skin.get_bind_name(i))
				transforms.append(h.skeleton.get_bone_global_pose(id)*m.skin.get_bind_pose(i))
			var p=[]
			for i in v.size():
				var point=Vector3.ZERO
				for j in range(4):point+=(transforms[b[i*4+j]]*v[i])*w[i*4+j]
				p.append(point)
			for i in range(0,ids.size(),3):
				for pair in [[0,1],[1,2],[2,0]]:
					var x=ids[i+pair[0]];var y=ids[i+pair[1]]
					if maxf(v[x].y,v[y].y)>.81: continue
					var length=v[x].distance_to(v[y]);if length<.001:continue
					var ratio=p[x].distance_to(p[y])/length
					max_ratio=maxf(max_ratio,ratio)
		report[clip]=max_ratio
		# Detect the old 6-8x sharp folds. This is a regression bound, not a cloth
		# realism criterion: the remaining gait stretch still needs cloth work.
		if max_ratio>(1.05 if clip in ["work","sit","strike"] else 4.0):
			push_error("Skirt panel folds beyond regression bound: "+clip+str(max_ratio))
			failures+=1
		print("SKIRT ",clip," max_edge_ratio=",max_ratio)
	h.queue_free();await process_frame
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"frames_per_clip":129,"max_edge_ratios":report,"failures":failures},"\t"))
	print("CAST_DEFORMATION_TEST failures=",failures)
	quit(failures)

extends "res://tests/city_home_test.gd"

# Inspect the rendered skin and clothes, not just the hip joint or seated flag.
func sofa_fit() -> Dictionary:
	var human: HumanVisual=game.player.visual
	var sofa: StaticBody3D=game.home.room.sofa
	var boxes: Array[AABB]=[]
	for part in sofa.get_children():
		if part is MeshInstance3D:
			boxes.append(part.transform*part.get_aabb())
	var worst := 0.0
	var worst_point := Vector3.ZERO
	var worst_box := AABB()
	var contact_gap := INF
	var vertices := 0
	var per_mesh := {}
	for mesh in human.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null: continue
		var transforms := []
		for bind in mesh.skin.get_bind_count():
			var bone: int=human.skeleton.find_bone(mesh.skin.get_bind_name(bind))
			transforms.append(sofa.global_transform.affine_inverse()*human.skeleton.global_transform*human.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
		var deepest := 0.0
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(surface)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var point := Vector3.ZERO
				for slot in range(4):
					point+=(transforms[arrays[Mesh.ARRAY_BONES][i*4+slot]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
				vertices+=1
				for box in boxes:
					var depth: Vector3=box.size*.5-(point-box.get_center()).abs()
					var penetration := minf(depth.x,minf(depth.y,depth.z))
					deepest=maxf(deepest,penetration)
					if penetration>worst:
						worst=penetration;worst_point=point;worst_box=box
					if absf(point.x)<.4 and absf(point.z+.15)<.16 and point.y>.3 and point.y<.65 and point.x>box.position.x and point.x<box.end.x and point.z>box.position.z and point.z<box.end.z:
						contact_gap=minf(contact_gap,absf(point.y-box.end.y))
		per_mesh[String(mesh.name)]=deepest;worst=maxf(worst,deepest)
	return {"max_penetration_m":worst,"support_gap_m":contact_gap,"sampled_vertices":vertices,"meshes":per_mesh,"worst_point":SaveGame.vector(worst_point),"worst_box_center":SaveGame.vector(worst_box.get_center())}

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(10);game.set_process(false)
	game.player.position=CityHome.SEAT+Vector3(0,0,-1.45)
	await frames(5)
	check(await home_use("home_sofa") and game.home.sitting(),"通过实际E坐下检查接触")
	await frames(60)
	var samples := []
	for i in range(4):
		var result := sofa_fit();samples.append(result)
		check(result.sampled_vertices>1000,"检查真实蒙皮与衣装顶点")
		check(result.max_penetration_m<.015,"沙发与蒙皮无超过1.5cm的穿透 "+JSON.stringify(result))
		check(result.support_gap_m<.025,"臀部表面在座垫2.5cm内得到支撑")
		await frames(37)
	var skeleton: Skeleton3D=game.player.visual.skeleton
	for side in ["L","R"]:
		var ankle: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("foot."+side)).origin)
		check(ankle.y>.02 and ankle.y<.14,"坐姿保留脚部接地高度 "+side)
	DirAccess.make_dir_recursive_absolute("res://build/c3i")
	FileAccess.open("res://build/c3i/seat-fit.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"failures":failures},"\t")+"\n")
	game.queue_free();await process_frame
	print("CITY_HOME_SEATING_TEST failures=",failures);quit(failures)

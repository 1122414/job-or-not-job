extends SceneTree

var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func seating(human: HumanVisual) -> Dictionary:
	var mesh: ArrayMesh=load(CityCarVisual.ROOT+"cabin.res")
	var cushions := [];var backs := []
	var seat := CityCar.SEAT
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for t in range(0,indices.size(),3):
			var a := points[indices[t]];var b := points[indices[t+1]];var c := points[indices[t+2]];var center := (a+b+c)/3
			if absf(center.x-seat.x)>.34 or absf(center.z-seat.z)>.47:continue
			var normal := (c-a).cross(b-a).normalized()
			if absf(normal.y)>.01 and center.y>.35 and center.y<.64:cushions.append([a,b,c])
			if absf(normal.z)>.9 and center.y>.66 and center.y<1.15:backs.append([a,b,c])
	var penetration := 0.0;var support_gap := 1000.0;var low_foot := 1000.0;var vertices := 0;var worst := Vector3.ZERO
	for body in human.find_children("*","MeshInstance3D",true,false):
		if body.skin==null:continue
		var transforms := []
		for bind in range(body.skin.get_bind_count()):
			var bone: int=human.skeleton.find_bone(body.skin.get_bind_name(bind))
			transforms.append(human.skeleton.global_transform*human.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
		for s in range(body.mesh.get_surface_count()):
			var arrays: Array=body.mesh.surface_get_arrays(s)
			for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var p := Vector3.ZERO
				for slot in range(4):p+=(transforms[arrays[Mesh.ARRAY_BONES][i*4+slot]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
				vertices+=1
				if p.z<seat.z-.15:low_foot=minf(low_foot,p.y)
				if absf(p.x-seat.x)>.27:continue
				if p.z>seat.z-.24 and p.z<seat.z+.13 and p.y>.35 and p.y<.80:
					var low := INF;var high := -INF
					for triangle in cushions:
						var hit: Variant=Geometry3D.segment_intersects_triangle(Vector3(p.x,.8,p.z),Vector3(p.x,.3,p.z),triangle[0],triangle[1],triangle[2])
						if hit!=null:low=minf(low,hit.y);high=maxf(high,hit.y)
					if low<high and p.y>=low:
						support_gap=minf(support_gap,absf(high-p.y))
						var depth := minf(high-p.y,p.y-low)
						if depth>penetration:penetration=depth;worst=p
				if p.y>.66 and p.y<1.15 and p.z>seat.z-.1 and p.z<seat.z+.45:
					var low := INF;var high := -INF
					for triangle in backs:
						var hit: Variant=Geometry3D.segment_intersects_triangle(Vector3(p.x,p.y,seat.z-.1),Vector3(p.x,p.y,seat.z+.5),triangle[0],triangle[1],triangle[2])
						if hit!=null:low=minf(low,hit.z);high=maxf(high,hit.z)
					if low<high:
						var depth := minf(p.z-low,high-p.z)
						if depth>penetration:penetration=depth;worst=p
	return {"vertices":vertices,"seat_triangles":cushions.size()+backs.size(),"penetration_m":penetration,"support_gap_m":support_gap,"lowest_foot_m":low_foot,"worst_point":SaveGame.vector(worst)}

func run() -> void:
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CityCarVisual.ROOT+"production.json"))
	for path in record.sources:check(FileAccess.get_sha256("res://"+path)==record.sources[path],"资产与制作源对应 "+path)
	var total := 0;var lods := 0;var bad_normals := 0;var degenerate := 0;var inward := 0
	for name in record.derived_files:
		check(FileAccess.get_sha256(CityCarVisual.ROOT+name)==record.derived_files[name],"运行网格摘要 "+name)
		var mesh: ArrayMesh=load(CityCarVisual.ROOT+name);var triangles := 0;var part_lods := 0
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			triangles+=indices.size()/3
			for n in normals:
				if not n.is_finite() or absf(n.length()-1)>.001:bad_normals+=1
			for i in range(0,indices.size(),3):
				var n := (points[indices[i+2]]-points[indices[i]]).cross(points[indices[i+1]]-points[indices[i]])
				if n.length()<.0000001:degenerate+=1
				elif n.normalized().dot(normals[indices[i]]+normals[indices[i+1]]+normals[indices[i+2]])<0:inward+=1
			var surface := RenderingServer.mesh_get_surface(mesh.get_rid(),s);var previous: int=surface.index_count*(2 if surface.vertex_count<65536 else 4)
			for lod in surface.get("lods",[]):
				check(lod.index_data.size()>0 and lod.index_data.size()<previous,"LOD有效且递减")
				previous=lod.index_data.size();part_lods+=1
		check(triangles==record.geometry[name.trim_suffix(".res")].triangles,"实际几何与清单一致")
		if triangles>5000:check(part_lods>0,"高面数部件有实际LOD")
		total+=triangles*(4 if name=="wheel.res" else 1);lods+=part_lods
	check(total<85000 and total>20000,"烘焙整车预算85K以内")
	check(bad_normals==0 and degenerate==0 and inward==0,"网格法线、退化面和绕序正确 "+str([bad_normals,degenerate,inward]))
	var cabin: ArrayMesh=load(CityCarVisual.ROOT+"cabin.res");var cover_rays := 0
	for side in [-1,1]:
		for axle in [-1.38,1.27]:
			for y in [.20,.40,.65]:
				for z_offset in [-.20,.20]:
					var covered := false
					for s in range(cabin.get_surface_count()):
						if cabin.surface_get_material(s).resource_name!="liner":continue
						var arrays := cabin.surface_get_arrays(s);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
						for t in range(0,indices.size(),3):
							var a := points[indices[t]];var b := points[indices[t+1]];var c := points[indices[t+2]]
							# Back-facing triangles do not hide the opposite wheel in the renderer.
							if (c-a).cross(b-a).normalized().dot(Vector3.RIGHT*side)<.9:continue
							if Geometry3D.segment_intersects_triangle(Vector3(side*1.2,y,axle+z_offset),Vector3(side*.65,y,axle+z_offset),a,b,c)!=null:covered=true;break
						if covered:break
					check(covered,"轮拱内盖从外侧可见并覆盖轮后空间 "+str([side,axle,y,z_offset]));cover_rays+=1
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10):await physics_frame
	game.set_process(false);game.driving.set_physics_process(false)
	var maximum_contact := 0.0;var maximum_leg_difference := 0.0
	for car in game.driving.cars:
		var collider: CollisionShape3D=car.get_child(0)
		check(collider.shape.size==Vector3(1.86,1.3,4.25) and collider.position==Vector3(0,.86,0),"保留原车辆碰撞")
		check(car.wheels.size()==4 and car.front_wheels.size()==2,"四轮和前轮转向存在")
		for wheel in car.wheels:check(absf(wheel.get_parent().position.y+wheel.mesh.get_aabb().position.y)<.004,"轮胎落在实际地面")
		if not car.driver:continue
		var human: HumanVisual=car.driver;var before := []
		for bone in ["upperleg01.L","lowerleg01.L","foot.L"]:before.append(human.skeleton.get_bone_global_pose(human.skeleton.find_bone(bone)).origin)
		human.animation.play("work",0);human.animation.advance(.4);human.animation.pause()
		var k := 0
		for bone in ["upperleg01.L","lowerleg01.L","foot.L"]:
			maximum_leg_difference=maxf(maximum_leg_difference,before[k].distance_to(human.skeleton.get_bone_global_pose(human.skeleton.find_bone(bone)).origin));k+=1
		for i in range(33):
			car.steering=lerpf(-.58,.58,i/32.0);car.animate_wheels(0,false)
			for side in ["L","R"]:maximum_contact=maxf(maximum_contact,human.contacts.palm(side).origin.distance_to(car.palm_target(side).origin))
	check(maximum_leg_difference<.00001,"静态司机腿部初始姿态已收敛")
	check(maximum_contact<.02,"三司机完整转向范围双掌可达")
	var natural := HumanVisual.new();natural.outfit="casual";root.add_child(natural)
	natural.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	natural.animation.play("idle",0);natural.animation.advance(.4)
	natural.pose(0,false,false,true)
	for i in range(40):natural.animation.advance(1.0/60.0)
	var natural_legs := []
	for bone in ["upperleg01.L","lowerleg01.L","foot.L"]:natural_legs.append(natural.skeleton.get_bone_global_pose(natural.skeleton.find_bone(bone)).origin)
	natural.animation.play("work",0);natural.animation.advance(.4)
	var natural_difference := 0.0;var leg_index := 0
	for bone in ["upperleg01.L","lowerleg01.L","foot.L"]:
		natural_difference=maxf(natural_difference,natural_legs[leg_index].distance_to(natural.skeleton.get_bone_global_pose(natural.skeleton.find_bone(bone)).origin));leg_index+=1
	check(natural_difference<.00001,"零混合司机腿部与40帧自然收敛一致")
	natural.queue_free();await process_frame
	var car: CityCar=game.driving.car_for("car_office")
	game.player.position=car.to_global(Vector3(-1.6,0,0));car.speed=0
	check(game.driving.enter(car),"保留实际驾驶入口")
	paused=true
	for day in [0,1,6]:
		for minute in [359,360,540,1079,1080,1439]:
			game.payroll.minute=day*Payroll.DAY+minute;game.update_daylight()
			for vehicle in game.driving.cars:
				var expected: bool=(minute<360 or minute>=1080) and (vehicle.traffic or vehicle==car)
				check(vehicle.visual.lamps.all(func(lamp):return lamp.visible==expected),"暂停跨日灯光与车辆使用状态一致")
	var night_save := SaveGame.snapshot(game)
	game.payroll.minute=720;game.update_daylight()
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(night_save))) and car.visual.lamps.all(func(lamp):return lamp.visible),"暂停夜档立即恢复头灯")
	car.animate_wheels(0,true)
	check(car.visual.taillights.material_override.emission_energy_multiplier>2,"制动灯比夜间位置灯更亮")
	check(game.driving.car_for("car_homes").visual.taillights.material_override.emission_energy_multiplier==0,"制动不污染其他车辆材质")
	game.driving.detach();check(car.visual.lamps.all(func(lamp):return not lamp.visible),"熄火离车关闭灯光")
	paused=false;game.queue_free();await process_frame
	var poses := {}
	for id in ["casual","protagonist"]:
		var human := HumanVisual.new()
		if id=="protagonist":human.cast_id=id
		else:human.outfit=id
		root.add_child(human);human.position=CityCar.SEAT+human.seated_offset
		human.animation.play("work",0);human.animation.advance(.4);human.animation.pause()
		var result := seating(human);poses[id]=result
		check(result.vertices>1000 and result.seat_triangles>0,"真实皮肤衣装与座舱网格采样")
		check(result.penetration_m<.015 and result.support_gap_m<.03,"驾驶座支撑且不明显穿透 "+id+" "+JSON.stringify(result))
		check(result.lowest_foot_m>=record.floor_top_m-.015 and result.lowest_foot_m<record.floor_top_m+.035,"驾驶者双脚支撑在实际地板 "+id+" "+JSON.stringify(result))
		human.queue_free();await process_frame
	print("CITY_CAR_VISUAL_TEST ",JSON.stringify({"failures":failures,"baked_triangles":total,"lods":lods,"bad_normals":bad_normals,"degenerate":degenerate,"inward_triangles":inward,"wheel_cover_rays":cover_rays,"driver_leg_difference_m":maximum_leg_difference,"natural_blend_leg_difference_m":natural_difference,"maximum_driver_palm_error_m":maximum_contact,"seating":poses}))
	quit(1 if failures else 0)

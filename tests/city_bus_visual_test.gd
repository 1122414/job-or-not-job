extends SceneTree

var failures := 0
var metrics := {}
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func run() -> void:
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CityBusVisual.ROOT+"production.json"))
	check(record.source_sha256==FileAccess.get_sha256("res://tools/prepare_city_bus.gd"),"运行资产对应当前制作源")
	var total := 0;var lods := 0;var degenerate := 0;var bad_normals := 0
	for id in ["body","cabin","door_front","door_rear","wheel"]:
		check(FileAccess.get_sha256(CityBusVisual.ROOT+id+".res")==record.derived_files[id+".res"],"运行网格摘要 "+id)
		var mesh: ArrayMesh=load(CityBusVisual.ROOT+id+".res")
		var triangles := 0;var part_lods := 0
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			triangles+=indices.size()/3
			for n in arrays[Mesh.ARRAY_NORMAL]:
				if not n.is_finite() or absf(n.length()-1)>.001:bad_normals+=1
			for index in range(0,indices.size(),3):
				if (points[indices[index+1]]-points[indices[index]]).cross(points[indices[index+2]]-points[indices[index]]).length()<.0000001:degenerate+=1
			var surface := RenderingServer.mesh_get_surface(mesh.get_rid(),s)
			var previous: int=surface.index_count*(2 if surface.vertex_count<65536 else 4)
			for lod in surface.get("lods",[]):
				check(lod.index_data.size()>0 and lod.index_data.size()<previous,"LOD索引严格递减")
				previous=lod.index_data.size();part_lods+=1
			var mat: StandardMaterial3D=mesh.surface_get_material(s)
			if mat.resource_name=="glass":check(mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a<.3,"车窗保留透明而非不透明墙")
		check(triangles==record.geometry[id].triangles,"生成清单与实际面数相符 "+id)
		if triangles>5000:check(part_lods>0,"高于5K的部件有实际LOD "+id)
		total+=triangles*(4 if id=="wheel" else 1);lods+=part_lods
	check(total<80000 and total>30000,"整车几何预算80K以内")
	check(degenerate==0 and bad_normals==0,"无退化三角形与非法法线")
	var cabin: ArrayMesh=load(CityBusVisual.ROOT+"cabin.res")
	var covered := 0
	for side in [-1,1]:
		for axle in [-2.4,2.1]:
			for i in range(1,8):
				var point := Vector3(side*.95,.43+sin(PI*i/8)*.4,axle+cos(PI*i/8)*.4)
				var target := point+Vector3(side*.10,0,0)
				var found := false
				for s in range(cabin.get_surface_count()):
					var arrays := cabin.surface_get_arrays(s);var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					for t in range(0,indices.size(),3):
						if Geometry3D.segment_intersects_triangle(point,target,points[indices[t]],points[indices[t+1]],points[indices[t+2]])!=null:found=true;break
					if found:break
				if found:covered+=1
	check(covered==28,"四个轮罩从乘坐侧遮住实际轮面，不能只有空心拱条")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(8):await physics_frame
	game.set_process(false);game.transit.set_physics_process(false)
	var transit: CityTransit=game.transit;var model := transit.visual
	paused=true
	game.payroll.minute=20*60;game.update_daylight()
	check(model.lamps.all(func(lamp):return lamp.visible),"暂停时间切换立即开启公交夜灯，无需物理帧")
	var night_save := SaveGame.snapshot(game)
	game.payroll.minute=9*60;game.update_daylight()
	check(model.lamps.all(func(lamp):return not lamp.visible),"暂停时间切换立即关闭公交夜灯")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(night_save))) and model.lamps.all(func(lamp):return lamp.visible),"暂停恢复夜间存档立即同步公交灯光")
	for day in [0,1,6]:
		for minute in [359,360,540,1079,1080,1439]:
			game.payroll.minute=day*Payroll.DAY+minute;game.update_daylight()
			var expected: bool=minute<360 or minute>=1080
			check(model.lamps.all(func(lamp):return lamp.visible==expected),"公交昼夜按日内分钟，在跨日及开关边界保持一致")
	paused=false
	var collider: CollisionShape3D=transit.bus.get_child(0)
	check(collider.shape.size==Vector3(2.6,2.8,7) and collider.position==Vector3(0,1.6,0),"原外部碰撞合同保持")
	var floor: MeshInstance3D=transit.bus.get_node("CabinFloor")
	check(is_equal_approx(floor.position.y+floor.mesh.size.y/2,.4),"舱内地面顶面仍为0.4m")
	check(CityPassengers.SEATS.size()==5 and model.wheels.size()==4 and model.front_axles.size()==2,"五公共座位和四个独立轮组")
	var maximum_contact := 0.0
	for steer in [-.58,0,.58]:
		model.set_motion(10,steer)
		for side in ["L","R"]:maximum_contact=maxf(maximum_contact,model.driver.contacts.palm(side).origin.distance_to(model.palm_target(side).origin))
	check(maximum_contact<.02,"司机转向时双掌与方向盘接触")
	for wheel in model.wheels:
		check(absf(wheel.rotation.x-fposmod(-10/.43,TAU))<.0001,"实际路程驱动轮胎滚动")
		check(absf(wheel.get_parent().position.y+wheel.mesh.get_aabb().position.y)<.01,"轮胎底部在地面附近")
	model.snap_doors(true);transit.dwell=0
	var original_distance := transit.distance
	transit.tick(.2)
	check(transit.current_stop==0 and transit.distance==original_distance and model.door_open>0 and model.door_open<1,"门关闭中保持静止，不带开门驶离")
	var mid_open := model.door_open;transit.tick(0)
	check(model.door_open==mid_open,"零时间推进不改变车门")
	for i in range(4):transit.tick(.2)
	check(transit.current_stop<0 and model.doors_closed(),"关闭完成后正常发车")
	var moving: Dictionary=JSON.parse_string(JSON.stringify(transit.snapshot()))
	model.snap_doors(true);transit.restore(moving)
	check(model.doors_closed(),"行驶中的JSON恢复立即关闭门")
	transit.distance=transit.stop_offsets[0];transit.current_stop=0;transit.next_stop=1;transit.speed=0;transit.dwell=1
	transit.sync_vehicle();model.snap_doors(false);transit.tick(.2)
	check(model.door_open>0 and model.door_open<1,"到站连续开门")
	game.player.position=CityLayout.STOPS[0].platform
	for i in range(3):await physics_frame
	check(transit.board(0),"原玩家上车入口保持")
	transit.request_stop();transit.dwell=0;transit.tick(2)
	check(transit.current_stop==0 and model.door_open==1,"玩家下车请求保持开门等候")
	var stopped: Dictionary=JSON.parse_string(JSON.stringify(transit.snapshot()))
	model.snap_doors(false);transit.restore(stopped)
	check(model.door_open==1 and transit.riding,"停站乘坐JSON恢复打开门且保持乘客")
	model.set_night(true);check(model.lamps.all(func(lamp):return lamp.visible and lamp.shadow_enabled),"夜间舱灯和前照灯有阴影")
	model.set_night(false);check(model.lamps.all(func(lamp):return not lamp.visible),"白天停用动态灯")
	var runtime_triangles: int=total+model.steering_wheel.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size()/3+floor.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size()/3
	check(runtime_triangles<80000,"含运行方向盘和地板的完整车辆仍在80K预算内，人物另计")
	metrics={"baked_triangles":total,"vehicle_triangles":runtime_triangles,"wheel_cover_rays":covered,"lods":lods,"degenerate":degenerate,"bad_normals":bad_normals,"maximum_driver_palm_error":maximum_contact,"failures":failures}
	print("CITY_BUS_VISUAL_TEST ",JSON.stringify(metrics))
	game.queue_free();await process_frame;quit(1 if failures else 0)

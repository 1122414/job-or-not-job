extends SceneTree

var failures := 0
var game: Node3D
var driving: CityDriving
var car: CityCar

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: int,pressed: bool=true) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)
func tap(code: int) -> void:
	key(code); key(code,false)
func click(id: String) -> void:
	var view: GamePageView=game.panels.view
	check(view.buttons.has(id),"地图车辆按钮存在 "+id)
	if not view.buttons.has(id): return
	view.scroll.ensure_control_visible(view.buttons[id])
	await frames(4)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=view.buttons[id].get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		if not pressed: break
	await frames(3)

func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	driving=game.driving
	car=driving.car_for("car_office")
	var original := SaveGame.snapshot(game)
	check(SaveGame.valid(original,game),"初始驾驶世界存档有效")
	tap(KEY_M)
	await frames(3)
	await click("guide-car_office")
	check(driving.guide_car=="car_office" and game.navigation_target()==car,"真实地图按钮导航到停放车辆")
	game.player.position=car.to_global(Vector3(-1.65,0,0))
	var toward: Vector3=car.position-game.player.position
	game.player.yaw=atan2(-toward.x,-toward.z)
	await frames(3)
	game.player.pick(game.props[0])
	tap(KEY_E)
	check(driving.active==car and game.player.inventory.has(game.props[0]) and game.player.held==null,"E 上车并只收纳一个手持物")
	check(not game.transit.board(0),"驾驶时不能同时乘公交")
	var position_before := car.position
	key(KEY_D)
	await frames(30)
	key(KEY_D,false)
	check(car.position.distance_to(position_before)<0.001 and absf(car.rotation.y-PI/2)<0.001,"停车打方向不原地旋转")
	for side in ["L","R"]:
		var error_mm: float=game.player.visual.contacts.palm(side).origin.distance_to(car.palm_target(side).origin)*1000
		check(error_mm<10,"主角双手随实际方向盘握持 "+side+" error_mm="+str(error_mm))
	key(KEY_W)
	await frames(120)
	check(car.speed>6 and car.position.distance_to(position_before)>5,"真实 W 输入加速出行")
	check(game.player.position.distance_to(car.to_global(CityCar.SEAT))<0.01,"驾驶者持续跟随车辆")
	check(not driving.leave(),"高速不能下车")
	var turn_before := car.rotation.y
	key(KEY_A)
	await frames(18)
	key(KEY_A,false)
	check(absf(angle_difference(car.rotation.y,turn_before))>0.08,"真实 A 输入改变行驶方向")
	for side in ["L","R"]:
		var error_mm: float=game.player.visual.contacts.palm(side).origin.distance_to(car.palm_target(side).origin)*1000
		check(error_mm<10,"行驶转向时手掌仍贴合方向盘 "+side+" error_mm="+str(error_mm))
	var saved := SaveGame.snapshot(game)
	var path := "user://driving-"+str(Time.get_ticks_usec())+".json"
	check(SaveGame.write(game,path)==OK,"驾驶中的完整状态真实写入 JSON")
	driving.detach()
	car.position=Vector3(0,0,60)
	check(SaveGame.restore(game,SaveGame.read(path,game)),"真实 JSON 恢复车辆驾驶关系")
	check(driving.active==car and car.position.distance_to(SaveGame.unvector(saved.city_driving.vehicles.car_office.position))<0.001,"恢复驾驶车辆的位置")
	check(is_equal_approx(car.speed,saved.city_driving.vehicles.car_office.speed) and driving.suspended,"速度恢复且不恢复旧油门输入")
	await frames(5)
	check(game.player.position.distance_to(car.to_global(CityCar.SEAT))<0.01,"位置修复不会把驾驶者搬出车")
	key(KEY_W,false)
	key(KEY_SPACE)
	await frames(110)
	key(KEY_SPACE,false)
	check(absf(car.speed)<0.01,"空格手刹能够刹停")
	var reverse_at := car.position
	key(KEY_S)
	await frames(90)
	key(KEY_S,false)
	check(car.speed< -3 and car.position.distance_to(reverse_at)>2,"S 刹停后继续倒车")
	tap(KEY_M)
	var paused_at := car.position
	await frames(12)
	check(car.position==paused_at and paused,"打开地图冻结驾驶与交通")
	tap(KEY_ESCAPE)
	check(driving.suspended and not driving.controls.back,"关地图不恢复旧倒车输入")
	key(KEY_W)
	await frames(5)
	game.player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(driving.suspended and not driving.controls.forward and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"失焦清理驾驶输入并释放鼠标")
	await frames(90)
	driving.set_physics_process(false)
	var palm_max_mm := 0.0
	for index in range(33):
		car.steering=lerpf(-.58,.58,index/32.0)
		car.animate_wheels(0,false)
		await frames(2)
		for side in ["L","R"]:
			palm_max_mm=maxf(palm_max_mm,game.player.visual.contacts.palm(side).origin.distance_to(car.palm_target(side).origin)*1000)
	check(palm_max_mm<10,"整个方向盘转向范围的双手可达 error_mm="+str(palm_max_mm))
	# Vehicle/exit tests use a clear part of the public path and preserve actual collision.
	driving.set_physics_process(false)
	game.transit.set_physics_process(false)
	car.speed=0
	car.position=Vector3(0,0,64)
	car.rotation.y=0
	driving.sync_driver()
	var left := Shapes.solid(game,Vector3(.8,2,1.5),car.to_global(Vector3(-1.6,1,0.15)),Color.RED)
	await frames(4)
	check(driving.leave() and game.player.position.x>1,"左门受阻时可以从右侧下车")
	check(car.position==Vector3(0,0,64),"下车后车辆留在原停车位置")
	check(driving.enter(car),"停车后可再次进入")
	var right := Shapes.solid(game,Vector3(.8,2,1.5),car.to_global(Vector3(1.6,1,0.15)),Color.RED)
	await frames(4)
	check(not driving.leave() and driving.active==car,"双侧车门受阻时保留驾驶关系")
	left.queue_free(); right.queue_free()
	await frames(3)
	driving.detach()
	game.player.position=Vector3(10,0,64)
	var wall := Shapes.solid(game,Vector3(7,3,0.05),Vector3(0,1.5,50),Color.RED)
	car.position=Vector3(0,0,56)
	car.rotation.y=0
	car.speed=CityCar.MAX_SPEED
	car.steering=0
	await frames(4)
	for i in range(12): car.drive(0.1,1,0,false)
	check(car.blocked and car.position.z>52.1 and car.speed==0,"高速扫掠不会穿过5厘米薄墙")
	wall.queue_free()
	await frames(3)
	var distances: Array[float]=[]
	for hz in [30,60,120]:
		car.position=Vector3(0,0,80)
		car.rotation.y=0
		car.speed=0
		car.steering=0
		for i in range(hz*3): car.drive(1.0/hz,1,0,false)
		distances.append(80-car.position.z)
	check(distances.max()-distances.min()<0.1 and distances.min()>17.8,"不同物理步长的加速距离稳定 "+str(distances))
	car.speed=0
	check(SaveGame.restore(game,saved),"再次恢复驾驶档用于非法状态边界")
	for entry in [["speed",INF],["speed",99.0],["yaw",99.0],["position",[0,0,2000]],["position",[0,8,64]],["distance",-1]]:
		var invalid := saved.duplicate(true)
		invalid.city_driving.vehicles.car_office[entry[0]]=entry[1]
		var before := driving.snapshot()
		check(not SaveGame.restore(game,invalid) and before==driving.snapshot(),"非法车辆字段拒绝且世界不变 "+entry[0])
	for mode in ["unknown_vehicle","double_occupancy","missing_vehicle"]:
		var invalid := saved.duplicate(true)
		if mode=="unknown_vehicle": invalid.city_driving.active="missing"
		if mode=="double_occupancy": invalid.city_transit.riding=true
		if mode=="missing_vehicle": invalid.city_driving.vehicles.erase("traffic_0")
		check(not SaveGame.restore(game,invalid),"非法驾驶关系拒绝 "+mode)
	for version in range(1,13):
		var legacy := original.duplicate(true)
		legacy.version=version
		legacy.erase("city_driving")
		if version<12: legacy.erase("city_transit")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(legacy))) and not driving.in_vehicle(),"v%d 兼容夹具保留旧世界并初始化新车" % version)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("CITY_DRIVING_TEST failures=",failures," acceleration_distances=",distances," max_palm_error_mm=",palm_max_mm)
	game.queue_free()
	await process_frame
	quit(failures)

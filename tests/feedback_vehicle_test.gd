extends SceneTree
var failures := 0
var view: Viewport
func _initialize() -> void:
	if DisplayServer.get_name()!="headless": root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message);failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	view=root
	if DisplayServer.get_name()!="headless":
		var capture:=SubViewport.new();capture.size=Vector2i(1280,800);capture.own_world_3d=true;capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(capture);view=capture
	root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	await frames(10)
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	game.response.set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var baseline: Dictionary=SaveGame.snapshot(game)
	for car in game.driving.cars+[game.transit.bus]:
		check(SaveGame.restore(game,baseline),"恢复原世界")
		car.position=Vector3(0,0,64);car.rotation.y=0;car.speed=0
		game.player.position=car.to_global(Vector3(-2 if car.bus_mode else -1.65,0,0));game.player.yaw=-PI/2
		await frames(3)
		check(car in game.targets(),"F05 所有车辆均可交互 "+car.stable_id)
		check(game.nearest()==car,"F05 面向车辆时真实E目标正确 "+car.stable_id)
		game.interact()
		if car.bus_mode:
			check(game.panels.page=="transit" and game.panels.view.buttons.has("bus-take"),"F05 公交E提供乘坐和接管页面")
			game.panels.view.buttons["bus-take"].pressed.emit()
		check(game.driving.active==car,"F05 实际交互接管驾驶 "+car.stable_id)
		check(not paused and game.panels.page=="","F05 接管按钮关闭页面并解除暂停")
		if car.traffic or car.bus_mode:
			check(car.taken and car.displaced!=null and not car.driver.visible,"F05 原司机离车且自动运营停止")
		while car.boarding:
			game.driving.step_entry(1.0/60);await physics_frame
		for i in range(60): car.drive(1.0/60,1,0,false);game.driving.sync_driver();await physics_frame
		check(car.speed>2 and car.position.z<63,"F05 接管车辆能真正移动")
		if car.bus_mode or car.stable_id=="traffic_0": await shot(game,car)
		var saved: Dictionary=SaveGame.snapshot(game)
		check(SaveGame.valid(saved,game),"F05 接管后完整存档有效 "+car.stable_id)
		var path: String="/private/tmp/feedback-vehicle-"+car.stable_id+"-"+str(Time.get_ticks_usec())+".json"
		check(SaveGame.write(game,path)==OK,"F05 接管状态实际写盘")
		check(SaveGame.restore(game,SaveGame.read(path,game)) and game.driving.active==car,"F05 从JSON恢复驾驶关系 "+car.stable_id)
		DirAccess.remove_absolute(path)
		car.speed=0
		check(game.driving.leave(),"F05 停稳后可下车 "+car.stable_id)
		if car.bus_mode:
			check(game.transit.board_vehicle() and game.transit.riding,"F05 接管后的公交仍可乘坐")
			check(SaveGame.valid(SaveGame.snapshot(game),game),"F05 非运营公交乘客身份可保存")
			check(game.transit.leave(),"F05 乘客从实际停车处下车")
	check(SaveGame.restore(game,baseline),"恢复运营公交")
	game.player.position=CityLayout.STOPS[0].platform
	check(game.transit.board(0),"F05 原有正常乘公交未破坏")
	check(game.driving.enter(game.transit.bus),"F05 公交乘客可接管驾驶")
	check(not game.transit.riding and game.driving.active==game.transit.bus,"F05 乘坐与驾驶互斥")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"F05 车内接管全档有效")
	var good: Dictionary=SaveGame.snapshot(game)
	for field in ["position","yaw"]:
		var bad: Dictionary=good.duplicate(true)
		bad.city_transit.manual[field]=[25,0,64] if field=="position" else 1.7
		check(not SaveGame.restore(game,bad),"F05 公交路线/驾驶双份坐标不一致原子拒绝")
		check(SaveGame.snapshot(game)==good,"F05 坏档不部分改变世界")
	check(SaveGame.restore(game,baseline),"恢复乘客夹具")
	var person: CityResident=game.population.residents[4]
	var goal: String=person.destination
	person.destination=CityPassengers.wait_node(0,0)
	game.passengers.trips[person.stable_id]={"origin":0,"destination":1,"queue":0,"goal":goal,"seat":0,"stage":"riding","early_exit":false}
	game.passengers.attach(person)
	game.player.position=game.transit.bus.to_global(Vector3(-2,0,0))
	await frames(3)
	check(game.driving.enter(game.transit.bus),"F05 有乘客时接管公交")
	game.transit.bus.position=Vector3(0,0,64);game.transit.bus.speed=3
	game.passengers.sync_all();game.driving.sync_driver()
	check(SaveGame.valid(SaveGame.snapshot(game),game),"F05 偏离路线乘客位置与全档一致")
	check(game.passengers.attend(person,.016) and game.passengers.aboard(person),"F05 行驶中不跳车")
	game.transit.bus.speed=0
	check(not game.passengers.attend(person,.016) and not game.passengers.aboard(person),"F05 停车后乘客离开实际公交")
	check(person.position.distance_to(game.transit.bus.position)<5,"F05 不传送回原站台")
	game.queue_free();await process_frame
	print("FEEDBACK_VEHICLE_TEST failures=",failures);quit(failures)

func shot(game: Node3D,car: CityCar) -> void:
	if DisplayServer.get_name()=="headless":return
	var camera:=Camera3D.new();game.add_child(camera);camera.position=car.position+Vector3(-7,4,-7);camera.look_at(car.position+Vector3.UP);camera.current=true
	for i in range(3):await process_frame
	RenderingServer.force_draw(false)
	var folder:="res://docs/evidence/2026-10-09-playtest-feedback/runtime"
	DirAccess.make_dir_recursive_absolute(folder)
	check(view.get_texture().get_image().save_png(folder.path_join("take-"+car.stable_id+".png"))==OK,"车辆实际图形证据")
	camera.queue_free()

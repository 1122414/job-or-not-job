extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.set_disable_input(true)
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false)
	game.transit.set_physics_process(false)
	game.driving.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=58
	for id in ["car_office","car_homes"]:
		var car: CityCar=game.driving.car_for(id)
		camera.position=car.to_global(Vector3(-5,2.8,-6))
		camera.look_at(car.position+Vector3.UP)
		if not await capture(viewport,id): quit(1); return
	var car: CityCar=game.driving.car_for("car_office")
	game.player.position=car.to_global(Vector3(-1.6,0,0))
	for i in range(3): await physics_frame
	if not game.driving.enter(car): push_error("Cannot enter render vehicle"); quit(1); return
	for i in range(40): await physics_frame
	camera.position=car.to_global(Vector3(-2.6,1.65,-1.7))
	camera.look_at(car.to_global(Vector3(-.3,1.1,.05)))
	if not await capture(viewport,"driver-seat"): quit(1); return
	for turn in [-.58,.58]:
		car.steering=turn
		car.animate_wheels(0,false)
		for i in range(6): await physics_frame
		camera.position=car.to_global(Vector3(-.43,1.35,-1.6))
		camera.look_at(car.to_global(Vector3(-.43,1.12,-.10)))
		if not await capture(viewport,"driver-turn-left" if turn<0 else "driver-turn-right"): quit(1); return
	car.steering=0
	car.animate_wheels(0,false)
	game.player.camera.make_current()
	game.driving.set_physics_process(true)
	viewport.set_disable_input(false)
	var throttle := InputEventKey.new()
	throttle.keycode=KEY_W
	throttle.physical_keycode=KEY_W
	throttle.pressed=true
	viewport.push_input(throttle,true)
	for i in range(120): await physics_frame
	if car.speed<5: push_error("Graphical real driving input failed"); quit(1); return
	game.driving.set_physics_process(false)
	viewport.set_disable_input(true)
	if not await capture(viewport,"driving-camera"): quit(1); return
	game.panels.show_page("city")
	if not await capture(viewport,"driving-map"): quit(1); return
	game.panels.view.scroll.ensure_control_visible(game.panels.view.buttons["guide-car_homes"])
	if not await capture(viewport,"driving-map-vehicles"): quit(1); return
	game.panels.show_page("")
	game.driving.detach()
	game.player.position=Vector3(20,0,18)
	var route_length: float=game.transit.curve.get_baked_length()
	for index in range(2):
		var traffic: CityCar=game.driving.car_for("traffic_"+str(index))
		traffic.route_distance=route_length-18-index*12
		traffic.transform=game.transit.vehicle_transform(traffic.route_distance)
		traffic.speed=6
	for i in range(100):
		for index in range(2): game.driving.car_for("traffic_"+str(index)).tick_traffic(.1,game.transit)
		await physics_frame
	camera.make_current()
	camera.position=Vector3(10,5,22)
	camera.look_at(Vector3(3,1,8))
	if not await capture(viewport,"traffic-bus-queue"): quit(1); return
	var data := {"images":captures,"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"cars":game.driving.cars.size(),"traffic":3,"real_input":true,"traffic_front_speed":game.driving.car_for("traffic_0").speed,"traffic_rear_speed":game.driving.car_for("traffic_1").speed}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("CITY_DRIVING_RENDER ",JSON.stringify(data))
	quit()

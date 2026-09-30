extends "res://tools/render_city_bus.gd"

const Driver = preload("res://tests/scene_driver.gd")
var keys := {}
var distance := 0.0
var maximum_step := 0.0
var samples := []

func key(code: int,down: bool) -> void:
	if keys.get(code,false)==down:return
	keys[code]=down
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	view.push_input(event,true)

func shot(title: String) -> bool:
	paused=true
	var success := await capture(title)
	paused=false
	return success

func approach_car(target: Vector3) -> bool:
	var path: PackedVector3Array=game.walking.route(game.player.position,Vector3(0,0,23))
	# Approach around the parked rear corner instead of cutting through its body.
	for point in [Vector3(-26,0,23.5),Vector3(-30,0,23.5),target]:path.append(point)
	for point in path:
		for i in range(1800):
			var offset: Vector3=point-game.player.position;offset.y=0
			if offset.length()<.22:break
			var direction := Driver.steer_around_people(game,offset)
			game.player.yaw=atan2(-direction.x,-direction.z);Input.action_press("forward")
			await physics_frame
		Input.action_release("forward")
		if game.player.position.distance_to(point)>.7:
			push_error("Car approach blocked at "+str(game.player.position)+" toward "+str(point));return false
	return not path.is_empty() and game.player.position.distance_to(target)<.7

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for i in range(10):await physics_frame
	if not guard() or game.persistence_enabled:push_error("Unsafe driving route startup");quit(1);return
	# Only the initial clock is selected; all travel uses player controls.
	game.payroll.minute=1060;game.update_daylight()
	var car: CityCar=game.driving.car_for("car_office")
	if not await approach_car(car.to_global(Vector3(-1.7,0,0))):push_error("Cannot walk to shared car");quit(1);return
	var facing: Vector3=car.position-game.player.position
	game.player.yaw=atan2(-facing.x,-facing.z)
	for i in range(8):await physics_frame
	if game.nearest()!=car:push_error("Shared car not selected by actual approach");quit(1);return
	if not await shot("walk-to-car"):quit(1);return
	key(KEY_E,true);key(KEY_E,false)
	if game.driving.active!=car:push_error("Actual E did not enter car");quit(1);return
	for i in range(40):await physics_frame
	if not await shot("seated-player-camera"):quit(1);return
	var route := Curve3D.new();route.bake_interval=.25
	for p in [car.position,Vector3(-36,0,20),Vector3(-44,0,12),Vector3(-55,0,8)]:route.add_point(p)
	var street: Curve3D=game.transit.curve
	var offset := street.get_closest_offset(Vector3(-55,0,8))+2
	var end := street.get_closest_offset(Vector3(76,0,80))
	while offset<end:route.add_point(street.sample_baked(offset));offset+=2
	for p in [Vector3(76,0,80),Vector3(77,0,74),Vector3(80,0,69),Vector3(80,0,64)]:route.add_point(p)
	var length := route.get_baked_length();var progress := 0.0;var previous := car.position
	var marks := {"west-street":70.0,"waterfront":170.0,"east-street":280.0}
	var blocked_frames := 0;var finished := false
	for frame in range(12000):
		progress=maxf(progress,route.get_closest_offset(car.position))
		var remaining := length-progress
		var target := route.sample_baked(minf(length,progress+4.0))
		var delta := target-car.position
		var error := angle_difference(car.rotation.y,atan2(-delta.x,-delta.z))
		var desired_speed := minf(5.5,sqrt(maxf(0,remaining-1.0)*5.0))
		var clearance := maxf(2.0,car.speed*car.speed/(2*CityCar.BRAKING)+1.0)
		var obstruction := car.test_move(car.transform,-car.basis.z*clearance)
		var stop := remaining<1.0 or car.speed>desired_speed+.4 or obstruction
		key(KEY_W,not stop and car.speed<desired_speed)
		key(KEY_SPACE,stop)
		key(KEY_A,error>.035);key(KEY_D,error<-.035)
		await physics_frame
		var step := previous.distance_to(car.position);distance+=step;maximum_step=maxf(maximum_step,step);previous=car.position
		if car.blocked:blocked_frames+=1
		if not guard():push_error("Desktop isolation lost");quit(1);return
		if frame%60==0:samples.append({"frame":frame,"position":SaveGame.vector(car.position),"speed":car.speed,"minute":game.payroll.minute,"progress":progress})
		for title in marks.keys():
			if progress>=marks[title]:
				if not await shot(title):quit(1);return
				if SaveGame.write(game,output.path_join(title+"-save.json"))!=OK:push_error("Driving route save invalid");quit(1);return
				marks.erase(title)
		if remaining<1.0 and car.speed<.05:finished=true;break
		if frame%1200==1199:print("CAR_JOURNEY_PROGRESS ",progress," / ",length," position=",car.position)
	for code in keys.keys():key(code,false)
	if not finished:push_error("Continuous driving did not finish at "+str(car.position)+" progress="+str(progress));quit(1);return
	if not await shot("parked-player-camera"):quit(1);return
	key(KEY_E,true);key(KEY_E,false)
	if game.driving.active!=null or car.visual.lamps.any(func(lamp):return lamp.visible):push_error("Actual exit or lights failed");quit(1);return
	for i in range(20):await physics_frame
	if not await shot("exit-at-homes") or SaveGame.write(game,output.path_join("parked-save.json"))!=OK:quit(1);return
	var result := {"images":pictures,"samples":samples,"driving_metres":distance,"maximum_car_step":maximum_step,"blocked_frames":blocked_frames,"minute":game.payroll.minute,"no_travel_teleports":true,"actual_keyboard_controls":true,"normal_player_camera":true,"traffic_enabled":game.driving.is_physics_processing(),"background_guard":guard(),"persistence":game.persistence_enabled,"normal_game_fps":false,"independent_player_acceptance":false}
	if distance<300 or maximum_step>.12 or blocked_frames!=0 or not marks.is_empty() or game.payroll.minute<1080 or game.persistence_enabled:push_error("Driving route acceptance failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CAR_JOURNEY_OK metres=",distance," maximum_step=",maximum_step," blocked_frames=",blocked_frames," minute=",game.payroll.minute," guard=",guard());game.queue_free();await process_frame;quit()

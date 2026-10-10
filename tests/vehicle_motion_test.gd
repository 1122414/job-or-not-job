extends SceneTree
var failures := 0
var game: Node3D
var metrics := {}
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message);failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: int) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(6)
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	game.player.set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var baseline := SaveGame.snapshot(game)
	var a: CityCar=game.driving.cars[0]
	var b: CityCar=game.driving.cars[1]
	var distances := []
	for hz in [30,60,120]:
		check(SaveGame.restore(game,baseline),"MOT01 fixture restore")
		a.position=Vector3(0,0,76);a.rotation.y=0;a.speed=12
		b.position=Vector3(.35,0,69);b.rotation.y=0
		game.player.position=Vector3(10,0,75)
		await frames(3)
		var hit := false
		for i in range(hz*3):
			a.drive(1.0/hz,0,0,false);b.step_impact(1.0/hz)
			hit=hit or b.crashed
			await physics_frame
		var distance := 69-b.position.z;distances.append(distance)
		check(hit and distance>1.0,"MOT01 struck car physically displaced "+str([hz,distance]))
		check(absf(b.rotation.y)>.02,"MOT01 off-centre impact rotates actual collider")
		check(a.rotation_clear(a.rotation.y) and b.rotation_clear(b.rotation.y),"MOT01 swept cars do not overlap")
		check(a.impact_velocity.length()<.1 and b.impact_velocity.length()<.1,"MOT01 friction settles motion")
		a.speed=0
		var saved: Dictionary=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
		check(SaveGame.valid(saved,game) and SaveGame.restore(game,saved),"MOT01 collision JSON roundtrip")
	check(distances.max()-distances.min()<.7,"MOT01 comparable 30/60/120 Hz displacement "+str(distances))
	metrics.displacement=distances
	for target in [game.driving.car_for("traffic_0"),game.transit.bus]:
		SaveGame.restore(game,baseline)
		a.position=Vector3(0,0,78);a.rotation.y=0;a.speed=14
		target.position=Vector3(.2,0,70);target.rotation.y=0;target.speed=0
		game.player.position=Vector3(10,0,75)
		await frames(3)
		for i in range(120):
			a.drive(1.0/60,0,0,false)
			if target.bus_mode: game.transit.tick(1.0/60)
			else: target.tick_traffic(1.0/60,game.transit)
			await physics_frame
		check(target.crashed and target.position.distance_to(Vector3(.2,0,70))>.05,"MOT01 traffic/bus remain at actual impact position "+target.stable_id)
		a.speed=0
		var saved := SaveGame.snapshot(game)
		check(SaveGame.valid(saved,game),"MOT01 displaced route vehicle save valid "+target.stable_id)
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"MOT01 displaced route restore "+target.stable_id)
		var before: Vector3=target.position
		if target.bus_mode: game.transit.sync_vehicle()
		check(target.position.distance_to(before)<.001,"MOT01 no route snap after restore")
	SaveGame.restore(game,baseline)
	var occupied: CityCar=game.driving.car_for("traffic_0")
	occupied.position=Vector3(0,0,65);occupied.rotation.y=0;occupied.speed=0
	game.player.position=Vector3(-1.65,0,65)
	await frames(3)
	check(game.driving.enter(occupied) and occupied.boarding,"MOT02 takeover starts sustained action")
	var start: Vector3=occupied.displaced.visual.global_position
	check(start.distance_to(occupied.to_global(occupied.seat())+occupied.displaced.visual.seated_offset)<.01,"MOT02 original driver starts inside seat")
	check(not game.driving.leave(),"MOT02 repeated E cannot interrupt ownership")
	occupied.drive(.1,1,0,false)
	check(occupied.speed==0,"MOT02 throttle blocked until entry complete")
	game.driving.set_physics_process(true)
	await frames(45)
	check(occupied.displaced.visual.global_position.distance_to(start)>.1 and absf(occupied.visual.doors[0].rotation.y)>.5,"MOT02 visible driver motion and open door")
	var midway := SaveGame.snapshot(game)
	check(SaveGame.valid(midway,game),"MOT02 mid-entry snapshot valid")
	await frames(180)
	check(not occupied.boarding and game.driving.active==occupied and game.player.visual.position.distance_to(game.player.visual.seated_offset)<.01,"MOT02 entry finishes seated")
	check(absf(occupied.visual.doors[0].rotation.y)<.001 and occupied.displaced.exit_elapsed<0,"MOT02 door closes and driver retreats")
	check(SaveGame.restore(game,midway) and not occupied.boarding and not game.driving.controls.forward,"MOT02 restore settles transition without stale throttle")
	game.driving.set_physics_process(false)
	var bad: Dictionary=midway.duplicate(true);bad.city_driving.vehicles.traffic_0.impact.velocity=[1000,0,0]
	check(not SaveGame.restore(game,bad),"MOT01 invalid impulse rejected atomically")
	# The third body must receive momentum, not act as a stationary wall.
	SaveGame.restore(game,baseline)
	var third: CityCar=game.driving.car_for("traffic_1")
	a.position=Vector3(0,0,83);a.rotation.y=0;a.speed=16
	b.position=Vector3(0,0,76);b.rotation.y=0
	third.position=Vector3(0,0,70);third.rotation.y=0;third.speed=0
	game.player.position=Vector3(10,0,80)
	await frames(3)
	for i in range(240):
		a.drive(1.0/60,0,0,false);b.step_impact(1.0/60);third.step_impact(1.0/60)
		await physics_frame
	check(third.crashed and third.position.z<69.8,"MOT01 three-car chain transfers momentum")
	metrics.chain_displacement=70-third.position.z
	var pushes := []
	for target in [b,game.transit.bus]:
		SaveGame.restore(game,baseline)
		a.position=Vector3(0,0,82);a.rotation.y=0;a.speed=12
		target.position=Vector3(0,0,74);target.rotation.y=0;target.speed=0
		game.player.position=Vector3(10,0,80)
		await frames(3)
		for i in range(240):
			a.drive(1.0/60,0,0,false);target.step_impact(1.0/60)
			await physics_frame
		pushes.append(74-target.position.z)
	check(pushes[0]>1 and pushes[1]>.01 and pushes[1]<pushes[0]*.6,"MOT01 heavy bus moves less than sedan "+str(pushes))
	metrics.mass_displacements=pushes
	bad=SaveGame.snapshot(game);bad.city_transit.manual=false
	check(not SaveGame.restore(game,bad),"MOT01 malformed bus mode rejected without exception")
	for automatic in [game.driving.car_for("traffic_0"),game.transit.bus]:
		SaveGame.restore(game,baseline)
		var offset := 160.0
		if automatic.bus_mode:
			game.transit.distance=offset;game.transit.current_stop=-1;game.transit.dwell=0;game.transit.speed=8
		else: automatic.route_distance=offset;automatic.speed=7
		automatic.transform=game.transit.vehicle_transform(offset)
		a.transform=automatic.transform
		a.position+=-automatic.basis.z*(5.65 if automatic.bus_mode else 4.3)
		a.speed=0
		game.player.position=Vector3(10,0,80)
		await frames(3)
		if automatic.bus_mode: game.transit.tick(.1)
		else: automatic.tick_traffic(.1,game.transit)
		check(a.crashed and a.impact_velocity.length()>.1,"MOT01 sudden obstruction receives autonomous-car/bus impulse "+automatic.stable_id)
	print("VEHICLE_MOTION_TEST failures=",failures," metrics=",JSON.stringify(metrics))
	game.queue_free();await process_frame;quit(failures)

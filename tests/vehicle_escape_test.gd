extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message);failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	game.player.set_physics_process(false);game.player.position=Vector3(12,0,80)
	for person in game.population.residents: person.set_physics_process(false)
	var wall := StaticBody3D.new();game.add_child(wall)
	Shapes.collider(wall,Vector3(16,4,.15),Vector3(0,2,65))
	for car in [game.driving.cars[0],game.transit.bus]:
		for hz in [30,60,120]:
			for turn in [0.0,1.0,-1.0]:
				car.position=Vector3(0,0,74);car.rotation.y=0;car.speed=8;car.steering=0
				car.impact_velocity=Vector3.ZERO;car.impact_spin=0
				await frames(2)
				for i in range(hz*2):
					car.drive(1.0/hz,1,0,false);await physics_frame
				var contact: float=car.position.z
				check(contact>65,"FB10-01 thin wall stops forward travel")
				for i in range(hz*2):
					car.drive(1.0/hz,-1,turn,false);await physics_frame
				check(car.position.z>contact+1,"FB10-01 reverse escapes wall "+str([car.bus_mode,hz,turn,contact,car.position.z]))
		car.position=Vector3(20,0,85);car.speed=0;car.steering=0
	var car: CityCar=game.driving.car_for("traffic_0")
	car.position=Vector3(0,0,80);car.rotation.y=0;car.speed=12;car.set_taken(true,Vector3(0,0,72),0)
	car.displaced.set_physics_process(false)
	await frames(2)
	for i in range(90):
		car.drive(1.0/60,1,0,false);await physics_frame
	check(car.position.z<69,"FB10-06 driver cannot act as an immovable pillar")
	check(car.displaced.hp==0,"FB10-06 high-speed collision is lethal")
	car.speed=0
	var saved: Dictionary=JSON.parse_string(JSON.stringify(game.driving.snapshot()))
	check(game.driving.valid(saved),"FB10-06 driver death JSON is valid")
	game.driving.restore(saved)
	check(car.displaced.hp==0 and not car.displaced.available(),"FB10-06 restore does not resurrect driver")
	var bad: Dictionary=saved.duplicate(true);bad.vehicles.traffic_0.driver_state.motion=[100,0,0]
	check(not game.driving.valid(bad),"FB10-06 malformed driver state rejected")
	var legacy: Dictionary=saved.duplicate(true);legacy.schema=3
	for entry in legacy.vehicles.values(): entry.erase("driver_state")
	check(game.driving.valid(legacy),"FB10-06 old schema remains valid")
	car.position=Vector3(0,0,78);car.rotation.y=0;car.speed=0
	car.set_taken(true,Vector3(0,0,75.76),0);car.displaced.set_physics_process(false)
	await frames(2)
	for i in range(120):
		car.drive(1.0/60,-1,0,false);await physics_frame
	check(car.position.z>79,"FB10-01 reverse must escape a driver touching the front bumper")
	var mentor: AutumnStoryPoint=game.story.points[0]
	mentor.set_physics_process(false);mentor.visible=true;mentor.position=Vector3(0,40,3)
	for yaw in [0.0,PI/2,PI,-PI/2]:
		mentor.down=12;mentor.visual.rotation.y=yaw;mentor._physics_process(.4)
		await frames(2)
		var expected := mentor.position+Vector3(-.7,.28,0).rotated(Vector3.UP,yaw)
		var ray := PhysicsRayQueryParameters3D.create(expected+Vector3.UP*2,expected-Vector3.UP)
		var hit: Dictionary=mentor.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider")==mentor,"FB10-05 physical body beneath fallen mentor yaw="+str(yaw))
	var mentor_saved: Dictionary=JSON.parse_string(JSON.stringify(mentor.snapshot()))
	check(AutumnStoryPoint.valid(mentor_saved),"FB10-05 mentor direction JSON valid")
	mentor.visual.rotation=Vector3.ZERO;mentor.restore(mentor_saved)
	check(absf(angle_difference(mentor.visual.rotation.y,mentor_saved.yaw))<.001 and mentor.body.position.y<.4,"FB10-05 restored body matches direction immediately")
	game.player.position=mentor.body.global_position+Vector3.UP*1.4
	game.player.velocity=Vector3.ZERO;game.player.set_physics_process(true)
	await frames(70)
	check(game.player.position.y>40.35 and game.player.is_on_floor(),"FB10-05 player can stand on fallen body instead of sinking through")
	game.player.set_physics_process(false)
	car.displaced.hp=100;car.displaced.down=0
	car.displaced.vehicle_hit(Vector3.RIGHT,3)
	check(car.displaced.hp>0 and car.displaced.down>0,"FB10-06 low speed knocks driver down without killing")
	var start: Vector3=car.displaced.position
	for i in range(20): car.displaced._physics_process(1.0/60)
	check(car.displaced.position.distance_to(start)>.2,"FB10-06 impact produces actual displacement")
	var peer: CityCar=game.driving.car_for("car_office")
	car.position=Vector3(0,0,1000);car.rotation.y=0;car.speed=6;car.crashed=false
	car.impact_velocity=Vector3.ZERO;car.impact_spin=0
	peer.position=Vector3(0,0,995);peer.rotation.y=0;peer.speed=0;peer.crashed=false
	peer.impact_velocity=Vector3.ZERO;peer.impact_spin=0
	await frames(2)
	var stale_contact := KinematicCollision3D.new()
	check(car.test_move(car.transform,Vector3.FORWARD*2,stale_contact) and stale_contact.get_collider()==peer,"FB10-01 restored-contact fixture is a real vehicle collision")
	# A restore can move the other body before a query's previous physics contact clears.
	peer.position=Vector3(30,0,995)
	check(not car.collide_vehicle(stale_contact) and not car.crashed and not peer.crashed,"FB10-01 stale contact after relocating another vehicle must not create a permanent crash")
	print("VEHICLE_ESCAPE_TEST failures=",failures)
	game.queue_free();await process_frame;quit(failures)

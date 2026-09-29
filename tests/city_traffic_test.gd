extends SceneTree

var failures := 0
var game: Node3D
var driving: CityDriving
var transit: CityTransit

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func place(car: CityCar,distance: float,speed: float=0) -> void:
	car.route_distance=fposmod(distance,transit.curve.get_baked_length())
	car.transform=transit.vehicle_transform(car.route_distance)
	car.speed=speed
	car.steering=0

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.set_process(false)
	game.player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	driving=game.driving
	transit=game.transit
	driving.set_physics_process(false)
	transit.set_physics_process(false)
	var cars: Array=driving.cars.filter(func(car): return car.traffic)
	var travelled := [0.0,0.0,0.0]
	var contacts := 0
	var length := transit.curve.get_baked_length()
	# Actual collision and bus stops stay enabled throughout all three natural loops.
	for i in range(2200):
		transit.tick(0.1)
		for index in range(cars.size()):
			var before: float=cars[index].route_distance
			cars[index].tick_traffic(0.1,transit)
			travelled[index]+=fposmod(cars[index].route_distance-before,length)
		await physics_frame
		if i%20==0:
			for car in cars:
				if not car.rotation_clear(car.rotation.y): contacts+=1
			check(driving.valid(JSON.parse_string(JSON.stringify(driving.snapshot()))),"转弯及路线首尾状态可经 JSON 恢复")
		if travelled.min()>length: break
	check(travelled.min()>length,"三辆通行车均自然完成整环 actual="+str(travelled))
	check(contacts==0,"自然车流与公交/世界无体积重叠 actual="+str(contacts))
	for car in cars:
		for side in ["L","R"]:
			check(car.driver.contacts.palm(side).origin.distance_to(car.palm_target(side).origin)<.01,"通行车辆驾驶者双手贴合方向盘 "+car.stable_id+side)
	# Two cars behind the actual stationary bus, followed by releasing the bus.
	transit.distance=0
	transit.current_stop=0
	transit.next_stop=1
	transit.speed=0
	transit.dwell=CityTransit.DWELL
	transit.sync_vehicle()
	place(cars[0],length-22,7)
	place(cars[1],length-34,7)
	place(cars[2],200)
	await frames(3)
	for i in range(100):
		cars[0].tick_traffic(0.1,transit)
		cars[1].tick_traffic(0.1,transit)
		await physics_frame
	check(cars[0].speed==0 and cars[1].speed==0,"公交停站时前车与后车依次停车")
	check(cars[0].rotation_clear(cars[0].rotation.y) and cars[1].rotation_clear(cars[1].rotation.y),"跟车停止不重叠公交或前车")
	var queue_before: float=cars[1].route_distance
	transit.dwell=0
	for i in range(90):
		transit.tick(0.1)
		cars[0].tick_traffic(0.1,transit)
		cars[1].tick_traffic(0.1,transit)
		await physics_frame
	check(fposmod(cars[1].route_distance-queue_before,length)>8 and cars[1].speed>0,"公交离站后排队车辆恢复通行")
	# A real player capsule on the road must be treated as an obstacle.
	var start := transit.curve.get_closest_offset(Vector3(-76,0,38))
	place(cars[0],start,7)
	place(cars[1],240)
	place(cars[2],340)
	game.player.position=transit.curve.sample_baked(start+13)
	await frames(4)
	for i in range(100):
		cars[0].tick_traffic(0.1,transit)
		await physics_frame
	check(cars[0].speed==0 and cars[0].position.distance_to(game.player.position)>2.2,"道路行人使通行车停止且不穿过人体")
	var stopped_at: Vector3=cars[0].position
	game.player.position+=Vector3(8,0,0)
	await frames(4)
	for i in range(50):
		cars[0].tick_traffic(0.1,transit)
		await physics_frame
	check(cars[0].position.distance_to(stopped_at)>5,"行人离开后车辆恢复通行")
	# A rear corner moves sideways during a turn even when forward travel is clear.
	var car := driving.car_for("car_office")
	car.position=Vector3(0,0,64)
	car.rotation.y=0
	car.speed=4
	car.steering=.58
	var post := Shapes.solid(game,Vector3(.08,2,.2),Vector3(-1.03,1,65.85),Color.RED)
	await frames(4)
	check(car.rotation_clear(0),"车尾转弯夹具初始无重叠")
	var tail_blocked := false
	var tail_overlap := false
	for i in range(20):
		car.drive(.1,1,1,false)
		tail_blocked=tail_blocked or car.blocked
		await physics_frame
		tail_overlap=tail_overlap or not car.rotation_clear(car.rotation.y)
	check(tail_blocked and not tail_overlap,"转弯车尾被细柱阻挡而不旋转穿透")
	post.queue_free()
	print("CITY_TRAFFIC_TEST failures=",failures," travelled_m=",travelled," overlaps=",contacts)
	game.queue_free()
	await process_frame
	quit(failures)

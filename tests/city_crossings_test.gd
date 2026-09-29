extends SceneTree

var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.set_process(false)
	game.transit.set_physics_process(false)
	game.driving.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var population: CityPopulation=game.population
	for person in population.residents:
		person.set_physics_process(false)
		person.position=Vector3(20+person.index*2,0,24)
	var car: CityCar=game.driving.car_for("car_office")
	car.position=Vector3(-68,0,64)
	car.rotation.y=0
	car.speed=4
	check(not population.safe_to_cross("market"),"自由驾驶车辆从斑马线端部接近时行人等待")
	car.speed=0
	check(population.safe_to_cross("market"),"斑马线外停车不阻止居民过街")
	car.position=Vector3(-68,0,58)
	check(not population.safe_to_cross("market"),"占用斑马线端部的停车仍阻挡过街")
	car.position=Vector3(-45,0,24)
	var person: CityResident=population.residents[0]
	person.position=CityPopulation.POINTS.west_in
	person.from_node="west_in"
	person.destination="market"
	person.route.assign(["west_out","market"])
	person.state="walking"
	person.set_physics_process(true)
	var traffic: CityCar=game.driving.car_for("traffic_0")
	traffic.route_distance=population.crossing_offsets.market-14
	traffic.transform=game.transit.vehicle_transform(traffic.route_distance)
	traffic.speed=7
	game.driving.set_physics_process(true)
	await frames(3)
	check(person.crossing=="" and person.state=="waiting","来车时居民在路沿等待")
	var saw_stop := false
	var restored := false
	var crossed := false
	var traffic_released := false
	var cooldown := false
	for i in range(1800):
		await physics_frame
		if person.crossing=="market":
			saw_stop=saw_stop or traffic.speed<.25 and population.route_gap("market",traffic.route_distance)>3.7
			if not restored and person.position.x< -73:
				var position_before := person.position
				var file := "user://city-crossing-"+str(Time.get_ticks_usec())+".json"
				check(SaveGame.write(game,file)==OK,"正在过街的世界可以写入JSON")
				check(SaveGame.restore(game,SaveGame.read(file,game)),"正在过街的JSON可恢复")
				check(person.position.distance_to(position_before)<.001 and person.crossing=="market","读档保留过街位置和通行身份")
				for suffix in ["",".bak",".tmp"]:
					if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
				restored=true
				person.hit(Vector3.FORWARD,10,game.next_action(),false)
		if person.position.x< -83 and person.crossing=="": crossed=true
		if crossed:
			cooldown=cooldown or not population.crossings.market.people and population.crossings.market.remaining>0
			traffic_released=traffic_released or population.route_gap("market",traffic.route_distance)< -5
		if crossed and traffic_released: break
	check(saw_stop and restored and crossed and traffic_released and cooldown,"居民过街、车流停线、读档及倒地恢复后走完、车辆恢复和通行间隔全部观察到")
	game.driving.set_physics_process(false)
	person.position=CityPopulation.POINTS.north_in
	person.from_node="north_in"
	person.route.assign(["north_out","sea_east"])
	person.destination="sea_east"
	person.crossing=""
	person.state="walking"
	person.fear=0
	population.crossings.waterfront={"people":false,"opened":false,"remaining":0.0}
	game.transit.distance=population.crossing_offsets.waterfront-18
	game.transit.current_stop=-1
	game.transit.next_stop=3
	game.transit.dwell=0
	game.transit.speed=8
	game.transit.sync_vehicle()
	game.transit.set_physics_process(true)
	await frames(3)
	check(person.crossing=="" and person.state=="waiting","全速公交刹车范围内居民留在路沿")
	var bus_stop := false
	var bus_release := false
	var late_clearance := true
	for i in range(1800):
		await physics_frame
		if person.crossing=="waterfront" and population.route_gap("waterfront",game.transit.distance)> -4.6:
			late_clearance=late_clearance and game.transit.speed<.25 and population.route_gap("waterfront",game.transit.distance)>5.1
		if person.position.z>111 and person.crossing=="" and population.route_gap("waterfront",game.transit.distance)< -7:
			bus_release=true
			break
	check(late_clearance and bus_release,"公交来不及在线前停稳时居民等待整车驶离再过街")
	person.position=CityPopulation.POINTS.north_in
	person.from_node="north_in"
	person.route.assign(["north_out","sea_east"])
	person.destination="sea_east"
	person.crossing=""
	person.state="walking"
	population.crossings.waterfront={"people":false,"opened":false,"remaining":0.0}
	game.transit.distance=population.crossing_offsets.waterfront-24
	game.transit.speed=8
	game.transit.current_stop=-1
	game.transit.next_stop=3
	game.transit.sync_vehicle()
	bus_release=false
	for i in range(1800):
		await physics_frame
		if person.crossing=="waterfront": bus_stop=bus_stop or game.transit.speed<.25 and population.route_gap("waterfront",game.transit.distance)>5.1
		if person.position.z>111 and person.crossing=="" and population.route_gap("waterfront",game.transit.distance)< -7:
			bus_release=true
			break
	check(bus_stop and bus_release,"公交停在过街线前并在居民走完后实际恢复行驶")
	game.transit.set_physics_process(false)
	person.position=Vector3(0,0,35)
	person.from_node="south"
	person.route.assign(["center"])
	person.destination="center"
	person.crossing=""
	person.state="walking"
	var barrier := Shapes.solid(game,Vector3(12,2,.5),Vector3(0,1,38),Color.GRAY)
	await frames(240)
	check(person.position.z<38,"步道被实际障碍挡住时不穿越")
	barrier.queue_free()
	await frames(1200)
	check("center" in person.visits,"移除障碍后居民真实行走到活动点")
	person.hit(Vector3.FORWARD,10,game.next_action(),false)
	await frames(2)
	check(person.state=="fallen" and person.hp==1,"非致命伤害倒地")
	await frames(800)
	check(person.available() and person.hp>=25 and person.state!="fallen","非致命倒地后可以起身恢复活动")
	print("CITY_CROSSINGS_TEST failures=",failures," stop=",saw_stop," restored=",restored," crossed=",crossed," released=",traffic_released," vehicle_interval=",cooldown," bus_stop=",bus_stop," bus_release=",bus_release," late_bus_clearance=",late_clearance)
	game.queue_free()
	await process_frame
	quit(failures)

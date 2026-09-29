extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6): await physics_frame
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var initial := SaveGame.snapshot(game)
	var samples := {}
	for place in ["market","homes","waterfront","bookshop"]:
		check(SaveGame.restore(game,initial),"重建路线夹具 "+place)
		for person in game.population.residents:
			person.set_physics_process(false)
			person.position=Vector3(26+person.index*2,0,24)
		var victim: CityResident=game.population.residents[2]
		if place=="bookshop": victim.position=Vector3(-54,0,31)
		else:
			var ends: Array=CityPopulation.CROSSINGS[place]
			victim.position=(CityPopulation.POINTS[ends[0]]+CityPopulation.POINTS[ends[1]])/2
		victim.from_node=game.population.closest(victim.position)
		victim.destination=victim.from_node
		victim.route.clear(); victim.crossing=""
		victim.hit(Vector3.FORWARD,10,game.next_action())
		victim.set_physics_process(true)
		game.response.report(victim,"player")
		game.player.position=Vector3(-18,0,18)
		var moved := false
		var completed := false
		var stopped_traffic := false
		var released_traffic := false
		var car: CityCar=game.driving.car_for("traffic_0")
		if place!="bookshop":
			car.route_distance=game.population.crossing_offsets[place]-24
			car.transform=game.transit.vehicle_transform(car.route_distance)
			car.speed=6.5
		var crossed_distance := 0.0
		var previous: Vector3=game.response.crew.position
		var max_step := 0.0
		for i in range(18000):
			await physics_frame
			var step: float=game.response.crew.position.distance_to(previous)
			max_step=maxf(max_step,step)
			crossed_distance+=step
			previous=game.response.crew.position
			if game.response.carried(victim): moved=true
			if place!="bookshop":
				if not moved and car.speed<.1 and game.population.route_gap(place,car.route_distance)>3.7: stopped_traffic=true
				if moved and game.population.route_gap(place,car.route_distance)< -7: released_traffic=true
			if game.response.resting(victim): completed=true; break
		samples[place]={"walked_m":crossed_distance,"max_step_m":max_step,"received":completed,"traffic_stopped":stopped_traffic,"traffic_released":released_traffic}
		check(moved and completed and max_step<.04,"小组实体往返、持续转运且不瞬移 "+place+" "+str(game.response.snapshot()))
		if place!="bookshop": check(stopped_traffic and released_traffic,"实际车辆在现场停线并在转运离路后通过 "+place)
	print("CITY_RESPONSE_ROUTES_TEST failures=",failures," routes=",JSON.stringify(samples))
	game.queue_free()
	await process_frame
	quit(failures)

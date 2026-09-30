extends SceneTree

var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10):await physics_frame
	game.set_process(false);game.transit.set_physics_process(false)
	game.driving.set_physics_process(false)
	for npc in game.npcs:npc.set_physics_process(false)
	for resident in game.population.residents:
		resident.set_physics_process(false);resident.position=Vector3(20+resident.index*2,0,24)
	var pair: Array=[game.population.residents[6],game.population.residents[7]]
	var traffic: CityCar=game.driving.car_for("traffic_0")
	for car in game.driving.cars:
		if car!=traffic:car.traffic=false
	var records := {}
	for id in CityPopulation.CROSSINGS:
		var ends: Array=CityPopulation.CROSSINGS[id]
		var a: Vector3=CityPopulation.POINTS[ends[0]]
		var b: Vector3=CityPopulation.POINTS[ends[1]]
		var axis := (b-a).normalized()
		# The bus is frozen in this fixture; park it elsewhere on its real route
		# so the office stop cannot independently block the release observation.
		game.transit.distance=fposmod(game.population.crossing_offsets[id]+100,game.transit.curve.get_baked_length())
		game.transit.sync_vehicle()
		# Both people were admitted before this gate expired. Seed a head-on
		# encounter with normal capsules, then let physical movement clear it.
		for i in range(2):
			var person: CityResident=pair[i]
			person.position=(a+b)/2+axis*(-1 if i==0 else 1)
			person.from_node=ends[i];person.destination=ends[1-i]
			person.route.assign([ends[1-i]]);person.crossing=id
			person.state="walking";person.hp=100;person.down=0;person.fear=0
			person.velocity=Vector3.ZERO;person.visits.clear()
			person.set_physics_process(true)
		game.population.crossings[id]={"people":true,"opened":true,"remaining":0.0}
		traffic.route_distance=game.population.crossing_offsets[id]-6
		traffic.transform=game.transit.vehicle_transform(traffic.route_distance)
		traffic.speed=0;game.driving.set_physics_process(true)
		var previous: Array=[pair[0].position,pair[1].position]
		var maximum := 0.0
		var minimum := INF
		var overlaps := 0
		var released := false
		var cleared := false
		for frame in range(900):
			await physics_frame
			minimum=minf(minimum,Vector2(pair[0].position.x-pair[1].position.x,pair[0].position.z-pair[1].position.z).length())
			for i in range(2):
				var person: CityResident=pair[i]
				maximum=maxf(maximum,person.position.distance_to(previous[i]));previous[i]=person.position
				var local: Vector3=traffic.to_local(person.position)
				if absf(local.x)<1.2 and absf(local.z)<2.45:overlaps+=1
			cleared=pair.all(func(person):return person.crossing=="" and person.destination in person.visits)
			released=game.population.route_gap(id,traffic.route_distance)< -5
			if cleared and released:break
		check(cleared and released,"双向行人走完且实际车流恢复："+id)
		check(maximum<.1 and minimum>.52 and overlaps==0,"过街分侧不瞬移、不穿人、不穿车："+id)
		records[id]={"both_cleared":cleared,"traffic_released":released,"max_step":maximum,"minimum_separation":minimum,"vehicle_overlap_samples":overlaps}
		for i in range(2):
			pair[i].set_physics_process(false);pair[i].crossing="";pair[i].route.clear()
			pair[i].position=Vector3(42+i*2,0,24)
		game.driving.set_physics_process(false)
	print("CITY_CROSSING_FLOW_TEST failures=",failures," data=",JSON.stringify(records))
	game.queue_free();await process_frame;quit(failures)

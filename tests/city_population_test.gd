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
	for npc in game.npcs: npc.set_physics_process(false)
	var population: CityPopulation=game.population
	check(population.residents.size()==12,"十二位稳定居民进入公共街区")
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"公共路网实际胶囊扫掠可通 "+str(link))
	var distance := [0.0,0.0,0.0]
	var cars: Array=game.driving.cars.filter(func(car): return car.traffic)
	var previous := [cars[0].route_distance,cars[1].route_distance,cars[2].route_distance]
	var entries := {"market":0,"homes":0,"waterfront":0}
	var last_crossing := {}
	var overlap_count := 0
	var invalid_count := 0
	var first_invalid := ""
	for person in population.residents: last_crossing[person.stable_id]=""
	for i in range(18000):
		await physics_frame
		for j in range(3):
			distance[j]+=fposmod(cars[j].route_distance-previous[j],game.transit.curve.get_baked_length())
			previous[j]=cars[j].route_distance
		for person in population.residents:
			if person.crossing!="" and last_crossing[person.stable_id]=="": entries[person.crossing]+=1
			last_crossing[person.stable_id]=person.crossing
		if i%120==0:
			for car in cars:
				if not car.rotation_clear(car.rotation.y): overlap_count+=1
			var data := population.snapshot()
			if not population.valid(JSON.parse_string(JSON.stringify(data))):
				invalid_count+=1
				if first_invalid=="":
					for person in population.residents:
						if not person.valid(data.people[person.stable_id]): first_invalid=person.stable_id+str(data.people[person.stable_id]); break
	var reached := {}
	for person in population.residents:
		reached[person.stable_id]=person.visits.duplicate()
		check(person.visits.size()>=2,"实际行走完成不同活动点 "+person.stable_id+" visits="+str(person.visits)+" position="+str(person.position)+" route="+str(person.route))
	for id in entries: check(entries[id]>0,"实际经过斑马线 "+id)
	check(distance.min()>game.transit.curve.get_baked_length(),"持续居民过街下三辆车仍自然完成整环 "+str(distance))
	check(overlap_count==0,"车流与实际居民无体积重叠 actual="+str(overlap_count))
	check(invalid_count==0,"运动中的居民JSON始终有效 actual="+str(invalid_count)+" first="+first_invalid)
	game.panels.show_page("city")
	var before := population.snapshot()
	await frames(10)
	check(population.snapshot()==before,"地图暂停冻结居民与过街时钟")
	game.panels.show_page("")
	var person: CityResident=population.residents[0]
	person.state="activity"
	person.route.clear()
	person.crossing=""
	person.destination="homes"
	person.journey=0
	person.activity_left=50
	person.phase=0
	game.payroll.minute=18*60
	await frames(5)
	check(person.destination=="sea_west" and person.state=="walking","共享时钟变化使居民改去晚间活动点")
	print("CITY_POPULATION_TEST failures=",failures," crossings=",entries," traffic_distance=",distance," visited=",reached)
	game.queue_free()
	await process_frame
	quit(failures)

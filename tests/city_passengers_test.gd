extends SceneTree

var failures := 0
var game: Node3D
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c2c")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10):await physics_frame
	var person: CityResident=game.population.residents[4]
	var observed := []
	var waiting_saved := false
	var riding_saved := false
	var arrived := false
	var invalid := 0
	var source := person.position
	var original_journey := person.journey
	var previous := source
	var walked := 0.0
	var maximum_walk_step := 0.0
	var maximum_ground_step := 0.0
	var boarded_distance := 0.0
	var last := ""
	for frame in range(24000):
		await physics_frame
		var trip: Dictionary=game.passengers.trips.get(person.stable_id,{})
		var stage: String=trip.get("stage","activity")
		if stage=="walking" and last=="walking":
			var step := Vector2(person.position.x-previous.x,person.position.z-previous.z).length()
			maximum_ground_step=maxf(maximum_ground_step,absf(person.position.y-previous.y))
			walked+=step;maximum_walk_step=maxf(maximum_walk_step,step)
		previous=person.position
		if stage!=last:
			print("PASSENGER_STAGE frame=",frame," stage=",stage," resident=",person.position," bus_stop=",game.transit.current_stop," destination=",person.destination)
			observed.append(stage);last=stage
		if stage=="waiting" and not waiting_saved:
			check(person.journey==original_journey,"候车不是额外的生活活动，不跳过原日程")
			waiting_saved=SaveGame.write(game,"res://build/c2c/waiting.json")==OK
			check(waiting_saved,"自然赴站候车实际存档")
			if not waiting_saved: diagnose();break
			check(walked>=source.distance_to(person.position)-1 and maximum_walk_step<.06 and maximum_ground_step<.1,"居民连续步行赴站，位移与路径一致且无传送 walked="+str(walked)+" direct="+str(source.distance_to(person.position))+" max_xz_step="+str(maximum_walk_step)+" max_ground_step="+str(maximum_ground_step))
		if stage=="riding":
			if boarded_distance==0:boarded_distance=game.transit.distance
			check(person.position.distance_to(game.transit.bus.to_global(CityPassengers.SEATS[int(trip.seat)]))<.08,"居民固定在所属公共座位")
			if not riding_saved and game.transit.current_stop<0 and absf(game.transit.distance-boarded_distance)>12:
				riding_saved=SaveGame.write(game,"res://build/c2c/riding.json")==OK
				check(riding_saved,"实际公交行驶中存档")
				if not riding_saved: diagnose();break
				var position_before := person.position
				check(SaveGame.restore(game,SaveGame.read("res://build/c2c/riding.json",game)),"行驶JSON恢复")
				check(game.passengers.aboard(person) and person.position.distance_to(position_before)<.08,"乘车身份和座位恢复")
				game.panels.show_page("city")
				var paused_distance: float=game.transit.distance
				var paused_position := person.position
				for i in range(10):await physics_frame
				check(game.transit.distance==paused_distance and person.position==paused_position,"地图暂停同时冻结公交和公共乘客")
				game.panels.show_page("")
		if frame%120==0 and not SaveGame.valid(JSON.parse_string(JSON.stringify(SaveGame.snapshot(game))),game):invalid+=1
		if riding_saved and not game.passengers.trips.has(person.stable_id) and person.destination=="market" and person.state=="activity":
			arrived=true;break
	check(observed.has("walking") and observed.has("waiting") and observed.has("riding") and arrived,"自然日程完成步行/候车/乘车/原目的地 "+str(observed)+" actual="+str(person.position)+" route="+str(person.route)+" trip="+str(game.passengers.trips.get(person.stable_id,{})))
	check(invalid==0,"完整世界JSON关联持续有效 count="+str(invalid))
	check(waiting_saved and riding_saved,"两份自然产生的乘客档已保存")
	check(person.journey==original_journey+1,"完成原目的地仅推进一次生活日程")
	check(game.player.position.distance_to(Vector3(-14,0,5))<.5 and not game.transit.riding,"自主出行不移动玩家或占用玩家状态")
	var result := {"failures":failures,"states":observed,"clock":game.payroll.minute,"final":SaveGame.vector(person.position),"walked_metres":walked,"max_walk_xz_step":maximum_walk_step,"max_ground_y_step":maximum_ground_step,"invalid_json_samples":invalid,"waiting_saved":waiting_saved,"riding_saved":riding_saved,"arrived_original_goal":arrived}
	FileAccess.open("res://build/c2c/natural-route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CITY_PASSENGERS_TEST ",JSON.stringify(result))
	game.queue_free();await process_frame;quit(failures)

func diagnose() -> void:
	var data := SaveGame.snapshot(game)
	FileAccess.open("res://build/c2c/invalid-world.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("PASSENGER_DIAG transit=",game.transit.valid(data.city_transit)," population=",game.population.valid(data.city_population,23,data.city_transit)," passengers=",game.passengers.valid(data.city_population.passengers,data.city_population.people,data.city_transit)," commons=",game.commons.valid(data.city_commons,data)," response=",game.response.valid(data.city_response,data.city_population.people)," home=",game.home.valid(data.city_home,data))
	for person in game.population.residents:
		if not person.valid(data.city_population.people[person.stable_id],game.passengers.aboard(person)):print("INVALID_RESIDENT ",person.stable_id," ",data.city_population.people[person.stable_id])

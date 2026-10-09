extends SceneTree

var failures := 0
var game: Node3D
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1
func frames(count: int=3) -> void:
	for i in range(count):await physics_frame
func same(a: Variant,b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func at_stop(index: int) -> void:
	game.transit.distance=game.transit.stop_offsets[index];game.transit.current_stop=index
	game.transit.next_stop=(index+1)%4;game.transit.speed=0;game.transit.dwell=8;game.transit.sync_vehicle()
func queue(person: CityResident,origin: int,destination: int,slot: int=0) -> void:
	game.commons.release(person)
	person.hp=100;person.down=0;person.fear=0
	person.route.clear();person.crossing="";person.state="activity"
	person.destination=CityPassengers.wait_node(origin,slot);person.from_node=person.destination
	person.position=CityPopulation.POINTS[person.destination]
	game.passengers.trips[person.stable_id]={"origin":origin,"destination":destination,"queue":slot,"seat":-1,"stage":"walking","early_exit":false,"goal":"market" if destination==1 else "homes"}
	game.passengers.attend(person,0)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(8)
	game.set_process(false);game.set_physics_process(false)
	for node in game.find_children("*","",true,false):node.set_process(false);node.set_physics_process(false)
	var initial := SaveGame.snapshot(game)
	for stop in range(4):
		for slot in range(3):
			var origin: Vector3=CityPopulation.POINTS[["south","west_in","north_in","east_in"][stop]]
			var point: Vector3=CityPopulation.POINTS[CityPassengers.wait_node(stop,slot)]
			check(game.walking.clear_segment(origin,point),"候车支路真实胶囊扫掠可通 "+str(stop)+"/"+str(slot))
		for point in game.passengers.exit_points(stop):
			var route: Array[String]=game.population.path(point,"center")
			var from: Vector3=point
			for node in route:
				var next: Vector3=CityPopulation.POINTS[node]
				check(game.walking.clear_segment(from,next),"下客落脚到步道的每段均可通 "+str(stop)+"/"+node)
				from=next
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from-route="):
			var loaded := SaveGame.read(argument.trim_prefix("--from-route="),game)
			check(not loaded.is_empty() and SaveGame.restore(game,loaded),"自然产生的乘客档独立进程读取")
			await frames()
			check(same(game.passengers.snapshot(),loaded.city_population.passengers),"完整旅程关联恢复")
			for person in game.population.residents:
				if game.passengers.aboard(person):check(person.position.distance_to(game.transit.bus.to_global(CityPassengers.SEATS[int(game.passengers.trips[person.stable_id].seat)]))<.08,"旧位置修复后仍在座位")
			print("CITY_PASSENGERS_SAVE_TEST failures=",failures," from_route=",argument)
			game.queue_free();await process_frame;quit(failures);return
	check(SaveGame.valid(initial,game),"新世界关联有效")
	var riders: Array[CityResident]=[]
	for index in [4,5,6,8,9]:
		var person: CityResident=game.population.residents[index];riders.append(person)
		queue(person,0,1)
		await frames()
	check(riders.all(func(person):return game.passengers.aboard(person)),"五个公共座位独立占用")
	var waiting: CityResident=game.population.residents[10]
	queue(waiting,0,1)
	check(not game.passengers.aboard(waiting) and game.passengers.trips[waiting.stable_id].stage=="waiting","满座保持候车")
	game.player.position=CityLayout.STOPS[0].platform;await frames()
	check(game.transit.board(0) and game.transit.riding,"公共满座时玩家仍可使用原座位")
	await frames(60)
	var floor: MeshInstance3D=game.transit.bus.get_node("CabinFloor")
	var floor_top: float=floor.position.y+floor.mesh.size.y/2
	var minimum_foot_clearance := 1000.0
	for person in riders:
		var skeleton: Skeleton3D=person.visual.skeleton
		for side in ["L","R"]:
			var foot: Vector3=game.transit.bus.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("foot."+side)).origin))
			minimum_foot_clearance=minf(minimum_foot_clearance,foot.y-floor_top)
			check(foot.y>floor_top and foot.y<floor_top+.2,"三种体型坐姿的脚部未被原型车厢地板吞没 "+person.stable_id+" "+str(foot.y))
	for person in riders:check(person.position.distance_to(game.player.position)>.6,"玩家座位没有居民重叠")
	game.transit.dwell=0
	for i in range(10):game.transit.tick(1.0);await frames(1)
	check(game.transit.current_stop<0,"载着居民与玩家实际离站")
	var path := "res://build/c2c/seat-boundary.json"
	check(SaveGame.write(game,path)==OK,"玩家与五居民同乘实际JSON写盘")
	var saved := SaveGame.read(path,game)
	check(not saved.is_empty() and SaveGame.restore(game,saved),"同乘全档恢复")
	await frames()
	check(game.transit.riding and riders.all(func(person):return game.passengers.aboard(person)),"恢复后保留玩家与居民座位")
	var bad_cases := ["missing","schema","unknown","seat","duplicate","fraction","origin","destination","stage","goal","position","orphan","route","commons","early_exit","wrong_type","invalid_bus"]
	for issue in bad_cases:
		var bad := saved.duplicate(true)
		var id := riders[0].stable_id
		match issue:
			"missing":bad.city_population.erase("passengers")
			"schema":bad.city_population.passengers.schema=2
			"unknown":bad.city_population.passengers.trips["stranger"]=bad.city_population.passengers.trips[id]
			"seat":bad.city_population.passengers.trips[id].seat=5
			"duplicate":bad.city_population.passengers.trips[riders[1].stable_id].seat=bad.city_population.passengers.trips[id].seat
			"fraction":bad.city_population.passengers.trips[id].seat=.5
			"origin":bad.city_population.passengers.trips[id].origin=4
			"destination":bad.city_population.passengers.trips[id].destination=0
			"stage":bad.city_population.passengers.trips[id].stage="flying"
			"goal":bad.city_population.passengers.trips[id].goal="unknown"
			"position":bad.city_population.people[id].position=[0,.4,0]
			"orphan":bad.city_population.passengers.trips.erase(id)
			"route":bad.city_population.people[id].route=["office"]
			"commons":bad.city_commons.visits[id]={"slot":"commons_west_0/0","seated":false}
			"early_exit":bad.city_population.passengers.trips[id].early_exit="yes"
			"wrong_type":bad.city_population.passengers.trips[id]=[]
			"invalid_bus":bad.city_transit.distance="invalid"
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and same(SaveGame.snapshot(game),before),"非法乘客档原子拒绝 "+issue)
	# All four platforms use their actual orientation; an occupied exit holds
	# this bus without moving the player, disabling collisions or discarding a rider.
	at_stop(1)
	var blocker := Shapes.solid(game,Vector3(1.6,2,7),CityLayout.STOPS[1].platform+Vector3.UP,Color.RED)
	await frames()
	for person in riders:game.passengers.attend(person,0)
	var held: float=game.transit.distance
	game.transit.tick(20)
	check(game.transit.distance==held and riders.all(func(person):return game.passengers.aboard(person)),"出口全被挡时保持乘客并等待")
	blocker.queue_free();await frames()
	for person in riders:game.passengers.attend(person,0)
	for a in range(riders.size()):
		for b in range(a+1,riders.size()):check(riders[a].position.distance_to(riders[b].position)>.8,"同一物理帧下客也不共享落脚点")
	await frames()
	check(riders.all(func(person):return not game.passengers.aboard(person) and person.destination=="market"),"解除阻挡后五居民继续原目的地")
	for stop in [0,2,3]:
		check(SaveGame.restore(game,initial),"重置边界夹具")
		await frames();at_stop(stop)
		queue(riders[0],stop,(stop+1)%4)
		check(game.passengers.aboard(riders[0]),"实际朝向站点上客 "+str(stop))
		at_stop((stop+1)%4);game.passengers.attend(riders[0],0)
		check(not game.passengers.aboard(riders[0]),"实际朝向站点下客 "+str(stop))
	check(SaveGame.restore(game,initial),"危险夹具重置")
	await frames();queue(riders[0],0,2)
	game.transit.dwell=0;game.transit.tick(1)
	riders[0].hit(Vector3.RIGHT,10,12345,true)
	check(riders[0].hp==1 and riders[0].down>0 and game.passengers.aboard(riders[0]) and not game.response.report(riders[0],"player"),"车内昏迷保留在车上，救助不抢走移动乘客")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"车内危险后的关联可保存")
	at_stop(1);game.passengers.attend(riders[0],0)
	check(riders[0].hp==1 and riders[0].down>0 and not game.passengers.aboard(riders[0]) and game.response.report(riders[0],"player"),"下一停站安全落脚后交给既有救助，受伤事实不变")
	check(SaveGame.restore(game,initial),"跳过等车夹具重置")
	await frames();queue(riders[0],0,1)
	game.player.position=CityLayout.STOPS[2].platform
	var middle_block := Shapes.solid(game,Vector3(1.6,2,7),CityLayout.STOPS[1].platform+Vector3.UP,Color.RED)
	await frames()
	var before_skip := SaveGame.snapshot(game)
	check(not game.transit.wait_for_bus(2) and same(SaveGame.snapshot(game),before_skip),"中途下客站被挡时跳过等车原子拒绝")
	middle_block.queue_free();await frames()
	# Frozen traffic_0 starts across the intermediate bus stop. This is a real
	# obstruction, so it must reject the skip before traffic drives away.
	before_skip=SaveGame.snapshot(game)
	check(not game.transit.wait_for_bus(2) and same(SaveGame.snapshot(game),before_skip),"中途车道被实际车流占据时跳过等车原子拒绝")
	for frame in range(300):
		for car in game.driving.cars:
			if car.traffic:car.tick_traffic(1.0/60,game.transit)
		await frames(1)
	check(game.transit.wait_for_bus(2) and game.transit.current_stop==2,"显式跳过等车仍抵达玩家站点")
	check(not game.passengers.aboard(riders[0]) and riders[0].position.distance_to(CityLayout.STOPS[1].platform)<3,"跳过等待时原乘客在途中目的站下车")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"跳过等车后的完整关联有效")
	check(SaveGame.restore(game,initial),"候车避险夹具重置")
	await frames();queue(riders[0],1,2)
	riders[0].avoid(game.player.position)
	check(not game.passengers.trips.has(riders[0].stable_id) and riders[0].fear>0,"候车危险让出出行所有权并保留避险")
	for version in range(1,23):
		var old := initial.duplicate(true);old.version=version
		old.city_population.schema=1;old.city_population.erase("passengers")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))) and game.passengers.trips.is_empty(),"v%d真实JSON旧结构初始化无乘客"%version)
		check(game.payroll.balance==initial.payroll.balance and game.career.employer==initial.career.employer,"旧职业和工资保持")
	print("CITY_PASSENGERS_SAVE_TEST failures=",failures," public_seats=5 bad_cases=",bad_cases.size()," legacy_versions=22 platforms=4 floor_top=",floor_top," minimum_foot_bone_clearance=",minimum_foot_clearance)
	game.queue_free();await process_frame;quit(failures)

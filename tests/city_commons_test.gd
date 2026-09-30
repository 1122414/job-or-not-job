extends "res://tests/city_bookshop_test.gd"

var prior_positions := {}
var prior_riding := {}
var walking_distance := 0.0
var walking_max_step := 0.0
var bus_transfers := 0

func observe_movement(person: CityResident) -> void:
	var riding: bool=game.passengers.aboard(person)
	if prior_positions.has(person.stable_id):
		if riding!=prior_riding[person.stable_id]:
			bus_transfers+=1
			check(game.transit.current_stop>=0,"居民只在实际停站交接上下车")
			if not riding:check(person.position.distance_to(CityLayout.STOPS[game.transit.current_stop].platform)<3,"下车位移只限该站落脚区域")
		elif not riding:
			var old: Vector3=prior_positions[person.stable_id]
			var step := Vector2(person.position.x-old.x,person.position.z-old.z).length()
			walking_distance+=step;walking_max_step=maxf(walking_max_step,step)
		if riding:
			var trip: Dictionary=game.passengers.trips[person.stable_id]
			check(person.position.distance_to(game.transit.bus.to_global(CityPassengers.SEATS[int(trip.seat)]))<.08,"乘车移动必须保持实际座位关联")
	prior_positions[person.stable_id]=person.position;prior_riding[person.stable_id]=riding

func reading_contact(person: CityResident) -> float:
	var error := 0.0
	check(game.commons.reading(person) and person.pastime_book.visible,"实际独坐阅读动作及书本可见 "+person.visual.outfit)
	for side in ["L","R"]:
		var support: Vector3=person.pastime_book.to_global(Vector3(-.13 if side=="L" else .13,-.015,0))
		error=maxf(error,person.visual.contacts.palm(side).origin.distance_to(support))
	var skeleton: Skeleton3D=person.visual.skeleton
	var hip: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("upperleg01.L")).origin)
	var foot: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("foot.L")).origin)
	check(absf(hip.y-.505)<.04 and foot.y>0 and foot.y<.15,"实际坐姿骨架与座面/地面相符 "+person.visual.outfit)
	return error

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var commons: CityCommons=game.commons
	check(commons.benches.size()==6,"三处连廊六张实体可用长凳")
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"公共路段仍可实际扫掠 "+str(link))
	var seated_seen := {}
	var departure_seen := {}
	var first: CityResident
	for i in range(18000):
		await physics_frame
		for person in game.population.residents:
			observe_movement(person)
			if commons.sitting(person):
				seated_seen[person.stable_id]=true
				check(person.seat_body!=null and is_equal_approx(person.body.shape.height,1.3),"落座同步身体碰撞")
				var visit: Dictionary=commons.visits[person.stable_id]
				var other_slot: String=visit.slot.get_slice("/",0)+"/"+str(1-int(visit.slot.get_slice("/",1)))
				if first==null and not commons.occupied(other_slot) and commons.clear_seat(other_slot,game.player):
					var entry: Vector3=commons.point(other_slot)+Vector3(0,0,1.35)
					if game.population.residents.all(func(other): return other.position.distance_to(entry)>1.4): first=person
			elif seated_seen.has(person.stable_id): departure_seen[person.stable_id]=true
		if first!=null: break
	check(first!=null,"无玩家触发，居民自然走近并落座")
	if first==null: print("COMMONS_DIAG ",commons.snapshot(),game.population.snapshot()); quit(1); return
	var slot: String=commons.visits[first.stable_id].slot
	var bench := commons.slot_bench(slot)
	var free_side := 1-int(slot.get_slice("/",1))
	# The fixture starts outside the chosen venue; entering and interacting uses real input.
	var entrance: Vector3=bench.seat_point(free_side)+Vector3(0,0,1.35)
	game.player.position=entrance+Vector3(0,0,1.1)
	await frames(3)
	check(await walk_to(entrance),"玩家实走到长凳前")
	game.player.yaw=atan2(-(bench.seat_point(free_side).x-game.player.position.x),-(bench.seat_point(free_side).z-game.player.position.z))
	for i in range(120):
		if game.nearest()==bench: break
		await physics_frame
	key(KEY_E)
	check(game.player.seated and commons.player_bench()==bench,"真实E坐入空位")
	if not game.player.seated: quit(1); return
	await frames(40)
	check(game.player.position.distance_to(bench.seat_point(free_side))<.06 and game.player.is_on_floor(),"座位位置和地面支撑保持")
	var facing: float=game.player.visual.rotation.y
	game.player.look(Vector2(300,0))
	await frames(30)
	check(absf(angle_difference(facing,game.player.visual.rotation.y))<.03,"转镜头不扭转坐姿穿过靠背")
	for topic in ["quiet","street","work"]:
		var offset: Vector3=first.position-game.player.position
		game.player.yaw=atan2(-offset.x,-offset.z)
		key(KEY_E)
		check(game.speaker==first,"真实E交谈实际邻座")
		var choice := -1
		for j in range(game.conversation.get("choices",[]).size()):
			if game.conversation.choices[j][1]=="commons_"+topic: choice=j
		check(choice>=0,"现场话题可选 "+topic)
		if choice>=0: key(KEY_1+choice)
		check(commons.memories.get(first.stable_id,{}).get("topic")==topic,"实际交谈留下不同经历 "+topic)
		game.close_interaction()
	var memory := commons.memories.duplicate(true)
	game.population.talk(first)
	commons.answer(first,"commons_work")
	check(commons.memories==memory and game.career.employer=="" and game.payroll.balance==0,"重复交流不刷奖励或替玩家入职")
	game.close_interaction()
	var save := SaveGame.snapshot(game)
	check(SaveGame.valid(save,game),"坐着的全世界快照有效")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(save))),"实际JSON恢复双方座位和记忆")
	await frames(20)
	check(game.player.seated and commons.sitting(first) and commons.memory_line(first).contains("打算"),"读档后坐姿与共同经历保留")
	game.panels.show_page("city")
	var frozen := JSON.stringify(SaveGame.snapshot(game))
	await frames(20)
	check(JSON.stringify(SaveGame.snapshot(game))==frozen,"地图暂停不推进公共生活")
	game.panels.show_page("")
	press("forward",true)
	await frames(5)
	press("forward",false)
	check(not game.player.seated and commons.player_slot=="","真实移动起身释放座位")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"全程不接管鼠标")
	# Let the same autonomous visit finish, then exercise different time-of-day plans.
	for person in game.population.residents:
		prior_positions[person.stable_id]=person.position;prior_riding[person.stable_id]=game.passengers.aboard(person)
	var used_benches := {}
	var pair_seen := false
	var read_seen := false
	var contacts := {}
	var max_contact := 0.0
	for minute in [540,800,1080]:
		game.payroll.minute=minute
		for i in range(12000):
			await physics_frame
			for person in game.population.residents:
				observe_movement(person)
				if commons.sitting(person):
					seated_seen[person.stable_id]=true
					used_benches[person.seat_body.stable_id]=true
					pair_seen=pair_seen or commons.companion(person)!=null
					read_seen=read_seen or person.pastime_book.visible
					if person.pastime_book.visible and person.activity_left<39 and not contacts.has(person.visual.outfit):
						max_contact=maxf(max_contact,reading_contact(person))
						contacts[person.visual.outfit]=true
				elif seated_seen.has(person.stable_id): departure_seen[person.stable_id]=true
			if i%120==0:
				var current := SaveGame.snapshot(game)
				if not SaveGame.valid(current,game):
					check(false,"自然运行全档关联有效"); quit(1); return
	check(used_benches.size()==6,"六张长凳均被自然使用 "+str(used_benches))
	var natural_contacts := contacts.keys()
	# Transit changes who meets on a bench: a body type may only be observed
	# talking in this finite route. Check any missing type in an explicitly
	# isolated seated-reading fixture, retaining the same physical/contact limits.
	for actor in game.population.residents:actor.set_physics_process(false)
	for index in [0,2,6]:
		var person: CityResident=game.population.residents[index]
		if contacts.has(person.visual.outfit):continue
		game.commons.visits.clear();game.passengers.reset()
		var place: String=game.commons.reserve(person,"commons_west_0")
		check(place!="center","体型接触夹具有实际空座")
		if place=="center":continue
		person.destination=place;person.from_node=place;person.route.clear();person.crossing=""
		person.state="activity";person.phase=game.population.time_phase()
		person.position=game.commons.point(game.commons.visits[person.stable_id].slot)
		person.set_physics_process(true)
		await frames(60)
		max_contact=maxf(max_contact,reading_contact(person))
		contacts[person.visual.outfit]=true
		person.set_physics_process(false)
	check(contacts.size()==3 and max_contact<.003,"三套居民身体双掌实际接触书本 "+str(contacts)+" error="+str(max_contact))
	check(pair_seen and read_seen,"自然出现邻座交谈和实体阅读")
	check(departure_seen.size()>=4 and walking_max_step<.065,"居民自然离开且步行无传送 max="+str(walking_max_step))
	print("CITY_COMMONS_TEST failures=",failures," benches=",used_benches," seated=",seated_seen.size()," left=",departure_seen.size()," walking_distance=",walking_distance," max_walking_step=",walking_max_step," bus_transfers=",bus_transfers," reading=",read_seen," pairs=",pair_seen," natural_contacts=",natural_contacts," contacts=",contacts," palm_error=",max_contact)
	game.queue_free()
	await process_frame
	quit(failures)

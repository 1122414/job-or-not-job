extends "res://tests/city_bookshop_test.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3g")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	# A single starting clock fixture; the game's normal clock advances afterwards.
	game.payroll.minute=1138
	var observed := {}
	var previous := {}
	var maximum := 0.0
	var metres := 0.0
	var overlaps := 0
	for id in CityEvening.PLANS:
		observed[id]={}; previous[id]=game.npc_for_role(id).position
	for frame in range(23000):
		await physics_frame
		for id in observed:
			var npc: OfficeNPC=game.npc_for_role(id)
			var step: float=npc.position.distance_to(previous[id])
			maximum=maxf(maximum,step); metres+=step; previous[id]=npc.position
			var place := CityEvening.at_place(npc)
			if place!="" and not observed[id].has(place): observed[id][place]=game.payroll.minute
			if game.payroll.minute>=1260 and npc.position.distance_to(CityEvening.FOYERS[id])<.65 and not observed[id].has("returned"): observed[id]["returned"]=game.payroll.minute
			for vehicle in [game.transit.bus]+game.driving.cars:
				var local: Vector3=vehicle.to_local(npc.position)
				if absf(local.x)<1.2 and absf(local.z)<(3.6 if vehicle==game.transit.bus else 2.2)+.25: overlaps+=1
		if frame==150:
			game.panels.show_page("city")
			var minute: int=game.payroll.minute
			var before: Vector3=game.npc_for_role("a_friend").position
			await frames(45)
			check(game.payroll.minute==minute and game.npc_for_role("a_friend").position==before,"地图暂停冻结自主行程和时钟")
			game.panels.show_page("")
		if game.payroll.minute>=1310: break
	for id in observed:
		for place in CityEvening.PLANS[id]: check(observed[id].has(place),"自然时钟内实际到达 "+id+"/"+place+" seen="+str(observed[id]))
		check(observed[id].has("returned"),"自然时钟内实际返程 "+id)
	check(maximum<.1 and overlaps==0,"自然时间行程无传送或车流重叠")
	check(game.social.outing.is_empty(),"不靠玩家发起或后台自动代答")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.persistence_enabled,"不捕获鼠标或写玩家档")
	var data := {"observed":observed,"start_minute":1138,"end_minute":game.payroll.minute,"metres":metres,"max_step":maximum,"vehicle_overlap_samples":overlaps,"clock_advanced_normally":true,"normal_fps_measured":false,"independent_player_acceptance":false}
	FileAccess.open("res://build/c3g/cycle.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("CITY_EVENING_CYCLE_TEST failures=",failures," data=",JSON.stringify(data))
	game.queue_free(); await process_frame; quit(failures)

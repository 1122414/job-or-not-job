extends SceneTree
const Driver=preload("res://tests/scene_driver.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.player.position=Vector3(-10,0,-4.9)
	game.social.meet(npc)
	for scenario in ["tea","lunch","legacy_walk","walk"]:
		var kind: String="walk" if scenario=="legacy_walk" else scenario
		game.payroll.advance({"tea":600,"lunch":750,"walk":1110}[kind]-game.payroll.minute,"")
		if scenario=="legacy_walk":
			game.social.outing={"person":npc.stable_id,"kind":"walk","stage":"walking","elapsed":0.0}
		else:
			game.social.handle("people_invite_"+kind,npc)
			if kind=="walk": game.social.handle("people_city_go_garden",npc)
		if scenario in ["lunch","legacy_walk"]:
			var old: Dictionary=SaveGame.snapshot(game)
			old.version=19 if scenario=="lunch" else 18
			old.city_population.crossings.erase("office")
			var payload := JSON.stringify(old)
			var file: String="user://daily-routine-"+scenario+"-test.json"
			FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify({"payload":payload,"checksum":payload.sha256_text()}))
			if not SaveGame.restore(game,SaveGame.read(file,game)): failures+=1; break
			for i in range(4): await physics_frame
			if game.social.destination(npc,kind).z<17: failures+=1; break
		var sample := {"previous":npc.position,"metres":0.0,"max_step":0.0,"overlaps":0}
		var observe := func():
			var step: float=npc.position.distance_to(sample.previous)
			sample.metres+=step; sample.max_step=maxf(sample.max_step,step); sample.previous=npc.position
			for vehicle in [game.transit.bus]+game.driving.cars:
				var local: Vector3=vehicle.to_local(npc.position)
				if absf(local.x)<1.2 and absf(local.z)<(3.6 if vehicle==game.transit.bus else 2.2)+.25: sample.overlaps+=1
		physics_frame.connect(observe)
		var arrived := await Driver.follow(self,game,npc,game.social.destination(npc,kind),12000)
		physics_frame.disconnect(observe)
		sample.erase("previous")
		if not arrived or sample.overlaps!=0 or sample.max_step>=.1:
			push_error("日常路线未通过 "+scenario+" "+JSON.stringify(sample)); failures+=1; break
		game.speaker=npc
		game.conversation=game.social.options(npc)
		if game.conversation.choices[0][1]!="people_share": failures+=1; break
		game.choose(0)
		game.choose(0)
		if not game.social.outing.is_empty(): failures+=1
		print("DAILY_ROUTE ",scenario," ",npc.position," ",JSON.stringify(sample))
	game.queue_free()
	await process_frame
	print("DAILY_ROUTINE_TEST failures=",failures)
	quit(failures)

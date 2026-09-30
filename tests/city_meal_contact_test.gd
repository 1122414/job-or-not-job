extends "res://tests/hand_contact_test.gd"

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10):await physics_frame
	game.set_process(false);game.meals.set_physics_process(false)
	for actor in game.npcs+game.population.residents+[game.player]:actor.set_physics_process(false)
	var results := {}
	for actor in [game.player,game.population.residents[1],game.population.residents[4],game.population.residents[8],game.npc_for_role("a_friend")]:
		var id: String="player" if actor==game.player else actor.stable_id
		var slot := 4 if id=="player" else 3 if actor is OfficeNPC else CityMeals.CUSTOMERS.find(id)
		actor.position=CityMeals.TABLES[slot];actor.velocity=Vector3.ZERO
		var h: HumanVisual=actor.visual
		h.rotation=Vector3(0,PI,0);h.position=Vector3.ZERO
		h.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		game.meals.orders={id:{"item":"noodles","stage":"eating","slot":slot,"cents":800 if id=="player" else 0,"window":0,"cooked":8.0,"eaten":0.0}}
		game.meals.scene.sync()
		var skin := {"L":skin_samples(h,"L"),"R":skin_samples(h,"R")}
		var error := 0.0;var surface := 0.0;var worst := {}
		for frame in range(241):
			game.meals.orders[id].eaten=frame/60.0
			h.animation.play("idle",0);h.animation.seek(frame/60.0,true);h.animation.advance(0)
			game.meals.scene.apply(actor)
			var dish: Node3D=game.meals.scene.foods[id];var utensil: Node3D=game.meals.scene.spoons[id]
			for side in ["L","R"]:
				var target := dish.to_global(Vector3(-.055,-.002,.005)) if side=="L" else utensil.to_global(Vector3(0,0,.08))
				var difference := h.contacts.palm(side).origin.distance_to(target)
				if difference>error:
					error=difference;worst={"frame":frame,"side":side,"target":SaveGame.vector(h.to_local(target)),"palm":SaveGame.vector(h.to_local(h.contacts.palm(side).origin)),"face":SaveGame.vector(h.to_local(h.face_position()))}
				surface=maxf(surface,surface_distance(h,skin[side],h.contacts.palm(side).origin))
			if frame in [110,120,130,140]:
				check(h.to_local(h.contacts.palm("R").origin).z<h.to_local(h.face_position()).z-.1,"送到嘴边时手腕仍在面部前方 "+id)
		check(error<.02,"餐具实际掌点接触小于2cm "+id+" error="+str(error))
		check(surface<.01,"实际蒙皮掌面在接触点1cm内 "+id)
		results[id]={"contact_error":error,"skin_error":surface,"worst":worst}
	var vendor: CityResident=game.meals.person(CityMeals.VENDOR)
	vendor.position=CityPopulation.POINTS.meal_vendor;vendor.velocity=Vector3.ZERO;vendor.visual.rotation=Vector3.ZERO
	game.payroll.minute=690
	game.meals.orders={"player":{"stage":"queued","cooked":0.0}}
	game.meals.queue.assign(["player"])
	var ladle_error := 0.0;var outside_pot := 0
	vendor.visual.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for frame in range(241):
		game.meals.orders.player.cooked=frame/30.0
		vendor.visual.animation.play("idle",0);vendor.visual.animation.seek(frame/30.0,true);vendor.visual.animation.advance(0)
		game.meals.scene.apply(vendor)
		var ladle: Node3D=game.meals.scene.ladle
		ladle_error=maxf(ladle_error,vendor.visual.contacts.palm("R").origin.distance_to(ladle.to_global(Vector3(0,0,.11))))
		var tip := ladle.to_global(Vector3(0,-.003,-.052))
		if Vector2(tip.x-10,tip.z-14.5).length()>.27 or tip.y<1.01 or tip.y>1.285:outside_pot+=1
	check(ladle_error<.02 and outside_pot==0,"摊主实际握住长柄勺，勺头在锅内而不是空中")
	results.vendor={"contact_error":ladle_error,"outside_pot_frames":outside_pot}
	game.meals.orders.clear();game.meals.queue.clear()
	DirAccess.make_dir_recursive_absolute("res://build/c3k")
	FileAccess.open("res://build/c3k/contacts.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"actors":results,"frames_per_actor":241},"\t")+"\n")
	print("CITY_MEAL_CONTACT_TEST failures=",failures," ",JSON.stringify(results))
	game.queue_free();await process_frame;quit(failures)

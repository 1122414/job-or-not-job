extends "res://tests/city_bookshop_test.gd"

const Driver = preload("res://tests/scene_driver.gd")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(10)
	game.set_process(false);game.payroll.minute=720
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.social.meet(npc)
	game.social.handle("people_invite_lunch",npc)
	var stages: Array=[];var path := PackedVector3Array()
	var before: Vector3=npc.position;var metres := 0.0;var maximum := 0.0
	var consumed := false
	for frame in range(14000):
		var distance: float=game.player.position.distance_to(npc.position)
		if frame%30==0: path=game.walking.route(game.player.position,npc.position,null,game.player)
		while not path.is_empty() and game.player.position.distance_to(path[0])<.15:path.remove_at(0)
		if distance>1.65 and not path.is_empty():
			var offset := Driver.steer_around_people(game,path[0]-game.player.position)
			game.player.yaw=atan2(-offset.x,-offset.z);press("forward",true)
		else: press("forward",false)
		await physics_frame
		var step: float=before.distance_to(npc.position);metres+=step;maximum=maxf(maximum,step);before=npc.position
		if game.meals.orders.has(npc.stable_id):
			var stage: String=game.meals.orders[npc.stable_id].stage
			if not stage in stages: stages.append(stage)
		elif "eating" in stages: consumed=true;break
		if frame%120==0:check(SaveGame.valid(SaveGame.snapshot(game),game),"自然午饭同行完整关联有效")
	press("forward",false)
	check(consumed and "queued" in stages and "ready" in stages and "carrying" in stages,"同伴真实赴摊、排队、取餐并吃完 "+str(stages))
	check(metres>20 and maximum<.1,"同伴保留原导航与身体碰撞")
	check(game.payroll.balance==0 and not game.meals.orders.has("player"),"玩家未消费，同伴照常完成自己的午饭")
	if consumed:
		check(await Driver.follow(self,game,npc,game.social.destination(npc,"lunch"),1800),"用餐后继续自由相处")
		var offset: Vector3=npc.position-game.player.position
		game.player.yaw=atan2(-offset.x,-offset.z);await frames(4);key(KEY_E)
		check(game.speaker==npc and game.conversation.choices[0][1]=="people_share","未消费仍能实际E与午饭同伴交谈")
		key(KEY_1);key(KEY_1)
		check(game.social.outing.is_empty() and game.social.state(npc).days.has("outing_0"),"倾听才记录共同经历，不把付费当关系门槛")
	FileAccess.open("res://build/c3k/companion-test.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"stages":stages,"metres":metres,"maximum_step":maximum,"player_paid":0,"npc_position":SaveGame.vector(npc.position),"player_position":SaveGame.vector(game.player.position),"route":str(npc.route),"velocity":str(npc.velocity),"target":str(game.meals.npc_target(npc)),"orders":game.meals.snapshot()},"\t")+"\n")
	print("CITY_MEALS_SOCIAL_TEST failures=",failures," metres=",metres," maximum=",maximum," stages=",stages)
	game.queue_free();await process_frame;quit(failures)

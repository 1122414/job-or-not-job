extends "res://tests/city_bookshop_test.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3k")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(10)
	game.set_process(false);game.meals.set_physics_process(false)
	for actor in game.npcs+game.population.residents+[game.player]: actor.set_physics_process(false)
	var original := SaveGame.snapshot(game)
	var meals: CityMeals=game.meals
	game.payroll.minute=720;game.payroll.balance=3000
	var vendor: CityResident=meals.person(CityMeals.VENDOR)
	vendor.position=CityPopulation.POINTS.meal_vendor;vendor.route.clear();vendor.velocity=Vector3.ZERO;vendor.state="activity"
	for id in CityMeals.CUSTOMERS: meals.served[id]=0
	game.player.position=CityMeals.PICKUP
	check(meals.add_order("player","noodles"),"事务夹具接受合法点餐")
	var file := "res://build/c3k/queued.json"
	check(SaveGame.write(game,file)==OK,"v25真实JSON写盘")
	var saved := SaveGame.read(file,game)
	check(not saved.is_empty() and saved.version==25,"v25真实JSON校验读取")
	if saved.is_empty(): finish();return
	var invalid := ["missing","orders_type","queue_type","served_type","unknown","item","stage","slot","amount","negative","fraction","window","future_today","cooked_nan","cooked_complete","eaten_early","eaten_complete","queue_missing","queue_duplicate","queue_unknown","served_unknown","served_future","served_future_today"]
	for issue in invalid:
		var bad := saved.duplicate(true)
		match issue:
			"missing":bad.erase("city_meals")
			"orders_type":bad.city_meals.orders=[]
			"queue_type":bad.city_meals.queue={}
			"served_type":bad.city_meals.served=[]
			"unknown":bad.city_meals.orders.ghost=bad.city_meals.orders.player;bad.city_meals.orders.erase("player")
			"item":bad.city_meals.orders.player.item="unknown"
			"stage":bad.city_meals.orders.player.stage="done"
			"slot":bad.city_meals.orders.player.slot=0
			"amount":bad.city_meals.orders.player.cents=1200
			"negative":bad.city_meals.orders.player.cents=-800
			"fraction":bad.city_meals.orders.player.cents=800.1
			"window":bad.city_meals.orders.player.window=100
			"future_today":bad.city_meals.orders.player.window=1
			"cooked_nan":bad.city_meals.orders.player.cooked=NAN
			"cooked_complete":bad.city_meals.orders.player.cooked=CityMeals.COOK_SECONDS
			"eaten_early":bad.city_meals.orders.player.eaten=1
			"eaten_complete":bad.city_meals.orders.player.eaten=24
			"queue_missing":bad.city_meals.queue.clear()
			"queue_duplicate":bad.city_meals.queue.append("player")
			"queue_unknown":bad.city_meals.queue.append("absent")
			"served_unknown":bad.city_meals.served.ghost=0
			"served_future":bad.city_meals.served.resident_chen_yu=4
			"served_future_today":bad.city_meals.served.resident_chen_yu=1
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"坏餐食状态原子拒绝 "+issue)
	check(SaveGame.restore(game,saved) and game.payroll.balance==2200 and meals.orders.player.cooked==0,"排队档恢复不重复扣款或虚增制作")
	meals.cancel("player");meals.cancel("player")
	check(game.payroll.balance==3000 and meals.orders.is_empty(),"重复取消只退款一次")
	check(SaveGame.restore(game,saved),"恢复排队后验证停工")
	vendor.position+=Vector3(3,0,0);meals._physics_process(2)
	check(meals.orders.player.cooked==0,"摊主未实际到岗不制作")
	vendor.position=CityPopulation.POINTS.meal_vendor;game.speaker=vendor;meals._physics_process(2)
	check(meals.orders.player.cooked==0,"交谈占用摊主不制作")
	game.close_interaction();vendor.down=4;meals._physics_process(2)
	check(meals.orders.player.cooked==0,"伤病期间不制作")
	vendor.down=0;meals._physics_process(4)
	check(meals.orders.player.cooked==4,"重新到岗从原实际进度继续")
	game.advance_time(120)
	check(not meals.orders.has("player") and game.payroll.balance==3000,"闭摊自动退回尚未取餐款项")
	game.advance_time(1440)
	check(game.payroll.balance==3000,"再次跨日不重复退款")
	check(SaveGame.restore(game,saved),"恢复到可正常制作的排队档")
	meals._physics_process(8)
	check(meals.orders.player.stage=="ready" and SaveGame.valid(SaveGame.snapshot(game),game),"制作完成的待取餐状态合法")
	check(SaveGame.write(game,"res://build/c3k/ready.json")==OK,"待取餐真实JSON写盘")
	var ready := SaveGame.read("res://build/c3k/ready.json",game)
	check(SaveGame.restore(game,ready) and meals.take("player") and not meals.take("player"),"领取只有一次，重复领取无效")
	check(game.payroll.balance==2200,"取餐不再收费")
	game.player.position=CityMeals.TABLES[4];meals.orders.player.stage="eating";meals._physics_process(3)
	check(SaveGame.write(game,"res://build/c3k/eating.json")==OK,"用餐途中真实JSON写盘")
	var eating := SaveGame.read("res://build/c3k/eating.json",game)
	check(SaveGame.restore(game,eating) and meals.orders.player.eaten==3 and game.payroll.balance==2200,"恢复用餐进度和原余额")
	game.advance_time(1440)
	check(not meals.orders.has("player") and game.payroll.balance==2200,"跨日收起已取餐食，不退款也不虚构吃完")
	check(SaveGame.restore(game,original),"恢复初始世界验证邀请所有权")
	game.payroll.minute=720
	var npc: OfficeNPC=game.npc_for_role("b_friend")
	game.social.outing={"person":npc.stable_id,"kind":"lunch","stage":"offered","elapsed":0.0}
	check(not meals.add_order(npc.stable_id,"noodles"),"未回应的午饭邀请不变成订单")
	game.social.outing.stage="walking"
	check(meals.add_order(npc.stable_id,"noodles") and game.payroll.balance==0,"同伴自行点餐不向玩家收费")
	var companion := SaveGame.snapshot(game)
	check(SaveGame.valid(companion,game),"已接受的同伴订单完整关联合法")
	for stage in ["offered","paused"]:
		var bad := companion.duplicate(true);bad.social.outing.stage=stage
		check(not SaveGame.valid(bad,game),"同伴订单不能依附未接受或暂缓约定 "+stage)
	var trust: Dictionary= game.social.state(npc).duplicate(true);var affinity: int=npc.affinity
	game.social.pause_outing("先各自安排")
	check(not meals.orders.has(npc.stable_id) and game.social.outing.stage=="paused" and game.social.state(npc)==trust and npc.affinity==affinity,"暂缓释放订单，不取消约定或惩罚关系")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"暂缓后即时存档合法")
	game.social.outing.stage="walking";meals.served.erase(npc.stable_id)
	check(meals.add_order(npc.stable_id,"noodles"),"重新安排同伴夹具")
	game.career.b_event="negotiating";meals._physics_process(0)
	check(not meals.orders.has(npc.stable_id) and meals.npc_target(npc)==null and game.social.outing.stage=="walking","工作接管让出人物，不把约定静默清掉")
	for version in range(1,25):
		var old := original.duplicate(true);old.version=version;old.erase("city_meals")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))) and meals.orders.is_empty() and meals.served.is_empty() and game.payroll.balance==old.payroll.balance,"旧v%d不虚构餐食或收费"%version)
	print("CITY_MEALS_SAVE_CASES bad=",invalid.size()," legacy=24 disk=queued,ready,eating")
	finish()

func finish() -> void:
	game.queue_free();await process_frame
	print("CITY_MEALS_SAVE_TEST failures=",failures);quit(failures)

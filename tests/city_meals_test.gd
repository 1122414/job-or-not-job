extends "res://tests/city_bookshop_test.gd"

var events := {}
var distances := {}
var previous := {}
var max_step := 0.0
var largest := {}
var owned_before := {}
var meal_metres := {}

func observe() -> void:
	for actor in game.population.residents:
		var id: String=actor.stable_id
		if previous.has(id):
			var step: float=actor.position.distance_to(previous[id])
			distances[id]=distances.get(id,0.0)+step
			if (game.meals.orders.has(id) or id==CityMeals.VENDOR) and owned_before.get(id,false) and not game.passengers.trips.has(id):
				meal_metres[id]=meal_metres.get(id,0.0)+step
			if (game.meals.orders.has(id) or id==CityMeals.VENDOR) and owned_before.get(id,false) and not game.passengers.trips.has(id) and step>max_step:
				max_step=step;largest={"id":id,"step":step,"from":str(previous[id]),"to":str(actor.position),"state":actor.state,"trip":game.passengers.trips.get(id,{}).duplicate(true),"order":game.meals.orders.get(id,{}).duplicate(true)}
		owned_before[id]=game.meals.orders.has(id) or id==CityMeals.VENDOR
		previous[id]=actor.position
		if game.meals.orders.has(id):
			var stage: String=game.meals.orders[id].stage
			if not events.has(id): events[id]=[]
			if not stage in events[id]: events[id].append(stage)

func choose_action(action: String) -> bool:
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]==action: key(KEY_1+i);return true
	check(false,"缺少实际餐食选项 "+action+" "+str(game.conversation));return false

func use_meal(index: int) -> bool:
	var point: CityMealPoint=game.meals.points[index]
	var offset: Vector3=point.position-game.player.position
	game.player.yaw=atan2(-offset.x,-offset.z);await frames(3);key(KEY_E)
	check(game.speaker==point,"实际E选择路边摊/小桌 "+str(index)+" actual="+str(game.speaker))
	return game.speaker==point

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3k")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(10)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	game.player.position=Vector3(22,0,21);game.payroll.minute=690
	for link in CityPopulation.LINKS+CityPopulation.MEAL_LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"摊位与桌子不阻挡公共路段 "+str(link))
	physics_frame.connect(observe)
	var meals: CityMeals=game.meals
	for frame in range(18000):
		await physics_frame
		if frame%120==0:
			check(SaveGame.valid(SaveGame.snapshot(game),game),"自主午间活动完整状态合法 帧"+str(frame))
			if failures>0: break
		if CityMeals.CUSTOMERS.all(func(id):return events.get(id,[]).has("eating") and not meals.orders.has(id)): break
	for id in CityMeals.CUSTOMERS:
		check(events.get(id,[]).has("queued") and events.get(id,[]).has("carrying") and events.get(id,[]).has("eating") and not meals.orders.has(id),"居民自然排队取餐用餐并离开 "+id+" "+str(events.get(id,[])))
	check(meals.staffed() and distances.get(CityMeals.VENDOR,0)>10,"摊主实际走到岗位后才开餐")
	check(max_step<.15,"居民自然移动没有传送")
	physics_frame.disconnect(observe)
	var actors := {}
	for id in CityMeals.CUSTOMERS+[CityMeals.VENDOR]: actors[id]=meals.person(id).snapshot()
	FileAccess.open("res://build/c3k/autonomous.json",FileAccess.WRITE).store_string(JSON.stringify({"orders":meals.snapshot(),"actors":actors,"largest":largest,"events":events},"\t")+"\n")
	if failures>0: finish_meals();return
	for target in [Vector3(20,0,18),Vector3(16,0,18),Vector3(12.7,0,16.55)]:
		if not await walk_to(target): finish_meals();return
	if not await use_meal(0): finish_meals();return
	check(choose_action("meal_buy_noodles") and game.payroll.balance==0 and not meals.orders.has("player"),"不足余额不产生订单或债务")
	game.payroll.balance=2400
	await use_meal(0);choose_action("meal_buy_noodles")
	check(meals.orders.has("player") and game.payroll.balance==1600,"真实点餐只扣一次800分")
	check(not meals.add_order("player","soup") and game.payroll.balance==1600,"重复点单不能重复扣款")
	var vendor: CityResident=meals.person(CityMeals.VENDOR)
	game.population.talk(vendor)
	var cooked: float=meals.orders.player.cooked
	await frames(90)
	check(meals.orders.player.cooked==cooked,"摊主交谈期间停止制作")
	game.close_interaction();await frames(40)
	paused=true;cooked=meals.orders.player.cooked
	for i in range(10): await process_frame
	check(meals.orders.player.cooked==cooked,"暂停不制作餐食")
	paused=false
	for i in range(700):
		await physics_frame
		if meals.orders.player.stage=="ready": break
	check(meals.orders.player.stage=="ready","实际在岗制作结束后才备好")
	await use_meal(0);choose_action("meal_take")
	check(meals.orders.player.stage=="carrying" and game.payroll.balance==1600,"实体取餐不再次扣款")
	for target in [Vector3(12.7,0,17.4),CityMeals.TABLES[4]]:
		if not await walk_to(target): finish_meals();return
	await use_meal(1);choose_action("meal_eat");await frames(180)
	check(meals.orders.player.stage=="eating" and meals.orders.player.eaten>2,"小桌真实输入开始用餐")
	var eaten: float=meals.orders.player.eaten
	await walk_to(Vector3(13.3,0,20));await frames(60)
	check(meals.orders.player.stage=="carrying" and meals.orders.player.eaten<eaten+.2,"移动打断用餐，餐食保留")
	await walk_to(CityMeals.TABLES[4]);await use_meal(1);choose_action("meal_eat")
	for i in range(1600):
		await physics_frame
		if not meals.orders.has("player"): break
	check(not meals.orders.has("player") and game.payroll.balance==1600,"继续吃完只消费原订单")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.persistence_enabled,"不抢鼠标，不改玩家存档")
	FileAccess.open("res://build/c3k/meals-test.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"resident_stages":events,"resident_metres":distances,"meal_metres":meal_metres,"max_resident_step":max_step,"real_keys":true},"\t")+"\n")
	finish_meals()

func finish_meals() -> void:
	if physics_frame.is_connected(observe):physics_frame.disconnect(observe)
	press("forward",false);game.queue_free();await process_frame
	print("CITY_MEALS_TEST failures=",failures);quit(failures)

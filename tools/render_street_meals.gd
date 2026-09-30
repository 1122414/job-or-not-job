extends "res://tools/render_city_bus.gd"

const Driver = preload("res://tests/scene_driver.gd")
var travelled := 0.0
var maximum_step := 0.0
var previous := Vector3.ZERO
var snapshots := []
var seen := {}

func measure() -> void:
	var step := previous.distance_to(game.player.position)
	travelled+=step;maximum_step=maxf(maximum_step,step);previous=game.player.position
	for id in game.meals.orders:
		if not seen.has(id):seen[id]=[]
		if not game.meals.orders[id].stage in seen[id]:seen[id].append(game.meals.orders[id].stage)

func key(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		view.push_input(event,true)

func choice(action: String) -> bool:
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]==action:key(KEY_1+i);return true
	push_error("Missing actual meal option "+action+" "+str(game.conversation));return false

func use(index: int) -> bool:
	var point: CityMealPoint=game.meals.points[index]
	var offset: Vector3=point.position-game.player.position
	game.player.yaw=atan2(-offset.x,-offset.z)
	for i in range(8):await physics_frame
	key(KEY_E)
	if game.speaker!=point:push_error("Meal point not selected: "+str(game.nearest()));return false
	return true

func walk(target: Vector3) -> bool:
	var route: PackedVector3Array=game.walking.route(game.player.position,target,null,game.player)
	if route.is_empty():push_error("No physical meal route to "+str(target));return false
	for point in route:
		for frame in range(1800):
			var offset: Vector3=point-game.player.position;offset.y=0
			if offset.length()<.2:break
			var direction := Driver.steer_around_people(game,offset)
			game.player.yaw=atan2(-direction.x,-direction.z);Input.action_press("forward")
			await physics_frame
		Input.action_release("forward")
		if game.player.position.distance_to(point)>.7:push_error("Meal route blocked "+str(game.player.position)+" target="+str(point));return false
	for i in range(4):await physics_frame
	return true

func shot(title: String,save: bool=false) -> bool:
	paused=true
	var ok := await capture(title)
	if save:
		var path := output.path_join(title+"-save.json")
		ok=ok and SaveGame.write(game,path)==OK
		if ok:snapshots.append(path)
	paused=false
	return ok

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for i in range(10):await physics_frame
	if not guard() or game.persistence_enabled:push_error("Unsafe meal route startup");quit(1);return
	# Fixture: opening time and money for an optional purchase. Positions, actor
	# schedules, service, travel and later time all continue through the game.
	game.payroll.minute=690;game.payroll.balance=2400;game.update_daylight()
	previous=game.player.position;physics_frame.connect(measure)
	if not await walk(Vector3(12.7,0,16.5)):quit(1);return
	if not await shot("approach-stall"):quit(1);return
	for frame in range(7500):
		await physics_frame
		if game.meals.staffed():break
		if not guard():quit(1);return
	if not game.meals.staffed():push_error("Vendor did not physically arrive");quit(1);return
	if not await use(0) or not await shot("open-menu") or not choice("meal_buy_soup"):quit(1);return
	if not game.meals.orders.has("player") or game.payroll.balance!=1200:push_error("Actual purchase failed");quit(1);return
	if not await shot("queued",true):quit(1);return
	# Leave the counter while the vendor works, without cancelling the order.
	if not await walk(Vector3(13,0,18.3)):quit(1);return
	game.player.yaw=.5
	for frame in range(3000):
		await physics_frame
		if game.meals.orders.get("player",{}).get("stage")=="ready":break
	if not await shot("ready-while-away",true):quit(1);return
	if not await walk(Vector3(12.7,0,16.5)) or not await use(0) or not choice("meal_take"):quit(1);return
	if game.meals.orders.player.stage!="carrying":push_error("Actual pickup failed");quit(1);return
	# Allow the real physics/animation update after the input event before
	# freezing the world; the input handler changes ownership immediately.
	for i in range(12):await physics_frame
	var dish: Node3D=game.meals.scene.foods.player
	if not dish.visible or dish.global_position.distance_to(game.player.visual.contacts.palm("L").origin)>.15:
		push_error("Picked-up meal is not visibly held after the natural update");quit(1);return
	if not await shot("carrying",true):quit(1);return
	if not await walk(CityMeals.TABLES[4]) or not await use(1) or not choice("meal_eat"):quit(1);return
	for i in range(105):await physics_frame
	game.player.yaw=0;game.player.pitch=-.12
	for i in range(8):await physics_frame
	if not await shot("eating",true):quit(1);return
	var eaten: float=game.meals.orders.player.eaten
	if not await walk(Vector3(13.4,0,20)):quit(1);return
	for i in range(80):await physics_frame
	if game.meals.orders.player.stage!="carrying" or game.meals.orders.player.eaten>eaten+.2:push_error("Walking did not interrupt eating");quit(1);return
	if not await shot("meal-interrupted",true):quit(1);return
	if not await walk(CityMeals.TABLES[4]) or not await use(1) or not choice("meal_eat"):quit(1);return
	for i in range(1600):
		await physics_frame
		if not game.meals.orders.has("player"):break
	if game.meals.orders.has("player") or game.payroll.balance!=1200:push_error("Meal did not finish with original payment");quit(1);return
	if not await shot("finished",true):quit(1);return
	physics_frame.disconnect(measure)
	var result := {"images":pictures,"saves":snapshots,"metres":travelled,"maximum_step":maximum_step,"observed_stages":seen,"minute":game.payroll.minute,"normal_player_camera":true,"real_keyboard_controls":true,"travel_teleports":false,"fixture":{"initial_minute":690,"initial_balance_cents":2400},"background_guard":guard(),"persistence":game.persistence_enabled,"normal_game_fps":false,"independent_player_acceptance":false}
	if not guard() or game.persistence_enabled or maximum_step>.2 or travelled<20:push_error("Meal route acceptance failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("STREET_MEALS_ROUTE_OK ",JSON.stringify(result));game.queue_free();await process_frame;quit()

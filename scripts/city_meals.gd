class_name CityMeals
extends Node3D

const VENDOR := "resident_tang_ke"
const CUSTOMERS := ["resident_chen_yu","resident_xu_hang","resident_zhao_lin"]
const MENU := {"noodles":{"name":"葱油拌面","cents":800},"soup":{"name":"蔬菜汤面","cents":1200}}
const COOK_SECONDS := 8.0
const EAT_SECONDS := 24.0
const PICKUP := Vector3(12.7,0,15.7)
const TABLES := [Vector3(4,0,20),Vector3(6.2,0,20),Vector3(16,0,20),Vector3(10,0,20),Vector3(11.7,0,20)]
var game: Node3D
var orders := {}
var queue: Array[String]=[]
var served := {}
var points: Array[CityMealPoint]=[]
var scene: CityMealScene

func _ready() -> void:
	name="StreetMeals"
	for entry in [["meal_counter","路边摊 · 菜单与取餐",PICKUP],["meal_table","路边小桌 · 用餐",Vector3(11.7,0,21.1)]]:
		var point := CityMealPoint.new()
		point.stable_id=entry[0];point.title=entry[1];point.position=entry[2]
		points.append(point);add_child(point)
	scene=CityMealScene.new();scene.meals=self;add_child(scene)

static func window_at(minute: int) -> int:
	var local := posmod(minute,Payroll.DAY)
	var part := 0 if local>=690 and local<840 else 1 if local>=1020 and local<1230 else -1
	return -1 if part<0 else int(minute/Payroll.DAY)*2+part

func person(id: String) -> Node3D:
	if id=="player": return game.player
	for actor in game.population.residents+game.npcs:
		if actor.stable_id==id: return actor
	return null

func safe(actor: Node3D) -> bool:
	if actor is CityResident:
		return actor.available() and actor.fear<=0 and not game.response.resting(actor) and not game.passengers.trips.has(actor.stable_id)
	if actor is OfficeNPC:
		return actor.available() and actor.hostile<=0 and actor.reaction<=0 and actor.hit_stun<=0 and not game.social.work_following(actor) and game.office.visit_target(actor)==null and game.onboarding.npc_target(actor)==null and game.interviews.host_target(actor)==null
	return actor==game.player and actor.dead<=0 and actor.hp>0

func staffed() -> bool:
	var vendor := person(VENDOR)
	return window_at(game.payroll.minute)>=0 and safe(vendor) and game.speaker!=vendor and vendor.position.distance_to(CityPopulation.POINTS.meal_vendor)<.12 and vendor.velocity.length()<.15

func accepted_lunch(actor: OfficeNPC) -> bool:
	var outing: Dictionary=game.social.outing
	return outing.get("person")==actor.stable_id and outing.get("kind")=="lunch" and outing.get("stage") in ["walking","sharing"] and safe(actor)

func add_order(id: String,item: String) -> bool:
	var window := window_at(game.payroll.minute)
	var actor := person(id)
	if window<0 or not MENU.has(item) or orders.has(id) or orders.size()>=5 or actor==null or not safe(actor): return false
	if actor is CityResident and actor.crossing!="": return false
	var slot := 4 if id=="player" else CUSTOMERS.find(id)
	if actor is OfficeNPC:
		if not accepted_lunch(actor) or orders.values().any(func(o):return o.slot==3): return false
		slot=3
	if slot<0: return false
	var cents: int=MENU[item].cents if id=="player" else 0
	if id=="player":
		if not staffed() or game.payroll.balance<cents: return false
		game.payroll.balance-=cents
	elif served.get(id,-1)==window: return false
	orders[id]={"item":item,"stage":"queued","slot":slot,"cents":cents,"window":window,"cooked":0.0,"eaten":0.0}
	queue.append(id)
	if id!="player": served[id]=window
	game.queue_save()
	return true

func cancel(id: String,message: bool=false) -> void:
	if not orders.has(id): return
	var order: Dictionary=orders[id]
	if id=="player" and order.stage in ["queued","ready"]:
		game.payroll.balance+=int(order.cents)
		if message: game.say("尚未取餐，已退回 ¥%.2f。"%(order.cents/100.0))
	elif id=="player" and message: game.say("已收起餐具。取餐后的餐食不退款。")
	orders.erase(id);queue.erase(id)
	var actor := person(id)
	if actor is CityResident and actor.destination.begins_with("meal_") and actor.crossing=="":
		actor.route.clear();actor.state="activity" if actor.available() else actor.state;actor.activity_left=0
	if actor is OfficeNPC: actor.route_clock=0
	game.queue_save()

func time_changed() -> void:
	var window := window_at(game.payroll.minute)
	var day := int(game.payroll.minute/Payroll.DAY)
	for id in orders.keys():
		var order: Dictionary=orders[id]
		if int(order.window/2)!=day or order.stage in ["queued","ready"] and order.window!=window:
			cancel(id,id=="player")
	for id in served.keys():
		if int(served[id]/2)!=day: served.erase(id)

func target_node(order: Dictionary) -> String:
	if order.stage=="queued": return "meal_queue_"+str(int(order.slot))
	if order.stage=="ready": return "meal_pickup"
	return "meal_table_"+str(int(order.slot))

func attend(actor: CityResident,delta: float) -> bool:
	if not safe(actor) or game.speaker==actor or actor.crossing!="": return false
	var node := ""
	if actor.stable_id==VENDOR and window_at(game.payroll.minute)>=0: node="meal_vendor"
	elif orders.has(actor.stable_id): node=target_node(orders[actor.stable_id])
	if node=="":
		if actor.destination=="meal_vendor" and actor.crossing=="": actor.activity_left=0
		return false
	if actor.destination!=node: actor.plan(node)
	if not actor.route.is_empty() or actor.state in ["walking","waiting"]: actor.walk(delta)
	else:
		actor.state="activity";actor.velocity=Vector3.ZERO
		actor.activity_left=2.0
		var offset: Vector3=CityPopulation.POINTS[node]-actor.position
		offset.y=0
		# Finish the public route with a physical approach to the work/table
		# position. The public graph intentionally stops outside a body radius.
		if offset.length()>.06:
			var speed := minf(1.0,offset.length()/maxf(delta,.001))
			var motion := offset.normalized()*speed
			if not actor.test_move(actor.transform,motion*delta): actor.velocity=motion
	return true

func npc_target(actor: OfficeNPC) -> Variant:
	if not accepted_lunch(actor) or game.speaker==actor or not orders.has(actor.stable_id): return null
	if actor.position.distance_to(game.player.position)>6 and CityFootRoutes.crossing_at(actor.position)=="": return actor.position
	return CityPopulation.POINTS[target_node(orders[actor.stable_id])]

func facing(actor: Node3D) -> Variant:
	if not safe(actor) or game.speaker==actor or actor.velocity.length()>.15: return null
	if actor is CityResident and actor.stable_id==VENDOR and staffed(): return Vector3(10,0,14)
	var id: String="player" if actor==game.player else actor.stable_id
	if orders.has(id) and orders[id].stage=="eating": return TABLES[int(orders[id].slot)]+Vector3(0,0,1)
	return null

func take(id: String) -> bool:
	var actor := person(id)
	if actor==null or not safe(actor) or not orders.has(id) or orders[id].stage!="ready" or actor.position.distance_to(PICKUP)>1.1: return false
	if actor==game.player and (actor.held!=null or actor.seated or game.in_vehicle()): return false
	orders[id].stage="carrying";queue.erase(id)
	if actor is OfficeNPC: actor.route_clock=0
	game.queue_save()
	return true

func can_eat(actor: Node3D,order: Dictionary) -> bool:
	if not safe(actor) or actor.position.distance_to(TABLES[int(order.slot)])>.85 or Vector2(actor.velocity.x,actor.velocity.z).length()>.15: return false
	if actor==game.player: return actor.held==null and actor.swing<=0 and not actor.seated and not game.in_vehicle()
	return game.speaker!=actor

func _physics_process(delta: float) -> void:
	time_changed()
	var window := window_at(game.payroll.minute)
	if window>=0:
		for id in CUSTOMERS:
			var actor: CityResident=person(id)
			if safe(actor) and game.speaker!=actor and not game.commons.visits.has(id) and served.get(id,-1)!=window: add_order(id,"soup" if actor.index%2==0 else "noodles")
		for actor in game.npcs:
			# An unanswered invitation never creates an order. The companion must
			# actually reach the stall before joining its service queue.
			if accepted_lunch(actor) and actor.position.distance_to(Vector3(10,0,18))<4 and game.speaker!=actor and served.get(actor.stable_id,-1)!=window: add_order(actor.stable_id,"noodles")
	for id in orders.keys():
		var actor := person(id)
		if actor==null: cancel(id);continue
		if actor!=game.player and (not safe(actor) or actor is OfficeNPC and not accepted_lunch(actor)):
			cancel(id);continue
		var order: Dictionary=orders[id]
		if id!="player" and order.stage=="ready": take(id)
		if id!="player" and order.stage=="carrying" and can_eat(actor,order): order.stage="eating";game.queue_save()
		if order.stage=="eating":
			if can_eat(actor,order):
				order.eaten=minf(EAT_SECONDS,order.eaten+delta)
				if order.eaten>=EAT_SECONDS:
					cancel(id)
					if id=="player": game.say("吃完了。收好餐具，接下来按自己的安排走。")
			elif id=="player": order.stage="carrying";game.queue_save()
	if staffed():
		for id in queue:
			var order: Dictionary=orders[id]
			if order.stage!="queued": continue
			# Public customers place their request only after physically reaching
			# the queue. A resident still travelling must not get a remote meal.
			if id!="player" and order.cooked==0 and person(id).position.distance_to(CityPopulation.POINTS["meal_queue_"+str(int(order.slot))])>.75: continue
			order.cooked=minf(COOK_SECONDS,order.cooked+delta)
			if order.cooked>=COOK_SECONDS:
				order.stage="ready";game.queue_save()
				if id=="player": game.say("唐可：你的"+MENU[order.item].name+"好了，方便时来取。")
			break
	scene.sync()

func near_point(point: CityMealPoint) -> bool:
	return game.player.dead<=0 and not game.in_vehicle() and game.player.position.distance_to(point.position)<3 and game.can_see(game.player,point)

func open_point(point: CityMealPoint) -> void:
	if not near_point(point): return
	game.close_interaction();game.speaker=point
	var choices: Array=[]
	var order: Dictionary=orders.get("player",{})
	var text := "唐可的路边摊 · 11:30—14:00 / 17:00—20:30\n不买东西，也可以和旁边的人聊聊。"
	if point.stable_id=="meal_table":
		text="路边小桌 · 吃饭、歇脚，也可以聊聊。"
		if order.get("stage") in ["carrying","eating"]:
			text+="\n手里的"+MENU[order.item].name+"还没有吃完。走到桌前，可随时停下或继续。"
			choices.append(["在这里慢慢吃","meal_eat"])
		else: text+="\n若想吃点东西，可以到旁边摊位看看菜单。"
	elif not order.is_empty():
		match order.stage:
			"queued": text+="\n已付 ¥%.2f · 等待制作，可以先去别处。"%(order.cents/100.0);choices.append(["稍后再看","meal_leave"])
			"ready": text+="\n你的"+MENU[order.item].name+"已备好。空出双手，到取餐台前领取。";choices.append(["取餐","meal_take"])
			_: text+="\n餐食已经在你手里，旁边小桌可以用餐。"
		choices.append(["取消并退款" if order.stage in ["queued","ready"] else "放弃这份餐食","meal_cancel"])
	elif staffed():
		text+="\n可用余额 ¥%.2f"%(game.payroll.balance/100.0)
		for item in MENU: choices.append([MENU[item].name+" · ¥%.2f"%(MENU[item].cents/100.0),"meal_buy_"+item])
	else: text+="\n现在尚未开始服务，等唐可到摊位后再点餐。" if window_at(game.payroll.minute)>=0 else "\n现在已经收摊，营业时间再来。"
	choices.append(["先按自己的安排走","meal_leave"])
	game.conversation={"text":text,"choices":choices}

func answer(point: CityMealPoint,action: String) -> void:
	if not near_point(point): game.close_interaction();return
	if action.begins_with("meal_buy_") and point.stable_id=="meal_counter":
		var item := action.trim_prefix("meal_buy_")
		if add_order("player",item): game.say("已点餐，可以等待，也可以先去别处；取餐前可取消退款。")
		else: game.say("余额不足、已有订单或摊位暂时不能接单。可以不消费，照常聊天。")
	elif action=="meal_take" and point.stable_id=="meal_counter":
		if take("player"): game.say("拿好餐食，旁边小桌可以慢慢吃。")
		else: game.say("请空出双手，走近取餐台；餐食备好后再取。")
	elif action=="meal_eat" and point.stable_id=="meal_table" and orders.get("player",{}).get("stage") in ["carrying","eating"]:
		if can_eat(game.player,orders.player): orders.player.stage="eating";game.queue_save();game.say("慢慢吃。移动或拿东西会暂停，之后可以继续。")
		else: game.say("走到小桌前，空出双手，停下来再吃。")
	elif action=="meal_cancel": cancel("player",true)
	game.close_interaction()

func lunch_line(npc: OfficeNPC) -> String:
	var order: Dictionary=orders.get(npc.stable_id,{})
	if order.get("stage") in ["queued","ready"]: return "我点了份面，等会儿去取。你不用买东西，我们照样可以聊。"
	if order.get("stage") in ["carrying","eating"]: return "我拿到面了。你按自己的安排，要不要吃都没关系。"
	return "在这里歇一会儿吧，吃不吃东西都可以。"

func snapshot() -> Dictionary:
	return {"orders":orders.duplicate(true),"queue":queue.duplicate(),"served":served.duplicate()}

static func number(value: Variant,low: float,high: float,integer: bool=false) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=low and value<=high and (not integer or value==floor(value))

func valid(data: Variant,whole: Dictionary) -> bool:
	if not data is Dictionary or not data.get("orders") is Dictionary or not data.get("queue") is Array or not data.get("served") is Dictionary: return false
	if data.orders.size()>5 or data.queue.size()>5 or data.served.size()>whole.npcs.size()+CUSTOMERS.size(): return false
	var max_window := int(whole.payroll.minute/Payroll.DAY)*2+1
	var slots := {};var pending := {}
	for id in data.served:
		if not id in CUSTOMERS and not whole.npcs.has(id): return false
		if not number(data.served[id],0,max_window,true): return false
		var start := int(data.served[id]/2)*Payroll.DAY+(690 if int(data.served[id])%2==0 else 1020)
		if start>whole.payroll.minute: return false
	for id in data.orders:
		var order: Variant=data.orders[id]
		if not order is Dictionary or not MENU.has(order.get("item","")) or not order.get("stage") in ["queued","ready","carrying","eating"]: return false
		if not number(order.get("slot"),0,4,true) or not number(order.get("window"),0,max_window,true) or not number(order.get("cooked"),0,COOK_SECONDS) or not number(order.get("eaten"),0,EAT_SECONDS): return false
		if not number(order.get("cents"),0,1200,true): return false
		if order.eaten>=EAT_SECONDS or int(order.window/2)!=int(whole.payroll.minute/Payroll.DAY): return false
		var start := int(order.window/2)*Payroll.DAY+(690 if int(order.window)%2==0 else 1020)
		if start>whole.payroll.minute: return false
		if order.stage in ["queued","ready"] and order.window!=window_at(int(whole.payroll.minute)): return false
		var slot := int(order.slot)
		if slots.has(slot): return false
		slots[slot]=true
		if id=="player":
			if slot!=4 or order.cents!=MENU[order.item].cents: return false
		elif id in CUSTOMERS:
			if slot!=CUSTOMERS.find(id) or order.cents!=0: return false
			if whole.city_population.passengers.trips.has(id) or whole.city_commons.visits.has(id) or whole.city_response.cases.get(id,{}).get("phase","") in ["queued","approaching","assessing","transporting","received"]: return false
		elif whole.npcs.has(id):
			var outing: Dictionary=whole.social.outing
			if slot!=3 or order.cents!=0 or outing.get("person")!=id or outing.get("kind")!="lunch" or not outing.get("stage") in ["walking","sharing"]: return false
		else: return false
		if id!="player" and data.served.get(id,-1)!=order.window: return false
		if order.stage=="queued" and (order.cooked>=COOK_SECONDS or order.eaten!=0): return false
		if order.stage!="queued" and order.cooked!=COOK_SECONDS: return false
		if order.stage=="ready" and order.eaten!=0: return false
		if order.stage in ["queued","ready"]: pending[id]=true
	for id in data.queue:
		if not id is String or not pending.has(id): return false
		pending.erase(id)
	return pending.is_empty()

func restore(data: Dictionary) -> void:
	orders=data.get("orders",{}).duplicate(true)
	queue.assign(data.get("queue",[]));served=data.get("served",{}).duplicate(true)
	if scene: scene.sync()

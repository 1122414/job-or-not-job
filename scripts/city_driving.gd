class_name CityDriving
extends Node3D

const PARKED := [
	{"id":"car_office","title":"蓝色共享车","position":Vector3(-30,0,20.5),"yaw":PI/2,"color":Color("477d88")},
	{"id":"car_homes","title":"米色共享车","position":Vector3(88,0,58),"yaw":0.0,"color":Color("b7a48b")}
]
const TRAFFIC_STARTS := [120.0,265.0,390.0]
var game: Node3D
var cars: Array[CityCar]=[]
var active: CityCar
var guide_car := ""
var controls := {"forward":false,"back":false,"left":false,"right":false,"jump":false}
var suspended := true
var save_clock := 0.0
var look_clock := 0.0

func _ready() -> void:
	name="CityDriving"
	for entry in PARKED:
		var car := CityCar.new()
		car.stable_id=entry.id
		car.title=entry.title
		car.position=entry.position
		car.rotation.y=entry.yaw
		car.paint=entry.color
		cars.append(car)
		add_child(car)
	for i in range(TRAFFIC_STARTS.size()):
		var car := CityCar.new()
		car.stable_id="traffic_"+str(i)
		car.title="通行车辆"
		car.traffic=true
		car.paint=[Color("80574f"),Color("d0c9b7"),Color("516674")][i]
		car.route_distance=TRAFFIC_STARTS[i]
		car.transform=game.transit.vehicle_transform(car.route_distance)
		cars.append(car)
		add_child(car)
	for car in cars:
		if car.traffic: continue
		var bay := Node3D.new()
		add_child(bay)
		bay.transform=car.transform
		for x in [-1.3,1.3]: Shapes.box(bay,Vector3(0.06,0.02,5.0),Vector3(x,0.015,0),Color("e9ddbd"))

func in_vehicle() -> bool:
	return active!=null

func _unhandled_input(event: InputEvent) -> void:
	if active==null: return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: look_clock=2.0
	if not event is InputEventKey or event.echo: return
	for action in controls:
		if event.is_action(action):
			controls[action]=event.pressed
			if event.pressed: suspended=false
			get_viewport().set_input_as_handled()
			return

func suspend_controls() -> void:
	for action in controls: controls[action]=false
	suspended=true

func _physics_process(delta: float) -> void:
	for car in cars:
		if car.traffic: car.tick_traffic(delta,game.transit)
	if active:
		var throttle := float(controls.forward)-float(controls.back)
		var steering := float(controls.right)-float(controls.left)
		active.drive(delta,0.0 if suspended else throttle,0.0 if suspended else steering,suspended or controls.jump)
		look_clock=maxf(0,look_clock-delta)
		if look_clock<=0:
			game.player.yaw=lerp_angle(game.player.yaw,active.rotation.y,1-exp(-delta*3))
		sync_driver()
		if absf(active.speed)>0.1:
			save_clock+=delta
			if save_clock>=2:
				save_clock=0
				game.queue_save()

func sync_driver() -> void:
	if active==null: return
	game.player.position=active.to_global(CityCar.SEAT)
	game.player.velocity=Vector3.ZERO
	game.player.seated=true
	game.player.visual.rotation.y=active.rotation.y
	active.pose_driver(game.player.visual)

func car_for(id: String) -> CityCar:
	for car in cars:
		if car.stable_id==id: return car
	return null

func enter(car: CityCar) -> bool:
	if active or game.transit.riding or car==null or car.traffic or not car in cars or game.player.dead>0: return false
	if game.player.position.distance_to(car.position)>3.0 or not game.can_see(game.player,car): return false
	if not game.player.stand_up(): return false
	game.player.store_held()
	game.close_interaction()
	active=car
	guide_car=""
	suspend_controls()
	game.player.add_collision_exception_with(car)
	car.add_collision_exception_with(game.player)
	game.player.spring.add_excluded_object(car.get_rid())
	game.player.yaw=car.rotation.y
	game.player.pitch=-0.15
	sync_driver()
	game.queue_save()
	game.say("W 加速 · S 刹车/倒车 · A/D 转向 · 空格手刹 · 刹停后 E 下车")
	return true

func leave() -> bool:
	if active==null: return false
	if absf(active.speed)>0.35:
		game.say("请先刹停，再下车。")
		return false
	for offset in [Vector3(-1.6,0,0.15),Vector3(1.6,0,0.15)]:
		var point := active.to_global(offset)
		if not game.position_clear(game.player,point): continue
		# A clear destination on the far side of a wall is not a valid exit.
		var query := PhysicsRayQueryParameters3D.create(active.to_global(Vector3(offset.x*0.48,0.9,offset.z)),point+Vector3.UP*0.9)
		query.exclude=[active.get_rid(),game.player.get_rid()]
		query.collision_mask=3
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		active.speed=0
		detach()
		game.player.position=point
		game.queue_save()
		return true
	game.say("两侧车门都被挡住了，请换个停车位置。")
	return false

func detach() -> void:
	if active:
		active.speed=0
		active.remove_collision_exception_with(game.player)
		game.player.remove_collision_exception_with(active)
		game.player.spring.remove_excluded_object(active.get_rid())
		game.player.seated=false
	active=null
	suspend_controls()

func snapshot() -> Dictionary:
	var vehicles := {}
	for car in cars:
		vehicles[car.stable_id]={"position":SaveGame.vector(car.position),"yaw":car.rotation.y,"speed":car.speed,"steering":car.steering,"distance":car.route_distance}
	return {"schema":1,"active":active.stable_id if active else "","guide_car":guide_car,"vehicles":vehicles}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("vehicles") is Dictionary: return false
	if data.vehicles.size()!=cars.size() or not data.get("active") in ["","car_office","car_homes"] or not data.get("guide_car") in ["","car_office","car_homes"]: return false
	for car in cars:
		var entry: Variant=data.vehicles.get(car.stable_id)
		if not entry is Dictionary or not SaveGame.valid_vector(entry.get("position")): return false
		var point := SaveGame.unvector(entry.position)
		if not CityLayout.BOUNDS.has_point(Vector2(point.x,point.z)) or absf(point.y)>0.01: return false
		for key in ["yaw","speed","steering","distance"]:
			if not (entry.get(key) is float or entry.get(key) is int) or not is_finite(entry[key]): return false
		if absf(entry.yaw)>PI+0.001 or entry.speed< -CityCar.REVERSE_SPEED or entry.speed>CityCar.MAX_SPEED or absf(entry.steering)>0.58: return false
		if entry.distance<0 or entry.distance>=game.transit.curve.get_baked_length(): return false
		if car.traffic:
			if entry.speed<0 or entry.speed>7.0: return false
			var expected: Transform3D=game.transit.vehicle_transform(entry.distance)
			if point.distance_to(expected.origin)>0.02 or absf(angle_difference(entry.yaw,expected.basis.get_euler().y))>0.02: return false
		elif entry.distance!=0 or data.active!=car.stable_id and entry.speed!=0: return false
	return true

func restore(data: Dictionary) -> void:
	detach()
	guide_car=data.get("guide_car","")
	for car in cars:
		var entry: Dictionary=data.get("vehicles",{}).get(car.stable_id,{})
		if entry.is_empty():
			if car.traffic:
				car.route_distance=TRAFFIC_STARTS[int(car.stable_id.trim_prefix("traffic_"))]
				car.transform=game.transit.vehicle_transform(car.route_distance)
			else:
				for spawn in PARKED:
					if spawn.id==car.stable_id: car.position=spawn.position; car.rotation.y=spawn.yaw
			car.speed=0
			car.steering=0
		else:
			car.position=SaveGame.unvector(entry.position)
			car.rotation.y=entry.yaw
			car.speed=entry.speed
			car.steering=entry.steering
			car.route_distance=entry.distance
		car.blocked=false
		car.animate_wheels(0,false)
	active=car_for(data.get("active",""))
	if active:
		game.player.add_collision_exception_with(active)
		active.add_collision_exception_with(game.player)
		game.player.spring.add_excluded_object(active.get_rid())
		sync_driver()

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
var entry_elapsed := -1.0
var entry_start := Vector3.ZERO
var entry_side := -1.0
const ENTRY_SECONDS := 3.2

func step_entry(delta: float) -> void:
	entry_elapsed=minf(ENTRY_SECONDS,entry_elapsed+delta)
	sync_driver()
	var progress := smoothstep(1.65,2.85,entry_elapsed)
	game.player.visual.position=entry_start.lerp(game.player.visual.seated_offset,progress)
	game.player.visual.pose(1.1 if progress>0 and progress<.8 else 0,false,false,progress>.8,progress>.8,false,progress==0)
	var door := smoothstep(0,.35,entry_elapsed)*(1-smoothstep(2.8,ENTRY_SECONDS,entry_elapsed))
	if active.bus_mode: active.bus_visual.door_open=door;active.bus_visual.apply_doors()
	else: active.visual.set_door(entry_side,door)
	if entry_elapsed>=ENTRY_SECONDS:
		active.boarding=false;entry_elapsed=-1
		game.player.visual.position=game.player.visual.seated_offset
		suspend_controls();game.queue_save()
		game.say("已坐进驾驶位 · W 加速 · S 刹车/倒车 · 刹停后 E 下车")


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
	if active.boarding:
		get_viewport().set_input_as_handled();return
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
		if car.traffic and not car.taken: car.tick_traffic(delta,game.transit)
		elif car!=active: car.step_impact(delta)
	if active and active.boarding:
		step_entry(delta);return
	if active:
		var throttle := float(controls.forward)-float(controls.back)
		var steering := float(controls.right)-float(controls.left)
		active.drive(delta,0.0 if suspended else throttle,0.0 if suspended else steering,suspended or controls.jump)
		look_clock=maxf(0,look_clock-delta)
		if look_clock<=0:
			game.player.yaw=lerp_angle(game.player.yaw,active.rotation.y,1-exp(-delta*3))
		sync_driver()
		if active.bus_mode and game.passengers: game.passengers.sync_all()
		if absf(active.speed)>0.1:
			save_clock+=delta
			if save_clock>=2:
				save_clock=0
				game.queue_save()

func sync_driver() -> void:
	if active==null: return
	game.player.position=active.to_global(active.seat())
	game.player.velocity=Vector3.ZERO
	game.player.seated=true
	game.player.visual.rotation.y=active.rotation.y
	if not active.boarding: active.pose_driver(game.player.visual)

func car_for(id: String) -> CityCar:
	if id=="bus_101": return game.transit.bus
	for car in cars:
		if car.stable_id==id: return car
	return null

func enter(car: CityCar) -> bool:
	if active or car==null or not car in cars+[game.transit.bus] or game.player.dead>0: return false
	if game.transit.riding and not car.bus_mode: return false
	if game.player.position.distance_to(car.position)>(4.5 if car.bus_mode else 3.0) or not game.transit.riding and not game.can_see(game.player,car): return false
	var moving: float=game.transit.speed if car.bus_mode and not car.taken else car.speed
	if absf(moving)>2 or car.impact_velocity.length()>.35:
		game.say("车辆还在快速行驶，等它停下或低速时靠近车门。")
		return false
	if not game.transit.riding and not game.player.stand_up(): return false
	var occupied := car.driver!=null and not car.taken
	var player_start: Vector3=game.player.visual.global_position
	if occupied:
		var exit_point: Variant=null
		for offset in [Vector3(-2,0,-1),Vector3(2,0,-1),Vector3(-2,0,1),Vector3(2,0,1)]:
			var point := car.to_global(offset)
			if point.distance_to(game.player.position)>.7 and game.position_clear(game.player,point): exit_point=point;break
		if exit_point==null:
			game.say("司机两侧都没有落脚空间，无法接管车辆。")
			return false
		car.set_taken(true,exit_point)
		entry_side=signf(car.to_local(exit_point).x)
		car.displaced.begin_exit()
		car.speed=0
		if car.bus_mode:
			game.transit.current_stop=-1;game.transit.speed=0;game.transit.dwell=0
		game.career.record("vehicle_taken_"+car.stable_id,"强行接管"+car.title+"，原司机离开驾驶位；车辆不再自动沿原路线行驶。")
	if game.transit.riding: game.transit.detach()
	if not game.player.stand_up(): return false
	game.player.store_held()
	game.panels.show_page("")
	active=car
	if occupied:
		car.boarding=true;entry_elapsed=0
		entry_start=player_start-car.to_global(car.seat())
	guide_car=""
	suspend_controls()
	game.player.add_collision_exception_with(car)
	car.add_collision_exception_with(game.player)
	game.player.spring.add_excluded_object(car.get_rid())
	game.player.yaw=car.rotation.y
	game.player.pitch=-0.15
	sync_driver()
	if occupied: step_entry(0)
	game.queue_save()
	game.say("正在接管车辆 · 等司机离座后进入驾驶位" if occupied else "W 加速 · S 刹车/倒车 · A/D 转向 · 空格手刹 · 刹停后 E 下车")
	return true

func leave() -> bool:
	if active==null: return false
	if active.boarding: return false
	if absf(active.speed)>0.35 or active.impact_velocity.length()>.35:
		game.say("请先刹停，再下车。")
		return false
	for offset in [Vector3(-1.6,0,0.15),Vector3(1.6,0,0.15)]:
		if active.bus_mode: offset=Vector3(signf(offset.x)*2,0,-1.5)
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
		if active.boarding:
			active.boarding=false
			if active.displaced: active.displaced.finish_exit()
			if active.bus_mode: active.bus_visual.snap_doors(false)
			else: active.visual.set_door(entry_side,0)
		game.player.visual.position=Vector3.ZERO
		entry_elapsed=-1
		active.speed=0
		if active.bus_mode: active.bus_visual.set_night(false)
		else: active.visual.set_lighting(false,false,false)
		active.remove_collision_exception_with(game.player)
		game.player.remove_collision_exception_with(active)
		game.player.spring.remove_excluded_object(active.get_rid())
		game.player.seated=false
	active=null
	suspend_controls()

func snapshot() -> Dictionary:
	var vehicles := {}
	for car in cars+([game.transit.bus] if game.transit.bus.taken else []):
		vehicles[car.stable_id]={"position":SaveGame.vector(car.position),"yaw":car.rotation.y,"speed":car.speed,"steering":car.steering,"distance":car.route_distance,"taken":car.taken,"driver_position":SaveGame.vector(car.displaced.position) if car.displaced else [],"driver_retreat":car.displaced.retreat if car.displaced else 0.0,"impact":car.impact_state()}
	return {"schema":3,"active":active.stable_id if active else "","guide_car":guide_car,"vehicles":vehicles}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 and data.get("schema")!=2 and data.get("schema")!=3 or not data.get("vehicles") is Dictionary: return false
	var has_bus: bool=data.vehicles.has("bus_101")
	if has_bus and data.schema<2: return false
	var ids: Array=[""]
	for car in cars+([game.transit.bus] if has_bus else []): ids.append(car.stable_id)
	if data.vehicles.size()!=ids.size()-1 or not data.get("active") in ids or not data.get("guide_car") in ["","car_office","car_homes"]: return false
	for car in cars+([game.transit.bus] if has_bus else []):
		var entry: Variant=data.vehicles.get(car.stable_id)
		if not entry is Dictionary or not SaveGame.valid_vector(entry.get("position")): return false
		if data.schema>=3 and not CityCar.valid_impact(entry.get("impact")): return false
		var damaged: bool=data.schema>=3 and entry.get("impact",{}).get("crashed",false)
		var taken: Variant=entry.get("taken",false)
		if not taken is bool or car.bus_mode and not taken or taken and not car.traffic and not car.bus_mode: return false
		if data.schema>=2:
			if not entry.get("taken") is bool or not CityPopulation.number(entry.get("driver_retreat"),0,3): return false
			if taken:
				if not SaveGame.valid_vector(entry.get("driver_position")): return false
				var driver_at := SaveGame.unvector(entry.driver_position)
				if absf(driver_at.y)>.1 or not CityLayout.BOUNDS.has_point(Vector2(driver_at.x,driver_at.z)): return false
			elif entry.get("driver_position")!=[] or entry.driver_retreat!=0: return false
		var point := SaveGame.unvector(entry.position)
		if not CityLayout.BOUNDS.has_point(Vector2(point.x,point.z)) or absf(point.y)>0.01: return false
		for key in ["yaw","speed","steering","distance"]:
			if not (entry.get(key) is float or entry.get(key) is int) or not is_finite(entry[key]): return false
		if absf(entry.yaw)>PI+0.001 or entry.speed< -CityCar.REVERSE_SPEED or entry.speed>CityCar.MAX_SPEED or absf(entry.steering)>0.58: return false
		if entry.distance<0 or entry.distance>=game.transit.curve.get_baked_length(): return false
		if car.traffic and not taken and not damaged:
			if data.active==car.stable_id: return false
			if entry.speed<0 or entry.speed>7.0: return false
			var expected: Transform3D=game.transit.vehicle_transform(entry.distance)
			if point.distance_to(expected.origin)>0.02 or absf(angle_difference(entry.yaw,expected.basis.get_euler().y))>0.02: return false
		elif (car.traffic and not taken and (data.active==car.stable_id or entry.speed!=0)): return false
		elif (not car.traffic and entry.distance!=0) or data.active!=car.stable_id and entry.speed!=0: return false
	return true

func restore(data: Dictionary) -> void:
	detach()
	guide_car=data.get("guide_car","")
	for car in cars+[game.transit.bus]:
		var entry: Dictionary=data.get("vehicles",{}).get(car.stable_id,{})
		var taken: bool=entry.get("taken",false)
		if not car.bus_mode or not entry.is_empty(): car.restore_impact(entry.get("impact",{}) if data.get("schema",1)>=3 else {})
		car.set_taken(taken,SaveGame.unvector(entry.get("driver_position",[0,0,0])) if taken else Vector3.ZERO,float(entry.get("driver_retreat",0)))
		if car.bus_mode and entry.is_empty():
			game.transit.sync_vehicle()
			continue
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

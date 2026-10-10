class_name CityTransit
extends Node3D

const MAX_SPEED := 8.0
const ACCELERATION := 2.4
const DWELL := 8.0
var game: Node3D
var bus: CityCar
var curve := CityLayout.route_curve()
var stop_offsets: Array[float]=[]
var distance := 0.0
var speed := 0.0
var dwell := DWELL
var current_stop := 0
var next_stop := 1
var riding := false
var requested := false
var blocked := false
var selected_stop := 0
var waypoint := ""
var visited: Array[String]=[]
var sign: Label3D
var visual: CityBusVisual

func _ready() -> void:
	name="CityTransit"
	for stop in CityLayout.STOPS: stop_offsets.append(curve.get_closest_offset(stop.point))
	bus=CityCar.new();bus.bus_mode=true;bus.stable_id="bus_101";bus.title="101 公交车"
	bus.name="Bus101"
	bus.collision_layer=1
	bus.collision_mask=3
	add_child(bus)
	# Keep the established passenger support plane and external physics contract.
	var floor := Shapes.box(bus,Vector3(2.5,.16,7),Vector3(0,.32,0),Color("4e5758"))
	floor.name="CabinFloor"
	visual=bus.bus_visual
	sign=Shapes.label(bus,"101  城区环线",Vector3(0,2.57,-3.409),28)
	sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	sign.pixel_size=0.005
	sign.rotation.y=PI
	sync_vehicle()

func _physics_process(delta: float) -> void:
	tick(delta)
	var region := CityLayout.region_at(game.player.position)
	if not visited.has(region):
		visited.append(region)
		game.queue_save()

func forward_at(offset: float) -> Vector3:
	var length := curve.get_baked_length()
	return (curve.sample_baked(fposmod(offset+0.25,length))-curve.sample_baked(fposmod(offset-0.25,length))).normalized()

func vehicle_transform(offset: float) -> Transform3D:
	var direction := forward_at(offset)
	return Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),curve.sample_baked(offset))

func sync_vehicle() -> void:
	if bus.taken or bus.crashed:
		sync_passenger()
		if game.passengers: game.passengers.sync_all()
		return
	bus.transform=vehicle_transform(distance)
	var before := vehicle_transform(distance-.5).basis.get_euler().y
	var after := vehicle_transform(distance+.5).basis.get_euler().y
	visual.set_motion(distance,clampf(atan(-angle_difference(before,after)*4.5),-.58,.58))
	sign.text="101  "+CityLayout.STOPS[next_stop].title.split(" · ")[0]
	sync_passenger()
	if game.passengers: game.passengers.sync_all()

func sync_passenger() -> void:
	if not riding: return
	game.player.position=bus.to_global(Vector3(0.65,0.40,-0.4))
	game.player.velocity=Vector3.ZERO
	game.player.seated=true
	game.player.visual.rotation.y=bus.rotation.y

func tick(delta: float) -> void:
	if delta<=0: return
	if bus.crashed and not bus.taken:
		bus.step_impact(delta);sync_vehicle();return
	if bus.taken:
		if game.driving.active!=bus: bus.step_impact(delta)
		sync_passenger()
		if game.passengers: game.passengers.sync_all()
		return
	blocked=false
	if current_stop>=0:
		if riding and requested or game.passengers and game.passengers.holds_departure():
			visual.step_doors(delta,true)
			return
		dwell=maxf(0,dwell-delta)
		visual.step_doors(delta,dwell>0)
		if dwell>0 or not visual.doors_closed(): return
		current_stop=-1
	var length := curve.get_baked_length()
	var remaining := fposmod(stop_offsets[next_stop]-distance,length)
	var desired := minf(MAX_SPEED,sqrt(2*ACCELERATION*remaining))
	if game.population: desired=minf(desired,game.population.speed_limit(distance,ACCELERATION,3.6))
	# Brake for existing traffic before contact. A sudden intrusion inside the
	# stopping distance still reaches the shared impact response below.
	var ahead := maxf(3.0,speed*speed/(2*ACCELERATION)+2.0)
	var probe := bus.transform
	var obstacle_ahead := false
	for i in range(1,ceili(ahead)+1):
		var sample := vehicle_transform(fposmod(distance+minf(i,ahead),length))
		if bus.test_move(probe,sample.origin-probe.origin):
			obstacle_ahead=true
			desired=minf(desired,sqrt(2*ACCELERATION*maxf(0,i-1.8)));break
		probe=sample
	speed=move_toward(speed,desired,ACCELERATION*delta)
	blocked=obstacle_ahead and is_zero_approx(speed)
	var advance := minf(remaining,speed*delta)
	var proposed := fposmod(distance+advance,length)
	var target := vehicle_transform(proposed)
	# Swept physical collision checks both the current and next orientation on bends.
	var motion := target.origin-bus.position
	var turned := Transform3D(target.basis,bus.position)
	var contact := KinematicCollision3D.new()
	if bus.test_move(bus.transform,motion,contact) or bus.test_move(turned,motion,contact):
		blocked=true
		if not bus.collide_vehicle(contact): speed=0
		return
	distance=proposed
	if remaining-advance<0.015:
		distance=stop_offsets[next_stop]
		current_stop=next_stop
		next_stop=(next_stop+1)%CityLayout.STOPS.size()
		dwell=DWELL
		speed=0
		if riding: game.say("到站："+CityLayout.STOPS[current_stop].title+" · E 查看下车选项")
		game.queue_save()
	sync_vehicle()

func open_stop(index: int) -> void:
	selected_stop=index
	game.panels.show_page("transit")

func at_platform(index: int) -> bool:
	return game.player.dead<=0 and game.player.position.distance_to(CityLayout.STOPS[index].platform)<3.1

func board(index: int) -> bool:
	if bus.taken or bus.crashed: return false
	if game.in_vehicle() or not at_platform(index) or current_stop!=index: return false
	if not game.player.stand_up(): return false
	game.player.store_held()
	game.player.add_collision_exception_with(bus)
	game.player.spring.add_excluded_object(bus.get_rid())
	riding=true
	requested=false
	dwell=maxf(3,dwell)
	game.panels.show_page("")
	sync_passenger()
	game.queue_save()
	game.say("已乘坐 101 · E 请求下一站下车，M 查看城区")
	return true

func board_vehicle() -> bool:
	if not bus.taken and not bus.crashed:
		return board(current_stop) if current_stop>=0 else false
	if game.in_vehicle() or game.player.dead>0 or absf(bus.speed)>.35 or bus.impact_velocity.length()>.35 or game.player.position.distance_to(bus.position)>4.5 or not game.can_see(game.player,bus): return false
	if not game.player.stand_up(): return false
	game.player.store_held()
	game.player.add_collision_exception_with(bus)
	game.player.spring.add_excluded_object(bus.get_rid())
	riding=true;requested=false
	game.panels.show_page("")
	sync_passenger();game.queue_save()
	return true

func manual_exits() -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for z in [-2.2,-1.1,0.0,1.1,2.2]: result.append(bus.to_global(Vector3(2,0,z)))
	return result

func manual_exit_clear(actor: CharacterBody3D,point: Vector3) -> bool:
	if not game.position_clear(actor,point): return false
	var ray := PhysicsRayQueryParameters3D.create(bus.position+Vector3.UP*.9,point+Vector3.UP*.9)
	ray.collision_mask=3
	var excluded: Array[RID]=[bus.get_rid(),actor.get_rid(),game.player.get_rid()]
	for person in game.population.residents:
		if game.passengers.aboard(person): excluded.append(person.get_rid())
	ray.exclude=excluded
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func leave() -> bool:
	if not riding or (current_stop<0 and not bus.taken and not bus.crashed): return false
	var point: Vector3=CityLayout.STOPS[maxi(0,current_stop)].platform
	if bus.taken or bus.crashed:
		if bus.impact_velocity.length()>.35: return false
		if absf(bus.speed)>.35: return false
		var found := false
		for candidate in manual_exits():
			if manual_exit_clear(game.player,candidate): point=candidate;found=true;break
		if not found: return false
	if not game.position_clear(game.player,point):
		game.say("站台被挡住了，清空落脚位置后再下车。")
		return false
	detach()
	game.player.position=point
	game.panels.show_page("")
	game.queue_save()
	return true

func detach() -> void:
	if riding:
		game.player.remove_collision_exception_with(bus)
		game.player.spring.remove_excluded_object(bus.get_rid())
		game.player.seated=false
	riding=false
	requested=false

func request_stop() -> void:
	if not riding: return
	requested=true
	game.panels.show_page("")
	game.say("已请求下车 · 到站后会等你主动下车")
	game.queue_save()

func wait_for_bus(index: int) -> bool:
	if bus.taken or bus.crashed:
		game.say("101已离开运营路线。可在实际车辆旁乘坐或接管，不能跳过等车召回。")
		return false
	if riding or not at_platform(index) or blocked: return false
	if current_stop==index: return true
	# The explicit time skip moves only the scheduled bus and advances the shared clock.
	var seconds := fposmod(stop_offsets[index]-distance,curve.get_baked_length())/MAX_SPEED
	var stop := next_stop
	while stop!=index:
		seconds+=DWELL
		stop=(stop+1)%CityLayout.STOPS.size()
	seconds+=dwell if current_stop>=0 else 0.0
	var stops: Array[int]=[]
	if current_stop>=0: stops.append(current_stop)
	var passing := next_stop
	while passing!=index:
		stops.append(passing);passing=(passing+1)%4
	stops.append(index)
	var exits: Variant=game.passengers.skipped_exits(stops) if game.passengers else {}
	if exits==null:
		game.say("途中站台被挡住了，等乘客能安全下车后再跳过等车。")
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=bus.get_child(0).shape
	query.collision_mask=3
	var excluded: Array[RID]=[bus.get_rid()]
	if game.passengers:
		for person in game.population.residents:
			if game.passengers.aboard(person): excluded.append(person.get_rid())
	query.exclude=excluded
	for passed in stops:
		query.transform=vehicle_transform(stop_offsets[passed])*Transform3D(Basis.IDENTITY,Vector3(0,1.6,0))
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			game.say("站点车道被挡住了，暂时无法跳过等车。")
			return false
	game.advance_time(seconds*Payroll.GAME_MINUTES_PER_SECOND)
	for passed in stops:
		distance=stop_offsets[passed];current_stop=passed;next_stop=(passed+1)%4
		dwell=DWELL;speed=0;sync_vehicle()
		for id in exits:
			if exits[id].stop==passed:
				var person: CityResident=game.response.person_for(id)
				game.passengers.finish_exit(person,game.passengers.trips[id],exits[id].point)
	game.queue_save()
	game.panels.view.refresh()
	return true

func snapshot() -> Dictionary:
	return {"route":"101-v1","distance":distance,"speed":speed,"dwell":dwell,"current_stop":current_stop,"next_stop":next_stop,"riding":riding,"requested":requested,"visited":visited.duplicate(),"waypoint":waypoint,"manual":{"position":SaveGame.vector(bus.position),"yaw":bus.rotation.y} if bus.taken else {},"collision":{"position":SaveGame.vector(bus.position),"yaw":bus.rotation.y,"impact":bus.impact_state()} if bus.crashed and not bus.taken else {}}

func stored_transform(data: Dictionary) -> Transform3D:
	var manual: Dictionary=data.get("manual",{})
	if manual.is_empty(): manual=data.get("collision",{})
	return Transform3D(Basis(Vector3.UP,manual.yaw),SaveGame.unvector(manual.position)) if not manual.is_empty() else vehicle_transform(data.distance)

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("route")!="101-v1": return false
	for key in ["distance","speed","dwell","current_stop","next_stop"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(data[key]): return false
	if data.distance<0 or data.distance>=curve.get_baked_length() or data.speed<0 or data.speed>MAX_SPEED or data.dwell<0 or data.dwell>DWELL: return false
	if data.current_stop!=int(data.current_stop) or data.next_stop!=int(data.next_stop): return false
	if data.current_stop< -1 or data.current_stop>=4 or data.next_stop<0 or data.next_stop>=4: return false
	if not data.get("riding") is bool or not data.get("requested") is bool or data.requested and not data.riding: return false
	if not data.get("visited") is Array or data.visited.size()>4: return false
	var ids: Array=[]
	for region in CityLayout.REGIONS: ids.append(region.id)
	for id in data.visited:
		if not id in ids or data.visited.count(id)!=1: return false
	if not data.get("waypoint") is String or not data.waypoint in ids+[""]: return false
	var crash: Variant=data.get("collision",{})
	if not crash is Dictionary: return false
	var manual: Variant=data.get("manual",{})
	if not manual is Dictionary: return false
	if not crash.is_empty() and (not CityCar.valid_impact(crash.get("impact")) or not crash.impact.crashed or not manual.is_empty()): return false
	if manual.is_empty(): manual=crash
	if not manual.is_empty():
		if not SaveGame.valid_vector(manual.get("position")) or not CityPopulation.number(manual.get("yaw"),-PI-.001,PI+.001): return false
		var at := SaveGame.unvector(manual.position)
		if absf(at.y)>.01 or not CityLayout.BOUNDS.has_point(Vector2(at.x,at.z)): return false
		if data.current_stop!=-1 or data.speed!=0 or data.dwell!=0: return false
	if data.current_stop>=0:
		if absf(data.distance-stop_offsets[int(data.current_stop)])>0.01 or data.next_stop!=(int(data.current_stop)+1)%4 or data.speed!=0: return false
	else:
		var previous := (int(data.next_stop)+3)%4
		var leg_length := fposmod(stop_offsets[int(data.next_stop)]-stop_offsets[previous],curve.get_baked_length())
		if fposmod(data.distance-stop_offsets[previous],curve.get_baked_length())>leg_length or data.dwell!=0: return false
	return true

func restore(data: Dictionary) -> void:
	detach()
	bus.taken=not data.get("manual",{}).is_empty()
	bus.restore_impact(data.get("collision",{}).get("impact",{}))
	distance=float(data.get("distance",0))
	speed=float(data.get("speed",0))
	dwell=float(data.get("dwell",DWELL))
	current_stop=int(data.get("current_stop",0))
	next_stop=int(data.get("next_stop",1))
	waypoint=data.get("waypoint","")
	visited.assign(data.get("visited",[]))
	blocked=false
	riding=data.get("riding",false) and game.player.hp>0
	requested=data.get("requested",false) and riding
	if riding:
		game.player.add_collision_exception_with(bus)
		game.player.spring.add_excluded_object(bus.get_rid())
	visual.snap_doors(current_stop>=0)
	if bus.taken or bus.crashed: bus.transform=stored_transform(data)
	sync_vehicle()

func station_for(id: String) -> WorkStation:
	for station in game.stations:
		if station.stable_id=="bus_"+id: return station
	return null

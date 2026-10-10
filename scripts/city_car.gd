class_name CityCar
extends CharacterBody3D

const MAX_SPEED := 17.0
const REVERSE_SPEED := 5.0
const ACCELERATION := 4.0
const BRAKING := 9.0
const WHEELBASE := 2.65
const SEAT := Vector3(-0.43,0.13,0.10)
var stable_id := ""
var title := "城区共享车"
var traffic := false
var taken := false
var bus_mode := false
var bus_visual: CityBusVisual
var displaced: VehicleDriver
var driven_distance := 0.0
var paint := Color("477d88")
var speed := 0.0
var steering := 0.0
var route_distance := 0.0
var blocked := false
var wheels: Array[Node3D]=[]
var front_wheels: Array[Node3D]=[]
var brake_lights: Array[MeshInstance3D]=[]
var driver: HumanVisual
var steering_wheel: MeshInstance3D
var visual: CityCarVisual
var braking_now := false
# Residual planar motion is independent of the engine and of the route controller.
var impact_velocity := Vector3.ZERO
var impact_spin := 0.0
var crashed := false
var boarding := false

func mass_kg() -> float:
	return 8000.0 if bus_mode else 1200.0

func inertia() -> float:
	return mass_kg()*(55.76 if bus_mode else 21.52)/12.0

func motion_velocity() -> Vector3:
	var forward_speed := speed
	if bus_mode and not taken and not crashed: forward_speed=get_parent().game.transit.speed
	return -basis.z*forward_speed+impact_velocity

func receive_impact(motion: Vector3,spin: float) -> void:
	impact_velocity=motion.limit_length(25);impact_velocity.y=0
	impact_spin=clampf(spin,-1.8,1.8)
	speed=0;crashed=true
	if bus_mode and not taken:
		var transit: CityTransit=get_parent().game.transit
		transit.speed=0;transit.dwell=0;transit.current_stop=-1
	get_parent().game.queue_save()

func collide_vehicle(collision: KinematicCollision3D) -> bool:
	var other := collision.get_collider() as CityCar
	if other==null or other.boarding or boarding: return false
	# A same-frame restore can leave a contact at the other body's previous location.
	# Keep the normal sweep stop, but never turn that stale contact into crash state.
	var size: Vector3=other.get_child(0).shape.size
	var offset := collision.get_position()-other.global_position
	var reach := Vector2(size.x,size.z).length()*.5+other.motion_velocity().length()*.1+.1
	if Vector2(offset.x,offset.z).length()>reach: return false
	var normal := collision.get_normal();normal.y=0;normal=normal.normalized()
	var relative := motion_velocity()-other.motion_velocity()
	var closing := -relative.dot(normal)
	if closing<.15: return false
	var lever := collision.get_position()-global_position;lever.y=0
	var other_lever := collision.get_position()-other.global_position;other_lever.y=0
	var torque := lever.cross(normal).y
	var other_torque := other_lever.cross(normal).y
	var impulse := 1.25*closing/(1/mass_kg()+1/other.mass_kg()+torque*torque/inertia()+other_torque*other_torque/other.inertia())
	var before := motion_velocity();var other_before := other.motion_velocity()
	receive_impact(before+normal*impulse/mass_kg(),impact_spin+torque*impulse/inertia())
	other.receive_impact(other_before-normal*impulse/other.mass_kg(),other.impact_spin-other_torque*impulse/other.inertia())
	var city: Node3D=get_parent().game
	if city.driving.active==self or city.driving.active==other:
		if city.shake_enabled: city.player.camera.h_offset=minf(.16,closing*.012)
	return true

func step_impact(delta: float) -> void:
	var dt := minf(delta,.1)
	if boarding: return
	if impact_velocity.length_squared()<.0001 and absf(impact_spin)<.001: return
	update_body_exceptions()
	var before := impact_velocity
	impact_velocity=impact_velocity.move_toward(Vector3.ZERO,3.5*dt)
	var collision := move_and_collide((before+impact_velocity)*.5*dt)
	if collision and not collide_vehicle(collision):
		impact_velocity=impact_velocity.slide(collision.get_normal())*.65
		impact_spin*=.5
	var angle := impact_spin*dt
	for i in range(maxi(1,ceili(absf(angle)/.015))):
		var next := rotation.y+angle/maxi(1,ceili(absf(angle)/.015))
		if not rotation_clear(next): impact_spin=0;break
		rotation.y=wrapf(next,-PI,PI)
	impact_spin=move_toward(impact_spin,0,1.6*dt)
	position.y=0

func impact_state() -> Dictionary:
	return {"crashed":crashed,"velocity":SaveGame.vector(impact_velocity),"spin":impact_spin}

static func valid_impact(data: Variant) -> bool:
	if not data is Dictionary or not data.get("crashed") is bool or not SaveGame.valid_vector(data.get("velocity")) or not CityPopulation.number(data.get("spin"),-1.8,1.8): return false
	var motion := SaveGame.unvector(data.velocity)
	return absf(motion.y)<.001 and motion.length()<=25.001 and (data.crashed or motion==Vector3.ZERO and data.spin==0)

func restore_impact(data: Dictionary) -> void:
	crashed=data.get("crashed",false)
	impact_velocity=SaveGame.unvector(data.get("velocity",[0,0,0]))
	impact_spin=float(data.get("spin",0));boarding=false


func update_body_exceptions() -> void:
	var people: Array=[]
	people.append_array(get_parent().game.population.residents)
	for car in get_parent().game.driving.cars+[get_parent().game.transit.bus]:
		if is_instance_valid(car.displaced): people.append(car.displaced)
	for person in people:
		if not person.available(): add_collision_exception_with(person)
		elif person in get_collision_exceptions(): remove_collision_exception_with(person)

func _ready() -> void:
	name=stable_id
	collision_mask=3
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	if bus_mode:
		Shapes.collider(self,Vector3(2.6,2.8,7),Vector3(0,1.6,0))
		bus_visual=CityBusVisual.new();add_child(bus_visual)
		driver=bus_visual.driver
		return
	Shapes.collider(self,Vector3(1.86,1.3,4.25),Vector3(0,0.86,0))
	visual=CityCarVisual.new();visual.car=self;add_child(visual)
	wheels=visual.wheels;front_wheels=visual.front_axles
	steering_wheel=visual.steering_wheel;driver=visual.driver
	brake_lights.append(visual.taillights)
	if driver:pose_driver(driver)

func update_lights() -> void:
	var city: Node3D=get_parent().game
	var minute: int=int(city.presentation_minute())%Payroll.DAY
	if bus_mode: bus_visual.set_night(minute<360 or minute>=1080)
	else: visual.set_lighting(minute<360 or minute>=1080,traffic and not taken or city.driving.active==self,braking_now)

func animate_wheels(delta: float, braking: bool) -> void:
	if bus_mode:
		driven_distance+=speed*delta
		bus_visual.set_motion(driven_distance,steering)
		bus_visual.step_doors(delta,false)
		update_lights()
		return
	for tire in wheels:tire.rotation.x=fposmod(tire.rotation.x-speed*delta/.34,TAU)
	for pivot in front_wheels:pivot.rotation.y=-steering
	steering_wheel.basis=Basis(Vector3.RIGHT,1.05)*Basis(Vector3.UP,-steering*2.5)
	braking_now=braking;update_lights()
	if driver and not taken:pose_driver(driver)

func palm_target(side: String) -> Transform3D:
	if bus_mode: return bus_visual.palm_target(side)
	var sign_value := -1.0 if side=="L" else 1.0
	var normal := Vector3(-sign_value,0,0)
	var along := Vector3(0,0,-1)
	return steering_wheel.global_transform*Transform3D(Basis(along.cross(normal),along,normal),Vector3(sign_value*.205,0,0))

func pose_driver(human: HumanVisual) -> void:
	for side in ["L","R"]:
		human.contacts.reach(side,palm_target(side))
		human.contacts.fingers(side,.72)

func drive(delta: float, throttle: float, turn: float, handbrake: bool) -> void:
	if boarding: return
	step_impact(delta)
	update_body_exceptions()
	# A planar bicycle controller for the current flat district. Sweeps cover travel;
	# rotation is also swept in small steps so a rear corner cannot rotate through a wall.
	var dt := minf(delta,0.1)
	var old_speed := speed
	var reversing := throttle*speed<0
	var target := throttle*(MAX_SPEED if throttle>=0 else REVERSE_SPEED)
	var acceleration := BRAKING if handbrake or reversing else 1.4 if is_zero_approx(throttle) else ACCELERATION
	speed=move_toward(speed,0.0 if handbrake else target,acceleration*dt)
	var steer_limit := lerpf(0.58,0.25,clampf(absf(speed)/MAX_SPEED,0,1))
	steering=move_toward(steering,turn*steer_limit,2.4*dt)
	var turn_angle := -(old_speed+speed)*0.5/(4.5 if bus_mode else WHEELBASE)*tan(steering)*dt
	var travel := (old_speed+speed)*0.5*dt
	blocked=false
	var substeps := maxi(1,ceili(absf(turn_angle)/0.015))
	for i in range(substeps):
		var old_rotation := rotation.y
		var next_rotation := old_rotation+turn_angle/substeps
		# A blocked turn must not veto translation away from an existing contact.
		if not is_zero_approx(turn_angle):
			if rotation_clear(next_rotation): rotation.y=next_rotation
			else: blocked=true
		var motion := -basis.z*travel/substeps
		var collision := move_and_collide(motion)
		if collision:
			var actor := collision.get_collider()
			if (actor is CityResident or actor is VehicleDriver) and (not traffic or taken) and absf(old_speed)>1.5:
				actor.vehicle_hit(-basis.z*signf(old_speed),absf(old_speed))
				add_collision_exception_with(actor)
				speed*=.9
				collision=move_and_collide(collision.get_remainder())
				if not collision: continue
			blocked=true
			if not collide_vehicle(collision): speed=0
			break
	rotation.y=wrapf(rotation.y,-PI,PI)
	position.y=0.0
	animate_wheels(dt,handbrake or reversing or blocked)

func rotation_clear(yaw: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=get_child(0).shape
	query.transform=Transform3D(Basis(Vector3.UP,yaw),position+Vector3(0,1.6 if bus_mode else .86,0))
	query.collision_mask=3
	query.exclude=[get_rid()]
	var exceptions := query.exclude
	for object in get_collision_exceptions(): exceptions.append(object.get_rid())
	query.exclude=exceptions
	for hit in get_world_3d().direct_space_state.intersect_shape(query,16):
		if (hit.collider is CityResident or hit.collider is VehicleDriver) and (not traffic or taken) and absf(speed)>1.5:
			hit.collider.vehicle_hit(-basis.z*signf(speed),absf(speed))
			add_collision_exception_with(hit.collider)
		else: return false
	return true

func seat() -> Vector3:
	return CityBusVisual.DRIVER_SEAT if bus_mode else SEAT

func set_taken(value: bool,at: Vector3=Vector3.ZERO,retreat_time: float=3.0) -> void:
	taken=value
	if driver: driver.visible=not taken
	if displaced:
		for car in get_parent().game.driving.cars+[get_parent().game.transit.bus]:
			car.remove_collision_exception_with(displaced)
		displaced.queue_free();displaced=null
	if taken and driver:
		displaced=VehicleDriver.new();displaced.vehicle=self
		get_parent().game.driving.add_child(displaced)
		displaced.position=at;displaced.retreat=retreat_time

func tick_traffic(delta: float, transit: CityTransit) -> void:
	if crashed:
		step_impact(delta);animate_wheels(delta,true);return
	var dt := minf(delta,0.1)
	var length := transit.curve.get_baked_length()
	var desired := 7.0
	var city: Node3D=get_parent().game
	if city.population: desired=minf(desired,city.population.speed_limit(route_distance,BRAKING,2.2))
	# Preview the curved path, rather than a tangent that misses a stopped bus on a bend.
	var ahead := maxf(3.0,speed*speed/(2*BRAKING)+2.0)
	var probe := transform
	var result := KinematicCollision3D.new()
	for i in range(1,ceili(ahead)+1):
		var target := transit.vehicle_transform(fposmod(route_distance+minf(i,ahead),length))
		if test_move(probe,target.origin-probe.origin,result):
			desired=minf(desired,sqrt(2*BRAKING*maxf(0,i-1.8)))
			break
		probe=target
	speed=move_toward(speed,desired,(BRAKING if desired<speed else 2.5)*dt)
	var advance := speed*dt
	var next_distance := fposmod(route_distance+advance,length)
	var next := transit.vehicle_transform(next_distance)
	var motion := next.origin-position
	steering=clampf(atan(-angle_difference(rotation.y,next.basis.get_euler().y)*WHEELBASE/maxf(advance,0.001)),-0.58,0.58)
	var contact := KinematicCollision3D.new()
	blocked=test_move(transform,motion,contact) or test_move(Transform3D(next.basis,position),motion,contact)
	if blocked:
		if not collide_vehicle(contact): speed=0
	else:
		route_distance=next_distance
		transform=next
	animate_wheels(dt,blocked or desired<6.5)

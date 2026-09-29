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

func _ready() -> void:
	name=stable_id
	collision_mask=3
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	Shapes.collider(self,Vector3(1.86,1.3,4.25),Vector3(0,0.86,0))
	var body := Shapes.box(self,Vector3(1.8,0.50,4.15),Vector3(0,0.64,0),paint)
	body.material_override.roughness=0.3
	body.material_override.metallic=0.45
	Shapes.box(self,Vector3(1.72,0.12,1.22),Vector3(0,0.90,-1.45),paint)
	Shapes.box(self,Vector3(1.72,0.12,0.75),Vector3(0,0.90,1.67),paint)
	Shapes.box(self,Vector3(1.54,0.09,1.65),Vector3(0,1.61,0.14),paint)
	for x in [-0.76,0.76]:
		for z in [-0.72,0.16,0.96]: Shapes.box(self,Vector3(0.065,0.72,0.07),Vector3(x,1.23,z),paint)
		Shapes.box(self,Vector3(0.08,0.05,0.26),Vector3(x*1.21,0.96,0.48),Color("aeb8ba"))
		Shapes.box(self,Vector3(0.23,0.14,0.28),Vector3(x*1.32,1.14,-0.7),paint)
	var glass := Shapes.material(Color(0.30,0.47,0.52,0.28))
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	glass.roughness=0.12
	for x in [-0.76,0.76]:
		var window := Shapes.box(self,Vector3(0.015,0.58,1.57),Vector3(x,1.25,0.14),Color.WHITE)
		window.material_override=glass
	for z in [-0.78,1.00]:
		var window := Shapes.box(self,Vector3(1.45,0.65,0.025),Vector3(0,1.24,z),Color.WHITE)
		window.rotation.x=-0.20 if z<0 else 0.20
		window.material_override=glass
	for x in [-0.43,0.43]:
		Shapes.box(self,Vector3(0.64,0.16,0.60),Vector3(x,0.65,0.10),Color("303c42"))
		Shapes.box(self,Vector3(0.64,0.64,0.14),Vector3(x,0.95,0.40),Color("303c42"))
	Shapes.box(self,Vector3(1.5,0.22,0.34),Vector3(0,0.99,-0.64),Color("303c42"))
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius=0.16
	torus.outer_radius=0.20
	wheel.mesh=torus
	wheel.material_override=Shapes.material(Color("273137"))
	add_child(wheel)
	wheel.position=Vector3(-0.43,1.05,-0.22)
	wheel.rotation.x=1.05
	steering_wheel=wheel
	for x in [-0.88,0.88]:
		for z in [-1.38,1.27]:
			var pivot := Node3D.new()
			add_child(pivot)
			pivot.position=Vector3(x,0.34,z)
			if z<0: front_wheels.append(pivot)
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=0.34
			cylinder.bottom_radius=0.34
			cylinder.height=0.22
			cylinder.radial_segments=24
			tire.mesh=cylinder
			tire.material_override=Shapes.material(Color("242d31"))
			pivot.add_child(tire)
			tire.rotation.z=PI/2
			wheels.append(tire)
	for z in [-2.09,2.09]:
		Shapes.box(self,Vector3(1.72,0.12,0.08),Vector3(0,0.41,z),Color("333e43"))
		for x in [-0.65,0.65]:
			var light := Shapes.box(self,Vector3(0.32,0.16,0.06),Vector3(x,0.80,z),Color("e1d8b6") if z<0 else Color("904b48"))
			if z>0: brake_lights.append(light)
	if traffic:
		driver=HumanVisual.new()
		driver.outfit="casual"
		add_child(driver)
		driver.position=SEAT+driver.seated_offset
		driver.pose(0,false,false,true)
		driver.animation.advance(0.4)
		driver.animation.pause()
		pose_driver(driver)

func animate_wheels(delta: float, braking: bool) -> void:
	for tire in wheels: tire.rotation.y+=speed*delta/0.34
	for pivot in front_wheels: pivot.rotation.y=-steering
	steering_wheel.basis=Basis(Vector3.RIGHT,1.05)*Basis(Vector3.UP,-steering*2.5)
	for light in brake_lights: light.material_override.albedo_color=Color("ef5750") if braking else Color("904b48")
	if driver: pose_driver(driver)

func palm_target(side: String) -> Transform3D:
	var sign_value := -1.0 if side=="L" else 1.0
	var normal := Vector3(-sign_value,0,0)
	var along := Vector3(0,0,-1)
	return steering_wheel.global_transform*Transform3D(Basis(along.cross(normal),along,normal),Vector3(sign_value*.205,0,0))

func pose_driver(human: HumanVisual) -> void:
	for side in ["L","R"]:
		human.contacts.reach(side,palm_target(side))
		human.contacts.fingers(side,.72)

func drive(delta: float, throttle: float, turn: float, handbrake: bool) -> void:
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
	var turn_angle := -(old_speed+speed)*0.5/WHEELBASE*tan(steering)*dt
	var travel := (old_speed+speed)*0.5*dt
	blocked=false
	var substeps := maxi(1,ceili(absf(turn_angle)/0.015))
	for i in range(substeps):
		var old_rotation := rotation.y
		var next_rotation := old_rotation+turn_angle/substeps
		if rotation_clear(next_rotation): rotation.y=next_rotation
		else: blocked=true; speed=0; break
		var motion := -basis.z*travel/substeps
		var collision := move_and_collide(motion)
		if collision:
			blocked=true
			speed=0
			break
	rotation.y=wrapf(rotation.y,-PI,PI)
	animate_wheels(dt,handbrake or reversing or blocked)

func rotation_clear(yaw: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=get_child(0).shape
	query.transform=Transform3D(Basis(Vector3.UP,yaw),position+Vector3(0,0.86,0))
	query.collision_mask=3
	query.exclude=[get_rid()]
	var exceptions := query.exclude
	for object in get_collision_exceptions(): exceptions.append(object.get_rid())
	query.exclude=exceptions
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func tick_traffic(delta: float, transit: CityTransit) -> void:
	var dt := minf(delta,0.1)
	var length := transit.curve.get_baked_length()
	var desired := 7.0
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
	blocked=test_move(transform,motion) or test_move(Transform3D(next.basis,position),motion)
	if blocked: speed=0
	else:
		route_distance=next_distance
		transform=next
	animate_wheels(dt,blocked or desired<6.5)

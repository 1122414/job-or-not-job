class_name OfficePlayer
extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 8.0
@export var sensitivity := 0.0025
var game: Node3D
var yaw := 0.0
var pitch := -0.12
var camera: Camera3D
var pivot: Node3D
var spring: SpringArm3D
var visual: HumanVisual
var hand: Node3D
var held: OfficeProp
var inventory: Array[OfficeProp] = []
var bag_open := false
var bag_page := 0
var cooldown := 0.0
var swing := 0.0
var hp := 100
var protection := 0.0
var dead := 0.0
var seated := false
var seat_body: OfficeProp
var body_shape: CollisionShape3D

func _ready() -> void:
	body_shape=CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.27
	capsule.height=1.75
	body_shape.shape=capsule
	body_shape.position.y=0.88
	add_child(body_shape)
	collision_mask=3
	visual = HumanVisual.new()
	visual.outfit="casual"
	add_child(visual)
	hand=visual.grip
	pivot = Node3D.new()
	add_child(pivot)
	pivot.position.y = 1.6
	spring = SpringArm3D.new()
	pivot.add_child(spring)
	spring.spring_length = 3.1
	spring.position.x = 0.45
	spring.margin = 0.2
	spring.add_excluded_object(get_rid())
	camera = Camera3D.new()
	spring.add_child(camera)
	camera.current = true
	camera.fov = 65
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func forward() -> Vector3:
	return Vector3(-sin(yaw),0,-cos(yaw))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -0.9, 0.5)
	if dead > 0: return
	if event.is_action_pressed("attack"):
		if not stand_up(): return
		game.close_interaction()
		attack()
	if event.is_action_pressed("interact"): game.interact()
	if event.is_action_pressed("throw"):
		if not stand_up(): return
		release(true)
	if event.is_action_pressed("drop"): release(false)
	if event.is_action_pressed("store"): store_held()
	if event.is_action_pressed("cycle"): cycle_item()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	swing = maxf(0,swing-delta)
	protection = maxf(0,protection-delta)
	pivot.rotation = Vector3(pitch,yaw,0)
	visual.rotation.y = yaw + sin(swing * 18) * 0.5
	visual.pose(Vector2(velocity.x,velocity.z).length(),swing>0,dead>0,seated)
	visual.position=visual.position.move_toward(visual.seated_offset if seated else Vector3.ZERO,delta*2)
	body_shape.shape.height=1.3 if seated else 1.75
	body_shape.position.y=0.68 if seated else 0.88
	if held:
		held.global_transform = hand.global_transform
	if dead > 0:
		dead -= delta
		visual.rotation.z = 1.4
		if dead <= 0: respawn()
		return
	if not is_on_floor(): velocity.y -= 22 * delta
	var input := Input.get_vector("left","right","forward","back")
	if input.length()>0.1 or Input.is_action_just_pressed("jump"):
		if not stand_up(): return
	var direction := Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if input.length() > 0.1: game.close_interaction()
	if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = 7
	move_and_slide()
	if position.y < -8: hurt(100)

func attack() -> void:
	if cooldown > 0: return
	cooldown = 0.5 if held and held.kind == "keyboard" else 0.7
	swing = 0.3
	var action: int = game.next_action()
	var reach := 2.7 if held and held.kind == "keyboard" else 2.0
	for node in game.targets():
		var offset: Vector3 = node.global_position - global_position
		offset.y = 0
		if offset.length() <= reach and offset.normalized().dot(forward()) > 0.35 and game.can_see(self,node):
			if node is OfficeNPC: node.hit(forward(),1.8 if held else 1.0,action)
			if node is OfficeProp and node != held:
				node.strike(forward(),action)
				game.on_property_hit(node,action)
			game.impact()

func pick(prop: OfficeProp) -> void:
	if not prop.portable():
		prop.strike(forward(),game.next_action())
		game.on_property_hit(prop,game.action_counter)
		return
	if held: store_held()
	inventory.erase(prop)
	prop.show()
	held = prop
	prop.freeze = true
	prop.collision_layer = 0
	prop.collision_mask = 0
	prop.thrown = false
	game.queue_save()

func release(throwing: bool) -> void:
	if not held: return
	var prop := held
	held = null
	prop.global_position = global_position + Vector3.UP * 1.3 + forward() * 0.9
	prop.freeze = false
	prop.collision_layer = prop.world_layer()
	prop.collision_mask = 3
	prop.linear_velocity = Vector3.ZERO
	game.queue_save()
	if throwing:
		prop.attack_id = game.next_action()
		prop.hits.clear()
		prop.thrown = true
		prop.flight_time = 3
		prop.apply_central_impulse((forward() * 14 + Vector3.UP * 3) * prop.mass)

func hurt(amount: int) -> void:
	stand_up()
	if protection > 0: return
	hp = maxi(0,hp-amount)
	game.impact()

	if hp == 0:
		dead = 2.0
		cooldown = 0
		swing = 0
		bag_open = false
		game.close_interaction()
		game.say("你倒下了。附近复活中，装备保留。")

func collect(prop: OfficeProp) -> void:
	if not prop.portable() or inventory.has(prop) or held==prop: return
	prop.freeze=true
	prop.collision_layer=0
	prop.collision_mask=0
	prop.thrown=false
	prop.hide()
	inventory.append(prop)
	game.say("已收纳 "+prop.title)
	game.queue_save()

func store_held() -> void:
	if not held: return
	if not inventory.has(held): inventory.append(held)
	held.hide()
	held = null
	game.queue_save()

func cycle_item() -> void:
	if inventory.is_empty(): return
	var item := inventory[0]
	pick(item)
	game.queue_save()

func respawn() -> void:
	position = game.safe_spawn(global_position)
	velocity = Vector3.ZERO
	hp = 100
	protection = 5.0
	visual.rotation.z = 0
	game.say("已在附近复活 · 5 秒保护 · 装备与世界后果保留")

func sit_at(point: Vector3) -> void:
	store_held()
	if seat_body: remove_collision_exception_with(seat_body)
	seat_body=null
	for prop in game.props:
		if prop.stable_id.ends_with("_seat") and Vector2(prop.position.x-point.x,prop.position.z-point.z).length()<0.5:
			seat_body=prop
			add_collision_exception_with(prop)
			break
	position=point
	velocity=Vector3.ZERO
	yaw=0
	seated=true

func stand_up() -> bool:
	if not seated: return true
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.28
	capsule.height=1.75
	query.shape=capsule
	query.margin=0.005
	query.collision_mask=3
	query.exclude=[get_rid()]
	for offset in [Vector3(0,0,0.85),Vector3(0.85,0,0),Vector3(-0.85,0,0),Vector3(0,0,1.5)]:
		var point: Vector3=position+offset.rotated(Vector3.UP,yaw)
		query.transform.origin=point+Vector3.UP*0.94
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			position=point
			seated=false
			if seat_body: remove_collision_exception_with(seat_body)
			seat_body=null
			return true
	game.say("起身空间被挡住了，请先挪开周围物品。")
	return false

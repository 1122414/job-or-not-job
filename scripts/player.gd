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
var cooldown := 0.0
var swing := 0.0
var hp := 100
var protection := 0.0
var dead := 0.0

func _ready() -> void:
	Shapes.collider(self, Vector3(0.6,1.75,0.6), Vector3(0,0.88,0))
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
		game.close_interaction()
		attack()
	if event.is_action_pressed("interact"): game.interact()
	if event.is_action_pressed("throw"): release(true)
	if event.is_action_pressed("drop"): release(false)
	if event.is_action_pressed("store"): store_held()
	if event.is_action_pressed("cycle"): cycle_item()
	if event.is_action_pressed("bag"):
		bag_open = not bag_open
		game.show_inventory()
	if event.is_action_pressed("cancel"):
		game.close_interaction()
		game.toggle_menu()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	swing = maxf(0,swing-delta)
	protection = maxf(0,protection-delta)
	pivot.rotation = Vector3(pitch,yaw,0)
	visual.rotation.y = yaw + sin(swing * 18) * 0.5
	visual.pose(Vector2(velocity.x,velocity.z).length(),swing>0,dead>0)
	if held:
		held.global_transform = hand.global_transform
	if dead > 0:
		dead -= delta
		visual.rotation.z = 1.4
		if dead <= 0: respawn()
		return
	if not is_on_floor(): velocity.y -= 22 * delta
	var input := Input.get_vector("left","right","forward","back")
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

func release(throwing: bool) -> void:
	if not held: return
	var prop := held
	held = null
	prop.global_position = global_position + Vector3.UP * 1.3 + forward() * 0.9
	prop.freeze = false
	prop.collision_layer = 1
	prop.collision_mask = 1
	prop.linear_velocity = Vector3.ZERO
	if throwing:
		prop.attack_id = game.next_action()
		prop.hits.clear()
		prop.thrown = true
		prop.flight_time = 3
		prop.apply_central_impulse((forward() * 14 + Vector3.UP * 3) * prop.mass)

func hurt(amount: int) -> void:
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

func store_held() -> void:
	if not held: return
	if not inventory.has(held): inventory.append(held)
	held.hide()
	held = null
	game.show_inventory()

func cycle_item() -> void:
	if inventory.is_empty(): return
	var item := inventory[0]
	pick(item)
	game.show_inventory()

func respawn() -> void:
	position = game.safe_spawn(global_position)
	velocity = Vector3.ZERO
	hp = 100
	protection = 5.0
	visual.rotation.z = 0
	game.say("已在附近复活 · 5 秒保护 · 装备与世界后果保留")

class_name OfficePlayer
extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 8.0
@export var sensitivity := 0.0025
var game: Node3D
var frame_remaining := 0.0
var frame_yaw := 0.0
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
	visual.cast_id="protagonist"
	visual.outfit="casual"
	add_child(visual)
	hand=visual.grip
	visual.animation.mixer_applied.connect(sync_held)
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func capture_permitted() -> bool:
	# Script fixtures and background windows must never own the desktop pointer.
	return game==get_tree().current_scene and not get_viewport().is_input_disabled() and DisplayServer.get_name()!="headless" and not "--no-mouse-capture" in OS.get_cmdline_user_args() and get_window().has_focus() and game.panels.page==""

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(game) and game.driving: game.driving.suspend_controls()

func forward() -> Vector3:
	return Vector3(-sin(yaw),0,-cos(yaw))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT and capture_permitted():
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		# The activation click must not also attack or throw an item.
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if dead > 0: return
	if game.in_vehicle():
		if event.is_action_pressed("interact"): game.interact()
		return
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
	if frame_remaining>0 and game.interviews.player_seated():
		frame_remaining=maxf(0,frame_remaining-delta)
		yaw=lerp_angle(yaw,frame_yaw,1-exp(-delta*7))
		pitch=lerpf(pitch,-0.06,1-exp(-delta*7))
	pivot.position.x=lerpf(pivot.position.x,0.48 if game.interviews.player_seated() else 0.0,1-exp(-delta*6))
	pivot.rotation = Vector3(pitch,yaw,0)
	pivot.position.y=lerpf(pivot.position.y,2.0 if game.driving.in_vehicle() else 1.32 if seated else 1.6,1.0-exp(-delta*5.0))
	spring.spring_length=lerpf(spring.spring_length,6.4 if game.driving.in_vehicle() else 2.15 if seated else 3.1,1.0-exp(-delta*5.0))
	# Camera-relative controls stay unchanged; feet follow the actual travel direction.
	var facing := atan2(-velocity.x,-velocity.z) if Vector2(velocity.x,velocity.z).length()>0.2 and swing<=0 and not seated else yaw
	visual.rotation.y = lerp_angle(visual.rotation.y,facing,1.0-exp(-delta*14.0))
	visual.pose(Vector2(velocity.x,velocity.z).length(),swing>0,dead>0,seated,game.interviews.player_seated() or game.in_vehicle())
	var speaker: OfficeNPC=game.speaker if game.speaker is OfficeNPC else null
	if speaker==null and game.interviews.player_seated():
		var session: Dictionary=game.interviews.sessions[game.interviews.active_firm()]
		speaker=game.npc_for_role(InterviewFlow.HOSTS[session.action])
	visual.set_attention(speaker.visual.face_position() if is_instance_valid(speaker) else Vector3.ZERO,is_instance_valid(speaker) and dead<=0)
	visual.position=visual.position.move_toward(visual.seated_offset if seated else Vector3.ZERO,delta*2)
	body_shape.shape.height=1.3 if seated else 1.75
	body_shape.position.y=0.68 if seated else 0.88
	sync_held()
	if dead > 0:
		dead -= delta
		visual.rotation.z = 1.4
		if dead <= 0: respawn()
		return
	if game.in_vehicle():
		if game.driving.in_vehicle(): game.driving.sync_driver()
		else: game.transit.sync_passenger()
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
	if game.in_vehicle(): return
	if cooldown > 0: return
	cooldown = 0.5 if held and held.kind == "keyboard" else 0.7
	swing = 0.3
	var action: int = game.next_action()
	var reach := 2.7 if held and held.kind == "keyboard" else 2.0
	var dangerous := held!=null and held.mass>=2.0 and Input.is_action_pressed("dangerous")
	var candidate: Node3D
	var nearest_distance := reach+1.0
	for node in game.targets():
		if not (node is OfficeNPC or node is CityResident or node is OfficeProp) or node==held: continue
		if not node.visible: continue
		if node is CityResident and (node.hp==0 or not dangerous and not node.available()): continue
		if node is OfficeNPC and (node.care_state in ["away","carried"] or not dangerous and not node.available()): continue
		var offset: Vector3=node.global_position-global_position
		offset.y=0
		if offset.length()<=reach and offset.length()<nearest_distance and offset.normalized().dot(forward())>0.35 and game.can_see(self,node):
			candidate=node
			nearest_distance=offset.length()
	if candidate is OfficeNPC or candidate is CityResident:
		candidate.hit(forward(),1.4 if dangerous else 0.5,action,dangerous)
		game.impact()
	elif candidate is OfficeProp:
		var strength := 4.0 if held and held.kind=="monitor" else 2.5 if held else 0.4
		if candidate.strike(forward(),action,strength): game.on_property_hit(candidate,action)
		else: game.say("徒手只能推撞，坚固家具需要重物或明确掀翻。")
		game.impact()

func pick(prop: OfficeProp) -> void:
	if game.in_vehicle(): return
	if not prop.portable():
		if prop.tip(forward(),game.next_action()):
			game.on_property_hit(prop,game.action_counter)
			game.say("已推掀 "+prop.title)
		return
	if held: store_held()
	inventory.erase(prop)
	prop.show()
	held = prop
	prop.freeze = true
	prop.collision_layer = 0
	prop.collision_mask = 0
	prop.thrown = false
	prop.linear_velocity=Vector3.ZERO
	prop.angular_velocity=Vector3.ZERO
	sync_held()
	game.queue_save()

func sync_held() -> void:
	if game.driving and game.driving.active: game.driving.active.pose_driver(visual)
	if not is_instance_valid(held): return
	if swing<=0 and dead<=0:
		var frame := Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
		var target := visual.global_transform*Transform3D(frame,Vector3(0.20,visual.standing_height*0.64,-0.38))
		visual.contacts.reach("R",target)
		visual.contacts.fingers("R",-0.3)
	# Use the evaluated bone pose directly; BoneAttachment updates later in the
	# frame and otherwise leaves the rigid prop one frame behind the hand.
	held.global_transform=visual.contacts.palm("R")*held.in_palm()
	if held.kind in ["keyboard","monitor"]:
		var support := held.support_point()
		support.x=-support.x
		var target := Transform3D(held.global_basis*held.in_palm().basis.inverse(),held.to_global(support)-held.global_basis.y*OfficeProp.HAND_CLEARANCE)
		visual.contacts.reach("L",target)
		visual.contacts.fingers("L",-0.3)

func release(throwing: bool) -> void:
	if game.in_vehicle(): return
	if not held: return
	sync_held()
	var prop := held
	held = null
	prop.freeze = false
	prop.collision_layer = prop.world_layer()
	prop.collision_mask = 3
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
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
		game.driving.detach()
		game.transit.detach()
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
	game.driving.detach()
	game.transit.detach()
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
	if game.in_vehicle(): return false
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

func frame_conversation(person: Node3D) -> void:
	var direction := person.position-position
	frame_yaw=atan2(-direction.x,-direction.z)
	frame_remaining=0.7

func look(relative: Vector2) -> void:
	frame_remaining=0
	yaw-=relative.x*sensitivity
	pitch=clampf(pitch-relative.y*sensitivity,-0.9,0.5)

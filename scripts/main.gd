extends Node3D

var player: OfficePlayer
var props: Array[OfficeProp] = []
var npcs: Array[OfficeNPC] = []
var action_counter := 0
var hud: StreetHUD
var audio: AudioStreamPlayer
var shake_enabled := true

func _ready() -> void:
	bind_inputs()
	build_lighting()
	player = OfficePlayer.new()
	player.game = self
	add_child(player)
	player.position = Vector3(-14,0.2,5)
	Neighborhood.build(self)
	build_ui()
	build_audio()

func bind_inputs() -> void:
	var keys := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"run":KEY_SHIFT,"jump":KEY_SPACE,"interact":KEY_E,"drop":KEY_G,"cancel":KEY_ESCAPE,"bag":KEY_TAB,"store":KEY_Q,"cycle":KEY_R,"save":KEY_F5,"load":KEY_F9,"journal":KEY_J}
	for action in keys:
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	for action in ["attack","throw"]:
		InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,event)

func build_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.light_energy = 0.65
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fb4c5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c7dbdf")
	env.environment.ambient_light_energy = 0.45
	add_child(env)

func add_prop(id: String, kind: String, pos: Vector3) -> void:
	var prop := OfficeProp.new()
	prop.setup(id,kind,pos,self)
	props.append(prop)
	add_child(prop)

func add_npc(id: String, title: String, pos: Vector3, firm: String, role: String) -> void:
	var npc := OfficeNPC.new()
	npc.setup(id,title,pos,firm,role,self)
	npcs.append(npc)
	add_child(npc)

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = StreetHUD.new()
	hud.game = self
	canvas.add_child(hud)

func _process(delta: float) -> void:
	player.camera.h_offset = lerpf(player.camera.h_offset,0,delta*15)

func location_name() -> String:
	if player.position.z > 2: return "下班路 · 公共街区"
	return "规程科技" if player.position.x<0 else "自己人网络"

func alert_level() -> int:
	return 0

func clock_text() -> String:
	return "09:00"

func money_text() -> String:
	return "¥ 0"

func objective_text() -> String:
	return "两家公司都能进入 · 靠近人物按 E · 随时可以离开"

func targets() -> Array:
	return npcs + props

func nearest() -> Node3D:
	var best: Node3D
	var distance := 3.0
	for node in targets():
		if node == player.held or not node.visible: continue
		var offset: Vector3 = node.global_position-player.global_position
		offset.y = 0
		var d := offset.length()
		if d < distance and offset.normalized().dot(player.forward()) > 0.2 and can_see(player,node):
			best = node
			distance = d
	return best

func can_see(from: Node3D, to: Node3D) -> bool:
	var start := from.global_position + Vector3.UP
	var end := to.global_position + (Vector3.UP if to is CharacterBody3D else Vector3.ZERO)
	var query := PhysicsRayQueryParameters3D.create(start,end)
	if from is CollisionObject3D: query.exclude = [from.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == to

func interact() -> void:
	var target := nearest()
	if target is OfficeProp: player.pick(target)
	elif target is OfficeNPC: say("%s：%s" % [target.title,"让我缓缓……" if target.down>0 else "今天也是来证明自己的？"])

func close_interaction() -> void:
	pass

func next_action() -> int:
	action_counter += 1
	return action_counter

func on_aggression(npc: OfficeNPC, _action: int) -> void:
	say(npc.title + "：别动手！")
	for witness in npcs:
		if witness==npc or witness.global_position.distance_to(npc.global_position)>8: continue
		if not can_see(witness,npc): continue
		if witness.role=="guard":
			witness.hostile=15
			witness.mood="介入：请停止动手"
		elif witness.role=="friend" and npc.role=="boss":
			witness.mood="解气，但别再打了！"
			witness.affinity=mini(100,witness.affinity+3)
		else:
			witness.mood="紧张：离远一点"
			witness.reaction=3


func on_property_hit(_prop: OfficeProp, _action: int) -> void:
	pass

func relationship(_npc: OfficeNPC) -> String:
	return "陌生人"

func say(text: String) -> void:
	hud.toast = text
	hud.toast_time = 6

func build_audio() -> void:
	audio = AudioStreamPlayer.new()
	add_child(audio)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	for i in range(2205):
		var sample := sin(float(i)*0.08) * (1.0-float(i)/2205.0) * 65
		bytes.append(int(sample) & 255)
	stream.data = bytes
	audio.stream = stream
	audio.volume_db = -12

func impact() -> void:
	audio.play()
	if shake_enabled: player.camera.h_offset = 0.12

func show_inventory() -> void:
	var names := PackedStringArray()
	for prop in player.inventory: names.append(prop.title)
	say("背包：%s\nQ 收纳手持 · R 轮换取出 · G 放下 · 右键投掷" % ("空" if names.is_empty() else " / ".join(names)))

func safe_spawn(origin: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	for x in [-20,-12,0,12,20]:
		for z in [8,4,-2]: candidates.append(Vector3(x,0.3,z))
	candidates.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.distance_squared_to(origin)<b.distance_squared_to(origin))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0,2.0,2.0)
	for point in candidates:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = point + Vector3.UP
		query.exclude = [player.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return point
	# Elevated recovery is only used if every normal point is obstructed.
	return Vector3(0,4,8)

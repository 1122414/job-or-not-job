extends Node3D

var player: OfficePlayer
var props: Array[OfficeProp] = []
var npcs: Array[OfficeNPC] = []
var action_counter := 0
var hud: Label
var notice: Label
var notice_time := 0.0
var audio: AudioStreamPlayer
var shake_enabled := true

func _ready() -> void:
	bind_inputs()
	build_lighting()
	Shapes.solid(self,Vector3(35,0.3,30),Vector3(0,-0.2,0),Color("657775"))
	Shapes.solid(self,Vector3(20,0.15,14),Vector3(0,0,0),Color("c9c6b6"))
	Shapes.solid(self,Vector3(20,3,0.3),Vector3(0,1.5,-7),Color("72878a"))
	Shapes.label(self,"今天不上班 / 动作现场",Vector3(0,3,-6))
	player = OfficePlayer.new()
	player.game = self
	add_child(player)
	player.position = Vector3(0,0.2,5)
	for item in [["keyboard",Vector3(-1,1.3,0)],["cup",Vector3(1,1.3,0)],["table",Vector3(0,1,0)],["chair",Vector3(2,0.6,-1)],["printer",Vector3(-3,0.8,-1)]]:
		add_prop("a_"+item[0],item[0],item[1])
	add_npc("a_hr","林岚 · HR",Vector3(0,0,-3),"a","hr")
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
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fb4c5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c7dbdf")
	env.environment.ambient_light_energy = 0.7
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
	hud = Label.new()
	hud.position = Vector2(24,20)
	hud.add_theme_font_size_override("font_size",20)
	hud.add_theme_color_override("font_shadow_color",Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x",2)
	hud.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(hud)
	notice = Label.new()
	notice.position = Vector2(24,620)
	notice.add_theme_font_size_override("font_size",22)
	canvas.add_child(notice)

func _process(delta: float) -> void:
	notice_time = maxf(0,notice_time-delta)
	notice.visible = notice_time > 0
	var target := nearest()
	hud.text = "今天不上班\nWASD 移动 · Shift 跑 · 空格 跳 · 鼠标 视角\n左键 推击/挥击 · 右键 投掷 · E 拿取/互动 · G 放下 · Esc 释放鼠标\n生命 %d | 手持：%s\n%s" % [player.hp,player.held.title if player.held else "空手", "E  " + target.title if target else "自由走走，或直接动手"]
	player.camera.h_offset = lerpf(player.camera.h_offset,0,delta*15)

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

func on_property_hit(_prop: OfficeProp, _action: int) -> void:
	pass

func relationship(_npc: OfficeNPC) -> String:
	return "陌生人"

func say(text: String) -> void:
	notice.text = text
	notice_time = 5

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

extends Node3D

var player: OfficePlayer
var props: Array[OfficeProp] = []
var npcs: Array[OfficeNPC] = []
var persistence_enabled := false
var save_delay := -1.0
var payroll := Payroll.new()
var walking := WalkingGrid.new()
var career := Career.new()
var stations: Array[WorkStation] = []
var conversation: Dictionary = {}
var speaker: Node3D
var journal_open := false
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
	add_station("archive","原始资料",Vector3(-24,0,-4))
	add_station("demo","演示交付台",Vector3(-19,0,-12))
	add_station("backup","备用投影",Vector3(-5,0,-12))
	add_station("handover","交接终端",Vector3(23,0,-4))
	add_station("rest","公交站 · 休息",Vector3(-2,0,14))
	build_ui()
	build_audio()
	build_walk_grid.call_deferred()
	startup.call_deferred()

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
	var payday_before := payroll.next_payday
	payroll.tick(delta,career.employer)
	if payroll.next_payday!=payday_before: queue_save()
	if save_delay>=0:
		save_delay-=delta
		if save_delay<0: save_game(false)
	player.camera.h_offset = lerpf(player.camera.h_offset,0,delta*15)

func location_name() -> String:
	if player.position.z > 2: return "下班路 · 公共街区"
	return "规程科技" if player.position.x<0 else "自己人网络"

func alert_level() -> int:
	if player.position.z>2: return 0
	return career.conflict.a if player.position.x<0 else career.conflict.b

func clock_text() -> String:
	return payroll.time_text()

func money_text() -> String:
	return "¥ %.2f · 发薪 第%d天" % [payroll.balance/100.0,payroll.next_payday/1440+1]

func objective_text() -> String:
	return career.objective()

func targets() -> Array:
	return npcs + props + stations

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

func add_station(id: String, title: String, pos: Vector3) -> void:
	var station := WorkStation.new()
	station.stable_id=id
	station.title=title
	station.position=pos
	stations.append(station)
	add_child(station)

func interact() -> void:
	var target := nearest()
	if target is OfficeProp:
		player.pick(target)
	elif target is OfficeNPC or target is WorkStation:
		if target is OfficeNPC and target.down>0:
			say("对方暂时倒地，稍后会恢复；也可以直接离开。")
			return
		speaker=target
		conversation=OfficeDialogue.options(target,career)
		if target is OfficeNPC and target.role in ["friend","group"] and payroll.after_work():
			conversation={"text":target.title+"：下班了，今天的事可以聊，也可以不聊。", "choices":[["聊今天发生的事","social"],["请你帮忙伪造未完成的成果","boundary"]]}
		if target is OfficeNPC and target.role=="guard":
			conversation={"text":"保安：需要时可以帮你清理被堵的通路。", "choices":[["请挪开走道上的大件","clear_path"]]}
		journal_open=false

func choose(index: int) -> void:
	if conversation.is_empty() or not is_instance_valid(speaker): return
	if player.dead>0 or player.position.distance_to(speaker.position)>3.5 or (speaker is OfficeNPC and speaker.down>0):
		close_interaction()
		return
	var choices: Array = conversation.choices
	if index>=choices.size(): return
	var action: String = choices[index][1]
	if action=="settle":
		var companion: OfficeNPC
		for npc in npcs:
			if npc.stable_id=="b_friend": companion=npc
		if companion.down>0 or companion.position.distance_to(speaker.position)>4:
			say("等阿乐走到现场再一起交涉；他倒地时会恢复。")
			return
	if action=="rest_evening":
		payroll.advance(posmod(18*60-payroll.minute%1440,1440),career.employer)
		queue_save()
		close_interaction()
		say("休息到傍晚。下班不结束世界，也不强制退出。")
		return
	if action=="rest_day":
		payroll.advance(1440,career.employer)
		queue_save()
		close_interaction()
		say("一天过去了，应得工资照常累计。")
		return
	if action=="clear_path":
		for prop in props:
			if not prop.portable(): prop.reset_position()
		close_interaction()
		say("大件已挪回原处，损坏与公司后果保留。")
		return
	if action=="social":
		var key: String = speaker.stable_id+"_social"
		if not career.facts.has(key):
			speaker.affinity=mini(100,speaker.affinity+8)
			career.record(key,speaker.title+"：下班聊过，关系不依赖是否还在同一公司。")
		var line: String = speaker.title+"：工作归工作，你不用每天来维护关系。"
		close_interaction()
		say(line)
		return
	var result := "小夏：我们关系再好，也不能造假。找捷径可以，伪造成果不行。" if action=="boundary" else career.apply(action)
	if action in ["join_b","handover","settle"]:
		for npc in npcs:
			if npc.stable_id=="b_friend": npc.affinity=mini(100,npc.affinity+12)
	close_interaction()
	queue_save()
	say(result)
	if action=="backup" and career.facts.has("output_two"):
		for station in stations:
			if station.stable_id=="backup": station.label.text="投影已恢复 · 成果已记录"

func close_interaction() -> void:
	conversation.clear()
	speaker=null

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_4: choose(event.physical_keycode-KEY_1)
		if event.is_action_pressed("save"): save_game(true)
		if event.is_action_pressed("load"): load_game()
		if event.is_action_pressed("journal"):
			journal_open=not journal_open
			close_interaction()

func next_action() -> int:
	action_counter += 1
	return action_counter

func on_aggression(npc: OfficeNPC, action: int) -> void:
	close_interaction()
	var warning := career.aggression(npc.company,action,action_counter)
	queue_save()
	say(warning if warning!="" else npc.title+"：别动手！")
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


func on_property_hit(prop: OfficeProp, action: int) -> void:
	for npc in npcs:
		if npc.position.distance_to(prop.position)<8 and can_see(npc,prop):
			on_aggression(npc,action)
			return

func relationship(npc: OfficeNPC) -> String:
	var tags := PackedStringArray()
	if career.employer==npc.company: tags.append("同事")
	elif career.former.has(npc.company): tags.append("前同事")
	else: tags.append("认识的人")
	if npc.affinity>=30: tags.append("朋友")
	return " · ".join(tags)

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

func build_walk_grid() -> void:
	await get_tree().physics_frame
	walking.build(self)

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream=null

func startup() -> void:
	await get_tree().physics_frame
	# Unit/integration scenes never load or overwrite the player's save slot.
	persistence_enabled=get_tree().current_scene==self
	if persistence_enabled and FileAccess.file_exists(SaveGame.PATH): load_game()

func queue_save() -> void:
	if persistence_enabled: save_delay=0.4

func save_game(show_message: bool = true) -> void:
	if not persistence_enabled: return
	var error := SaveGame.write(self)
	if error!=OK: say("保存失败："+error_string(error)+"。旧档保留，请检查磁盘空间。")
	elif show_message: say("已保存。F9 继续此存档，F5 再次保存。")

func load_game() -> void:
	if not persistence_enabled: return
	var data := SaveGame.read(SaveGame.PATH,self)
	var backup := false
	if data.is_empty():
		data=SaveGame.read(SaveGame.PATH+".bak",self)
		backup=true
	if data.is_empty():
		say("没有有效存档。损坏文件保留；当前世界未被清空。")
		return
	SaveGame.restore(self,data)
	save_delay=-1
	say("主档损坏，已恢复有效备份；损坏文件保留。" if backup else "已继续存档：装备、成果、工资和公司后果均已恢复。")

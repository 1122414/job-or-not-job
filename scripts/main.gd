extends Node3D

var player: OfficePlayer
var props: Array[OfficeProp] = []
var npcs: Array[OfficeNPC] = []
var panels: GamePanels
var initial_state: Dictionary
var menu: PauseMenu
var ledger_open := false
var ledger_page := 0
var help_open := false
var debug_open := false
var save_path := SaveGame.PATH
var archive_directory := "user://restarts"
var persistence_enabled := false
var save_delay := -1.0
var payroll := Payroll.new()
var walking := WalkingGrid.new()
var office := OfficeLife.new()
var staffing := Staffing.new()
var care := NPCCare.new()
var social := SocialLife.new()
var onboarding := Onboarding.new()
var recruitment := RecruitmentFlow.new()
var projects := WorkProjects.new()
var promises := WorkPromises.new()
var person_index := 0
var interviews := InterviewFlow.new()
var career := Career.new()
var stations: Array[WorkStation] = []
var restore_revision := 0
var conversation: Dictionary = {}
var focus_target: Node3D
var speaker: Node3D
var journal_open := false
var history_open := false
var history_page := 0
var action_counter := 0
var hud: StreetHUD
var sun: DirectionalLight3D
var environment: Environment
var audio: AudioStreamPlayer
var interview_audio: InterviewAudio
var shake_enabled := true
var navigation_dirty := -1.0
var transit: CityTransit
var driving: CityDriving
var population: CityPopulation
var city_life: CityLife

func _ready() -> void:
	bind_inputs()
	build_lighting()
	player = OfficePlayer.new()
	player.game = self
	add_child(player)
	player.position = Vector3(-14,0.2,5)
	office.game=self
	staffing.game=self
	care.game=self
	social.game=self
	onboarding.game=self
	recruitment.game=self
	projects.game=self
	promises.game=self
	interviews.game=self
	Neighborhood.build(self)
	for firm in ["a","b"]: add_prop(firm+"_badge","badge",OfficeRooms.point(self,firm,"reception")+Vector3(0.35,0.98,0))
	for id in OfficeLife.DESKS: add_station(id,"我的工位",OfficeRooms.point(self,"b" if id=="desk_b" else "a",id))
	add_station("archive","原始资料",OfficeRooms.point(self,"a","archive"))
	add_station("demo","演示交付台",OfficeRooms.point(self,"a","demo"))
	add_station("backup","备用投影",OfficeRooms.point(self,"a","backup"))
	add_station("handover","交接终端",OfficeRooms.point(self,"b","handover"))
	add_station("rest","公交站 · 休息",Vector3(-2,0,14))
	for firm in ["a","b"]: add_station("interview_"+firm,"01 面试室",OfficeRooms.point(self,firm,"interview_seat"))
	transit=CityTransit.new()
	transit.game=self
	add_child(transit)
	driving=CityDriving.new()
	driving.game=self
	add_child(driving)
	population=CityPopulation.new()
	population.game=self
	add_child(population)
	city_life=CityLife.new()
	city_life.game=self
	add_child(city_life)
	build_ui()
	build_audio()
	interview_audio=InterviewAudio.new()
	add_child(interview_audio)
	build_walk_grid.call_deferred()
	startup.call_deferred()

func bind_inputs() -> void:
	for action in ["ui_accept","ui_cancel"]:
		var ui_button := InputEventJoypadButton.new()
		ui_button.button_index=JOY_BUTTON_A if action=="ui_accept" else JOY_BUTTON_B
		ui_button.device=-1
		if not InputMap.action_has_event(action,ui_button): InputMap.action_add_event(action,ui_button)
	var keys := {"city":KEY_M,"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"run":KEY_SHIFT,"jump":KEY_SPACE,"interact":KEY_E,"drop":KEY_G,"cancel":KEY_ESCAPE,"bag":KEY_TAB,"store":KEY_Q,"cycle":KEY_R,"save":KEY_F5,"load":KEY_F9,"journal":KEY_J,"ledger":KEY_L,"help":KEY_H,"history":KEY_K,"dangerous":KEY_ALT,"people":KEY_P,"messages":KEY_N,"promises":KEY_O}
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
	light.light_energy = 0.7
	light.shadow_enabled = true
	sun=light
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	environment=env.environment
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fb4c5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c6c9cc")
	env.environment.ambient_light_energy = 0.48
	add_child(env)

func add_prop(id: String, kind: String, pos: Vector3) -> void:
	var prop := OfficeProp.new()
	prop.setup(id,kind,pos,self)
	props.append(prop)
	add_child(prop)

func add_npc(id: String, title: String, pos: Vector3, firm: String, role: String, role_id: String = "") -> void:
	var npc := OfficeNPC.new()
	npc.setup(id,title,pos,firm,role,self)
	npc.role_id=id if role_id=="" else role_id
	npcs.append(npc)
	add_child(npc)

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = StreetHUD.new()
	hud.game = self
	canvas.add_child(hud)
	menu=PauseMenu.new()
	menu.game=self
	menu.process_mode=Node.PROCESS_MODE_ALWAYS
	canvas.add_child(menu)
	panels=GamePanels.new()
	panels.game=self
	add_child(panels)
	panels.view=GamePageView.new()
	panels.view.game=self
	canvas.add_child(panels.view)
	hud.process_mode=Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if navigation_dirty>=0:
		navigation_dirty-=delta
		if navigation_dirty<0: build_walk_grid.call_deferred()
	focus_target=nearest()
	interviews.tick(delta)
	office.tick(delta)
	staffing.tick(delta)
	care.tick(delta)
	social.tick(delta)
	onboarding.tick()
	var payday_before := payroll.next_payday
	payroll.tick(delta*(0.2 if not conversation.is_empty() else 1.0),career.employer)
	recruitment.tick()
	update_daylight()
	if payroll.next_payday!=payday_before: queue_save()
	if save_delay>=0:
		save_delay-=delta
		if save_delay<0: save_game(false)
	player.camera.h_offset = lerpf(player.camera.h_offset,0,delta*15)

func location_name() -> String:
	if player.position.z>2 or absf(player.position.x)>29:
		var region := CityLayout.region_at(player.position)
		for entry in CityLayout.REGIONS:
			if entry.id==region: return entry.title
	return "规程科技" if player.position.x<0 else "自己人网络"

func alert_level() -> int:
	if player.position.z>2 or absf(player.position.x)>29: return 0
	return career.conflict.a if player.position.x<0 else career.conflict.b

func clock_text() -> String:
	return payroll.time_text()

func money_text() -> String:
	return "¥ %.2f · 发薪 第%d天" % [payroll.balance/100.0,payroll.next_payday/1440+1]

func objective_text() -> String:
	if city_life and city_life.guide!="": return city_life.status_text()
	if driving and driving.guide_car!="": return "前往 "+driving.car_for(driving.guide_car).title+" · 靠近车辆按 E 上车"
	if transit and transit.waypoint!="":
		for stop in CityLayout.STOPS:
			if stop.id==transit.waypoint: return "自由探索 · "+stop.title+"（M 更改目的地）"
	return ObjectiveGuide.current(self).title

func update_daylight() -> void:
	var hour := float(payroll.minute%1440)/60.0
	var daylight := clampf(sin((hour-6.0)/12.0*PI),0,1)
	sun.light_energy=0.04+daylight*0.65
	sun.rotation_degrees.x=-10-daylight*55
	environment.background_color=Color("142330").lerp(Color("91b2c2"),daylight)
	environment.ambient_light_energy=0.18+daylight*0.23
	environment.ambient_light_color=Color("8c9bae").lerp(Color("c6c9cc"),daylight)

func in_vehicle() -> bool:
	return transit!=null and transit.riding or driving!=null and driving.in_vehicle()

func navigation_target() -> Node3D:
	if city_life and city_life.guide!="": return city_life.point_for(city_life.guide)
	if driving and driving.guide_car!="": return driving.car_for(driving.guide_car)
	return transit.station_for(transit.waypoint) if transit.waypoint!="" else ObjectiveGuide.target(self)

func targets() -> Array:
	return npcs + stations + props + (driving.cars.filter(func(car): return not car.traffic) if driving else []) + (population.residents if population else []) + (city_life.points if city_life else [])

func nearest() -> Node3D:
	var best: Node3D
	var distance := 3.0
	var visit := office.visit()
	for node in targets():
		if node == player.held or not node.visible: continue
		var offset: Vector3 = node.global_position-player.global_position
		offset.y = 0
		var d := offset.length()
		var score: float = d*(0.4 if node is WorkStation or node is CityActivityPoint else 0.55 if node is OfficeNPC else 1.0)
		var arriving: bool=node is OfficeNPC and not node.dead and not visit.is_empty() and visit.npc==node.role_id and career.facts.get("visit_state_"+visit.key,"")=="arrived"
		if arriving: score-=1.0
		if d<3.0 and score < distance and (arriving or (node is WorkStation and d<0.7) or offset.normalized().dot(player.forward()) > 0.2) and can_see(player,node):
			best = node
			distance = score
	return best

func can_see(from: Node3D, to: Node3D) -> bool:
	var start := from.global_position + Vector3.UP*1.35
	var end := to.global_position + (Vector3.UP*1.2 if to is CharacterBody3D or to is WorkStation or to is CityActivityPoint else Vector3.ZERO)
	var query := PhysicsRayQueryParameters3D.create(start,end)
	if from is CollisionObject3D: query.exclude = [from.get_rid()]
	if to is WorkStation and to.stable_id.begins_with("desk_"):
		var excluded := query.exclude
		for prop in props:
			if prop.stable_id.ends_with("_seat") and Vector2(prop.position.x-to.position.x,prop.position.z-to.position.z).length()<0.5:
				excluded.append(prop.get_rid())
		query.exclude=excluded
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
	if driving.in_vehicle():
		driving.leave()
		return
	if transit.riding:
		transit.open_stop(transit.current_stop if transit.current_stop>=0 else transit.next_stop)
		return
	if interviews.advance(): return
	var target := nearest()
	if target is CityActivityPoint:
		city_life.open_point(target)
		return
	if target is CityResident:
		population.talk(target)
		return
	if target is CityCar:
		driving.enter(target)
		return
	if target is WorkStation and target.stable_id.begins_with("bus_"):
		for i in range(CityLayout.STOPS.size()):
			if target.stable_id=="bus_"+CityLayout.STOPS[i].id: transit.open_stop(i)
		return
	if target is OfficeProp:
		if target.portable(): player.collect(target)
		else: player.pick(target)
	elif target is OfficeNPC or target is WorkStation:
		if target is OfficeNPC and not target.available():
			say("对方已死亡，无法再交谈。" if target.dead else "对方正在接受救助或休养，之后会返岗。")
			return
		speaker=target
		if target is OfficeNPC: social.meet(target)
		conversation=OfficeDialogue.options(target,career)
		if target is OfficeNPC: conversation=recruitment.options(target,conversation)
		if target is WorkStation and target.stable_id=="rest" and recruitment.next_time()>0:
			conversation.choices.push_front(["休息到下一安排 · "+recruitment.stamp(recruitment.next_time()),"rest_next"])
		if target is WorkStation and target.stable_id.begins_with("desk_"): conversation=office.desk_choices(target)
		if target is WorkStation and target.stable_id.begins_with("interview_"): conversation=interviews.room_options(target.stable_id.trim_prefix("interview_"))

		if target is OfficeNPC and target.role=="guard":
			conversation={"text":"保安：需要时可以帮你清理被堵的通路。", "choices":[["请挪开走道上的大件","clear_path"]]}
		if target is OfficeNPC:
			conversation=office.visit_choices(target,conversation)
			if social.outing.get("person")==target.stable_id and social.outing.get("stage")=="walking": conversation=social.options(target)
			elif conversation.choices.size()<4: conversation.choices.append(["回应私人邀约" if social.outing.get("person")==target.stable_id else "聊聊近况与相处","people_menu"])
			var introduction: Dictionary=onboarding.options(target)
			if not introduction.is_empty(): conversation=introduction
			conversation=onboarding.service_options(target,conversation)
		journal_open=false

func choose(index: int) -> void:
	if conversation.is_empty() or not is_instance_valid(speaker): return
	if player.dead>0 or player.position.distance_to(speaker.position)>3.5 or (speaker is OfficeNPC and (speaker.down>0 or speaker.dead)):
		close_interaction()
		return
	var choices: Array = conversation.choices
	if index>=choices.size(): return
	var action: String = choices[index][1]
	if speaker is CityActivityPoint:
		city_life.answer(speaker,action)
		return
	if speaker is CityResident:
		population.answer(speaker,action)
		return
	if speaker is OfficeNPC and social.handle(action,speaker): return
	if action=="open_messages":
		recruitment.selected=speaker.company
		panels.show_page("messages")
		return
	if recruitment.handle(action): return
	if promises.handle(action,speaker): return
	if projects.handle(action): return
	if onboarding.handle(action): return
	if interviews.handle(action): return
	if action in ["visit_confirm","visit_defer"]:
		var visitor: OfficeNPC=speaker
		office.answer_visit(visitor,action=="visit_confirm")
		close_interaction()
		# Continue with the confirmed visitor; nearby desks must not steal the next action.
		if action=="visit_confirm":
			speaker=visitor
			conversation=OfficeDialogue.options(visitor,career)
			if visitor.role_id=="a_lead" and career.stage==3 and not career.facts.has("promise_reviewed"): promises.review(visitor)
		return
	if action=="desk_repair":
		office.repair_desk(speaker)
		close_interaction()
		return
	if action=="desk_open":
		office.open_desk(speaker)
		close_interaction()
		return
	if action=="settle":
		var companion: OfficeNPC
		for npc in npcs:
			if npc.role_id=="b_friend" and not npc.dead: companion=npc
		if not companion or companion.dead or companion.down>0 or companion.position.distance_to(speaker.position)>4:
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
		navigation_dirty=0.1
		close_interaction()
		say("大件已挪回原处，损坏与公司后果保留。")
		return
	if action=="social":
		if speaker is OfficeNPC and social.willing(speaker): career.record(speaker.stable_id+"_social","你们下班后聊过。")
		social.handle("people_chat",speaker)
		return

	if action=="prepare" and speaker is WorkStation:
		office.start_preview(speaker)
		close_interaction()
		return
	var result := "小夏：我们关系再好，也不能造假。找捷径可以，伪造成果不行。" if action=="boundary" else career.apply(action)
	if action in ["permission","confirm"]:
		projects.state("a").approval="confirmed" if career.facts.has("confirm") else "permission" if career.facts.has("permission") else "none"
	if action in ["handover","settle"] and career.employer=="b":
		var friend: OfficeNPC=npc_for_role("b_friend")
		if friend: social.remember(friend,action,"你们一起安顿设备或确认了交接的边界。",8,6)
	if action in ["shortcut","submit","no_hc","transfer"] and career.employer=="a":
		var colleague: OfficeNPC=npc_for_role("a_friend" if action=="shortcut" else "a_lead")
		if colleague: social.remember(colleague,action,"你们核对了工作依据和已完成的成果。",4,5)
	close_interaction()
	queue_save()
	say(result)
	if action in ["join_a","join_b"] and career.employer==action.trim_prefix("join_"): onboarding.start(career.employer)
	if action=="backup" and career.facts.has("output_two"):
		for station in stations:
			if station.stable_id=="backup": station.label.text="投影已恢复 · 成果已记录"

func close_interaction() -> void:
	interviews.interrupt()
	conversation.clear()
	speaker=null

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_4: choose(event.physical_keycode-KEY_1)
		if event.physical_keycode==KEY_F3 and OS.is_debug_build(): debug_open=not debug_open
		if event.is_action_pressed("save"): save_game(true)
		if event.is_action_pressed("load"): load_game()

func next_action() -> int:
	action_counter += 1
	return action_counter

func on_aggression(npc: OfficeNPC, action: int) -> void:
	if population: population.alarm(npc,action)
	if npc.last_hit==action: social.hurt(npc,action)
	staffing.calm[npc.company]=0.0
	close_interaction()
	var warning := career.aggression(npc.company,action,action_counter)
	queue_save()
	if warning!="": say(warning)
	for witness in npcs:
		if not witness.available() or witness==npc or witness.global_position.distance_to(npc.global_position)>8: continue
		if not can_see(witness,npc): continue
		if witness.role=="guard":
			witness.hostile=15
			witness.mood="介入：请停止动手"
		elif witness.role=="friend":
			witness.mood="别打了，我去找人帮忙"
			witness.reaction=5
		else:
			witness.mood="紧张：离远一点"
			witness.reaction=3


func npc_for_role(id: String) -> OfficeNPC:
	for npc in npcs:
		if npc.role_id==id and not npc.dead: return npc
	return null

func on_npc_death(npc: OfficeNPC) -> void:
	career.record("death_"+npc.stable_id,npc.title.split(" · ")[0]+"已死亡。岗位等待替代人员到岗，原角色不会复活。")
	staffing.calm[npc.company]=0.0
	say(npc.title.split(" · ")[0]+"已死亡 · 现场平静后安排岗位接替")
	queue_save()

func on_property_hit(prop: OfficeProp, action: int) -> void:
	for npc in npcs:
		if not npc.dead and npc.position.distance_to(prop.position)<8 and can_see(npc,prop):
			on_aggression(npc,action)
			return

func relationship(npc: OfficeNPC) -> String:
	return social.describe(npc)

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
	initial_state=SaveGame.snapshot(self)
	persistence_enabled=get_tree().current_scene==self
	if persistence_enabled:
		if FileAccess.file_exists(save_path): load_game()
		else: import_previous(OS.get_user_data_dir().get_base_dir().path_join("今天不上班/neighborhood.json"))

func queue_save() -> void:
	if persistence_enabled: save_delay=0.4

func save_game(show_message: bool = true) -> bool:
	if not persistence_enabled: return false
	var error := SaveGame.write(self,save_path)
	if error!=OK: say("保存失败："+error_string(error)+"。旧档保留，请检查磁盘空间。")
	elif show_message: say("已保存。F9 继续此存档，F5 再次保存。")
	return error==OK

func load_game() -> void:
	if not persistence_enabled: return
	var data := SaveGame.read(save_path,self)
	var backup := false
	if data.is_empty():
		data=SaveGame.read(save_path+".bak",self)
		backup=true
	if data.is_empty():
		say("没有有效存档。损坏文件保留；当前世界未被清空。")
		return
	SaveGame.restore(self,data)
	save_delay=-1
	say("主档损坏，已恢复有效备份；损坏文件保留。" if backup else "已继续存档：装备、成果、工资和公司后果均已恢复。")

func toggle_menu() -> void:
	panels.toggle("pause")

func new_game() -> void:
	if not persistence_enabled: return
	var archive := SaveGame.archive(self,archive_directory)
	if archive.is_empty():
		say("备份失败，未重开。当前世界和旧档保留。")
		return
	SaveGame.restore(self,initial_state.duplicate(true))
	panels.show_page("")
	if save_game(false): say("新的一天。旧进度已备份，可在菜单恢复。")

func restore_previous() -> void:
	if not persistence_enabled: return
	var archives := SaveGame.archives(archive_directory)
	if archives.is_empty():
		say("尚无重开备份。")
		return
	var data := SaveGame.read(archives[0],self)
	if data.is_empty():
		say("备份校验失败，当前世界未改变。")
		return
	if SaveGame.archive(self,archive_directory).is_empty():
		say("当前进度备份失败，未执行恢复。")
		return
	SaveGame.restore(self,data)
	panels.show_page("")
	if save_game(false): say("已恢复上一次进度；刚才的进度也已备份。")

func repair_migrated_positions(revision: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if revision!=restore_revision: return
	for actor in [player]+npcs:
		if actor==player and in_vehicle(): continue
		if actor!=player and (actor.dead or actor.care_state!="awake"): continue
		var origin: Vector3=actor.position
		if position_clear(actor,origin): continue
		var found := false
		for radius in [0.5,1.0,1.5,2.0,3.0]:
			for step in range(16):
				var candidate: Vector3 = origin+Vector3(sin(step*TAU/16),0,cos(step*TAU/16))*radius
				if position_clear(actor,candidate):
					actor.position=candidate
					found=true
					break
			if found: break
		if not found and actor==player: player.position=safe_spawn(origin)

func position_clear(actor: CharacterBody3D,point: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius=0.27
	shape.height=1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=3
	query.margin=0.001
	query.transform.origin=Vector3(point.x,maxf(point.y,0)+0.89,point.z)
	query.exclude=[actor.get_rid()]
	if actor.seat_body:
		var exceptions := query.exclude
		exceptions.append(actor.seat_body.get_rid())
		query.exclude=exceptions
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func import_previous(path: String) -> bool:
	if not persistence_enabled or FileAccess.file_exists(save_path): return false
	var data := SaveGame.read(path,self)
	if data.is_empty(): data=SaveGame.read(path+".bak",self)
	if data.is_empty():
		if FileAccess.file_exists(path): say("旧版存档未能读取，原文件保持原样。可继续新世界，或在旧版中检查备份。")
		return false
	if not SaveGame.restore(self,data): return false
	if not save_game(false): return false
	save_delay=-1
	say("已将旧版进度复制到0.5.0独立存档，原档保留。想体验新开局可在Esc选择新游戏。")
	return true

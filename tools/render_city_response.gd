extends "res://tools/render_character_candidates.gd"

func _initialize() -> void:
	super._initialize()
	root.set_flag(Window.FLAG_NO_FOCUS,true)

func key(viewport: SubViewport,code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		viewport.push_input(event,true)

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	if root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Background rendering guard: mode=%s native=%s unfocusable=%s mouse=%s" % [root.mode,DisplayServer.window_get_mode(),root.get_flag(Window.FLAG_NO_FOCUS),Input.mouse_mode]); quit(1); return
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for person in game.population.residents:
		person.set_physics_process(false)
		person.position=Vector3(26+person.index*2,0,24)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=58
	camera.position=Vector3(25,7,60)
	camera.look_at(Vector3(16,1,76))
	if not await capture(viewport,"response-station"): quit(1); return
	var patient: CityResident=game.population.residents[2]
	patient.position=Vector3(-76,0,58)
	patient.from_node="west_in"; patient.destination="market"; patient.route.assign(["west_out","market"]); patient.crossing="market"
	patient.hit(Vector3.FORWARD,10,game.next_action())
	patient.set_physics_process(true)
	game.player.position=Vector3(-76,0,60)
	game.player.yaw=0
	for i in range(45): await physics_frame
	key(viewport,KEY_E)
	if game.speaker!=patient: push_error("Report interaction missing"); quit(1); return
	camera.position=Vector3(-68,4,63)
	camera.look_at(Vector3(-76,.5,58))
	if not await capture(viewport,"scene-report"): quit(1); return
	key(viewport,KEY_1)
	game.player.position=Vector3(-65,0,64)
	var stages := {}
	for i in range(18000):
		await physics_frame
		var phase: String=game.response.cases[patient.stable_id].phase
		var shot := ""
		if phase=="approaching" and game.response.crew.position.distance_to(patient.position)<14 and not stages.has("crew-arrival"): shot="crew-arrival"
		if phase=="assessing" and game.response.elapsed>2 and not stages.has("scene-assessment"): shot="scene-assessment"
		if phase=="transporting" and not stages.has("scene-transfer"): shot="scene-transfer"
		if phase=="transporting" and game.response.crew.position.x> -40 and not stages.has("return-through-city"): shot="return-through-city"
		if phase=="received" and not stages.has("station-received"): shot="station-received"
		if shot!="":
			if shot=="station-received":
				for j in range(150): await physics_frame
			var focus: Vector3=patient.position if shot=="station-received" else game.response.crew.position
			camera.position=focus+Vector3(7,4.5,7)
			camera.look_at(focus+Vector3.UP)
			if shot=="station-received":
				camera.position=Vector3(16,2.6,76)
				camera.look_at(patient.position+Vector3.UP)
			if not await capture(viewport,shot): quit(1); return
			stages[shot]={"phase":phase,"crew":SaveGame.vector(game.response.crew.position),"patient":SaveGame.vector(patient.position),"hp":patient.hp}
		if phase=="received": break
	if stages.size()!=5: push_error("Not every physical response stage completed: "+str(stages)); quit(1); return
	game.panels.show_page("city")
	if not await capture(viewport,"response-map"): quit(1); return
	var data := {"images":captures,"stages":stages,"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"root_hidden":not root.visible,"root_minimized":root.mode==Window.MODE_MINIMIZED,"root_unfocusable":root.get_flag(Window.FLAG_NO_FOCUS),"root_focused":root.has_focus(),"real_report_input":true,"death_preserved":patient.hp==0,"physical_transfer":true,"final_visual_acceptance":false}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("CITY_RESPONSE_RENDER images=",captures," stages=",stages.keys()," root_minimized=",root.mode==Window.MODE_MINIMIZED," root_focused=",root.has_focus()," pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	viewport.queue_free()
	await process_frame
	quit()

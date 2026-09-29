extends "res://tools/render_character_candidates.gd"

func key(viewport: SubViewport,code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		viewport.push_input(event,true)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.set_disable_input(true)
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=58
	var states := {}
	for i in range(5400):
		await physics_frame
		for person in game.population.residents:
			var id: String=person.crossing if person.crossing!="" else person.requested_crossing()
			if id=="": continue
			var shot: String="crossing-"+id if person.crossing!="" else "waiting-"+id
			if states.has(shot) or person.state not in ["walking","waiting"]: continue
			var ends: Array=CityPopulation.CROSSINGS[id]
			var middle: Vector3=(CityPopulation.POINTS[ends[0]]+CityPopulation.POINTS[ends[1]])/2
			if person.crossing!="" and person.position.distance_to(middle)>2: continue
			if person.crossing=="" and person.state!="waiting": continue
			camera.position=middle+Vector3(10,5,10)
			camera.look_at(middle+Vector3.UP)
			states[shot]={"resident":person.stable_id,"position":SaveGame.vector(person.position),"state":person.state,"crossing":person.crossing,"gate":game.population.crossings[id].duplicate(true)}
			if not await capture(viewport,shot): quit(1); return
		if states.has("crossing-market") and states.has("crossing-homes") and states.has("crossing-waterfront") and i>2400: break
	if not states.has("crossing-market") or not states.has("crossing-homes") or not states.has("crossing-waterfront"):
		push_error("Graphical population did not naturally use every crossing"); quit(1); return
	var resident: CityResident
	for person in game.population.residents:
		if person.available() and person.crossing=="" and absf(person.position.x)<65:
			resident=person
			break
	if resident==null: push_error("No resident available for graphical conversation"); quit(1); return
	game.player.position=resident.position+Vector3(0,0,1.5)
	game.player.yaw=0
	for i in range(3): await physics_frame
	viewport.set_disable_input(false)
	key(viewport,KEY_E)
	if game.speaker!=resident: push_error("Graphical E conversation missed resident"); quit(1); return
	camera.position=resident.position+Vector3(3.7,2.6,4)
	camera.look_at(resident.position+Vector3(0,1,.65))
	if not await capture(viewport,"resident-talk"): quit(1); return
	key(viewport,KEY_1)
	if not await capture(viewport,"resident-directions"): quit(1); return
	key(viewport,KEY_1)
	var attack := InputEventAction.new()
	attack.action="attack"
	attack.pressed=true
	viewport.push_input(attack,true)
	attack=attack.duplicate()
	attack.pressed=false
	viewport.push_input(attack,true)
	for i in range(45): await physics_frame
	if resident.hits==0 or resident.fear==0: push_error("Graphical attack did not produce resident response"); quit(1); return
	camera.position=resident.position+Vector3(4,2.8,6)
	camera.look_at(resident.position+Vector3.UP)
	if not await capture(viewport,"resident-avoid-danger"): quit(1); return
	viewport.set_disable_input(true)
	# Offscreen cost samples measure submitted work, not displayed game FPS.
	var samples: Array[float]=[]
	var drawn_before := Engine.get_frames_drawn()
	for i in range(360):
		var start := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw(false)
		if i>=60: samples.append((Time.get_ticks_usec()-start)/1000.0)
	var sorted := samples.duplicate()
	sorted.sort()
	var performance := {"kind":"offscreen_process_plus_force_draw_wall_ms_not_game_fps","renderer":RenderingServer.get_current_rendering_method(),"resolution":[1440,900],"samples_ms":samples,"p95_ms":sorted[int(sorted.size()*.95)],"frames_drawn_delta":Engine.get_frames_drawn()-drawn_before,"public_residents":12,"traffic":3,"final_performance_accepted":false}
	var data := {"images":captures,"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"root_hidden":not root.visible,"natural_crossings":states,"real_E_and_attack":true,"resident":resident.stable_id,"hits":resident.hits,"fear":resident.fear,"performance":performance}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("CITY_POPULATION_RENDER images=",captures," crossings=",states.keys()," pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE," offscreen_p95_ms=",performance.p95_ms," not_game_fps=true")
	quit()

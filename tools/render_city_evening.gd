extends "res://tools/render_city_outing.gd"

func choose(viewport: Viewport,game: Node3D,action: String) -> bool:
	var choices: Array=game.conversation.get("choices",[])
	for i in range(choices.size()):
		if choices[i][1]==action:
			key(viewport,KEY_1+i)
			return true
	push_error("Evening choice missing: "+action+" "+str(game.conversation))
	return false

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false)
	var camera := Camera3D.new()
	game.add_child(camera); camera.fov=55
	var crossing := SaveGame.read("res://build/c3g/office-crossing.json",game)
	if crossing.is_empty() or not SaveGame.restore(game,crossing): push_error("Missing physical office crossing save"); quit(1); return
	for i in range(10): await physics_frame
	game.update_daylight(); camera.make_current()
	camera.position=Vector3(10,7,21); camera.look_at(Vector3(3,0,9))
	if not guard() or not await capture(viewport,"office-crossing"): quit(1); return
	var saved := SaveGame.read("res://build/c3g/first-arrived.json",game)
	if saved.is_empty() or not SaveGame.restore(game,saved): push_error("Missing actual evening arrival"); quit(1); return
	for i in range(10): await physics_frame
	game.update_daylight()
	var observations := []
	for item in [["a_friend","bookshop","people_listen"],["a_group","garden","people_boundary"],["b_friend","waterfront","people_city_quiet"]]:
		var npc: OfficeNPC=game.npc_for_role(item[0])
		if CityEvening.at_place(npc)!=item[1]: push_error("Evening subject is not at their actual destination"); quit(1); return
		camera.make_current()
		camera.position=npc.position+Vector3(4,2.5,4)
		camera.look_at(npc.position+Vector3(0,1.0,0))
		for i in range(20): await physics_frame
		if not guard() or not await capture(viewport,item[0]+"-own-time"): quit(1); return
		# Nearby player placement is a labelled interaction fixture. Autonomous
		# arrival was physical; player traversal is covered by city_evening_test.
		game.player.position=npc.position+Vector3(0,0,1.7)
		game.player.camera.make_current()
		game.player.yaw=0; game.player.pitch=-.05
		for i in range(20): await physics_frame
		key(viewport,KEY_E)
		if game.speaker!=npc or not choose(viewport,game,"people_evening_join") or not choose(viewport,game,"people_share"): quit(1); return
		for i in range(35): await physics_frame
		if not guard() or not await capture(viewport,item[0]+"-encounter"): quit(1); return
		if not choose(viewport,game,item[2]): quit(1); return
		if not await capture(viewport,item[0]+"-response"): quit(1); return
		observations.append({"person":npc.stable_id,"venue":item[1],"reply":game.social.state(npc).city[item[1]].reply})
		game.close_interaction()
		for i in range(10): await physics_frame
	var second := SaveGame.read("res://build/c3g/second-arrived.json",game)
	if second.is_empty() or not SaveGame.restore(game,second): push_error("Missing second physical arrival"); quit(1); return
	for i in range(10): await physics_frame
	game.update_daylight(); camera.make_current()
	camera.position=Vector3(32,3,123); camera.look_at(Vector3(27,1,116))
	if not guard() or not await capture(viewport,"later-waterfront"): quit(1); return
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify({"images":captures,"encounters":observations,"actual_arrival_saves":true,"player_nearby_fixtures":true,"root_minimized":true,"root_unfocusable":true,"root_focused":false,"pointer_visible":true,"normal_fps_measured":false,"independent_player_acceptance":false},"\t")+"\n")
	print("CITY_EVENING_RENDER images=",captures," guard=",guard())
	viewport.queue_free(); await process_frame; quit()

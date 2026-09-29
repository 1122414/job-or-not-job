extends "res://tools/render_city_day_cycle.gd"

var travelling := false

func record_step(game: Node3D) -> void:
	var distance: float=game.player.position.distance_to(player_previous)
	if travelling:
		metres+=distance;max_step=maxf(max_step,distance)
	player_previous=game.player.position
	desktop_safe=desktop_safe and guard()

func go(game: Node3D,points: Array) -> bool:
	travelling=true
	for point in points:
		if not await walk_to(game,point):travelling=false;return false
	travelling=false
	return true

func use_home(viewport: SubViewport,game: Node3D,id: String) -> bool:
	var point: CityHomePoint=game.home.point_for(id)
	var direction: Vector3=point.position-game.player.position
	game.player.yaw=atan2(-direction.x,-direction.z)
	for i in range(8):await physics_frame
	if game.nearest()!=point:push_error("Home graphical selection missed "+id);return false
	key(viewport,KEY_E)
	return guard()

func views(viewport: SubViewport,game: Node3D) -> bool:
	var camera := Camera3D.new()
	game.add_child(camera);camera.fov=65;camera.make_current()
	game.player.hide()
	for item in [
		["entrance-day",Vector3(61,2.0,44),Vector3(56,1.7,36),600],
		["living-day",Vector3(56.4,1.8,37.5),Vector3(61,1.2,32),600],
		["bedroom-day",Vector3(54.3,1.8,31.5),Vector3(51.5,1.1,27),600],
		["living-night",Vector3(56.4,1.8,37.5),Vector3(61,1.2,32),1230]
	]:
		game.payroll.minute=item[3];game.update_daylight()
		camera.position=item[1];camera.look_at(item[2])
		if not guard() or not await capture(viewport,item[0]):return false
	game.player.show();game.player.camera.make_current();camera.queue_free()
	return true

func seat_views(viewport: SubViewport,game: Node3D) -> bool:
	var saved := SaveGame.read(source,game)
	if saved.is_empty() or not SaveGame.restore(game,saved):push_error("Actual seated route required");return false
	for i in range(40):await physics_frame
	if not game.home.sitting():return false
	var camera := Camera3D.new()
	game.add_child(camera);camera.fov=60;camera.make_current()
	for item in [["sofa-front",Vector3(59.6,1.35,31.8)],["sofa-side",Vector3(62.5,1.1,35.4)]]:
		camera.position=item[1];camera.look_at(CityHome.SEAT+Vector3(0,.85,0))
		if not guard() or not await capture(viewport,item[0]):return false
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	if "--seat-inspection" in OS.get_cmdline_user_args():
		game.set_process(false)
		if not await seat_views(viewport,game):quit(1);return
		print("CITY_HOME_SEAT_VIEWS images=",captures," guard=",guard())
		viewport.queue_free();await process_frame;quit();return
	if "--views-only" in OS.get_cmdline_user_args():
		game.set_process(false)
		if not await views(viewport,game):quit(1);return
		print("CITY_HOME_VIEWS images=",captures," guard=",guard())
		viewport.queue_free();await process_frame;quit();return
	# Initial location/time only. Thereafter walking uses input, while the
	# sofa uses the same bounded sit/stand placement as the player's E action.
	game.payroll.minute=1110;game.player.position=Vector3(0,0,23);game.player.pitch=-.08
	game.update_daylight()
	player_previous=game.player.position
	var monitor: Callable=record_step.bind(game)
	physics_frame.connect(monitor)
	key(viewport,KEY_M)
	for i in range(5):await process_frame
	var view: GamePageView=game.panels.view
	var button: Button=view.buttons["city-home"]
	view.scroll.ensure_control_visible(button)
	for i in range(5):await process_frame
	if not await shot(viewport,game,"home-map"):quit(1);return
	var click := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=click;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		viewport.push_input(event,true)
	if not game.home.guiding or game.navigation_target()!=game.home.entrance or game.panels.page!="":push_error("Actual home map click failed");quit(1);return
	if not await go(game,[Vector3(0,0,58),Vector3(58,0,58),Vector3(58,0,44),Vector3(56,0,42)]):quit(1);return
	if not await shot(viewport,game,"arrive-home"):quit(1);return
	if not await go(game,[Vector3(56,0,37),Vector3(56,0,34.5),Vector3(59.6,0,34.3)]):quit(1);return
	if not await use_home(viewport,game,"home_sofa") or not game.home.sitting():push_error("Actual sofa input failed");quit(1);return
	game.player.yaw=-1.15;game.player.pitch=-.12
	for i in range(45):await physics_frame
	if not await shot(viewport,game,"sofa-evening"):quit(1);return
	if SaveGame.write(game,output.path_join("seated-route.json"))!=OK:push_error("Actual seated route invalid");quit(1);return
	Input.action_press("forward")
	for i in range(4):await physics_frame
	Input.action_release("forward")
	for i in range(10):await physics_frame
	if game.player.seated:push_error("Actual sofa stand input failed "+str(game.player.position)+" "+game.hud.toast);quit(1);return
	if not await go(game,[Vector3(56,0,34.5),Vector3(56,0,37),Vector3(57.9,0,37.1)]):quit(1);return
	if not await use_home(viewport,game,"home_light") or game.home.lights_on:quit(1);return
	if not await shot(viewport,game,"home-lights-off"):quit(1);return
	if not await use_home(viewport,game,"home_light") or not game.home.lights_on:quit(1);return
	if not await go(game,[Vector3(60.5,0,37.8)]):quit(1);return
	if not await use_home(viewport,game,"home_curtain") or not game.home.curtains_closed:quit(1);return
	if not await shot(viewport,game,"curtains-closed"):quit(1);return
	if not await go(game,[Vector3(61.6,0,36),Vector3(61.6,0,33)]):quit(1);return
	if not await use_home(viewport,game,"home_picture") or not choose(viewport,game,"home_picture_2"):quit(1);return
	if not await shot(viewport,game,"chosen-postcard"):quit(1);return
	if not await go(game,[Vector3(61.6,0,31),Vector3(57,0,31),Vector3(56,0,33.3),Vector3(53.6,0,33.3),Vector3(53.6,0,29.1),Vector3(51.95,0,29.1)]):quit(1);return
	if not await use_home(viewport,game,"home_bed") or not await shot(viewport,game,"rest-choice"):quit(1);return
	var before: Vector3=game.player.position
	if not choose(viewport,game,"home_morning") or game.payroll.minute!=1980 or game.player.position!=before:push_error("Actual morning choice failed");quit(1);return
	if not await shot(viewport,game,"next-morning"):quit(1);return
	if SaveGame.write(game,output.path_join("morning-route.json"))!=OK:quit(1);return
	if not await go(game,[Vector3(53.6,0,29.1),Vector3(53.6,0,33.3),Vector3(56,0,33.3),Vector3(56,0,37),Vector3(56,0,42),Vector3(58,0,44),Vector3(58,0,58),Vector3(0,0,58),Vector3(0,0,23)]):quit(1);return
	if not await shot(viewport,game,"back-to-city"):quit(1);return
	physics_frame.disconnect(monitor)
	var result := {"images":captures,"visits":visits,"actual_map_click":true,"actual_E_and_choices":true,"walking_metres":metres,"walking_max_step":max_step,"bounded_sofa_sit_stand":true,"clock_from":1110,"clock_to":game.payroll.minute,"background_guard":desktop_safe and guard(),"persistence":game.persistence_enabled,"normal_player_camera":true,"normal_game_fps":false,"independent_player_acceptance":false}
	if not desktop_safe or not guard() or game.persistence_enabled or metres<230 or max_step>.2:push_error("Home route failed "+JSON.stringify(result));quit(1);return
	FileAccess.open(output.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CITY_HOME_ROUTE_OK ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit()

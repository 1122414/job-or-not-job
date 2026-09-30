extends SceneTree

# Works from source or as an external script in the actual packaged app.
var output := ""
var completed := 0
var metres := 0.0
var max_step := 0.0
var costs := []
var images := []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func draw() -> bool:
	var before := completed
	var start := Time.get_ticks_usec()
	RenderingServer.force_draw(false)
	costs.append((Time.get_ticks_usec()-start)/1000.0)
	for pending in range(3):
		if completed>before:break
		await process_frame
	return completed>before and guard()

func frames(count: int) -> bool:
	for frame in range(count):
		await process_frame
		if not await draw():return false
	return true

func shot(viewport: SubViewport,title: String) -> bool:
	var picture := viewport.get_texture().get_image()
	if picture==null or picture.is_empty() or picture.save_png(output.path_join(title+".png"))!=OK:return false
	images.append(title);return guard()

func walk(game: Node3D,viewport: SubViewport,point: Vector3,title: String) -> bool:
	for frame in range(1200):
		var offset: Vector3=point-game.player.position;offset.y=0
		if offset.length()<.18:
			Input.action_release("forward")
			return await frames(5) and shot(viewport,title)
		game.player.yaw=atan2(-offset.x,-offset.z)
		var before: Vector3=game.player.position
		Input.action_press("forward")
		await physics_frame
		var distance: float=before.distance_to(game.player.position)
		metres+=distance;max_step=maxf(max_step,distance)
		if not await draw():return false
	Input.action_release("forward");return false

func key(viewport: SubViewport,code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		viewport.push_input(event,true)

func fail(message: String) -> void:
	Input.action_release("forward");push_error(message);quit(1)

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	if output.is_empty() or DisplayServer.get_name()=="headless":fail("Require graphical output directory");return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	if not BuildInfo.read().is_empty() and (FileAccess.file_exists("res://tools/city_lighting_bake.gd") or ResourceLoader.exists("res://production/lighting/2026-09-30-room-gi/baked/home.res")):
		fail("Production-only resources leaked into package");return
	RenderingServer.frame_post_draw.connect(func():completed+=1)
	for frame in range(10):await physics_frame
	if not game.room_lighting.available or game.persistence_enabled:fail("Runtime room lighting unavailable or player persistence enabled");return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--restore="):
			var stored := SaveGame.read(argument.trim_prefix("--restore="),game)
			paused=true
			if stored.is_empty() or not SaveGame.restore(game,stored) or game.home.lights_on:fail("Independent lamp save restore failed");return
			if not await frames(128) or not game.room_lighting.pending.is_empty() or not shot(viewport,"independent-restore"):fail("Independent lamp refresh failed");return
			FileAccess.open(output.path_join("restore.json"),FileAccess.WRITE).store_string(JSON.stringify({"build_id":BuildInfo.read().get("build_id","source"),"source_sha256":BuildInfo.read().get("source_sha256",""),"lights_on":game.home.lights_on,"lamp_energy":game.home.room.lamps[0].light_energy,"paused":paused,"guard":guard(),"player_persistence":game.persistence_enabled,"pending":game.room_lighting.pending},"\t")+"\n")
			viewport.queue_free();await process_frame;print("ROOM_LIGHT_INDEPENDENT_RESTORE_OK");quit();return
	game.payroll.minute=1077;game.player.position=Vector3(56,0,44);game.player.pitch=-.08;game.player.yaw=0
	game.update_daylight()
	if not await frames(128):fail("Warmup guard");return
	var start_minute: int=game.payroll.minute
	for item in [[Vector3(56,0,40.5),"approach"],[Vector3(56,0,38.8),"threshold"],[Vector3(56,0,37),"inside"],[Vector3(56,0,34.5),"living"],[Vector3(57.9,0,37.1),"switch"]]:
		if not await walk(game,viewport,item[0],item[1]):fail("Continuous entrance route blocked");return
	var direction: Vector3=game.home.point_for("home_light").position-game.player.position
	game.player.yaw=atan2(-direction.x,-direction.z)
	if not await frames(10):fail("Switch guard");return
	key(viewport,KEY_E)
	if game.home.lights_on or not await frames(100) or not shot(viewport,"lights-off"):fail("Actual lamp E failed");return
	var saved: Dictionary=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
	if SaveGame.write(game,output.path_join("lights-off-save.json"))!=OK:fail("Actual route save failed");return
	key(viewport,KEY_E)
	if not game.home.lights_on or not await frames(100) or not shot(viewport,"lights-on"):fail("Lamp on failed");return
	key(viewport,KEY_ESCAPE)
	if not paused:fail("Menu input failed");return
	var toggle: CheckButton=game.menu.find_child("RoomLighting",true,false)
	var scroll: ScrollContainer=toggle.get_parent().get_parent()
	scroll.ensure_control_visible(toggle)
	if not await frames(5):fail("Settings guard");return
	for expected in [false,true]:
		var click := toggle.get_global_rect().get_center()
		for pressed in [true,false]:
			var event := InputEventMouseButton.new();event.position=click;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			viewport.push_input(event,true)
		if game.room_lighting.enabled!=expected or not await frames(100):fail("Actual graphics setting click failed");return
	if not shot(viewport,"graphics-setting"):fail("Settings capture failed");return
	if not SaveGame.restore(game,saved) or game.home.lights_on:fail("Paused JSON restore failed");return
	if not await frames(100):fail("Paused reflection refresh guard");return
	if not paused:fail("Restore unexpectedly unpaused");return
	key(viewport,KEY_ESCAPE)
	if paused or not await frames(10) or not shot(viewport,"restored-lights-off"):fail("Restore resume failed");return
	key(viewport,KEY_E)
	for item in [[Vector3(56,0,37),"return-inside"],[Vector3(56,0,40.5),"return-threshold"],[Vector3(56,0,44),"street-again"]]:
		if not await walk(game,viewport,item[0],item[1]):fail("Continuous exit route blocked");return
	costs.sort()
	var result := {"build":BuildInfo.read(),"metres":metres,"max_step":max_step,"images":images,"draws":completed,"refresh_requests":game.room_lighting.refresh_count,"start_minute":start_minute,"end_minute":game.payroll.minute,"guard":guard(),"player_persistence":game.persistence_enabled,"actual_lamp_and_menu_input":true,"paused_json_restore":true,"force_draw_wall_ms":{"p95":costs[int((costs.size()-1)*.95)],"max":costs.back()},"normal_game_fps":false,"independent_player_acceptance":false}
	if metres<20 or max_step>.2 or not guard() or start_minute>=1080 or game.payroll.minute<1080:fail("Route incomplete or dusk boundary not crossed");return
	FileAccess.open(output.path_join("walk.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("ROOM_LIGHT_WALK_OK metres=",metres," draws=",completed," guard=",guard()," paused_restore=true")
	viewport.queue_free();await process_frame;quit()

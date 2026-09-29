extends SceneTree

var output := ""
var images: Array[String]=[]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func key(viewport: SubViewport,code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		viewport.push_input(event,true)

func capture(viewport: SubViewport,title: String) -> bool:
	for i in range(3):await process_frame;RenderingServer.force_draw(false)
	var picture := viewport.get_texture().get_image()
	if not guard() or picture==null or picture.is_empty() or picture.save_png(output.path_join(title+".png"))!=OK:return false
	images.append(title);return true

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	root.set_disable_input(true)
	if output=="":push_error("Package home output path required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var build := BuildInfo.read()
	if build.is_empty() or build.save_schema!=22:push_error("Package home identity missing");quit(1);return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	game.set_process(false);game.payroll.minute=1140;game.update_daylight()
	# These are labelled visual/interaction fixtures. The project route covers
	# continuous traversal; this probe checks the actual packaged renderer/input.
	game.player.position=CityHome.CENTER+Vector3(0,0,5.5);game.player.yaw=0;game.player.pitch=-.05
	for i in range(20):await physics_frame
	if not await capture(viewport,"home-evening"):quit(1);return
	game.player.position=CityHome.CENTER+Vector3(-4.05,0,-2.8);game.player.yaw=0
	for i in range(20):await physics_frame
	key(viewport,KEY_E)
	if game.speaker!=game.home.point_for("home_bed") or not await capture(viewport,"bed-options"):push_error("Package bed E failed");quit(1);return
	key(viewport,KEY_1)
	if game.payroll.minute!=1980 or game.home.last_rest!=1980 or not await capture(viewport,"home-morning"):push_error("Package rest input failed");quit(1);return
	game.player.position=CityHome.SEAT+Vector3(0,0,-1.45);game.player.yaw=PI
	for i in range(10):await physics_frame
	key(viewport,KEY_E)
	if not game.home.sitting():push_error("Package sofa E failed");quit(1);return
	game.player.yaw=PI
	for i in range(60):await physics_frame
	if not await capture(viewport,"home-sofa"):quit(1);return
	var saved := JSON.parse_string(JSON.stringify(SaveGame.snapshot(game))) as Dictionary
	if not SaveGame.restore(game,saved):push_error("Package home save restore failed");quit(1);return
	for i in range(20):await physics_frame
	if not game.home.sitting():push_error("Package seated JSON restore failed");quit(1);return
	var data := {"build_id":build.build_id,"source_sha256":build.source_sha256,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"images":images,"real_E_and_choice":true,"home_rest":game.home.last_rest,"seated_restore":true,"json_restore":true,"background_guard":guard(),"persistence":game.persistence_enabled,"player_positions_are_fixtures":true,"normal_game_fps":false}
	if not guard() or game.persistence_enabled:push_error("Package home desktop isolation failed");quit(1);return
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("PACKAGED_HOME_GUI_OK ",JSON.stringify(data))
	viewport.queue_free();await process_frame;quit()

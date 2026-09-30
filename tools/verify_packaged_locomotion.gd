extends SceneTree

var output := ""
var images: Array[String]=[]
var metres := 0.0
var maximum_step := 0.0
var previous := Vector3.ZERO
var desktop_safe := true

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func record_step(game: Node3D) -> void:
	var step: float=game.player.position.distance_to(previous)
	metres+=step;maximum_step=maxf(maximum_step,step);previous=game.player.position
	desktop_safe=desktop_safe and guard()

func capture(viewport: SubViewport,title: String) -> bool:
	for i in range(3):await process_frame;RenderingServer.force_draw(false)
	var picture := viewport.get_texture().get_image()
	if not guard() or picture==null or picture.is_empty() or picture.save_png(output.path_join(title+".png"))!=OK:return false
	images.append(title);return true

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	if output=="":push_error("Package locomotion output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var build := BuildInfo.read()
	if build.is_empty():push_error("Actual packaged build required");quit(1);return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10):await physics_frame
	game.player.position=Vector3(-34,0,44);game.player.yaw=PI;game.player.pitch=-.12
	game.payroll.minute=1080;game.update_daylight();previous=game.player.position
	var monitor: Callable=record_step.bind(game);physics_frame.connect(monitor)
	var motions := []
	for part in [["walk-out",.7,false,100],["run-out",1.0,false,70],["fast-out",1.0,true,55],["walk-return",.7,false,80],["run-return",1.0,false,50],["stop",0.0,false,30]]:
		if part[0]=="walk-return":game.player.yaw=0
		Input.action_release("forward");Input.action_release("run")
		if part[1]>0:Input.action_press("forward",part[1])
		if part[2]:Input.action_press("run")
		for frame in range(part[3]):await physics_frame
		var expected := "idle" if part[1]==0 else "walk" if part[1]<1 else "run"
		if game.player.visual.current!=expected or not await capture(viewport,part[0]):push_error("Package motion failed "+part[0]);quit(1);return
		motions.append({"section":part[0],"clip":expected,"position":SaveGame.vector(game.player.position)})
	Input.action_release("forward");Input.action_release("run");physics_frame.disconnect(monitor)
	if not desktop_safe or not guard() or game.persistence_enabled or metres<20 or maximum_step>.15:push_error("Package movement or isolation failed");quit(1);return
	var result := {"build_id":build.build_id,"source_sha256":build.source_sha256,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"images":images,"motions":motions,"metres":metres,"maximum_step":maximum_step,"background_guard":desktop_safe and guard(),"persistence":game.persistence_enabled,"normal_player_camera":true,"simulated_analog_input":true,"normal_game_fps":false}
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("PACKAGED_LOCOMOTION_GUI_OK ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit()

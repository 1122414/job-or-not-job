extends SceneTree

var output := "res://build/c4j/before"
var view: SubViewport
var game: Node3D
var pictures := []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func capture(title: String) -> bool:
	for i in range(4):await process_frame;RenderingServer.force_draw(false)
	var picture := view.get_texture().get_image()
	if not guard() or picture==null or picture.is_empty() or picture.save_png(output.path_join(title+".png"))!=OK:return false
	pictures.append({"name":title,"draw_calls":view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
	return true

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for i in range(10):await physics_frame
	paused=true
	var bus: Node3D=game.transit.bus
	var camera := Camera3D.new();game.add_child(camera);camera.make_current();camera.fov=58
	for shot in [
		["front",Vector3(-5,2.7,-6),Vector3(0,1.4,0)],
		["rear",Vector3(5,2.7,6),Vector3(0,1.4,0)],
		["platform-door",Vector3(-4,1.7,-1.3),Vector3(0,1.4,-1.3)],
		["cabin-forward",Vector3(0,2.0,3),Vector3(0,1.4,-2.9)],
		["cabin-rear",Vector3(0,2,-1.7),Vector3(0,1.4,2.9)],
		["driver",Vector3(.65,2,-1.6),Vector3(-.65,1.35,-2.8)]]:
		camera.position=bus.to_global(shot[1]);camera.look_at(bus.to_global(shot[2]))
		if not await capture(shot[0]):quit(1);return
	if game.transit.get("visual")!=null:
		var model: Node3D=game.transit.visual
		for amount in [0.0,.5,1.0]:
			model.door_open=amount;model.apply_doors()
			camera.position=bus.to_global(Vector3(-4,1.7,-1.3));camera.look_at(bus.to_global(Vector3(0,1.4,-1.3)))
			if not await capture("door-"+str(int(amount*100))):quit(1);return
		model.door_open=1;model.apply_doors()
		# Explicit pose fixtures complement the natural shared-ride probe.
		for outfit in ["casual","office","office_female"]:
			var human := HumanVisual.new();human.outfit=outfit;bus.add_child(human)
			human.position=CityPassengers.SEATS[0]+human.seated_offset
			human.animation.play("sit",0);human.animation.advance(.4);human.animation.pause()
			camera.position=bus.to_global(Vector3(.9,1.8,-1.7));camera.look_at(bus.to_global(CityPassengers.SEATS[0]+Vector3(0,.5,0)))
			if not await capture("seated-"+outfit):quit(1);return
			human.queue_free();await process_frame
	game.payroll.minute=20*60;game.update_daylight()
	camera.position=bus.to_global(Vector3(0,2,3));camera.look_at(bus.to_global(Vector3(0,1.4,-2.9)))
	if not await capture("cabin-night"):quit(1);return
	var result := {"images":pictures,"background_guard":guard(),"persistence":game.persistence_enabled,"fixture_cameras":true,"normal_game_fps":false,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	paused=false;game.queue_free();await process_frame
	print("CITY_BUS_RENDER_OK ",JSON.stringify(result));quit()

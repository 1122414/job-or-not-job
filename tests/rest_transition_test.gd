extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message);failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(6): await physics_frame
	game.set_process(false)
	var baseline := SaveGame.snapshot(game)
	for pair in [[540,1080],[1140,1980],[540,540+Payroll.DAY*28]]:
		SaveGame.restore(game,baseline)
		for i in range(3): await physics_frame
		game.payroll.minute=pair[0]
		game.player.position=Vector3(52,0,29)
		var position: Vector3=game.player.position
		var old_camera: Camera3D=game.get_viewport().get_camera_3d()
		game.rest_until(pair[1])
		check(paused and game.rest_transition.active and game.payroll.minute==pair[1],"MOT03 starts montage and settles calendar once")
		var before := SaveGame.snapshot(game)
		var colors := []
		game.rest_transition.set_process(false)
		for i in range(25):
			game.rest_transition._process(.16)
			colors.append(game.environment.sky.sky_material.sky_horizon_color)
			await physics_frame
		check(colors[4]!=colors[18] and game.player.position==position,"MOT03 sky interpolates while physical world paused")
		check(game.get_viewport().get_camera_3d()==game.rest_transition.camera,"MOT03 exterior camera shows sky")
		var key := InputEventKey.new();key.keycode=KEY_E;key.physical_keycode=KEY_E;key.pressed=true;root.push_input(key,true)
		check(game.rest_transition.active and game.conversation.is_empty() and game.panels.page=="","MOT03 E cannot open dialogue/menu mid-montage")
		key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.physical_keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,true)
		check(not paused and not game.rest_transition.active and game.get_viewport().get_camera_3d()==old_camera,"MOT03 Esc skips and restores camera")
		var after := SaveGame.snapshot(game)
		check(after==before,"MOT03 skip never repeats calendar rewards")
		game.rest_until(game.payroll.minute+1440)
		check(SaveGame.restore(game,before) and not game.rest_transition.active and not paused,"MOT03 load cancels presentation")
	game.rest_transition.set_process(true)
	game.rest_until(game.payroll.minute+1440)
	for i in range(330): await process_frame
	check(not game.rest_transition.active and not paused,"MOT03 natural completion restores input")
	print("REST_TRANSITION_TEST failures=",failures)
	game.queue_free();await process_frame;quit(failures)

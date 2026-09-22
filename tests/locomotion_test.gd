extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.player.position=Vector3(0,0,12)
	game.player.yaw=0
	for action in ["right","back","left","forward"]:
		var before: Vector3=game.player.position
		Input.action_press(action)
		for i in range(30): await physics_frame
		Input.action_release(action)
		var moved: Vector3=game.player.position-before
		moved.y=0
		var facing: Vector3=Vector3.FORWARD.rotated(Vector3.UP,game.player.visual.rotation.y)
		check(moved.length()>1.0,"原WASD移动保持有效："+action)
		check(facing.dot(moved.normalized())>0.95,"身体应朝实际行走方向："+action)
		check(is_zero_approx(game.player.yaw),"移动不强行旋转镜头")
	game.player.attack()
	for i in range(10): await physics_frame
	check(absf(wrapf(game.player.visual.rotation.y,-PI,PI))<0.3,"攻击转回准星方向")
	game.queue_free()
	await process_frame
	print("LOCOMOTION_TEST failures=",failures)
	quit(failures)

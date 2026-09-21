extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func walk(game: Node3D, target: Vector3) -> void:
	for i in range(420):
		var diff: Vector3 = target-game.player.position
		diff.y=0
		if diff.length()<0.4: break
		game.player.yaw=atan2(-diff.x,-diff.z)
		Input.action_press("forward")
		await physics_frame
	Input.action_release("forward")
	check(game.player.position.distance_to(target)<1.5,"步行抵达："+str(target)+" 实际 "+str(game.player.position))
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await walk(game,Vector3(-14,0,3))
	await walk(game,Vector3(-14,0,0.5))
	await walk(game,Vector3(-14,0,5))
	await walk(game,Vector3(14,0,5))
	await walk(game,Vector3(14,0,0.5))
	check(game.npcs.size()==10,"两家公司人物存在")
	print("WORLD_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

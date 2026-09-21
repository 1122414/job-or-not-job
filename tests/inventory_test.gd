extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var p = game.player
	var keyboard = game.props[0]
	var cup = game.props[1]
	p.pick(keyboard)
	p.pick(cup)
	check(p.inventory.size()==1 and not keyboard.visible and p.held==cup,"切换时旧手持收纳且只有一个位置")
	p.cycle_item()
	check(p.held==keyboard and p.inventory==[cup],"轮换不复制")
	p.bag_open=true
	p.hurt(100)
	check(p.dead>0 and not p.bag_open,"死亡中断背包")
	for i in range(140): await physics_frame
	check(p.hp==100 and p.protection>0 and p.held==keyboard and p.inventory==[cup],"复活保留装备并保护")
	p.hurt(100)
	check(p.hp==100,"保护阻止连续死亡")
	p.release(true)
	p.protection=0
	p.hurt(100)
	for i in range(140): await physics_frame
	check(p.held==null and not p.inventory.has(keyboard),"投出物不随复活回包")
	var blocker := Shapes.solid(game,Vector3(4,3,4),Vector3(0,1,4),Color.GRAY)
	await physics_frame
	var point: Vector3 = game.safe_spawn(Vector3(0,0,4))
	check(point.distance_to(Vector3(0,0,4))>2,"安全点被堵时选择可用点")
	blocker.queue_free()
	print("INVENTORY_TEST failures=",failures)
	game.audio.stop()
	# The audio mixer uses wall time even when physics is simulated with fixed FPS.
	OS.delay_msec(150)
	await process_frame
	game.queue_free()
	await process_frame
	quit(failures)

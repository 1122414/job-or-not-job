extends SceneTree

var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var npc = game.npcs[0]
	npc.hit(Vector3.FORWARD,1,10)
	var affinity: int = npc.affinity
	npc.hit(Vector3.FORWARD,1,10)
	check(npc.affinity == affinity,"同次攻击应只结算一次")
	check(npc.down > 0,"NPC 应倒地")
	for i in range(200): await physics_frame
	check(npc.down <= 0,"NPC 应恢复")
	var keyboard = game.props[0]
	game.player.pick(keyboard)
	check(game.player.held == keyboard and keyboard.freeze,"小件可持有")
	game.player.release(true)
	check(game.player.held == null and keyboard.thrown and not keyboard.freeze,"投掷进入物理世界")
	var table = game.props[2]
	game.player.pick(table)
	check(game.player.held == null,"大件不能持有")
	check(table.thrown,"桌子可掀翻")
	keyboard.position.y = -20
	await physics_frame
	await physics_frame
	check(keyboard.position.y > -8,"出界物品恢复")
	print("ACTION_TEST failures=",failures)
	game.audio.stop()
	# The audio mixer uses wall time even when physics is simulated with fixed FPS.
	OS.delay_msec(150)
	await process_frame
	game.queue_free()
	await process_frame
	quit(failures)

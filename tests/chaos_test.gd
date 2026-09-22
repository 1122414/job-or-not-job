extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	var opponent: OfficeNPC=game.npc_for_role("a_boss")
	opponent.position=Vector3(0,0,12)
	game.player.position=opponent.position+Vector3(0,0,1.4)
	# Self-defence is now brief and personality-dependent, so exercise recovery from an injured state.
	game.player.hp=36
	game.player.yaw=0
	game.player.pick(game.props[0])
	game.player.pick(game.props[1])
	game.player.attack()
	var died := false
	var revived := false
	for i in range(1500):
		await physics_frame
		if game.player.dead>0: died=true
		if died and game.player.dead<=0 and game.player.hp==100: revived=true
	check(died and revived,"易冲动角色的有限反击能使受伤玩家倒下并恢复")
	check(game.player.held==game.props[1] and game.player.inventory==[game.props[0]],"真实战斗复活保留装备")
	check(game.career.conflict.a>0 and game.career.conflict.b==0,"战斗后果不跨公司传播")
	for i in range(3600):
		if i%120==0:
			var prop = game.props[(i/120)%game.props.size()]
			if prop!=game.player.held and not game.player.inventory.has(prop): prop.strike(Vector3(1,0,-1),game.next_action())
		await physics_frame
	check(game.player.position.is_finite(),"混乱运行角色坐标有效")
	for npc in game.npcs: check(npc.position.is_finite(),"NPC 位置有限")
	game.audio.stop()
	OS.delay_msec(150)
	await process_frame
	print("CHAOS_TEST failures=",failures," simulated_seconds=85")
	game.queue_free()
	await process_frame
	quit(failures)

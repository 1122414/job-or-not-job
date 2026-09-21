extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.payroll.advance(540,"")
	game.player.position=Vector3(0,0,18)
	for i in range(1500): await physics_frame
	for npc in game.npcs:
		if npc.role in ["friend","group"]:
			check(npc.position.z>9,"下班应抵达公共区："+npc.stable_id+str(npc.position))
	print("SCHEDULE_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

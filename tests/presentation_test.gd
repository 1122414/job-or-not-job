extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(180): await physics_frame
	var ground: Node3D
	for node in game.get_children():
		if node is StaticBody3D and node.position==Vector3(0,-0.2,0): ground=node
	check(ground!=null and ground.get_child(0).position.y< -0.02,"基础可见面不能与道路顶面共面")
	var keyboard=game.props[0]
	var table=game.props[2]
	check(absf((keyboard.position.y-OfficeProp.TYPES.keyboard[1].y/2)-(table.position.y+0.11))<0.03,"键盘静置时有桌面支撑，不悬浮")
	game.focus_target=game.npcs[0]
	await physics_frame
	for npc in game.npcs: check(not npc.label.text.contains("\n"),"头顶不堆四行信息")
	game.player.pick(keyboard)
	await physics_frame
	check(keyboard.to_global(keyboard.support_point()).distance_to(game.player.visual.contacts.palm("R").origin)<0.01,"手持物底部支撑点跟随手掌")
	game.player.release(false)
	for i in range(120): await physics_frame
	check(not keyboard.freeze and keyboard.position.y<0.3,"放下后回到物理地面")
	game.queue_free()
	await process_frame
	print("PRESENTATION_TEST failures=",failures)
	quit(failures)

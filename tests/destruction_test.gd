extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	var desk: OfficeProp
	var cup: OfficeProp
	for prop in game.props:
		if prop.kind=="desk": desk=prop
		if prop.kind=="cup": cup=prop
	game.player.position=Vector3(-30,0,20)
	game.player.yaw=0
	desk.position=Vector3(-30,0.72,18.2)
	await physics_frame
	await physics_frame
	game.player.attack()
	for i in range(34): await physics_frame
	check(not desk.damaged and desk.durability==desk.max_durability(),"真实空手攻击不坍塌桌子")
	var first: OfficeNPC=game.npcs[0]
	var second: OfficeNPC=game.npcs[1]
	first.set_physics_process(false);second.set_physics_process(false)
	first.position=Vector3(29.7,0,18)
	second.position=Vector3(30.3,0,18)
	game.player.position=Vector3(30,0,18.75)
	await physics_frame
	await physics_frame
	game.player.cooldown=0
	game.player.attack()
	for i in range(34): await physics_frame
	check(int(first.hp<100)+int(second.hp<100)==1,"一次真实挥击只有一个主要对象受伤")
	for i in range(15): desk.strike(Vector3.FORWARD,game.next_action(),0.4)
	check(not desk.damaged and desk.durability==desk.max_durability(),"徒手不损坏坚固桌体")
	desk.strike(Vector3.FORWARD,game.next_action(),4.0)
	check(not desk.damaged and desk.durability<desk.max_durability(),"重物多次才能破坏桌子")
	var partial: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,partial),"部分耐久状态可保存恢复")
	for i in range(5): desk.strike(Vector3.FORWARD,game.next_action(),4.0)
	check(desk.damaged,"连续有效重击可破坏桌体")
	cup.strike(Vector3.FORWARD,game.next_action(),2.5)
	check(cup.damaged,"杯子比坚固家具易碎")
	check(desk.tip(Vector3.FORWARD,game.next_action()) and not desk.freeze,"明确操作可以推掀家具")
	check(SaveGame.restore(game,SaveGame.snapshot(game)) and desk.tipped and not desk.freeze,"掀翻状态读档保留")
	game.audio.stop()
	OS.delay_msec(150)
	await process_frame
	game.queue_free()
	await process_frame
	print("DESTRUCTION_TEST failures=",failures)
	quit(failures)

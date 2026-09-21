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
	var hr: OfficeNPC = game.npcs[0]
	for stage in [0,1,5]:
		game.career.stage=stage
		game.speaker=hr
		game.conversation={"text":"可中断现场对话","choices":[["继续","brief"]]}
		game.player.swing=0
		game.player.cooldown=0
		var event := InputEventAction.new()
		event.action="attack"
		event.pressed=true
		game.player._unhandled_input(event)
		check(game.conversation.is_empty() and game.player.swing>0,"面试/工作/答辩中应立即动手："+str(stage))
	var guard: OfficeNPC
	for npc in game.npcs:
		if npc.stable_id=="a_guard": guard=npc
	var printer: OfficeProp = game.props[4]
	printer.position=Vector3(-14,0.8,2)
	printer.damaged=true
	game.career.conflict.a=1
	game.player.position=guard.position+Vector3(0,0,1.5)
	game.speaker=guard
	game.conversation={"text":"挪开障碍","choices":[["清理通路","clear_path"]]}
	game.choose(0)
	check(printer.position.distance_to(printer.home)<0.1,"保安可恢复堵路大件的位置")
	check(printer.damaged and game.career.conflict.a==1,"清障不洗掉损坏和后果")
	game.audio.stop()
	OS.delay_msec(150)
	await process_frame
	game.queue_free()
	await process_frame
	print("INTERRUPTION_TEST failures=",failures)
	quit(failures)

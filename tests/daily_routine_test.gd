extends SceneTree
const Driver=preload("res://tests/scene_driver.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.player.position=Vector3(-10,0,-4.9)
	game.social.meet(npc)
	for kind in ["tea","lunch","walk"]:
		game.payroll.advance({"tea":600,"lunch":750,"walk":1110}[kind]-game.payroll.minute,"")
		game.social.handle("people_invite_"+kind,npc)
		if not await Driver.follow(self,game,npc,game.social.destination(npc,kind)): failures+=1; break
		game.speaker=npc
		game.conversation=game.social.options(npc)
		if game.conversation.choices[0][1]!="people_share": failures+=1; break
		game.choose(0)
		game.choose(0)
		if not game.social.outing.is_empty(): failures+=1
		print("DAILY_ROUTE ",kind," ",npc.position)
	game.queue_free()
	await process_frame
	print("DAILY_ROUTINE_TEST failures=",failures)
	quit(failures)

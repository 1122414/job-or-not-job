extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func choose_at(game: Node3D, id: String, action: String) -> void:
	var target: Node3D
	for node in game.targets():
		if node.stable_id==id: target=node
	game.player.position=target.position+Vector3(0,0,1.8)
	game.player.yaw=0
	await physics_frame
	game.interact()
	check(game.speaker==target,"应可接近并互动："+id)
	if game.conversation.is_empty(): return
	var index := -1
	for i in range(game.conversation.choices.size()):
		if game.conversation.choices[i][1]==action: index=i
	check(index>=0,"应显示选项："+action)
	if index>=0: game.choose(index)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	for step in [["a_hr","interview_hr"],["a_lead","interview_lead"],["a_boss","interview_boss"],["a_hr","join_a"],["a_lead","brief"],["archive","data"],["a_friend","shortcut"],["demo","submit"],["a_lead","no_hc"],["a_group","transfer"],["backup","backup"],["a_boss","defend"]]:
		await choose_at(game,step[0],step[1])
	check(game.career.stage==6,"场景交互完整转正")
	game.interact()
	Input.action_press("forward")
	await physics_frame
	await physics_frame
	Input.action_release("forward")
	check(game.conversation.is_empty(),"走开即时关闭对话")
	print("INTERACTION_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

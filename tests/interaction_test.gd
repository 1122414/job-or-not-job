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
	# Place the interaction fixture on a visible approach, not inside the next desk row.
	game.close_interaction()
	game.player.stand_up()
	for sample in range(24):
		var angle := sample*TAU/24
		var offset := Vector3(sin(angle),0,cos(angle))*1.4
		game.player.position=target.position+offset
		game.player.yaw=angle
		await physics_frame
		if game.nearest()==target: break
	game.interact()
	if not game.conversation.is_empty() and game.conversation.choices.size()>0 and game.conversation.choices[0][1]=="visit_confirm":
		game.choose(0)
		game.interact()
	check(game.speaker==target,"应可接近并互动："+id)
	if game.conversation.is_empty(): return
	var index := -1
	for i in range(game.conversation.choices.size()):
		if game.conversation.choices[i][1]==action: index=i
	check(index>=0,"应显示选项："+action)
	if index>=0:
		game.choose(index)
		if action in InterviewFlow.ACTIONS:
			check(await preload("res://tests/scene_driver.gd").complete_interview(self,game,action),"走入独立房间完成交流："+action)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	for step in [["a_hr","interview_hr"],["a_lead","interview_lead"],["a_boss","interview_boss"],["a_hr","join_a"],["a_lead","brief"],["archive","data"],["a_friend","shortcut"],["desk_a","prepare"],["demo","submit"],["a_lead","no_hc"],["a_group","transfer"],["backup","backup"],["a_boss","defend"]]:
		await choose_at(game,step[0],step[1])
	check(game.career.stage==6,"场景交互完整转正")
	game.interact()
	if not game.conversation.is_empty() and game.conversation.choices.size()>0 and game.conversation.choices[0][1]=="visit_confirm":
		game.choose(0)
		game.interact()
	Input.action_press("forward")
	await physics_frame
	await physics_frame
	Input.action_release("forward")
	check(game.conversation.is_empty(),"走开即时关闭对话")
	await choose_at(game,"a_hr","resign")
	for step in [["b_hr","interview_b"],["b_hr","join_b"],["b_friend","refuse"],["b_friend","negotiate"]]:
		await choose_at(game,step[0],step[1])
	for npc in game.npcs:
		if npc.stable_id=="b_boss": game.player.position=npc.home+Vector3(0,0,1.8)
	for i in range(700): await physics_frame
	await choose_at(game,"b_boss","settle")
	check(game.career.b_event=="negotiated","同伴实际到场后交涉完成")
	game.toggle_menu()
	check(paused and game.menu.visible,"菜单暂停世界")
	game.toggle_menu()
	check(not paused and not game.menu.visible,"关闭菜单恢复控制")
	print("INTERACTION_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

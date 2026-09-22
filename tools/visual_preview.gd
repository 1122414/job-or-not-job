extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.player.position=Vector3(-14,0,5)
	game.player.yaw=0
	game.player.pitch=-0.12
	game.player.hp=100

	if OS.get_cmdline_user_args().has("--internship"):
		for action in ["interview_hr","interview_lead","interview_boss","join_a"]: game.career.apply(action)
		game.player.position=OfficeLife.DESKS.desk_a+Vector3(0,0,1.5)
	var interview_action := "interview_hr" if OS.get_cmdline_user_args().has("--interview") else ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--interview="): interview_action=argument.trim_prefix("--interview=")
	if interview_action in InterviewFlow.ACTIONS:
		if interview_action in ["interview_lead","interview_boss"]: game.career.apply("interview_hr")
		if interview_action=="interview_boss": game.career.apply("interview_lead")
		game.interviews.schedule(interview_action)
		var firm := "b" if interview_action=="interview_b" else "a"
		game.player.position=OfficeRooms.INTERVIEW_SEATS[firm]+Vector3(0,0,0.25)
	if OS.get_cmdline_user_args().has("--work"):
		for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data"]: game.career.apply(action)
		game.career.facts.welcome_a=true
		game.career.facts.visit_brief=true
		game.player.position=OfficeLife.DESKS.desk_a+Vector3(0,0,1.2)
	if OS.get_cmdline_user_args().has("--pending"):
		for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data","prepare"]: game.career.apply(action)
		game.career.facts.desk_a_arrived=true
		game.career.facts.visit_state_welcome_a="arrived"
		game.player.position=OfficeLife.DESKS.desk_a+Vector3(0,0,1.2)
	if OS.get_cmdline_user_args().has("--bwelcome"):
		for action in ["interview_b","join_b"]: game.career.apply(action)
		game.career.facts.visit_state_welcome_b="arrived"
		game.player.position=game.npc_for_role("b_friend").position+Vector3(0,0,1.3)
	# Preview-only framing controls for repeatable visual inspection; no career mutation.
	var framing := Node.new()
	framing.set_script(load("res://tools/preview_framing.gd"))
	framing.game=game
	game.add_child(framing)

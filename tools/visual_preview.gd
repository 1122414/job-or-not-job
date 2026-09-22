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
	# Preview-only framing controls for repeatable visual inspection; no career mutation.
	var framing := Node.new()
	framing.set_script(load("res://tools/preview_framing.gd"))
	framing.game=game
	game.add_child(framing)

extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(180): await physics_frame
	for firm in ["a","b"]:
		var chair: OfficeProp=game.props.filter(func(prop): return prop.stable_id==firm+"_chair")[0]
		# Free chairs previously had only seat/back collision; their wheels fell through the floor.
		check(chair.position.y>0.46 and chair.position.y<0.62,"自由办公椅由轮脚支撑，不沉入地面："+firm)
		check(chair.rotation.length()<0.05,"未受力自由椅保持直立："+firm)
		chair.freeze=true
		chair.position=Vector3(-14 if firm=="a" else 14,1.8,1)
		chair.linear_velocity=Vector3.ZERO
		chair.angular_velocity=Vector3.ZERO
		chair.freeze=false
		chair.sleeping=false
	for i in range(240): await physics_frame
	for firm in ["a","b"]:
		var chair: OfficeProp=game.props.filter(func(prop): return prop.stable_id==firm+"_chair")[0]
		check(chair.position.y>0.46 and chair.position.y<0.62,"垂直落下后轮脚仍支撑："+firm)
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,saved),"有支撑的自由椅状态可恢复")
	game.queue_free()
	await process_frame
	print("CHAIR_SUPPORT_TEST failures=",failures)
	quit(failures)

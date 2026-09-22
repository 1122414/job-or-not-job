extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	game.player.walk_speed=2.5
	for firm in ["a","b"]:
		var destination: Vector3=OfficeRooms.INTERVIEW_SEATS[firm]
		var route: PackedVector3Array=game.walking.route(game.player.position,destination)
		check(not route.is_empty(),"街道至面试室有路线 "+firm)
		for point in route:
			for i in range(100):
				var offset: Vector3=point-game.player.position
				offset.y=0
				if offset.length()<0.20: break
				game.player.yaw=atan2(-offset.x,-offset.z)
				Input.action_press("forward")
				await physics_frame
		Input.action_release("forward")
		check(Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<0.65,"实际步行进入面试室 "+firm)
	game.queue_free()
	await process_frame
	print("ROOMS_TEST failures=",failures)
	quit(failures)

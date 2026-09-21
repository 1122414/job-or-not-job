extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.player.position=Vector3(-14,0,0)
	game.player.yaw=0
	game.player.pitch=-0.12
	game.player.hp=100

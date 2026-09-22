extends Node
var game: Node3D
func _ready() -> void: process_mode=Node.PROCESS_MODE_ALWAYS
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F6:
		game.player.yaw=0
		game.player.pitch=-0.08
		game.player.pivot.rotation=Vector3(-0.08,0,0)
		get_viewport().set_input_as_handled()

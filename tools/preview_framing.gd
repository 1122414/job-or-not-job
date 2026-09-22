extends Node
var game: Node3D
func _ready() -> void: process_mode=Node.PROCESS_MODE_ALWAYS
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F6:
		game.player.yaw=0
		game.player.pitch=-0.08
		game.player.pivot.rotation=Vector3(-0.08,0,0)
		get_viewport().set_input_as_handled()

# Preview-only timing, never included in the exported game or formal player save.
var started := -1
var timed_action := ""
func _process(_delta: float) -> void:
	var firm: String=game.interviews.active_firm()
	if firm!="" and started<0:
		started=Time.get_ticks_msec()
		timed_action=game.interviews.sessions[firm].action
	if started<0: return
	for session in game.interviews.sessions.values():
		if session.action==timed_action and session.status=="completed":
			var elapsed := (Time.get_ticks_msec()-started)/1000.0
			started=-1
			DirAccess.make_dir_recursive_absolute("res://logs")
			var path := "res://logs/manual-interviews.jsonl"
			var file := FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
			file.seek_end()
			file.store_line(JSON.stringify({"action":timed_action,"seconds":elapsed,"answers":session.answers,"method":"GUI逐页选择，含工具往返耗时","date":Time.get_datetime_string_from_system()}))
			file.close()

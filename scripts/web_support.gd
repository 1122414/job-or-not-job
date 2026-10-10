extends Node

var started := false
var had_capture := false

func _enter_tree() -> void:
	if OS.has_feature("web"):
		# Canvas drawing uses the fallback directly, outside the Control theme.
		ThemeDB.fallback_font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		process_mode=Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	# Godot enables script processing at ready, after _enter_tree has run.
	set_process(OS.has_feature("web"))

func _process(_delta: float) -> void:
	if not OS.has_feature("web"): return
	var game := get_tree().current_scene
	if game==null or not game.get("panels"): return
	update_pointer_lock(game,Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)

func update_pointer_lock(game: Node,captured: bool) -> void:
	if not started:
		started=true
		game.panels.show_page("pause")
		return
	# Browsers can release pointer lock independently of the in-game menu.
	# Wait for the asynchronous capture request before treating it as lost.
	# Dialogue intentionally releases the pointer for choices and free text.
	var talking: bool=not game.conversation.is_empty() or game.free_chat.holding_input
	if game.panels.page=="" and had_capture and not captured and not talking:
		game.panels.show_page("pause")
		had_capture=false
	else:
		had_capture=captured

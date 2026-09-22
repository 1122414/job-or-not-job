extends Node

var started := false
var had_capture := false

func _enter_tree() -> void:
	if OS.has_feature("web"):
		# Canvas drawing uses the fallback directly, outside the Control theme.
		ThemeDB.fallback_font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		process_mode=Node.PROCESS_MODE_ALWAYS
	else:
		set_process(false)

func _process(_delta: float) -> void:
	var game := get_tree().current_scene
	if game==null or not game.get("panels"): return
	if not started:
		started=true
		game.panels.show_page("pause")
		return
	# Browsers can release pointer lock independently of the in-game menu.
	# Wait for the asynchronous capture request before treating it as lost.
	var captured := Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	if game.panels.page=="" and had_capture and not captured:
		game.panels.show_page("pause")
		had_capture=false
	else:
		had_capture=captured

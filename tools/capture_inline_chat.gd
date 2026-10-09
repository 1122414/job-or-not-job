extends SceneTree
var output := "res://docs/evidence/2026-10-09-inline-chat/runtime"
var viewport: SubViewport
var game: Node3D
var images: Array=[]
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")
func shot(label: String) -> void:
	for i in range(4): await process_frame;RenderingServer.force_draw(false)
	if root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE or game.persistence_enabled:
		push_error("Capture isolation failed");quit(1);return
	var bounds := Rect2(Vector2.ZERO,Vector2(viewport.size))
	if not bounds.encloses(game.hud.chat_row.get_global_rect()): push_error("Inline input outside viewport");quit(1);return
	for button in game.hud.chat_choices:
		if not bounds.encloses(button.get_global_rect()) or button.get_global_rect().intersects(game.hud.chat_row.get_global_rect()): push_error("Inline choice/input overlap");quit(1);return
	if viewport.get_texture().get_image().save_png(output.path_join(label+".png"))!=OK:
		push_error("Capture failed");quit(1);return
	images.append(label)
func run() -> void:
	root.set_disable_input(true);root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(10): await physics_frame
	game.story.start_new()
	var mentor: AutumnStoryPoint=game.story.points[0]
	game.player.position=mentor.position+Vector3(0,0,1.5);game.player.yaw=0
	game.interact(mentor)
	await shot("normal-dialogue")
	game.free_chat.open(mentor)
	game.free_chat.draft="老师，我想去实习，能不能商量一下？"
	game.free_chat.notice="对方正在回应……（界面等待演示）"
	await shot("typing-inline")
	# Explicit display fixture; no real cloud request or credential access.
	game.free_chat.apply_reply({"reply":"实习的事我们刚才已经谈过了。先把论文和实验做好，我不同意你现在离校。","attitude":"guarded","affinity":0,"trust":0},game.free_chat.draft)
	game.free_chat.draft="";game.free_chat.notice="界面演示：固定回复，非云端生成。"
	await shot("reply-inline")
	game.free_chat.reply_text="导师："+"你说的安排我听到了，但实验和论文仍要按时推进。".repeat(18)
	await shot("long-reply-inline")
	viewport.size=Vector2i(1280,720)
	await shot("wide-inline")
	var record := {"build":BuildInfo.read().get("build_id","source"),"images":images,"background_guard":not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"persistence":game.persistence_enabled,"reply_source":"explicit_display_fixture_not_cloud"}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	game.close_interaction();viewport.queue_free();await process_frame
	print("INLINE_CHAT_GRAPHICS_OK ",JSON.stringify(record));quit()

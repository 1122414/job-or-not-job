extends SceneTree
var output := "res://docs/evidence/2026-10-09-npc-dialogue/runtime"
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
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func capture(label: String) -> void:
	for i in range(3): await process_frame;RenderingServer.force_draw(false)
	if root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE or game.persistence_enabled:
		push_error("Capture desktop or save isolation failed");quit(1);return
	var picture := viewport.get_texture().get_image()
	if picture.save_png(output.path_join(label+".png"))!=OK: push_error("Capture write failed");quit(1);return
	images.append(label)
func reset(mentor: AutumnStoryPoint) -> void:
	game.player.cancel_strike();game.player.cooldown=0
	mentor.restore({});mentor.position=Vector3(3,40,0)
	game.player.position=Vector3(3,40,.75);game.player.yaw=0;game.player.visual.rotation=Vector3.ZERO
	await frames(8)
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	await frames(10);game.story.start_new()
	var mentor: AutumnStoryPoint=game.story.points[0]
	for style in ["strike","strike_left","push","kick"]:
		await reset(mentor)
		game.player.next_left=style=="strike_left"
		game.player.attack(style if style in ["push","kick"] else "")
		await frames(12)
		await capture(style)
		await frames(35)
	await reset(mentor)
	mentor.hit(Vector3.FORWARD,.5,game.next_action(),false);await frames(16)
	game.focus_target=mentor
	await capture("mentor-reaction-status")
	mentor.hit(Vector3.RIGHT,100,game.next_action(),true);await frames(30)
	game.focus_target=mentor
	await capture("mentor-unconscious")
	await frames(750)
	game.player.position=mentor.position+Vector3(0,0,1.2)
	game.free_chat.open(mentor)
	# Explicit display fixture, never presented as a live cloud response.
	game.free_chat.apply_reply({"reply":"先退后。刚才动手的事我记得，实习的决定也没有改变。你如果愿意把话说清楚，我可以听。","attitude":"guarded","affinity":0,"trust":0},"老师，我想解释一下。（界面演示）")
	game.free_chat.notice="界面演示：固定回复夹具，尚未连接真实云端。"
	game.panels.view.refresh()
	await capture("free-input-preview")
	game.panels.open_child("llm_settings")
	await capture("model-settings")
	var build := BuildInfo.read()
	var record := {"images":images,"background_guard":not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"persistence":game.persistence_enabled,"cloud_response":"not_tested_display_fixture_only","build":build.get("build_id","source")}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	game.panels.show_page("");viewport.queue_free();await process_frame
	print("NPC_DIALOGUE_GRAPHICS_OK ",JSON.stringify(record));quit()

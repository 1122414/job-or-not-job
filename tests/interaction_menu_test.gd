extends SceneTree

var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message);failures+=1
func frames() -> void:
	for i in range(4): await process_frame
func key(code: int,echo: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode=code;event.keycode=code;event.pressed=pressed;event.echo=echo and pressed
		root.push_input(event,true)
		await process_frame
	await frames()
func run() -> void:
	var support: Node=root.get_node("WebSupport")
	check(not OS.has_feature("web") and not support.is_processing(),"INPUT01 桌面autoload必须在ready后停止逐帧网页逻辑")
	# The production autoload looks up current_scene, which ordinary fixtures leave null.
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(6): await physics_frame
	check(not game.persistence_enabled,"加载真实场景前保持玩家存档隔离")
	current_scene=game
	game.story.start_new()
	var mentor: AutumnStoryPoint=game.story.points[0]
	game.player.position=mentor.position+Vector3(0,0,1.5);game.player.yaw=0
	check(game.nearest()==mentor,"E输入夹具面对导师")
	# Model the previous capture sample without grabbing the operating-system pointer.
	support.started=true;support.had_capture=true
	await key(KEY_E)
	check(game.panels.page=="" and not game.menu.visible and game.speaker==mentor and not game.conversation.is_empty(),"INPUT01 实际E交谈释放鼠标后不能被网页逻辑改成暂停菜单")
	if failures>0:
		support.set_process(false);game.panels.show_page("");current_scene=null
		game.queue_free();await process_frame
		print("INTERACTION_MENU_TEST baseline failures=",failures);quit(failures);return
	for i in range(5):
		await key(KEY_E)
		check(game.panels.page=="" and game.speaker==mentor,"连续E只保留交谈")
	await key(KEY_E,true)
	check(game.panels.page=="" and game.speaker==mentor,"长按E重复事件不打开菜单")
	await key(KEY_ESCAPE)
	check(game.panels.page=="pause" and paused,"Esc仍能明确打开暂停菜单")
	await key(KEY_ESCAPE)
	check(game.panels.page=="" and not paused,"Esc关闭菜单恢复游戏")
	await key(KEY_E)
	check(game.speaker==mentor and game.panels.page=="","菜单返回后E仍能交谈")
	game.free_chat.open(mentor)
	check(game.free_chat.holding_input and paused,"自由输入仍暂停世界")
	await key(KEY_E)
	check(game.panels.page=="" and game.free_chat.holding_input,"输入框中的E不打开暂停菜单")
	await key(KEY_ESCAPE)
	check(not paused and game.panels.page=="" and not game.conversation.is_empty(),"退出自由输入保留普通对话")
	# Defensive platform guard also protects a manually invoked process callback.
	support.started=false;support.had_capture=true;support._process(0)
	check(game.panels.page=="" and not game.menu.visible,"桌面显式回调也不能进入网页初始菜单")
	# Browser state transitions use synthetic capture samples, never OS capture.
	support.started=true;support.had_capture=true
	support.update_pointer_lock(game,false)
	check(game.panels.page=="" and game.speaker==mentor and not support.had_capture,"网页交谈主动释放指针不打开菜单")
	game.close_interaction();support.update_pointer_lock(game,false)
	check(game.panels.page=="","网页交谈结束不把上一轮释放延迟当成失锁")
	support.started=false;support.update_pointer_lock(game,false)
	check(game.panels.page=="pause","网页首次启动仍显示开始菜单")
	game.panels.back();support.update_pointer_lock(game,true);support.update_pointer_lock(game,false)
	check(game.panels.page=="pause","网页非对话意外失锁仍暂停")
	game.panels.back()
	check(not game.persistence_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"测试不写用户存档或捕获桌面鼠标")
	game.close_interaction();current_scene=null;game.queue_free();await process_frame
	print("INTERACTION_MENU_TEST failures=",failures);quit(failures)

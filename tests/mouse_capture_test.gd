extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	root.set_disable_input(true)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(3): await physics_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"启动不捕获桌面鼠标")
	check(not game.player.capture_permitted(),"自动夹具不得申请捕获")
	for page in ["pause","bag","journal","help","computer","messages","people","history","ledger","promises"]:
		game.panels.show_page(page)
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"打开页面释放鼠标："+page)
		game.panels.back()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"关闭页面不重新捕获："+page)
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	var actions: int=game.action_counter
	game.player._unhandled_input(click)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"模拟点击不得绕过自动运行保护")
	check(game.action_counter==actions and game.player.swing==0,"激活点击不穿透攻击")
	var before: float=game.player.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(50,20)
	game.player._unhandled_input(motion)
	check(is_equal_approx(game.player.yaw,before),"释放鼠标后桌面移动不带动镜头")
	game.player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	game.player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"切走与返回窗口都不自动捕获")
	game.queue_free()
	await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"退出场景释放鼠标")
	print("MOUSE_CAPTURE_TEST failures=",failures)
	quit(failures)

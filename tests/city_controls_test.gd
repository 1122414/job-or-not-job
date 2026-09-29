extends SceneTree

var failures := 0
var game: Node3D
var view: GamePageView

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func settle() -> void:
	for i in range(5): await process_frame
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		root.push_input(event,true)
	await settle()
func click(id: String) -> void:
	check(view.buttons.has(id),"公交/地图按钮存在 "+id)
	if not view.buttons.has(id): return
	var button: Button=view.buttons[id]
	view.scroll.ensure_control_visible(button)
	await settle()
	var point := button.get_global_rect().get_center()
	check(view.scroll.get_global_rect().has_point(point),"按钮可以滚动到可点击区域 "+id)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
	await settle()

func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(4): await physics_frame
	view=game.panels.view
	game.set_process(false)
	game.transit.set_physics_process(false)
	await key(KEY_M)
	check(game.panels.page=="city" and paused,"M 打开地图并暂停世界")
	await click("city-waterfront")
	check(game.transit.waypoint=="waterfront" and not paused,"真实鼠标选择滨水导航")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"地图关闭不捕获鼠标")
	await key(KEY_M)
	view.buttons["city-clear"].grab_focus()
	await key(KEY_ENTER)
	check(game.transit.waypoint=="" and game.panels.page=="","焦点键盘恢复职业目标")
	game.player.position=CityLayout.STOPS[0].platform
	for i in range(3): await physics_frame
	await key(KEY_E)
	await click("bus-board")
	check(game.transit.riding and not paused,"真实 E 和鼠标上车")
	var t: CityTransit=game.transit
	t.dwell=0
	for i in range(80):
		t.tick(0.1)
		await physics_frame
	var actions: int=game.action_counter
	await key(KEY_E)
	await click("bus-request")
	check(t.requested and game.action_counter==actions,"请求下车点击不穿透攻击")
	for i in range(900):
		t.tick(0.1)
		await physics_frame
		if t.current_stop==1: break
	check(t.current_stop==1,"下车页面在真实到站后可用")
	await key(KEY_E)
	await click("bus-leave")
	check(not t.riding and game.player.position.distance_to(CityLayout.STOPS[1].platform)<0.1,"真实按钮下车")
	# Large text and three aspect ratios must retain reachable navigation actions.
	for size in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1680,720)]:
		root.size=size
		for scale_value in [1.0,1.25,1.5]:
			view.set_font_scale(scale_value)
			game.panels.show_page("city")
			await settle()
			await click("city-homes")
			check(t.waypoint=="homes" and not paused,"比例/字号地图末站可点击 "+str(size)+" / "+str(scale_value))
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"所有页面交互保持鼠标可用")
	print("CITY_CONTROLS_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

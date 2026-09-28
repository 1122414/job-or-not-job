extends SceneTree

var failures := 0
var game: Node3D
var view: GamePageView

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func settle() -> void:
	for i in range(5): await process_frame
func key(code: int,shift: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.shift_pressed=shift
		event.pressed=pressed
		root.push_input(event,true)
	await settle()
func click_button(id: String) -> void:
	check(view.buttons.has(id),"按钮存在："+id)
	if not view.buttons.has(id): return
	var button: Button=view.buttons[id]
	view.scroll.ensure_control_visible(button)
	await settle()
	var point := button.get_global_rect().get_center()
	check(view.scroll.get_global_rect().has_point(point),"点击按钮在滚动可视区域："+id)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
	await settle()
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/p2-pages")
	root.get_texture().get_image().save_png("res://build/p2-pages/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	view=game.panels.view
	check(not game.persistence_enabled,"界面测试隔离玩家存档")
	game.panels.show_page("journal")
	await settle()
	var minute: float=game.payroll.minute
	var counter: int=game.action_counter
	await click_button("company-b")
	check(game.career.facts.get("guide_company")=="b","鼠标可选择B公司")
	await key(KEY_1)
	check(game.career.facts.get("guide_company")=="a","数字键选择与鼠标使用相同业务")
	view.buttons["company-b"].grab_focus()
	await key(KEY_ENTER)
	check(game.career.facts.get("guide_company")=="b","Enter激活聚焦按钮")
	var before: Control=root.gui_get_focus_owner()
	await key(KEY_TAB)
	check(root.gui_get_focus_owner()!=before and game.panels.page=="journal","Tab转移焦点而不是切到背包")
	check(game.payroll.minute==minute and game.action_counter==counter,"界面点击不推进世界或触发攻击")
	await screenshot("journal")
	await click_button("open-history")
	await key(KEY_ESCAPE)
	check(game.panels.page=="journal" and paused,"历史返回安排页")
	game.panels.show_page("pause")
	game.panels.open_child("journal")
	game.panels.open_child("history")
	game.panels.back()
	check(game.panels.page=="journal","三层返回先回安排")
	game.panels.back()
	check(game.panels.page=="pause","三层返回保留暂停父级")
	game.panels.toggle("help")
	await settle()
	await click_button("help-end")
	check(game.panels.page=="pause" and paused,"帮助按钮返回暂停菜单")
	await key(KEY_ESCAPE)
	check(game.panels.page=="" and not paused,"关闭后恢复世界")
	for action in ["interview_hr","interview_lead","interview_boss","interview_b"]: game.recruitment.finish(action)
	game.recruitment.handle("rest_next")
	game.panels.show_page("messages")
	await settle()
	await click_button("firm-b")
	await click_button("reply-1")
	check(game.recruitment.applications.b.phase=="deferred","鼠标暂缓B邀请")
	await click_button("reply-0")
	check(game.recruitment.applications.b.phase=="accepted" and game.career.employer=="","鼠标接受仅预约，不提前建立雇佣")
	await screenshot("messages")
	game.panels.back()
	SaveGame.restore(game,game.initial_state.duplicate(true))
	game.career.employer="a"
	game.panels.show_page("computer")
	await settle()
	await click_button("document-0")
	await click_button("project-4")
	await click_button("project-6")
	check(game.projects.state("a").source=="official" and game.projects.state("a").preview!="error","鼠标阅读、配置并预览A工作")
	await screenshot("computer-a")
	game.career.employer="b"
	view.refresh()
	await settle()
	for i in range(3): await click_button("document-"+str(i))
	await click_button("project-4")
	await click_button("project-5")
	await click_button("project-6")
	check(game.projects.state("b").preview.contains("✓"),"鼠标操作B工作检查")
	await screenshot("computer-b")
	game.panels.back()
	var item: OfficeProp
	for prop in game.props:
		if prop.portable(): item=prop; break
	game.player.collect(item)
	game.panels.show_page("bag")
	await settle()
	await click_button("item-0")
	check(game.player.held==item and not game.player.inventory.has(item),"鼠标取出物品且只有一个归属")
	await click_button("store")
	check(game.player.held==null and game.player.inventory.count(item)==1,"鼠标收纳不复制")
	await screenshot("bag")
	for page in ["people","promises","ledger"]:
		game.panels.show_page(page)
		await settle()
		await screenshot(page)
	game.career.records.append("长经历边界："+"项目反馈和实际经历。".repeat(300))
	game.panels.show_page("history")
	await settle()
	var scroll_before := view.scroll.scroll_vertical
	check(view.body.size.y>view.scroll.size.y,"长记录夹具确实超过可视高度")
	await key(KEY_PAGEDOWN)
	check(view.scroll.scroll_vertical>scroll_before,"历史长记录可用PageDown滚动")
	for page in GamePageView.TITLES:
		game.panels.show_page(page)
		view.set_font_scale(1.5)
		await settle()
		check(view.body.size.x<=view.scroll.size.x+1,"所有页面的大字模式无水平溢出："+page)
	for resolution in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1260,540)]:
		root.size=resolution
		for font_size in [1.0,1.25,1.5]:
			view.set_font_scale(font_size)
			game.panels.show_page("help")
			await settle()
			var actual := root.get_visible_rect().size
			check(absf(actual.x/actual.y-float(resolution.x)/resolution.y)<0.01,"实际内容宽高比对应窗口而非固定16:10")
			if font_size==1.5: print("UI_VIEWPORT requested=",resolution," logical=",actual," render=",root.get_texture().get_size())
			check(root.get_visible_rect().encloses(view.sheet.get_global_rect()),"页面在窗口内："+str(resolution)+" / "+str(font_size))
			check(view.body.size.x<=view.scroll.size.x+1,"无水平溢出")
			view.buttons["help-end"].grab_focus()
			await settle()
			check(view.scroll.get_global_rect().encloses(view.buttons["help-end"].get_global_rect()),"焦点自动滚动到帮助末项")
			if font_size==1.5: await screenshot("help-"+str(resolution.x)+"x"+str(resolution.y))
	game.panels.back()
	SaveGame.restore(game,game.initial_state.duplicate(true))
	game.panels.show_page("journal")
	await settle()
	view.buttons["company-a"].grab_focus()
	for pressed in [true,false]:
		var accept := InputEventJoypadButton.new()
		accept.button_index=JOY_BUTTON_A
		accept.pressed=pressed
		root.push_input(accept,true)
	await settle()
	check(game.career.facts.get("guide_company")=="a","手柄确认激活聚焦按钮")
	var old_focus: Control=root.gui_get_focus_owner()
	for pressed in [true,false]:
		var down := InputEventJoypadButton.new()
		down.button_index=JOY_BUTTON_DPAD_DOWN
		down.pressed=pressed
		root.push_input(down,true)
	await settle()
	check(root.gui_get_focus_owner()!=old_focus,"手柄方向按钮移动焦点")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index=JOY_BUTTON_B
	cancel.pressed=true
	root.push_input(cancel,true)
	await settle()
	check(game.panels.page=="" and not paused,"手柄UI返回映射关闭页面")
	var start := InputEventJoypadButton.new()
	start.button_index=JOY_BUTTON_START
	start.pressed=true
	root.push_input(start,true)
	await settle()
	check(game.panels.page=="pause" and game.menu.get_global_rect().end.y<=root.get_visible_rect().end.y,"手柄Start打开适应窗口的菜单")
	await screenshot("pause")
	paused=false
	game.queue_free()
	await settle()
	print("PAGE_CONTROLS_TEST failures=",failures)
	quit(failures)

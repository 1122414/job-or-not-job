class_name PauseMenu
extends PanelContainer
var game: Node3D
func _ready() -> void:
	position=Vector2(430,70)
	custom_minimum_size=Vector2(420,420)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.025,0.035,0.05,0.97)
	style.content_margin_left=24
	style.content_margin_right=24
	style.content_margin_top=22
	style.content_margin_bottom=22
	add_theme_stylebox_override("panel",style)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",12)
	add_child(list)
	var title := Label.new()
	title.text="今天不上班 / 菜单"
	title.add_theme_font_size_override("font_size",26)
	list.add_child(title)
	for entry in [["继续游戏",func(): game.toggle_menu()], ["新游戏（自动备份当前进度）",func(): game.new_game()], ["恢复上一次进度（当前进度也会备份）",func(): game.restore_previous()], ["操作说明 / H",func(): game.panels.toggle("help")], ["保存 / F5",func(): game.save_game()], ["读取 / F9",func(): game.load_game()], ["保存并退出",func():
		if SaveGame.write(game,game.save_path)==OK: get_tree().quit()
		else: game.say("保存失败，未退出；请检查磁盘空间。")], ["直接退出",func(): get_tree().quit()]]:
		if OS.has_feature("web") and entry[0] in ["保存并退出","直接退出"]: continue
		var button := Button.new()
		button.text=entry[0]
		button.pressed.connect(entry[1])
		list.add_child(button)
	var shake := CheckButton.new()
	shake.text="镜头震动"
	shake.button_pressed=game.shake_enabled
	shake.toggled.connect(func(value: bool): game.shake_enabled=value)
	list.add_child(shake)
	var label := Label.new()
	label.text="鼠标灵敏度"
	list.add_child(label)
	var sensitivity := HSlider.new()
	sensitivity.min_value=0.001
	sensitivity.max_value=0.006
	sensitivity.step=0.0002
	sensitivity.value=game.player.sensitivity
	sensitivity.value_changed.connect(func(value: float): game.player.sensitivity=value)
	list.add_child(sensitivity)
	var help := Label.new()
	help.text="Esc 返回 · H 操作说明\n菜单期间世界暂停，关闭即恢复。"
	if OS.has_feature("web"):
		help.text="点击继续游戏后控制视角，Esc 释放鼠标。\n请用菜单保存；保存后可关闭网页。\n进度仅保留于当前浏览器，清除网站数据会丢失。"
	list.add_child(help)
	hide()

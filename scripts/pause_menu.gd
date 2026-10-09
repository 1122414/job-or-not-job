class_name PauseMenu
extends PanelContainer
var game: Node3D
var first_button: Button
var audio_sliders := {}
func arrange() -> void:
	var viewport := get_viewport_rect().size
	var width := minf(560,viewport.x-32)
	position=Vector2((viewport.x-width)/2,24)
	size=Vector2(width,viewport.y-48)
func focus_first() -> void:
	if visible and first_button: first_button.grab_focus()
func _ready() -> void:
	get_viewport().size_changed.connect(arrange)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.025,0.035,0.05,0.97)
	style.content_margin_left=24
	style.content_margin_right=24
	style.content_margin_top=22
	style.content_margin_bottom=22
	add_theme_stylebox_override("panel",style)
	var list := VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	add_child(scroll)
	scroll.add_child(list)
	var title := Label.new()
	title.text="今天不上班 / 菜单"
	title.add_theme_font_size_override("font_size",26)
	list.add_child(title)
	for entry in [["继续游戏",func(): game.toggle_menu()], ["今天的安排 / J",func(): game.panels.open_child("journal")], ["新游戏（自动备份当前进度）",func(): game.new_game()], ["恢复上一次进度（当前进度也会备份）",func(): game.restore_previous()], ["操作说明 / H",func(): game.panels.toggle("help")], ["保存 / F5",func(): game.save_game()], ["读取 / F9",func(): game.load_game()], ["保存并退出",func():
		if game.save_game(): get_tree().quit()], ["直接退出",func(): get_tree().quit()]]:
		if OS.has_feature("web") and entry[0] in ["保存并退出","直接退出"]: continue
		var button := Button.new()
		button.text=entry[0]
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y=42
		button.pressed.connect(entry[1])
		list.add_child(button)
		if first_button==null: first_button=button
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
	var font_size := OptionButton.new()
	for scale in [100,125,150]: font_size.add_item("信息页面字号：%d%%" % scale)
	font_size.item_selected.connect(func(index: int): game.panels.view.set_font_scale([1.0,1.25,1.5][index]))
	list.add_child(font_size)
	var lighting := CheckButton.new()
	lighting.name="RoomLighting"
	lighting.text="室内间接光与反射"
	lighting.button_pressed=game.room_lighting.enabled
	lighting.disabled=not game.room_lighting.available
	lighting.tooltip_text="增强室内明暗层次；关闭可减少图形负担。" if game.room_lighting.available else "当前渲染模式不支持此项。"
	lighting.toggled.connect(game.room_lighting.set_enabled)
	list.add_child(lighting)
	for bus in CitySoundscape.LABELS:
		var sound_label := Label.new()
		list.add_child(sound_label)
		var volume := HSlider.new()
		volume.name="Volume"+bus
		volume.min_value=0; volume.max_value=100; volume.step=1
		volume.value=game.soundscape.levels[bus]*100
		volume.custom_minimum_size.y=32
		volume.tooltip_text=CitySoundscape.LABELS[bus]+"；0 为静音"
		volume.value_changed.connect(func(value: float):
			game.soundscape.set_level(bus,value/100)
			sound_label.text=CitySoundscape.LABELS[bus]+"："+("静音" if value==0 else str(roundi(value))+"%"))
		sound_label.text=CitySoundscape.LABELS[bus]+"："+str(roundi(volume.value))+"%"
		list.add_child(volume); audio_sliders[bus]=volume
	visibility_changed.connect(func():
		if visible:
			lighting.set_pressed_no_signal(game.room_lighting.enabled)
			for bus in audio_sliders: audio_sliders[bus].value=game.soundscape.levels[bus]*100)
	var help := Label.new()
	help.text="Esc 释放鼠标 / 返回 · H 操作说明\n关闭菜单后，点击游戏画面才开始控制视角。"
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if OS.has_feature("web"):
		help.text="关闭菜单后，点击游戏画面控制视角；Esc 释放鼠标。\n请用菜单保存；保存后可关闭网页。\n进度仅保留于当前浏览器，清除网站数据会丢失。"
	list.add_child(help)
	var build_label := Label.new()
	build_label.text=BuildInfo.label()
	build_label.add_theme_font_size_override("font_size",12)
	build_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	list.add_child(build_label)
	arrange()
	hide()

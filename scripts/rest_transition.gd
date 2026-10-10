class_name RestTransition
extends CanvasLayer

const DURATION := 4.8
var game: Node3D
var active := false
var elapsed := 0.0
var from_minute := 0
var to_minute := 0
var display_minute := 0.0
var camera: Camera3D
var previous_camera: Camera3D
var shade: ColorRect
var title: Label
var clock_label: Label
var old_hud := true

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=90
	shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color.BLACK;shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	for bottom in [false,true]:
		var bar := ColorRect.new();bar.color=Color(0,0,0,.85);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(bar);bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top=-92 if bottom else 0;bar.offset_bottom=0 if bottom else 70
	title=Label.new();add_child(title);title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position.y=22;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",22)
	clock_label=Label.new();add_child(clock_label);clock_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	clock_label.offset_top=-78;clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;clock_label.add_theme_font_size_override("font_size",22)
	camera=Camera3D.new();game.add_child(camera);camera.fov=62
	visible=false

func start(target: int) -> void:
	if active: finish()
	from_minute=game.payroll.minute;to_minute=maxi(target,from_minute)
	game.close_interaction();game.panels.show_page("")
	game.driving.suspend_controls()
	previous_camera=game.get_viewport().get_camera_3d()
	old_hud=game.hud.visible
	# Settle the calendar once. The paused montage only interpolates presentation,
	# so saving, skipping or restoring cannot pay wages or deliver messages twice.
	game.advance_time(to_minute-from_minute)
	active=true;elapsed=0;display_minute=from_minute
	game.hud.visible=false;visible=true
	var home: bool=game.home.inside(game.player.position)
	camera.position=Vector3(64,8,51) if home else Vector3(-6,9,31)
	camera.look_at(Vector3(56,3,31) if home else Vector3(-16,3,6))
	camera.make_current()
	title.text="把时间留给自己" if home else "休息片刻"
	game.get_tree().paused=true
	update_frame()

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey and event.pressed and not event.echo and (event.is_action("cancel") or event.keycode in [KEY_ESCAPE,KEY_SPACE]): finish()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active: return
	elapsed=minf(DURATION,elapsed+delta)
	update_frame()
	if elapsed>=DURATION: finish()

func update_frame() -> void:
	var phase := smoothstep(.45,DURATION-.5,elapsed)
	# Large skips show one complete day, then the exact destination date.
	var span := mini(Payroll.DAY,to_minute-from_minute)
	display_minute=lerpf(to_minute-span,to_minute,phase)
	if elapsed<.45: display_minute=from_minute
	game.update_daylight()
	var minute := roundi(display_minute)
	clock_label.text="第%d天  %02d:%02d\nEsc / 空格 跳过" % [minute/Payroll.DAY+1,(minute%Payroll.DAY)/60,minute%60]
	shade.color.a=1-smoothstep(0,.45,elapsed) if elapsed<.45 else smoothstep(DURATION-.45,DURATION,elapsed)

func finish() -> void:
	if not active: return
	active=false;visible=false
	if is_instance_valid(previous_camera): previous_camera.make_current()
	else: game.player.camera.make_current()
	game.hud.visible=old_hud
	game.get_tree().paused=game.panels.page!=""
	game.update_daylight();game.driving.suspend_controls()
	game.say(game.payroll.time_text()+" · 休息过了，接下来由你安排。")

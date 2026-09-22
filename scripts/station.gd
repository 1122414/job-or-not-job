class_name WorkStation
extends StaticBody3D
var stable_id := ""
var title := ""
var label: Label3D
var screen: Label3D
var indicator: MeshInstance3D
var work_bars: Array[MeshInstance3D] = []
var result_board: Label3D
var screen_back: MeshInstance3D
var display_device: OfficeProp

func _ready() -> void:
	if stable_id.begins_with("interview_"):
		pass
	elif stable_id.begins_with("desk_"):
		# The first workstations reuse existing desks; the second group has a new place.
		if stable_id=="desk_a2":
			Shapes.solid(self,Vector3(2.5,0.12,1.1),Vector3(0,0.72,-1.05),Color("a18a6b"))
			for x in [-1,1]: Shapes.box(self,Vector3(0.08,0.85,0.8),Vector3(x,0.42,-1.05),Color("42494e"))
			Shapes.box(self,Vector3(1.1,0.65,0.09),Vector3(0,1.20,-1.5),Color("252f36"))
			OfficeDress.chair(self,Vector3.ZERO)
		screen=Shapes.label(self,"",Vector3(0,1.20,-1.44 if stable_id=="desk_a2" else -1.28),28)
		screen.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		screen.pixel_size=0.0019
		screen.outline_size=0
	elif stable_id=="rest":
		Shapes.box(self,Vector3(0.08,1.5,0.08),Vector3(0,0.75,0),Color("4a575f"))
		Shapes.box(self,Vector3(0.8,0.5,0.08),Vector3(0,1.5,0),Color("456e65"))
		Shapes.collider(self,Vector3(0.2,1.8,0.2),Vector3(0,0.9,0))
	elif stable_id=="archive":
		Shapes.box(self,Vector3(1,1.3,0.65),Vector3(0,0.65,0),Color("637f8a"))
		for y in [0.25,0.65,1.05]:
			Shapes.box(self,Vector3(0.9,0.025,0.04),Vector3(0,y,0.35),Color("575e60"))
			Shapes.box(self,Vector3(0.3,0.04,0.06),Vector3(0,y+0.15,0.37),Color("707c80"))
		Shapes.collider(self,Vector3(1,1.3,0.65),Vector3(0,0.65,0))
	else:
		Shapes.box(self,Vector3(1.4,0.1,0.8),Vector3(0,0.85,0),Color("a28b70"))
		for x in [-0.55,0.55]: Shapes.box(self,Vector3(0.08,0.8,0.65),Vector3(x,0.4,0),Color("454d53"))
		Shapes.collider(self,Vector3(1.4,0.95,0.8),Vector3(0,0.475,0))
		indicator=Shapes.box(self,Vector3(1.1,0.6,0.07),Vector3(0,1.28,-0.2),Color("29383f"))
		screen=Shapes.label(self,"",Vector3(0,1.28,-0.15),28)
		screen.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		screen.pixel_size=0.0018
		screen.outline_size=0
		Shapes.box(self,Vector3(0.7,0.03,0.23),Vector3(0,0.92,0.2),Color("42484b"))
	if screen:
		screen.width=390
		screen.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		screen_back=Shapes.box(self,Vector3(0.74,0.40,0.001),screen.position+Vector3(0,0,-0.002),Color("20333e"))
		if stable_id in ["desk_a","desk_b"]:
			var device_id := ("a" if stable_id=="desk_a" else "b")+"_desk_6_-2_monitor"
			for prop in get_parent().props:
				if prop.stable_id==device_id: display_device=prop
		for i in range(3):
			var bar := Shapes.box(self,Vector3(0.65,0.014,0.003),screen.position+Vector3(0,-0.12-i*0.026,0.01),Color("74ae9b"))
			bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			work_bars.append(bar)
	if stable_id in ["demo","backup"]:
		# A visible scene output at the delivery site; results survive save/load via career facts.
		var board_at := Vector3(0,2.05,-0.55)
		Shapes.box(self,Vector3(2.1,1.08,0.06),board_at,Color("e6e5db"))
		result_board=Shapes.label(self,"",board_at+Vector3(0,0,0.04),32)
		result_board.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		result_board.pixel_size=0.0026
		result_board.outline_size=0
		result_board.modulate=Color("234d55")
	label=Shapes.label(self,title,Vector3(0,1.85,0),24)
	label.pixel_size=0.003
	label.outline_size=3

func _process(_delta: float) -> void:
	var game = get_parent()
	label.visible=false
	if not screen: return
	var device_present := true
	if display_device:
		device_present=display_device.visible and not display_device.damaged and display_device.position.distance_to(display_device.home)<0.20 and display_device.rotation.length()<0.1
	screen.visible=device_present
	screen_back.visible=device_present
	var facts: Dictionary=game.career.facts
	if stable_id.begins_with("desk_"):
		var assigned: bool=game.office.assigned_desk()==stable_id
		screen.text=(game.career.grade+"\n"+("演示包预览成功 ✓" if facts.has("prepared") else "资料已接收 · 可整理预览" if facts.has("data") else "欢迎入职 · 待接收资料")) if assigned else "备用工位"
		label.text="我的工位 · "+game.career.grade if assigned else "备用工位"
	elif stable_id=="demo":
		screen.text="演示运行中\n交付已通过 ✓" if facts.has("output_one") else "演示待交付\n离线 / 常规权限"
	elif stable_id=="backup":
		screen.text="备用线路在线\n现场恢复成功 ✓" if facts.has("output_two") else "主线路无信号\n可切换备用线路"
	elif stable_id=="handover":
		screen.text="发送完成 ✓\n阿乐可以下班" if facts.has("b_help") else "交接包已就绪\n等待接手人"
	var progress := 0.0
	if stable_id.begins_with("desk_"):
		if game.office.preview_station==self:
			progress=clampf(game.office.preview_elapsed/OfficeLife.PREVIEW_SECONDS,0,1)
			screen.text="演示预览 · %d%%\n数据载入 → 离线校验" % int(progress*100)
		elif stable_id==game.office.assigned_desk():
			if game.career.employer=="b": screen.text="个人终端 / 交接工作\n"+{"pending":"等待确认交接安排","helping":"交接台：发送已有资料","refused":"今晚不接手 · 由阿乐处理","negotiating":"与阿乐现场确认截止时间","helped":"交接完成 · 今晚自由","negotiated":"交接改明早 · 今晚自由","conflict":"现场已停止 · 查看公司处分"}.get(game.career.b_event,"自由安排")
			elif game.career.stage>=4: screen.text="两份成果已归档 ✓\n正式员工" if game.career.stage==6 else "第二份成果：现场恢复 ✓\n准备答辩" if facts.has("output_two") else "第二章 / 现场投影\n第一次成果已保留 ✓"
			progress=1.0 if facts.has("prepared") else 0.0
	else: progress=1.0 if (stable_id=="demo" and facts.has("output_one")) or (stable_id=="backup" and facts.has("output_two")) or (stable_id=="handover" and facts.has("b_help")) else 0.0
	if stable_id==game.office.assigned_desk() and not game.onboarding.account_ready(): screen.text="无法登录 · 候选人组织\n工单：已完成 / 请联系前台"
	for i in range(work_bars.size()):
		work_bars[i].visible=progress>0 and device_present
		work_bars[i].scale.x=maxf(0.01,clampf(progress*3-i,0,1))
	if result_board:
		if stable_id=="demo": result_board.text="演示交付 / 通过\n资料 ✓   预览 ✓   运行 ✓\n第一份成果已归档" if facts.has("output_one") else "演示交付现场\n等待可运行的演示包"
		else: result_board.text="备用线路 ━ 投影输出\n现场演示已恢复 ✓\n第二份成果已归档" if facts.has("output_two") else "主线路 ┄ 无信号\n备用线路待切换"
	if stable_id in ["desk_a","desk_a2","demo"] and game.recruitment.work.has("project_a"):
		var project: Dictionary=game.recruitment.work.project_a
		if project.preview!="":
			var output: String="错误：草稿包含未确认功能" if project.preview=="error" else project.preview
			if stable_id=="demo" and result_board:
				result_board.text=("已归档 / " if project.delivered else "待现场交付 / ")+output
			elif stable_id==game.office.assigned_desk() and game.career.stage<4 and game.onboarding.account_ready(): screen.text=output
	if stable_id=="handover" and game.recruitment.work.has("project_b"):
		var project: Dictionary=game.recruitment.work.project_b
		screen.text=("已发送 / " if project.sent else "协商材料就绪 / " if project.proposal else "检查 / ")+project.preview
	if indicator:
		var complete: bool=(stable_id=="demo" and facts.has("output_one")) or (stable_id=="backup" and facts.has("output_two")) or (stable_id=="handover" and facts.has("b_help"))
		indicator.material_override.albedo_color=Color("335647") if complete else Color("29383f")

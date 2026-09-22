class_name WorkStation
extends StaticBody3D
var stable_id := ""
var title := ""
var label: Label3D
var screen: Label3D
var indicator: MeshInstance3D

func _ready() -> void:
	if stable_id.begins_with("desk_"):
		# The first workstations reuse existing desks; the second group has a new place.
		if stable_id=="desk_a2":
			Shapes.solid(self,Vector3(2.5,0.12,1.1),Vector3(0,0.85,-1.05),Color("a18a6b"))
			for x in [-1,1]: Shapes.box(self,Vector3(0.08,0.85,0.8),Vector3(x,0.42,-1.05),Color("42494e"))
			Shapes.box(self,Vector3(1.1,0.65,0.09),Vector3(0,1.35,-1.5),Color("252f36"))
			OfficeDress.chair(self,Vector3.ZERO)
		screen=Shapes.label(self,"",Vector3(0,1.35,-1.42),28)
		screen.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		screen.pixel_size=0.0019
		screen.outline_size=0
	elif stable_id=="rest":
		Shapes.box(self,Vector3(0.08,1.5,0.08),Vector3(0,0.75,0),Color("4a575f"))
		Shapes.box(self,Vector3(0.8,0.5,0.08),Vector3(0,1.5,0),Color("456e65"))
		Shapes.collider(self,Vector3(0.2,1.8,0.2),Vector3(0,0.9,0))
	elif stable_id=="archive":
		Shapes.box(self,Vector3(1,1.3,0.65),Vector3(0,0.65,0),Color("b4b2a6"))
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
	label=Shapes.label(self,title,Vector3(0,1.85,0),24)
	label.pixel_size=0.003
	label.outline_size=3

func _process(_delta: float) -> void:
	var game = get_parent()
	label.visible=false
	if not screen: return
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
	if indicator:
		var complete: bool=(stable_id=="demo" and facts.has("output_one")) or (stable_id=="backup" and facts.has("output_two")) or (stable_id=="handover" and facts.has("b_help"))
		indicator.material_override.albedo_color=Color("335647") if complete else Color("29383f")

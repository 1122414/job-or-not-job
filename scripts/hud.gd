class_name StreetHUD
extends Control

var game: Node3D
var font: Font = ThemeDB.fallback_font
var toast := ""
var toast_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func text_at(pos: Vector2, text: String, size: int = 20, color: Color = Color.WHITE) -> void:
	draw_string_outline(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,4,Color(0,0,0,0.8))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _process(delta: float) -> void:
	toast_time = maxf(0,toast_time-delta)
	queue_redraw()

func _draw() -> void:
	if not game.player: return
	var p: OfficePlayer = game.player
	var w := size.x
	var h := size.y
	var center := Vector2(112,h-135)
	draw_circle(center,83,Color(0.02,0.03,0.04,0.85))
	draw_circle(center,77,Color("586469"))
	# North-up street map; player marker rotates with camera heading.
	draw_line(center+Vector2(-72,25),center+Vector2(72,25),Color("a8acaa"),17)
	for x in [-1,1]:
		draw_rect(Rect2(center+Vector2(x*35-26,-48),Vector2(52,56)),Color("849697") if x<0 else Color("a6927c"))
	text_at(center+Vector2(-42,-14),"A",18)
	text_at(center+Vector2(29,-14),"B",18)
	for npc in game.npcs:
		var point := center + Vector2(npc.position.x,npc.position.z)*2.05
		if point.distance_to(center)<71: draw_circle(point,2.3,Color("e8d9b8"))
	var marker := center+Vector2(p.position.x,p.position.z)*2.05
	marker = center+(marker-center).limit_length(71)
	var points := PackedVector2Array()
	for point in [Vector2(0,-8),Vector2(-5,6),Vector2(0,3),Vector2(5,6)]: points.append(marker+point.rotated(-p.yaw))
	draw_colored_polygon(points,Color("63d6ef"))
	text_at(center+Vector2(-6,-61),"N",12)
	draw_rect(Rect2(35,h-47,154,10),Color("182720"))
	draw_rect(Rect2(35,h-47,154*float(p.hp)/100,10),Color("62bd62") if p.protection<=0 else Color("63d6ef"))
	text_at(Vector2(35,h-20),game.location_name(),16)
	text_at(Vector2(w-240,44),"☆☆☆☆☆",32,Color("a7aaa7"))
	text_at(Vector2(w-240,44),"★".repeat(game.alert_level()),32,Color("f4c250"))
	text_at(Vector2(w-236,77),"%s  ·  %s" % [p.held.title if p.held else "空手",game.clock_text()],18)
	text_at(Vector2(w-236,102),game.money_text(),18,Color("8ed79d"))
	text_at(Vector2(30,38),"今天不上班",22)
	text_at(Vector2(30,65),game.objective_text(),17,Color("f2dba7"))
	var target: Node3D = game.nearest()
	var hint: String = "E  " + target.title if target else "WASD 移动  ·  Shift 跑  ·  空格 跳跃"
	text_at(Vector2(w*0.34,h-43),hint,20)
	text_at(Vector2(w*0.30,h-18),"左键 动手  ·  右键 投掷  ·  Q 收纳  ·  R 换物  ·  Tab 背包  ·  J 记录",14)
	if toast_time>0:
		draw_rect(Rect2(w*0.22,h-165,w*0.72,85),Color(0,0,0,0.72))
		var lines := toast.split("\n")
		for i in range(mini(lines.size(),3)): text_at(Vector2(w*0.24,h-137+i*24),lines[i],18)
	if p.bag_open:
		draw_rect(Rect2(w-360,135,330,280),Color(0.02,0.04,0.06,0.9))
		text_at(Vector2(w-340,168),"随身物品 / 无容量限制",20)
		text_at(Vector2(w-340,198),"手持："+(p.held.title if p.held else "空"),18)
		for i in range(p.inventory.size()): text_at(Vector2(w-340,228+i*23),p.inventory[i].title,18)
		text_at(Vector2(w-340,392),"R 轮换取出 · Q 收纳 · G 放下",16)
	if p.dead>0:
		draw_rect(Rect2(0,h*0.4,w,100),Color(0.15,0,0,0.75))
		text_at(Vector2(w*0.38,h*0.4+60),"今天，先躺一下。",34,Color("e27670"))

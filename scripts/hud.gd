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
	var target: Node3D = game.focus_target
	var hint: String = "E  " + target.title if target else "WASD 移动  ·  Shift 跑  ·  空格 跳跃"
	text_at(Vector2(w*0.34,h-43),hint,20)
	text_at(Vector2(w*0.30,h-18),"左键 动手 · 右键 投掷 · H 操作帮助",14)
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

	if game.speaker is OfficeNPC and not game.conversation.is_empty():
		var npc: OfficeNPC = game.speaker
		draw_rect(Rect2(w*0.22,h-399, w*0.75,56),Color(0.02,0.03,0.05,0.85))
		text_at(Vector2(w*0.24,h-376),npc.title+"  ·  "+game.relationship(npc)+"  ·  "+npc.mood,16)
		draw_rect(Rect2(w*0.24,h-363,100,4),Color("444b50"))
		draw_rect(Rect2(w*0.24,h-363,float(npc.affinity+100)/200.0*100,4),Color("89b8a4"))
	if not game.conversation.is_empty():
		draw_rect(Rect2(w*0.22,h-335,w*0.75,155),Color(0.02,0.03,0.05,0.9))
		text_at(Vector2(w*0.24,h-305),game.conversation.text,18)
		for i in range(game.conversation.choices.size()):
			text_at(Vector2(w*0.24,h-275+i*27),str(i+1)+"  "+game.conversation.choices[i][0],18,Color("f5d386"))
		text_at(Vector2(w*0.24,h-194),"数字键选择 · 走开或动手立即中断",14)
	if game.journal_open:
		draw_rect(Rect2(240,100,w-300,h-200),Color(0.02,0.04,0.06,0.95))
		text_at(Vector2(265,137),"已知事项 / 成果记录 · J 关闭",24)
		text_at(Vector2(265,175),game.career.grade,18,Color("f5d386"))
		var records: Array = game.career.records
		for i in range(maxi(0,records.size()-15),records.size()):
			text_at(Vector2(265,210+(i-maxi(0,records.size()-15))*26),records[i],16)

		text_at(Vector2(265,h-150),"应付：规程 %.2f / 自己人 %.2f" % [game.payroll.pending.a/100.0,game.payroll.pending.b/100.0],16)
		if not game.payroll.payments.is_empty():
			var last: Dictionary = game.payroll.payments.back()
			text_at(Vector2(265,h-120),"最近到账：%s  ¥%.2f（全部明细保存在存档）" % [last.company,last.cents/100.0],16)

	if game.ledger_open:
		draw_rect(Rect2(240,100,w-300,h-200),Color(0.02,0.04,0.06,0.95))
		text_at(Vector2(265,137),"工资到账明细 · L 关闭 · PgUp/PgDn 翻页",22)
		text_at(Vector2(265,173),"余额 %.2f / 应付 规程 %.2f · 自己人 %.2f" % [game.payroll.balance/100.0,game.payroll.pending.a/100.0,game.payroll.pending.b/100.0],18)
		var payments: Array = game.payroll.payments
		var pages := maxi(1,ceili(payments.size()/14.0))
		game.ledger_page=mini(game.ledger_page,pages-1)
		for i in range(game.ledger_page*14,mini(payments.size(),(game.ledger_page+1)*14)):
			var entry: Dictionary = payments[i]
			text_at(Vector2(265,211+(i%14)*26),"第%d天 · %s · 到账 ¥%.2f · 编号 %s" % [int(entry.minute)/1440+1,"规程科技" if entry.company=="a" else "自己人网络",entry.cents/100.0,entry.id],17)
		text_at(Vector2(265,h-120),"第 %d / %d 页 · 在职计薪，不按工作量扣款" % [game.ledger_page+1,pages],16)
	if game.help_open:
		draw_rect(Rect2(230,105,w-460,470),Color(0.02,0.04,0.06,0.96))
		var lines := ["操作说明 / H 关闭", "WASD 移动 · Shift 跑 · 空格 跳跃 · 鼠标转向", "E 靠近交互/拾取/推掀大件 · 数字 1–4 选择对话", "左键 推击或挥击 · 右键 投掷 · G 放下", "Q 收纳 · R 轮换取出 · Tab 查看背包", "J 已知事项与成果 · L 工资明细", "F5 保存 · F9 读取 · Esc 菜单与设置", "蓝色 A：规程科技 · 棕色 B：自己人网络", "星级代表当前公司后果：警告 → 机会取消 → 决裂", "死亡附近复活，不掉装备。投出的物品留在世界。", "按 E 找保安清理堵路大件；已造成的后果不会消失。", "移动或动手随时中断对话。所有职业内容均可不动手完成。"]
		for i in range(lines.size()): text_at(Vector2(255,145+i*33),lines[i],18)
	if game.debug_open:
		text_at(Vector2(270,95),"DEBUG stage=%d employer=%s facts=%d fps=%d" % [game.career.stage,game.career.employer,game.career.facts.size(),Engine.get_frames_per_second()],16)

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
	draw_string_outline(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,1,Color(0,0,0,0.6))
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
	if game.alert_level()>0:
		text_at(Vector2(w-205,44),"★".repeat(game.alert_level())+"☆".repeat(5-game.alert_level()),27,Color("e3bc69"))
	text_at(Vector2(w-160,73),game.clock_text(),15,Color("d2d8db"))
	text_at(Vector2(32,35),"J  任务    TAB  背包",14,Color("c7cdd0"))
	text_at(Vector2(w-92,h-25),"H  帮助",14,Color("c7cdd0"))
	var target: Node3D = game.focus_target
	if target and not p.bag_open and game.conversation.is_empty():
		var verb := "交谈" if target is OfficeNPC else "使用"
		if target is OfficeProp: verb="收进背包" if target.portable() else "破坏" if target.anchored() else "推动"
		if target is OfficeNPC and target.dead: verb="查看"
		var title: String=target.title.split(" · ")[0]
		var hint := "E  "+verb+"  ·  "+title
		if target is OfficeProp and target.damaged: hint+="（已损坏）"
		var width := font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+40
		draw_style_box(panel_style(),Rect2((w-width)/2,h-78,width,42))
		text_at(Vector2((w-width)/2+20,h-51),hint,18)
	if toast_time>0 and not p.bag_open and game.conversation.is_empty():
		var width := minf(620,w-300)
		var lines := wrap_lines(toast,width-36,17)
		var height := mini(3,lines.size())*25+24
		draw_style_box(panel_style(),Rect2((w-width)/2,h-104-height,width,height))
		for i in range(mini(lines.size(),3)): text_at(Vector2((w-width)/2+18,h-104-height+29+i*25),lines[i],17,Color("e1e5e6"))
	if p.bag_open:
		var left := w-380
		draw_style_box(panel_style(),Rect2(left,110,348,400))
		text_at(Vector2(left+24,149),"随身物品",24)
		text_at(Vector2(left+24,181),"手持  "+(p.held.title if p.held else "无"),15,Color("a4b3bd"))
		var pages := maxi(1,ceili(p.inventory.size()/8.0))
		p.bag_page=clampi(p.bag_page,0,pages-1)
		for i in range(p.bag_page*8,mini(p.inventory.size(),(p.bag_page+1)*8)):
			var y := 219+(i%8)*29
			text_at(Vector2(left+24,y),str(i%8+1)+"   "+p.inventory[i].title,18)
		if p.inventory.is_empty(): text_at(Vector2(left+24,235),"靠近小物件，按 E 收纳",17,Color("a4b3bd"))
		text_at(Vector2(left+24,466),"数字键取出  ·  Q 收纳  ·  G 放下",14,Color("a4b3bd"))
		text_at(Vector2(left+24,492),"PgUp / PgDn    %d / %d" % [p.bag_page+1,pages],14,Color("a4b3bd"))
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
		text_at(Vector2(265,175),game.objective_text(),17,Color("d5c393"))
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
		var lines := ["操作说明 / H 关闭", "WASD 移动 · Shift 跑 · 空格 跳跃 · 鼠标转向", "E 交互 / 小件入包 / 破坏或推掀大件 · 数字 1–4 选择对话", "左键 推击或挥击 · 右键 投掷 · G 放下", "Q 收纳 · R 轮换取出 · Tab 背包（数字键取出）", "J 已知事项与成果 · L 工资明细", "F5 保存 · F9 读取 · Esc 菜单与设置", "蓝色 A：规程科技 · 棕色 B：自己人网络", "星级代表当前公司后果：警告 → 机会取消 → 决裂", "玩家死亡附近复活；NPC 可死亡，后果永久保存。", "按 E 找保安清理堵路大件；已造成的后果不会消失。", "移动或动手随时中断对话。所有职业内容均可不动手完成。"]
		for i in range(lines.size()): text_at(Vector2(255,145+i*33),lines[i],18)
	if game.debug_open:
		text_at(Vector2(270,95),"DEBUG stage=%d employer=%s facts=%d fps=%d" % [game.career.stage,game.career.employer,game.career.facts.size(),Engine.get_frames_per_second()],16)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.045,0.055,0.065,0.91)
	style.border_color=Color(0.3,0.36,0.4,0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func wrap_lines(value: String,width: float,font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for character in value:
		if character=="\n" or font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
			lines.append(line)
			line="" if character=="\n" else character
		else: line+=character
	if not line.is_empty(): lines.append(line)
	return lines

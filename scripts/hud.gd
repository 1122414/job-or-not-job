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
	if not get_tree().paused: toast_time = maxf(0,toast_time-delta)
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
	var destination := ObjectiveGuide.target(game)
	if destination:
		var point := center+Vector2(destination.position.x,destination.position.z)*2.05
		draw_circle(point,5,Color("e4be70"))
		draw_arc(point,8,0,TAU,24,Color("e4be70"),1.5)
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
	if game.panels.page=="":
		var goal: String=game.objective_text()
		var lines := wrap_lines(goal,480,17)
		for i in range(mini(2,lines.size())): text_at(Vector2(32,38+i*24),lines[i],17,Color("f0e6d3"))
		text_at(Vector2(32,92),"J  目标与公司    TAB  背包",13,Color("c7cdd0"))
		if destination:
			text_at(Vector2(35,h-64),"目的地  %dm" % int(p.position.distance_to(destination.position)),14,Color("e4be70"))
	text_at(Vector2(w-92,h-25),"H  帮助",14,Color("c7cdd0"))
	var target: Node3D = game.focus_target
	if target and game.panels.page=="" and game.conversation.is_empty():
		var verb := "交谈" if target is OfficeNPC else "使用"
		if target is OfficeProp: verb="收进背包" if target.portable() else "查看固定支架" if target.kind in ["panel","side_panel"] else "推掀"
		if target is OfficeNPC and target.dead: verb="查看"
		var title: String=target.title.split(" · ")[0]
		var hint := "E  "+verb+"  ·  "+title
		if target is OfficeProp and target.damaged: hint+="（已损坏）"
		var width := font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+40
		draw_style_box(panel_style(),Rect2((w-width)/2,h-78,width,42))
		text_at(Vector2((w-width)/2+20,h-51),hint,18)
	if toast_time>0 and game.panels.page=="" and game.conversation.is_empty():
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

	if not game.conversation.is_empty():
		var dialogue_lines := wrap_lines(game.conversation.text,w*0.69,18)
		var height: float=80+dialogue_lines.size()*25+game.conversation.choices.size()*29
		var top: float=h-80-height
		if game.speaker is OfficeNPC:
			var npc: OfficeNPC=game.speaker
			draw_style_box(panel_style(),Rect2(w*0.22,top-39,w*0.75,35))
			text_at(Vector2(w*0.24,top-16),npc.title+"  ·  "+game.relationship(npc),16)
		draw_style_box(panel_style(),Rect2(w*0.22,top,w*0.75,height))
		var y: float=top+30
		for line in dialogue_lines:
			text_at(Vector2(w*0.24,y),line,18)
			y+=25
		y+=14
		for i in range(game.conversation.choices.size()):
			text_at(Vector2(w*0.24,y),str(i+1)+"  "+game.conversation.choices[i][0],17,Color("f5d386"))
			y+=29
		text_at(Vector2(w*0.24,h-97),"数字键选择 · 走开或动手立即中断",14,Color("a4b3bd"))
	if game.journal_open:
		draw_style_box(panel_style(),Rect2(230,80,w-460,h-160))
		text_at(Vector2(260,122),"今天的安排",26)
		text_at(Vector2(w-400,120),"K 历史 · Esc 返回",14,Color("a4b3bd"))
		var row := 165.0
		if game.career.employer=="":
			for item in [["1  规程科技","三轮面试 · 从实习开始 · 流程明确，名额另算"],["2  自己人网络","一轮面试 · 同事互帮互助，也可能有人情加班"]]:
				text_at(Vector2(260,row),item[0],20,Color("e4be70"))
				text_at(Vector2(260,row+28),item[1],16,Color("c7cdd0"))
				row+=76
			text_at(Vector2(260,row),"数字键选择导航；可以随时改变主意。",15,Color("a4b3bd"))
			row+=40
		text_at(Vector2(260,row),"当前目标",18,Color("e4be70"))
		row+=28
		for line in wrap_lines(game.objective_text(),w-520,17):
			text_at(Vector2(260,row),line,17)
			row+=25
		row+=22
		var pending: Array=game.office.pending_visits()
		if not pending.is_empty():
			text_at(Vector2(260,row),"可选交谈 · 数字键导航 / 3 回到工作目标",16,Color("e4be70"))
			row+=28
			for i in range(pending.size()):
				var person: OfficeNPC=game.npc_for_role(pending[i].npc)
				text_at(Vector2(260,row),str(i+4)+"  "+(person.title if person else "岗位接替中")+" · 有未读事项",16)
				row+=24
			row+=14
		text_at(Vector2(260,row),"最近发生",18,Color("a4b3bd"))
		row+=28
		var records: Array=game.career.records
		if records.is_empty(): text_at(Vector2(260,row),"先了解岗位，再决定是否入职。",16)
		for i in range(maxi(0,records.size()-5),records.size()):
			for line in wrap_lines(records[i],w-520,15):
				if row<h-120: text_at(Vector2(260,row),line,15,Color("c7cdd0"))
				row+=23

	if game.history_open:
		draw_style_box(panel_style(),Rect2(230,80,w-460,h-160))
		text_at(Vector2(260,122),"经历与成果",26)
		var lines: PackedStringArray=[]
		for record in game.career.records:
			lines.append_array(wrap_lines(record,w-520,16))
			lines.append("")
		var pages := maxi(1,ceili(lines.size()/18.0))
		game.history_page=clampi(game.history_page,0,pages-1)
		for i in range(game.history_page*18,mini(lines.size(),(game.history_page+1)*18)):
			text_at(Vector2(260,167+(i%18)*25),lines[i],16)
		text_at(Vector2(260,h-110),"PgUp/PgDn  %d / %d · Esc 返回" % [game.history_page+1,pages],14,Color("a4b3bd"))
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
		var lines := ["操作说明 / H 关闭", "WASD 移动 · Shift 跑 · 空格 跳跃 · 鼠标转向", "E 交互 / 小件入包 / 推掀大件 · 数字 1–4 选择对话", "左键 普通击打（不致命） · Alt+左键 重物危险攻击", "右键 投掷（重物可能致命） · G 放下", "Q 收纳 · R 轮换取出 · Tab 背包（数字键取出）", "J 已知事项与成果 · L 工资明细", "F5 保存 · F9 读取 · Esc 菜单与设置", "蓝色 A：规程科技 · 棕色 B：自己人网络", "星级代表当前公司后果：警告 → 机会取消 → 决裂", "徒手最多打昏；伤者救助离场，次日上午返岗。", "危险行为可致命；死者不复活，岗位另行接替。", "按 E 找保安清理堵路大件；已造成的后果不会消失。", "移动或动手随时中断对话。所有职业内容均可不动手完成。"]
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

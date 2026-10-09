class_name StreetHUD
extends Control

var game: Node3D
var font: Font = ThemeDB.fallback_font
var toast := ""
var toast_time := 0.0
var free_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	free_button=Button.new();free_button.text="T  我想自己说……"
	free_button.add_theme_font_override("font",preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"))
	free_button.pressed.connect(func(): game.free_chat.open(game.speaker if is_instance_valid(game.speaker) else game.focus_target))
	add_child(free_button)

func text_at(pos: Vector2, text: String, size: int = 20, color: Color = Color.WHITE) -> void:
	draw_string_outline(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,1,Color(0,0,0,0.6))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _process(delta: float) -> void:
	if not get_tree().paused: toast_time = maxf(0,toast_time-delta)
	var person: Node3D=game.speaker if is_instance_valid(game.speaker) else game.focus_target
	free_button.visible=game.panels.page=="" and TargetStatus.supported(person) and person.visible and person.available()
	free_button.position=Vector2(size.x-354,276);free_button.size=Vector2(326,38)
	queue_redraw()

func _draw() -> void:
	if not game.player: return
	var p: OfficePlayer = game.player
	var w := size.x
	var h := size.y
	var scene_dialogue: bool=game.conversation.get("scene",false)
	var center := Vector2(112,h-135)
	draw_circle(center,83,Color(0.02,0.03,0.04,0.85))
	draw_circle(center,77,Color("586469"))
	# A north-up overview uses the connected district coordinates, including transit.
	var map_scale := 0.5
	var map_origin := Vector2(0,54)
	var route := PackedVector2Array()
	for point in game.transit.curve.get_baked_points(): route.append(center+(Vector2(point.x,point.z)-map_origin)*map_scale)
	draw_polyline(route,Color("a8acaa"),5,true)
	for x in [-14,14]:
		var point := center+(Vector2(x,-4)-map_origin)*map_scale
		draw_rect(Rect2(point-Vector2(5,4),Vector2(10,8)),Color("a6927c"))
	for stop in CityLayout.STOPS:
		draw_circle(center+(Vector2(stop.point.x,stop.point.z)-map_origin)*map_scale,3,Color("e4be70"))
	draw_circle(center+(Vector2(game.transit.bus.position.x,game.transit.bus.position.z)-map_origin)*map_scale,3,Color("e09267"))
	var destination: Node3D=game.navigation_target()
	if destination:
		var point := center+(Vector2(destination.position.x,destination.position.z)-map_origin)*map_scale
		draw_arc(point,6,0,TAU,24,Color("e4be70"),1.5)
	var marker := center+(Vector2(p.position.x,p.position.z)-map_origin)*map_scale
	marker=center+(marker-center).limit_length(71)
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
	if game.save_problem!="": text_at(Vector2(w-275,100),"进度未保存 · F5 重试 / Esc 菜单",14,Color("e4be70"))
	if game.panels.page=="" and not scene_dialogue:
		var goal: String=game.objective_text()
		var lines := wrap_lines(goal,480,17)
		for i in range(mini(2,lines.size())): text_at(Vector2(32,38+i*24),lines[i],17,Color("f0e6d3"))
		text_at(Vector2(32,92),"J  安排    M  城区与出行    P  人物    TAB  背包",13,Color("c7cdd0"))
		if game==get_tree().current_scene and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
			text_at(Vector2(32,118),"点击画面控制视角 · Esc 释放鼠标",15,Color("e4be70"))
		if destination:
			text_at(Vector2(35,h-64),"目的地  %dm" % int(p.position.distance_to(destination.position)),14,Color("e4be70"))
	if not scene_dialogue: text_at(Vector2(w-92,h-25),"H  帮助",14,Color("c7cdd0"))
	var subtitle_top := h-92.0
	if game.city_life and game.panels.page=="" and game.conversation.is_empty():
		var caption: String=game.city_life.caption()
		if caption=="" and game.commons: caption=game.commons.caption()
		if caption!="":
			var width := minf(780,w-340)
			var subtitle_lines := wrap_lines(caption,width-40,19)
			var height := 34+subtitle_lines.size()*27
			var at := Vector2((w-width)/2,h-height-85)
			subtitle_top=at.y
			draw_style_box(dialogue_style(),Rect2(at,Vector2(width,height)))
			for i in range(subtitle_lines.size()): text_at(at+Vector2(20,27+i*27),subtitle_lines[i],19)
	if game.transit.riding and game.panels.page=="":
		text_at(Vector2(w*0.35,h-52),"101 · "+("已离线停靠 · E 下车 / 接管" if game.transit.bus.taken else "已到站 · E 下车" if game.transit.current_stop>=0 else "E 请求下车 · 下一站 "+CityLayout.STOPS[game.transit.next_stop].title),18,Color("e4be70"))
	if game.driving.in_vehicle() and game.panels.page=="":
		text_at(Vector2(w*0.35,h-52),"%02d km/h   W/S 油门与倒车 · A/D 转向 · 空格手刹 · E 下车" % roundi(absf(game.driving.active.speed)*3.6),16,Color("e4be70"))
	var person: Node3D=game.speaker if is_instance_valid(game.speaker) else game.focus_target
	if game.panels.page=="" and TargetStatus.supported(person) and person.visible:
		var status := TargetStatus.describe(game,person)
		var at := Vector2(w-354,132)
		draw_style_box(panel_style(),Rect2(at,Vector2(326,136)))
		text_at(at+Vector2(14,25),status.name+" · "+status.state.left(12),16)
		draw_rect(Rect2(at+Vector2(14,39),Vector2(298,9)),Color("372e32"))
		draw_rect(Rect2(at+Vector2(14,39),Vector2(298*status.hp/100.0,9)),Color("e78963"))
		text_at(at+Vector2(14,71),"生命 %d / 100"%status.hp,14)
		text_at(at+Vector2(14,97),"好感 %+d  信任 %+d  恐惧 %d"%[status.affinity,status.trust,status.fear],15)
		text_at(at+Vector2(14,121),status.reason.left(20),13,Color("e4be70"))
	var target: Node3D = null if game.in_vehicle() else game.focus_target
	if target and game.panels.page=="" and game.conversation.is_empty():
		var verb := "交谈" if target is OfficeNPC or target is CityResident or target is AutumnStoryPoint and target.person else "使用"
		if target is CityCar: verb="乘坐 / 接管" if target.bus_mode else "抢夺车辆" if target.traffic and not target.taken else "驾驶"
		if target is OfficeProp: verb="收进背包" if target.portable() else "查看固定支架" if target.kind in ["panel","side_panel"] else "推掀"
		if target is OfficeNPC and target.dead: verb="查看"
		if target is CityResident and not target.available(): verb="查看"
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
		var top := minf(h-104,subtitle_top-12)-height
		draw_style_box(panel_style(),Rect2((w-width)/2,top,width,height))
		for i in range(mini(lines.size(),3)): text_at(Vector2((w-width)/2+18,top+29+i*25),lines[i],17,Color("e1e5e6"))
	if p.dead>0:
		draw_rect(Rect2(0,h*0.4,w,100),Color(0.15,0,0,0.75))
		text_at(Vector2(w*0.38,h*0.4+60),"今天，先躺一下。",34,Color("e27670"))

	if not game.conversation.is_empty():
		var in_scene: bool=scene_dialogue
		var panel_x: float=w*0.22
		var panel_width: float=w*(0.64 if in_scene else 0.75)
		var dialogue_lines := wrap_lines(game.conversation.text,panel_width-48,18)
		var option_lines: Array=[]
		var option_height: float=0
		for i in range(game.conversation.choices.size()):
			var lines := wrap_lines(str(i+1)+"  "+game.conversation.choices[i][0],panel_width-48,17)
			option_lines.append(lines)
			option_height+=lines.size()*23+6
		var actor: OfficeNPC=game.npc_for_role(game.conversation.get("actor","")) if in_scene else game.speaker if game.speaker is OfficeNPC else null
		var name_height: float=30 if in_scene and actor else 0
		var height: float=maxf(112,76+name_height+dialogue_lines.size()*25+option_height)
		var top: float=h-52-height
		if actor and not in_scene:
			var npc: OfficeNPC=actor
			draw_style_box(panel_style(),Rect2(panel_x,top-39,panel_width,35))
			text_at(Vector2(panel_x+24,top-16),npc.title+"  ·  "+game.relationship(npc),16)
		draw_style_box(dialogue_style() if in_scene else panel_style(),Rect2(panel_x,top,panel_width,height))
		var y: float=top+30
		if actor and in_scene:
			text_at(Vector2(panel_x+24,y),actor.title.split(" · ")[0],17,Color("e4c889"))
			y+=name_height
		for line in dialogue_lines:
			text_at(Vector2(panel_x+24,y),line,18)
			y+=25
		y+=12
		for lines in option_lines:
			for line in lines:
				text_at(Vector2(panel_x+24,y),line,17,Color("f5d386"))
				y+=23
			y+=6
		text_at(Vector2(panel_x+24,top+height-19),game.conversation.get("hint","数字键选择 · 走开或动手立即中断"),14,Color("a4b3bd"))
	if game.debug_open:
		text_at(Vector2(270,95),"DEBUG stage=%d employer=%s facts=%d fps=%d" % [game.career.stage,game.career.employer,game.career.facts.size(),Engine.get_frames_per_second()],16)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.045,0.055,0.065,0.91)
	style.border_color=Color(0.3,0.36,0.4,0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func dialogue_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.025,0.035,0.045,0.78)
	style.border_color=Color(0.55,0.60,0.62,0.22)
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

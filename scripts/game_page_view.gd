class_name GamePageView
extends Control

const TITLES := {"journal":"今天的安排","messages":"招聘消息","computer":"工作台","people":"认识的人","promises":"谈过的约定","bag":"随身物品","history":"经历与成果","ledger":"工资到账明细","help":"操作说明"}
const ACCENT := Color("e6c785")
const MUTED := Color("afc0c8")
var game: Node3D
var sheet: PanelContainer
var heading: Label
var body: VBoxContainer
var scroll: ScrollContainer
var back_button: Button
var feedback: Label
var buttons: Dictionary={}
var displayed_page := ""
var font_scale := 1.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(0.015,0.025,0.035,0.72)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	theme=Theme.new()
	theme.default_font_size=18
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("26353d") if state=="normal" else Color("3b4e56")
		style.set_content_margin_all(12)
		style.set_corner_radius_all(4)
		if state=="focus":
			style.bg_color=Color.TRANSPARENT
			style.border_color=ACCENT
			style.set_border_width_all(2)
		theme.set_stylebox(state,"Button",style)
	sheet=PanelContainer.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color=Color("101b22")
	panel.set_content_margin_all(24)
	panel.set_corner_radius_all(8)
	sheet.add_theme_stylebox_override("panel",panel)
	add_child(sheet)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",16)
	sheet.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	heading=Label.new()
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size",28)
	header.add_child(heading)
	back_button=Button.new()
	back_button.text="返回 · Esc"
	back_button.pressed.connect(func(): game.panels.back())
	header.add_child(back_button)
	scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	layout.add_child(scroll)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",14)
	scroll.add_child(body)
	feedback=Label.new()
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_color_override("font_color",ACCENT)
	layout.add_child(feedback)
	var footer := Label.new()
	footer.text="Tab 选择 · Enter 确认 · 滚轮翻阅"
	footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_color_override("font_color",MUTED)
	footer.add_theme_font_size_override("font_size",14)
	layout.add_child(footer)
	resized.connect(arrange)
	arrange()
	hide()

func arrange() -> void:
	if not sheet: return
	var width := minf(1000,size.x-32)
	sheet.position=Vector2((size.x-width)/2,24)
	sheet.size=Vector2(width,size.y-48)

func set_font_scale(value: float) -> void:
	font_scale=clampf(value,1,1.5)
	theme.default_font_size=roundi(18*font_scale)
	heading.add_theme_font_size_override("font_size",roundi(28*font_scale))
	refresh()

func paragraph(value: String, color: Color=Color.WHITE) -> Label:
	var label := Label.new()
	label.text=value
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color",color)
	body.add_child(label)
	return label

func action(id: String, value: String, callback: Callable, disabled: bool=false) -> Button:
	var button := Button.new()
	button.text=value
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y=46*font_scale
	button.disabled=disabled
	button.set_meta("action_id",id)
	button.pressed.connect(callback)
	body.add_child(button)
	buttons[id]=button
	return button

func key_action(id: String, value: String, key: int, disabled: bool=false) -> void:
	action(id,value,func(): game.panels.activate_key(key),disabled)

func refresh() -> void:
	var page: String=game.panels.page
	visible=TITLES.has(page)
	if not visible: displayed_page=""; return
	var same_page := displayed_page==page
	var old_scroll := scroll.scroll_vertical if same_page else 0
	var focused := get_viewport().gui_get_focus_owner()
	var focus_id: String=focused.get_meta("action_id","") if is_instance_valid(focused) and same_page else ""
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	buttons.clear()
	displayed_page=page
	heading.text=TITLES[page]
	feedback.visible=page=="computer"
	feedback.text=""
	match page:
		"journal": journal()
		"help": help_page()
		"bag": bag()
		"messages": messages()
		"computer": computer()
		"people": people()
		"promises": promises()
		"history":
			if game.career.records.is_empty(): paragraph("还没有经历。先了解岗位，再决定是否入职。",MUTED)
			for record in game.career.records: paragraph(record)
		"ledger": ledger()
	restore_focus.call_deferred(page,focus_id,old_scroll)

func restore_focus(page: String,id: String,old_scroll: int) -> void:
	if not visible or displayed_page!=page: return
	scroll.scroll_vertical=old_scroll
	if buttons.has(id) and not buttons[id].disabled: buttons[id].grab_focus()
	else: back_button.grab_focus()

func journal() -> void:
	paragraph("当前目标",ACCENT)
	paragraph(game.objective_text())
	if game.career.employer=="":
		paragraph("了解岗位后再决定。导航选择可以随时更改。",MUTED)
		key_action("company-a","1  规程科技 · 演示项目岗位 / 三轮沟通",KEY_1)
		key_action("company-b","2  自己人网络 · 协作与资料交接 / 一轮沟通",KEY_2)
	var pending: Array=game.office.pending_visits()
	if not pending.is_empty():
		paragraph("可选交谈",ACCENT)
		key_action("work-goal","3  回到工作目标",KEY_3)
		for i in range(mini(6,pending.size())):
			var person: OfficeNPC=game.npc_for_role(pending[i].npc)
			key_action("visit-"+str(i),str(i+4)+"  "+(person.title if person else "岗位接替中")+" · 有未读事项",KEY_4+i)
	var navigation := HFlowContainer.new()
	navigation.add_theme_constant_override("h_separation",12)
	navigation.add_theme_constant_override("v_separation",12)
	body.add_child(navigation)
	for page in ["messages","history","people","bag","promises","ledger"]:
		var destination: String=page
		var button := action("open-"+page,TITLES[page],func(): game.panels.open_child(destination))
		button.custom_minimum_size.x=210*font_scale
		button.reparent(navigation,false)
	paragraph("最近发生",ACCENT)
	var records: Array=game.career.records
	if records.is_empty(): paragraph("先了解岗位，再决定是否入职。",MUTED)
	for i in range(maxi(0,records.size()-5),records.size()): paragraph(records[i])

func help_page() -> void:
	for section in [
		["走进城市","WASD 移动 · Shift 跑 · 空格跳跃 · 鼠标转向。\nE 交互或推进台词，数字键回应；移动或动手可中断对话。"],
		["随身物品","Q 收纳 · R 轮换取出 · Tab 打开背包。\n背包内可点击物品取出、收纳或放下，Esc 返回；Tab 在按钮间移动焦点。"],
		["信息与工作","J 已知事项 · P 人物关系 · L 工资明细。\nN 招聘消息 · O 实际约定 · K 历史经历。\n电脑可点击阅读资料与配置，保留 1—7 快捷键。"],
		["冲突与后果","左键普通击打，不致命；Alt＋左键为重物危险攻击。\n右键投掷，重物可能致命；G 放下。\n星级代表当前公司后果：警告、机会取消、决裂。"],
		["伤者与清理","徒手最多打昏；伤者救助离场，次日上午返岗。\n危险行为可致命；死者不复活，岗位另行接替。\n按 E 找保安清理堵路大件；已经造成的后果不会消失。"],
		["保存与返回","F5 保存 · F9 读取 · Esc 菜单。\n页面支持鼠标、Tab/Shift＋Tab、Enter，也可用手柄方向与确认/返回按钮。\n菜单期间世界暂停，关闭即恢复。"],
		["自由选择","蓝色 A：规程科技 · 棕色 B：自己人网络。\n所有职业内容均可不动手完成；你可以离开、拒绝或改变决定。"]]:
		paragraph(section[0],ACCENT)
		paragraph(section[1])
	action("help-end","已了解，返回",func(): game.panels.back())

func bag() -> void:
	var p: OfficePlayer=game.player
	paragraph("手持："+(p.held.title if p.held else "无"),ACCENT)
	key_action("store","Q  收纳手持物",KEY_Q,p.held==null)
	key_action("drop","G  放下手持物",KEY_G,p.held==null)
	var pages := maxi(1,ceili(p.inventory.size()/8.0))
	p.bag_page=clampi(p.bag_page,0,pages-1)
	if p.inventory.is_empty(): paragraph("靠近可携带物件，按 E 收纳。",MUTED)
	for i in range(p.bag_page*8,mini(p.inventory.size(),(p.bag_page+1)*8)):
		key_action("item-"+str(i),str(i%8+1)+"  取出 "+p.inventory[i].title,KEY_1+i%8)
	paragraph("第 %d / %d 页" % [p.bag_page+1,pages],MUTED)
	key_action("previous","上一页 · PgUp",KEY_PAGEUP,p.bag_page==0)
	key_action("next","下一页 · PgDn",KEY_PAGEDOWN,p.bag_page>=pages-1)

func messages() -> void:
	var flow: RecruitmentFlow=game.recruitment
	key_action("firm-a",("● " if flow.selected=="a" else "")+"规程科技",KEY_LEFT)
	key_action("firm-b",("● " if flow.selected=="b" else "")+"自己人网络",KEY_RIGHT)
	var selected: Array=flow.messages.filter(func(item): return item.firm==flow.selected)
	flow.message_page=clampi(flow.message_page,0,maxi(0,selected.size()-1))
	if selected.is_empty(): paragraph("暂无消息。面试结束后，约定时间会在这里收到反馈。",MUTED)
	else:
		var item: Dictionary=selected[selected.size()-1-flow.message_page]
		paragraph(item.sender+" · "+flow.stamp(int(item.minute)),ACCENT)
		paragraph(item.body)
	key_action("older","较早消息 · PgUp",KEY_PAGEUP,flow.message_page>=selected.size()-1)
	key_action("newer","较新消息 · PgDn",KEY_PAGEDOWN,flow.message_page==0)
	var phase: String=flow.applications[flow.selected].phase
	paragraph("当前状态："+{"idle":"尚未完成面试","waiting":"等待反馈","offered":"等待回复","deferred":"已暂缓，可继续考虑","declined":"已拒绝，可重新联系","accepted":"待现场报到","reported":"已报到"}.get(phase,phase),ACCENT)
	if phase in ["offered","deferred","declined"]:
		for i in range(3): key_action("reply-"+str(i),["1  接受并预约报到","2  暂缓决定","3  拒绝邀请"][i],KEY_1+i)
	if phase=="accepted":
		key_action("reply-0","1  改约到再下一日",KEY_1)
		key_action("reply-1","2  取消报到安排",KEY_2)
	key_action("conditions","Q  追问条件",KEY_Q)

func computer() -> void:
	var firm: String=game.career.employer
	if not firm in ["a","b"]: paragraph("当前没有可用的工作账号。",MUTED); return
	var project: Dictionary=game.projects.state(firm)
	var docs: Array=WorkProjects.A_DOCS if firm=="a" else WorkProjects.B_DOCS
	heading.text="演示工作台" if firm=="a" else "交接工作台"
	for i in range(3): key_action("document-"+str(i),str(i+1)+"  "+docs[i][0]+("  · 已打开" if game.projects.document==i else ""),KEY_1+i)
	paragraph(docs[game.projects.document][0],ACCENT)
	paragraph(docs[game.projects.document][1])
	var choices: Array
	if firm=="a": choices=["演示依据："+{"":"未选择","official":"正式说明 v1.2","draft":"未确认草稿 v2"}[project.source],"运行方式："+("离线样例" if project.mode=="offline" else "生产环境"),"运行预览"]
	else: choices=["交接版本："+{"":"未选择","complete":"完整交接包","old":"旧交接包"}[project.package],"计划时间："+{"":"未填写","tonight":"今晚","tomorrow":"明早10:00"}[project.deadline],"检查交接包","发送 / 准备协商材料"]
	for i in range(choices.size()): key_action("project-"+str(i+4),str(i+4)+"  "+choices[i],KEY_4+i)
	paragraph("预览 / 检查结果",ACCENT)
	paragraph("检查未通过，请查看具体问题。" if project.preview=="error" else project.preview if project.preview!="" else "尚未运行。配置改变后需要重新检查。")
	if firm=="a" and project.preview!="":
		paragraph("自动退款 · 未确认\n实时数据 · 缺少来源" if project.preview=="error" else "A-017 · 已处理 · 1\nA-018 · 待确认 · 1")
	feedback.text=game.projects.feedback

func people() -> void:
	var roster: Array[OfficeNPC]=game.social.roster()
	if roster.is_empty(): paragraph("还没有认识的人。",MUTED); return
	game.person_index=clampi(game.person_index,0,roster.size()-1)
	var selector := OptionButton.new()
	selector.set_meta("action_id","person-selector")
	selector.custom_minimum_size.y=46*font_scale
	selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	selector.fit_to_longest_item=false
	for person in roster: selector.add_item(person.title)
	selector.select(game.person_index)
	selector.item_selected.connect(func(index: int): game.person_index=index; refresh.call_deferred())
	body.add_child(selector)
	buttons["person-selector"]=selector
	var person: OfficeNPC=roster[game.person_index]
	var profile: Array=SocialLife.PROFILES.get(person.role_id,[person.title,"公司同事","需要相处才能了解。",""])
	paragraph(person.title+" · "+game.social.describe(person),ACCENT)
	paragraph(profile[1])
	paragraph(profile[2] if game.social.state(person).met else "尚未正式认识。可在招聘接待或办公区找到对方。")
	if game.social.outing.get("person")==person.stable_id: paragraph("当前约定："+game.social.kind_name(game.social.outing.kind)+"；靠近后 E 回应，可暂缓。")
	paragraph("最近的经历",ACCENT)
	var memories: Array=game.social.state(person).memories
	if memories.is_empty(): paragraph("还没有共同经历。",MUTED)
	for i in range(memories.size()-1,maxi(-1,memories.size()-5),-1): paragraph(memories[i])
	action("open-promises","查看实际约定",func(): game.panels.open_child("promises"))

func promises() -> void:
	var items: Array=game.recruitment.promises
	if items.is_empty(): paragraph("尚无记录。只保存实际完成过的关键交流。",MUTED); return
	game.promises.page=clampi(game.promises.page,0,items.size()-1)
	var item: Dictionary=items[items.size()-1-game.promises.page]
	paragraph(item.name+" · "+game.recruitment.stamp(int(item.minute)),ACCENT)
	paragraph("你当时说："+item.reply)
	paragraph("对方的原话："+item.quote)
	paragraph("岗位："+{"a_hr":"规程科技 · 招聘接待","a_lead":"规程科技 · 技术主管","a_boss":"规程科技 · 用工负责人","b_hr":"自己人网络 · 招聘接待"}.get(item.role,"岗位事务"),MUTED)
	var holder: OfficeNPC=game.npc_for_role(item.role)
	if holder and holder.stable_id!=item.person: paragraph("岗位现由"+holder.title+"接手；此前原话保留，私人关系独立。")
	key_action("older","较早约定 · PgUp",KEY_PAGEUP,game.promises.page>=items.size()-1)
	key_action("newer","较新约定 · PgDn",KEY_PAGEDOWN,game.promises.page==0)

func ledger() -> void:
	paragraph("余额 ¥%.2f" % (game.payroll.balance/100.0),ACCENT)
	paragraph("应付：规程 ¥%.2f · 自己人 ¥%.2f\n在职计薪，不按工作量扣款。" % [game.payroll.pending.a/100.0,game.payroll.pending.b/100.0],MUTED)
	if game.payroll.payments.is_empty(): paragraph("暂无到账记录。",MUTED)
	for entry in game.payroll.payments:
		paragraph("第%d天 · %s · 到账 ¥%.2f\n编号 %s" % [int(entry.minute)/1440+1,"规程科技" if entry.company=="a" else "自己人网络",entry.cents/100.0,entry.id])

class_name DepartureResponse
extends RefCounted

var game: Node3D

static func blank() -> Dictionary:
	return {"written":{},"meeting":{},"guide":""}

func state() -> Dictionary:
	return game.story.data.response

func available() -> bool:
	return game.story.active() and game.career.facts.has("conversion_failed")

func left_early() -> bool:
	return game.story.active() and game.career.former.has("a") and game.career.employer=="" and not available()

func person(id: String) -> OfficeNPC:
	for npc in game.npcs:
		if npc.stable_id==id: return npc
	return null

func witness() -> OfficeNPC:
	for item in game.recruitment.promises:
		if item.key=="internship_week8": return person(item.person)
	return game.npc_for_role("a_group")

func station() -> WorkStation:
	for node in game.stations:
		if node.stable_id=="backup": return node
	return null

func point(npc: OfficeNPC) -> Vector3:
	# The left side belongs to the group workstation; meet in the clear projection aisle.
	return station().position+Vector3(2 if npc.stable_id==state().meeting.boss else 0,0,2.2)

func owns(npc: OfficeNPC) -> bool:
	var m: Dictionary=state().meeting
	return not m.is_empty() and m.phase in ["walking","testified"] and npc.stable_id in [m.person,m.boss]

func safe() -> bool:
	var m: Dictionary=state().meeting
	if m.is_empty() or not available() or game.career.conflict.a>=2 or game.player.hp<=0 or game.in_vehicle(): return false
	if game.payroll.after_work() or game.payroll.minute/Payroll.DAY!=int(m.arranged_at)/Payroll.DAY: return false
	if game.player.position.distance_to(station().position)>22: return false
	for id in [m.person,m.boss]:
		var npc := person(id)
		if not npc or not npc.available() or npc.hostile>0 or npc.reaction>0 or npc.hit_stun>0: return false
	return game.social.willing(person(m.person))

func npc_target(npc: OfficeNPC) -> Variant:
	if not owns(npc) or not safe(): return null
	return npc.position if game.speaker==npc else point(npc)

func present() -> bool:
	if not safe(): return false
	var m: Dictionary=state().meeting
	if not m.phase in ["walking","testified"]: return false
	for id in [m.person,m.boss]:
		var npc := person(id)
		if npc.position.distance_to(point(npc))>.8 or not game.can_see(game.player,npc): return false
	return game.player.position.distance_to(station().position+Vector3(1,0,2.2))<3.5

func pause(reason: String) -> void:
	var m: Dictionary=state().meeting
	if m.is_empty() or not m.phase in ["walking","testified"]: return
	m.phase="paused";m.reason=reason
	for id in [m.person,m.boss]:
		var npc := person(id)
		if npc: npc.route_clock=0
	game.queue_save()

func tick() -> void:
	var m: Dictionary=state().meeting
	if m.get("phase","") in ["walking","testified"] and not safe():
		pause("会面暂缓：需在同一工作日、现场安全且大家愿意交谈时继续；原证言保留。")

func clear_guide() -> void:
	state().guide=""

func focus(id: String) -> void:
	game.home.guiding=false;game.city_life.guide="";game.city_life.walk.guiding=false
	game.driving.guide_car="";game.transit.waypoint=""
	if game.social.outing.has("guiding"): game.social.outing.guiding=false
	state().guide=id;game.queue_save()

func target() -> Node3D:
	if state().guide.begins_with("person:"): return person(state().guide.trim_prefix("person:"))
	if state().guide!="meeting": return null
	var m: Dictionary=state().meeting
	if m.is_empty() or m.phase in ["done","cancelled"]: return null
	return station() if m.phase in ["walking","testified"] else person(m.person)

func objective() -> Dictionary:
	var t := target()
	if t:
		if state().guide.begins_with("person:"): return {"title":"自愿安排 · 找"+t.title.split(" · ")[0]+"聊聊（J可取消导航）","id":""}
		var m: Dictionary=state().meeting
		return {"title":"成果见证 · 到投影旁，等两人到场后分别交谈" if m.phase in ["walking","testified"] else "成果见证 · 找原见证者确认或继续会面（J可取消）","id":""}
	if left_early(): return {"title":"实习已中止 · 已有成果和关系保留，J可选择接下来的去处","id":""}
	return {}

func status() -> String:
	if not game.story.active(): return ""
	var m: Dictionary=state().meeting
	if not m.is_empty():
		if m.phase=="paused": return m.reason
		if m.phase=="done": return "见证已完成 · 参与者说明成果合格，用工负责人当面承认；记录保留，仍未转正。"
		if m.phase=="requested": return "还没有约好见证者 · 需要你当面询问，对方可以拒绝。"
		if m.phase in ["walking","testified"]: return "两人已到场 · 请分别交谈，核对成果。" if present() else "两人正在前往投影成果旁，尚未记作见证完成。"
	if game.career.conflict.a>=2: return "公司机会已关闭，伤害与成果分别保留。你可以离开、回家或去公共街区。"
	if game.career.conflict.a==1: return "已收到动手警告；继续主动升级会关闭职业机会。可以先离开现场，再决定下一步。"
	if left_early(): return "你已提前离开这段实习。保留实际完成的成果，没有补记完整12周或转正失败答辩。"
	return "工作结果已经确定，接下来仍由你安排。" if available() else ""

func menu(npc: OfficeNPC) -> void:
	var w := witness()
	var choices: Array=[["请留下成果通过、无HC的书面结论","story_response_written"]]
	if w and not state().meeting.get("phase","") in ["done","walking","testified"]:
		choices.append(["我想请"+w.title.split(" · ")[0]+"到成果旁一起核对","story_response_request"])
	choices.append(["不再争论，先离开现场","story_response_leave"])
	choices.append(["返回答辩记录","story_verdict"])
	game.conversation={"text":OfficeDialogue.voice(npc,"方总：你可以要求把结论写清楚，也可以请参与项目的人来核对成果。名额的结论不会因此变成录用。"),"choices":choices}

func decorate(npc: Node3D,fallback: Dictionary) -> Dictionary:
	if not available() or not npc is OfficeNPC: return fallback
	var m: Dictionary=state().meeting
	if npc.role_id=="a_boss" and not fallback.choices.any(func(c): return c[1]=="story_response_menu"):
		fallback.choices.append(["要求书面结论、请人见证或离开","story_response_menu"])
	if m.is_empty(): return fallback
	if npc.stable_id==m.person:
		if m.phase in ["requested","paused","cancelled"]:
			fallback.choices.push_front(["当面确认：一起去投影成果旁作证（可稍后）","story_response_invite"])
		elif m.phase=="walking":
			fallback={"text":"先等我们都到投影旁。你可以暂停会面，原成果不会丢。","choices":[["请你当着方总说明成果","story_response_testify"],["先各自忙，暂停会面","story_response_pause"]]}
		elif m.phase=="testified": fallback={"text":"我的说明已经记下。请用工负责人当面回应。","choices":[["继续等方总回应","story_pause"],["先暂停会面","story_response_pause"]]}
	if npc.stable_id==m.boss and m.phase=="testified":
		fallback={"text":"方总：我听到了。你想核对这次成果的结论？","choices":[["请当着见证者承认成果通过、未转正是因为无HC","story_response_acknowledge"],["先暂停会面","story_response_pause"]]}
	return fallback

func local_actor(role: String="") -> OfficeNPC:
	var npc: OfficeNPC=game.speaker as OfficeNPC
	if not npc or not npc.available() or npc.hostile>0 or npc.reaction>0 or game.player.position.distance_to(npc.position)>3.5 or not game.can_see(game.player,npc): return null
	return npc if role=="" or npc.role_id==role else null

func handle(action: String) -> bool:
	if not action.begins_with("story_response_"): return false
	if not available(): return true
	var npc := local_actor()
	if not npc: return true
	var m: Dictionary=state().meeting
	match action:
		"story_response_menu":
			if npc.role_id=="a_boss": menu(npc)
		"story_response_written":
			if npc.role_id!="a_boss": return true
			if state().written.is_empty():
				state().written={"person":npc.stable_id,"at":game.payroll.minute}
				game.story.arc.remember(npc,"review_written","请把成果通过与无HC分别写下来。","演示交付与现场恢复均通过。未转正原因为公司没有正式HC，不是业务考核失败。")
				game.career.record("review_written","取得用工负责人的书面结论：两份成果通过，未转正原因为无正式HC。")
				game.social.remember(npc,"review_written","你要求他把成果评价与名额问题分开写清楚。",-1,1)
			game.conversation={"text":"书面结论已放入“谈过的约定”，签署人和日期保留。两份成果通过；未转正原因为无正式HC。","choices":[["查看书面记录","story_response_records"],["收好材料，先离开","story_response_leave"]]}
		"story_response_records": game.panels.show_page("promises")
		"story_response_request":
			if npc.role_id!="a_boss" or m.get("phase","") in ["walking","testified","done"]: return true
			var w := witness()
			if not w: return true
			if m.is_empty():
				state().meeting={"phase":"requested","person":w.stable_id,"boss":npc.stable_id,"requested_at":game.payroll.minute,"arranged_at":0,"testified_at":0,"finished_at":0,"reason":""}
			else: m.phase="requested"
			focus("meeting");game.close_interaction();game.say("先去当面询问"+w.title.split(" · ")[0]+"。同意之后，两人才会到投影成果旁会合。")
		"story_response_invite":
			if m.is_empty() or npc.stable_id!=m.person or not m.phase in ["requested","paused","cancelled"]: return true
			var previous: int=m.arranged_at
			m.arranged_at=game.payroll.minute
			if not safe():
				m.arranged_at=previous
				game.say("现在无法会面：需要工作时段、双方可交谈且现场安全。可以稍后再来或J取消。")
				return true
			for id in [m.person,m.boss]:
				if game.social.outing.get("person")==id:
					if game.social.outing.stage=="offered": game.social.expire_offer()
					else: game.social.pause_outing("先核对成果，原来的私人约定暂缓，之后可继续。")
				game.meals.cancel(id);person(id).route_clock=0
			m.phase="testified" if m.testified_at>0 else "walking";m.reason=""
			focus("meeting");game.close_interaction();game.say("两人将实际前往投影成果旁。到场后请分别交谈；可以随时离开或暂停。")
		"story_response_testify":
			if m.get("phase")!="walking" or npc.stable_id!=m.person: return true
			if not present(): game.say("需等你、见证者和方总都到场，才能作证。");return true
			m.phase="testified";m.testified_at=game.payroll.minute
			game.story.arc.remember(npc,"review_testimony","请当着方总核对两份成果。","第一份交付保留，第二份现场恢复也通过。我们要求的工作已经完成，不能把无名额写成成果不合格。")
			game.career.record("review_testimony","见证者到场核对两份成果并说明均合格，等待用工负责人回应。")
			game.social.remember(npc,"review_testimony","你请她到成果旁，当面确认已完成的工作。",2,2)
			game.conversation={"text":npc.title.split(" · ")[0]+"：两份成果都通过了。不能把无名额写成成果不合格。我的说明已经记下，请方总回应。","choices":[["记下证言，向方总核对","story_pause"],["先暂停会面","story_response_pause"]]}
		"story_response_acknowledge":
			if m.get("phase")!="testified" or npc.stable_id!=m.boss: return true
			if not present(): game.say("请等见证者回到现场，再确认当面结论。");return true
			m.phase="done";m.finished_at=game.payroll.minute;state().guide=""
			for id in [m.person,m.boss]: person(id).route_clock=0
			game.story.arc.remember(npc,"review_acknowledged","请在见证者面前确认未转正的原因。","我当面确认：两份成果通过；这次未转正是因为公司无正式HC。此前有HC的承诺没有兑现。")
			game.career.record("review_acknowledged","用工负责人在见证者面前确认成果通过、未转正原因为公司无HC；没有获得录用。")
			game.social.remember(npc,"review_acknowledged","你要求他在项目见证者面前承认成果与名额是两回事。",-1,1)
			game.conversation={"text":"方总当着见证者确认了成果通过与无HC，两份说明都保留。见证者回去处理自己的安排。你仍未转正，但这次结论有了共同见证。","choices":[["收好记录，先离开","story_response_leave"],["查看双方原话","story_response_records"]]}
		"story_response_pause": pause("你暂停了会面；原证言与私人约定保留。J可取消或重新寻找见证者。");game.close_interaction()
		"story_response_leave":
			pause("你先离开现场，会面暂缓；记录保留。")
			game.career.record("review_left","你决定先离开这次争论，把接下来的时间留给自己。材料和结果仍可回来看。")
			state().guide="";game.close_interaction();game.say("你结束了交谈。材料仍在，J可以选择回家、公共街区或熟人，也可以自己走走。")
	game.queue_save();return true

func cancel_meeting() -> void:
	var m: Dictionary=state().meeting
	if m.is_empty() or m.phase=="done": return
	m.phase="cancelled";m.reason="你取消了本次会面，已有证言保留。";state().guide=""
	for id in [m.person,m.boss]:
		var npc := person(id)
		if npc: npc.route_clock=0
	game.queue_save()

func opportunities() -> Array:
	if not (available() or left_early() or game.story.active() and game.career.conflict.a>0): return []
	var items: Array=[]
	for id in ["a_friend","a_group","b_friend"]:
		var npc: OfficeNPC=game.npc_for_role(id)
		if npc and game.social.state(npc).met and game.social.willing(npc):
			items.append({"id":"person:"+npc.stable_id,"text":"找"+npc.title.split(" · ")[0]+"聊聊 · 先当面看看对方是否有空"});break
	items.append({"id":"bookshop" if game.city_life.is_open() else "home","text":"去社区书屋看看 · 正在开放" if game.city_life.is_open() else "回东里住处歇一会儿 · 书屋已闭馆"})
	items.append({"id":"waterfront","text":"去海风步道走走 · 步行或乘101环线"})
	return items

func choose_place(id: String) -> void:
	if not opportunities().any(func(item): return item.id==id): return
	focus("")
	if id.begins_with("person:"): state().guide=id
	elif id=="home": game.home.guiding=true
	elif id=="bookshop": game.city_life.guide="notice"
	elif id=="waterfront": game.transit.waypoint="waterfront"
	game.panels.show_page("");game.queue_save()

static func valid(value: Variant,root: Dictionary) -> bool:
	if not value is Dictionary or not value.get("written") is Dictionary or not value.get("meeting") is Dictionary or not value.get("guide") is String: return false
	var facts: Dictionary=root.career.facts
	var m: Dictionary=value.meeting
	var w: Dictionary=value.written
	if (not m.is_empty() or not w.is_empty()) and (root.autumn_story.mode!="current" or not facts.has("conversion_failed")): return false
	if value.guide!="" and value.guide!="meeting" and (not value.guide.begins_with("person:") or not root.npcs.has(value.guide.trim_prefix("person:"))): return false
	if value.guide=="meeting" and (m.is_empty() or m.get("phase") in ["done","cancelled"]): return false
	for key in ["review_written","review_testimony","review_acknowledged"]:
		var records: Array=root.recruitment.promises.filter(func(item): return item.key==key)
		if (not records.is_empty())!=facts.has(key): return false
	if w.is_empty()!= (not facts.has("review_written")): return false
	if not w.is_empty():
		if not root.npcs.has(w.get("person","")) or not minute_valid(w.get("at"),root.payroll.minute): return false
		if root.npcs[w.person].role_id!="a_boss" or not has_record(root,"review_written",w.person,w.at): return false
	if m.is_empty(): return not facts.has("review_testimony") and not facts.has("review_acknowledged")
	if not m.get("phase") in ["requested","walking","paused","testified","done","cancelled"] or not m.get("reason") is String: return false
	for key in ["person","boss"]:
		if not m.get(key) is String or not root.npcs.has(m[key]): return false
	if m.person==m.boss or root.npcs[m.person].role_id!="a_group" or root.npcs[m.boss].role_id!="a_boss": return false
	for key in ["requested_at","arranged_at","testified_at","finished_at"]:
		if not minute_valid(m.get(key),root.payroll.minute): return false
	if m.arranged_at>0 and m.arranged_at<m.requested_at: return false
	if m.testified_at>0 and m.testified_at<m.requested_at: return false
	if m.phase in ["walking","testified","done"] and m.arranged_at==0: return false
	if (m.testified_at>0)!=facts.has("review_testimony"): return false
	if m.phase in ["testified","done"] and m.testified_at==0 or m.phase=="walking" and m.testified_at>0: return false
	if (m.finished_at>0)!=(m.phase=="done") or (m.finished_at>0)!=facts.has("review_acknowledged"): return false
	if m.finished_at>0 and (m.finished_at<m.testified_at or m.finished_at<m.arranged_at): return false
	if m.testified_at>0 and not has_record(root,"review_testimony",m.person,m.testified_at): return false
	if m.finished_at>0 and not has_record(root,"review_acknowledged",m.boss,m.finished_at): return false
	return true

static func minute_valid(value: Variant,now: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=0 and value==int(value) and value<=now

static func has_record(root: Dictionary,key: String,id: String,at: float) -> bool:
	for record in root.recruitment.promises:
		if record.key==key: return record.person==id and record.minute==at
	return false

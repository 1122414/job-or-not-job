class_name InterviewFlow
extends RefCounted

var game: Node3D
var sessions: Dictionary = {}
const ACTIONS := ["interview_hr","interview_lead","interview_boss","interview_b"]
const HOSTS := {"interview_hr":"a_hr","interview_lead":"a_lead","interview_boss":"a_boss","interview_b":"b_hr"}
func active_firm() -> String:
	for firm in sessions:
		if sessions[firm].status=="active": return firm
	return ""

func pages(action: String) -> Array:
	var result: Array=InterviewContent.CORE[action].duplicate(true)
	var firm := "b" if action=="interview_b" else "a"
	var session: Dictionary=sessions.get(firm,{})
	var follow: Array=InterviewContent.FOLLOW[action]
	if session.get("action")==action and follow[0] in session.get("answers",[]): result.append(follow[1])
	return result

func schedule(action: String) -> void:
	var firm := "b" if action=="interview_b" else "a"
	if game.career.conflict[firm]>=2:
		game.say("公司处分仍在生效，当前不接受面试。")
		return
	if not sessions.has(firm) or sessions[firm].action!=action or sessions[firm].status=="completed":
		sessions[firm]={"action":action,"step":0,"status":"scheduled","phase":"question","answers":[],"reply":0,"edition":2}
	else: sessions[firm].status="scheduled"
	game.career.facts["guide_company"]=firm
	game.close_interaction()
	var seen: String="waiting_seen_"+action
	game.say("面试室在里面，他还在回复上一场会议的消息。" if not game.career.facts.has(seen) else "01面试室，刚才的交流记录还在。")
	game.career.facts[seen]=true
	game.queue_save()

func host_target(npc: OfficeNPC) -> Variant:
	var session: Dictionary=sessions.get(npc.company,{})
	if session.is_empty() or session.status not in ["scheduled","active"] or HOSTS[session.action]!=npc.role_id: return null
	return OfficeRooms.INTERVIEW_HOSTS[npc.company]

func host_seated(npc: OfficeNPC) -> bool:
	var target: Variant=host_target(npc)
	return target!=null and npc.available() and npc.hit_stun<=0 and npc.block_time<=0 and npc.hostile<=0 and npc.position.distance_to(target)<0.35

func player_seated() -> bool:
	return game.player.seated and active_firm()!=""

func room_options(firm: String) -> Dictionary:
	var session: Dictionary=sessions.get(firm,{})
	if session.is_empty() or session.status=="completed": return {"text":"01 面试室 · 请先联系招聘接待安排面试。","choices":[]}
	var host: OfficeNPC=game.npc_for_role(HOSTS[session.action])
	if not host: return {"text":"岗位正在安排接替人员。原交流进度保留，稍后可继续。","choices":[]}
	if not host_seated(host): return {"text":host.title+"正在前来。可以先看看环境，等他到位后按E继续。","choices":[]}
	return {"text":host.title+"：请坐。","choices":[["坐下，开始或继续这轮交流","interview_seat_"+firm],["暂时不参加，保留进度","interview_leave"]]}

func raw_question(firm: String) -> Dictionary:
	var session: Dictionary=sessions[firm]
	var items := pages(session.action)
	if session.step>=items.size(): return {"text":closing(session.action),"choices":[["记录约定，结束本轮交流","interview_finish"],["暂不继续，保留选择与进度","interview_leave"]]}
	var item: Array=items[session.step]
	var host: OfficeNPC=game.npc_for_role(HOSTS[session.action])
	if session.phase=="reply": return {"text":item[2][session.reply],"choices":[["继续交流","interview_next"],["先离开，稍后继续","interview_leave"]]}
	var choices: Array=[]
	for i in range(item[1].size()): choices.append([item[1][i],"interview_answer_"+str(i)])
	return {"text":OfficeDialogue.voice(host,item[0]) if host else item[0],"choices":choices}

func handle(action: String) -> bool:
	if action in ACTIONS:
		schedule(action)
		return true
	if action=="interview_leave":
		interrupt()
		game.close_interaction()
		game.player.stand_up()
		game.say("面试已暂缓，进度保留。愿意时可回面试室继续。")
		return true
	if action.begins_with("interview_seat_"):
		var firm := action.trim_prefix("interview_seat_")
		if not sessions.has(firm): return true
		var host: OfficeNPC=game.npc_for_role(HOSTS[sessions[firm].action])
		if not host or not host_seated(host): return true
		sessions[firm].status="active"
		game.player.sit_at(OfficeRooms.INTERVIEW_SEATS[firm])
		game.player.frame_conversation(host)
		game.conversation=question(firm)
		return true
	var firm := active_firm()
	if firm=="" or not action.begins_with("interview_"): return false
	var session: Dictionary=sessions[firm]
	if action.begins_with("interview_answer_") and session.phase=="question":
		var answer := int(action.trim_prefix("interview_answer_"))
		if session.step>=pages(session.action).size(): return true
		if answer<0 or answer>=pages(session.action)[session.step][1].size(): return true
		session.answers.append(pages(session.action)[session.step][1][answer])
		session.reply=answer
		session.phase="reply"
	elif action=="interview_next" and session.phase=="reply":
		session.step+=1
		session.phase="question"
	elif action=="interview_finish" and session.step==pages(session.action).size():
		session.status="completed"
		game.career.record("terms_"+session.action,"面试约定："+"；".join(PackedStringArray(session.answers)))
		var result: String=game.recruitment.finish(session.action)
		if session.action in ["interview_hr","interview_lead"]: result=closing(session.action)
		game.close_interaction()
		game.player.stand_up()
		game.say(result)
		game.queue_save()
		return true
	game.conversation=question(firm)
	game.queue_save()
	return true

func interrupt() -> void:
	for firm in sessions:
		if sessions[firm].status=="active": sessions[firm].status="scheduled"

func tick() -> void:
	var firm := active_firm()
	if firm=="": return
	var host: OfficeNPC=game.npc_for_role(HOSTS[sessions[firm].action])
	if not host or not host.available() or host.hit_stun>0 or host.block_time>0 or not game.player.seated or game.player.position.distance_to(OfficeRooms.INTERVIEW_SEATS[firm])>1.2:
		game.close_interaction()
		game.say("面试已中断，未完成的交流可稍后继续。")

# The cursor belongs to a spoken segment, not to a UI panel. Reopening resumes it.
func question(firm: String) -> Dictionary:
	var raw := raw_question(firm)
	var session: Dictionary=sessions[firm]
	var key: String=session.action+"_"+str(session.step)+"_"+session.phase
	var cursor: Dictionary=game.recruitment.scenes.get(firm,{})
	if cursor.get("key","")!=key:
		cursor={"key":key,"line":0}
		game.recruitment.scenes[firm]=cursor
	var parts := segments(raw.text)
	cursor.line=clampi(int(cursor.line),0,parts.size()-1)
	var last: bool=cursor.line==parts.size()-1
	var choices: Array=raw.choices if last and session.phase=="question" and session.step<pages(session.action).size() else []
	return {"text":parts[cursor.line],"choices":choices,"scene":true,"hint":"数字键回应 · 起身可离开" if not choices.is_empty() else "E 继续 · 起身可离开","actor":HOSTS[session.action]}

static func segments(value: String) -> Array[String]:
	var result: Array[String]=[]
	var rest := value
	while rest.length()>46:
		var cut := 46
		for i in range(45,20,-1):
			if rest[i] in ["。","，","；","？","！"]: cut=i+1; break
		result.append(rest.substr(0,cut))
		rest=rest.substr(cut)
	result.append(rest)
	return result

func advance() -> bool:
	var firm := active_firm()
	if firm=="" or not game.conversation.get("scene",false): return false
	var session: Dictionary=sessions[firm]
	var cursor: Dictionary=game.recruitment.scenes[firm]
	var parts := segments(raw_question(firm).text)
	if cursor.line<parts.size()-1:
		cursor.line+=1
		game.conversation=question(firm)
	elif session.phase=="reply": handle("interview_next")
	elif session.step==pages(session.action).size(): handle("interview_finish")
	game.queue_save()
	return true

func performance(npc: OfficeNPC) -> String:
	if active_firm()!=npc.company or not host_seated(npc) or npc.hit_stun>0 or npc.block_time>0: return ""
	var session: Dictionary=sessions[npc.company]
	if HOSTS[session.action]!=npc.role_id: return ""
	if session.phase=="reply": return "sit_talk"
	return ["read","write","message","pause"][int(session.step)%4]

func closing(action: String) -> String:
	return {"interview_hr":"林岚：周工在里面，简历你拿好。", "interview_lead":"周工：方总接下来有空。我把意见发给他了。", "interview_boss":"方总：明天十点前，等林岚消息。", "interview_b":"阿诚：明天十点前联系你，路上慢点。"}[action]

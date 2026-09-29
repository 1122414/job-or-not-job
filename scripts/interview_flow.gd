class_name InterviewFlow
extends RefCounted

var game: Node3D
var sessions: Dictionary = {}
var heard_cues: Dictionary = {}
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
		sessions[firm]={"action":action,"step":0,"status":"scheduled","phase":"question","answers":[],"reply":0,"edition":2,"call_stage":"approach","call_elapsed":0.0,"exit_remaining":0.0,"box_drop_done":false,"gesture_done_step":-1}
	else: sessions[firm].status="scheduled"
	game.career.facts["guide_company"]=firm
	game.close_interaction()
	var seen: String="waiting_seen_"+action
	game.say("面试室在里面，他还在回复上一场会议的消息。" if not game.career.facts.has(seen) else "01面试室，刚才的交流记录还在。")
	game.career.facts[seen]=true
	game.queue_save()

func host_target(npc: OfficeNPC) -> Variant:
	if game.career.conflict[npc.company]>=2: return null
	var session: Dictionary=sessions.get(npc.company,{})
	if session.is_empty() or HOSTS[session.action]!=npc.role_id: return null
	if session.status=="completed": return OfficeRooms.point(game,npc.company,"interview_call") if float(session.get("exit_remaining",0))>0 else null
	if session.status not in ["scheduled","active"]: return null
	if session.status=="scheduled" and session.get("call_stage","room") in ["approach","calling"]: return OfficeRooms.point(game,npc.company,"interview_call")
	return OfficeRooms.point(game,npc.company,"interview_host")

func host_seated(npc: OfficeNPC) -> bool:
	var session: Dictionary=sessions.get(npc.company,{})
	return not session.is_empty() and session.status in ["scheduled","active"] and session.get("call_stage","room")=="room" and HOSTS[session.action]==npc.role_id and npc.available() and npc.hit_stun<=0 and npc.block_time<=0 and npc.hostile<=0 and npc.position.distance_to(OfficeRooms.point(game,npc.company,"interview_host"))<0.35

func host_calling(npc: OfficeNPC) -> bool:
	var session: Dictionary=sessions.get(npc.company,{})
	return not session.is_empty() and session.status=="scheduled" and session.get("call_stage","room")=="calling" and HOSTS[session.action]==npc.role_id and npc.available() and npc.position.distance_to(OfficeRooms.point(game,npc.company,"interview_call"))<0.35

func player_seated() -> bool:
	return game.player.seated and active_firm()!=""

func room_options(firm: String) -> Dictionary:
	if game.career.conflict[firm]>=2: return {"text":"这家公司已取消招聘安排。","choices":[]}
	var session: Dictionary=sessions.get(firm,{})
	if session.is_empty() or session.status=="completed": return {"text":"01 面试室 · 请先联系招聘接待安排面试。","choices":[]}
	var host: OfficeNPC=game.npc_for_role(HOSTS[session.action])
	if not host: return {"text":"岗位正在安排接替人员。原交流进度保留，稍后可继续。","choices":[]}
	if not host_seated(host): return {"text":host.title+"正在接你进去。","choices":[]}
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
		game.player.sit_at(OfficeRooms.point(game,firm,"interview_seat"))
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
		game.promises.heard(session,game.npc_for_role(HOSTS[session.action]))
		session.step+=1
		session.phase="question"
	elif action=="interview_finish" and session.step==pages(session.action).size():
		session.status="completed"
		session.exit_remaining=4.0
		cue_once(firm+"/"+session.action+"/exit","chair",OfficeRooms.point(game,firm,"interview_host"))
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
		if sessions[firm].status=="active":
			var host: OfficeNPC=game.npc_for_role(HOSTS[sessions[firm].action])
			if host:
				host.visual.animation.stop()
				host.visual.current=""
			sessions[firm].status="scheduled"

func tick(delta: float=0.016) -> void:
	update_props()
	for company in sessions:
		var pending: Dictionary=sessions[company]
		if pending.status=="completed": pending.exit_remaining=maxf(0.0,float(pending.get("exit_remaining",0))-delta)
		if pending.status!="scheduled" or pending.get("call_stage","room")=="room": continue
		var caller: OfficeNPC=game.npc_for_role(HOSTS[pending.action])
		if not caller or not caller.available() or caller.hit_stun>0 or caller.block_time>0: continue
		if pending.call_stage=="calling" and caller.position.distance_to(OfficeRooms.point(game,company,"interview_call"))>0.55:
			pending.call_stage="approach"
			pending.call_elapsed=0.0
			continue
		if pending.call_stage=="approach" and caller.position.distance_to(OfficeRooms.point(game,company,"interview_call"))<0.35:
			pending.call_stage="calling"
			pending.call_elapsed=0.0
			cue_once(company+"/"+pending.action+"/call","chair",caller.global_position)
		elif pending.call_stage=="calling":
			pending.call_elapsed+=delta
			if pending.call_elapsed>=1.8:
				pending.call_stage="room"
				game.queue_save()
	var firm := active_firm()
	if firm=="": return
	if game.career.conflict[firm]>=2:
		sessions.erase(firm)
		game.close_interaction()
		game.player.stand_up()
		game.say("现场冲突中止了这家公司的面试。")
		game.queue_save()
		return
	var host: OfficeNPC=game.npc_for_role(HOSTS[sessions[firm].action])
	if not host or not host.available() or host.hit_stun>0 or host.block_time>0 or not game.player.seated or game.player.position.distance_to(OfficeRooms.point(game,firm,"interview_seat"))>1.2:
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
	if host_calling(npc): return "beckon"
	if active_firm()!=npc.company or not host_seated(npc) or npc.hit_stun>0 or npc.block_time>0: return ""
	var session: Dictionary=sessions[npc.company]
	if HOSTS[session.action]!=npc.role_id: return ""
	var visual: HumanVisual=npc.visual
	var expected: String=["move_box","phone_reply","box_message"][int(session.step)] if session.action=="interview_b" and int(session.step)<3 else "phone_reply" if session.action=="interview_lead" and int(session.step)==1 or session.action=="interview_boss" and int(session.step)==2 else ""
	if expected!="" and visual.current==expected and visual.animation.is_playing() and int(session.get("gesture_done_step",-1))!=int(session.step): return visual.current
	if int(session.get("gesture_done_step",-1))==int(session.step): return "sit_talk"
	if session.action=="interview_b":
		if session.phase=="question" and session.step<3: return ["move_box","phone_reply","box_message"][int(session.step)]
	if session.phase=="reply": return "sit_talk"
	var actions := {"interview_hr":["read","write","pause"],"interview_lead":["read","phone_reply","write"],"interview_boss":["sit_talk","pause","phone_reply"]}
	return actions.get(session.action,["sit_talk"])[mini(int(session.step),2)]

func update_props() -> void:
	update_a_props()
	var box: Node3D=OfficeRooms.object(game,"b","InterviewBoxB")
	var table_phone: Node3D=OfficeRooms.object(game,"b","InterviewPhoneB")
	var host: OfficeNPC=game.npc_for_role("b_hr")
	if not box or not table_phone or not host or not host.visual.scene_phone: return
	var session: Dictionary=sessions.get("b",{})
	var step: int=int(session.get("step",-1))
	var playing: bool=active_firm()=="b" and host.visual.animation.is_playing()
	var clip: String=host.visual.current if playing else ""
	var phase: float=host.visual.animation.current_animation_position/maxf(0.1,host.visual.animation.current_animation_length) if playing else 1.0
	if active_firm()=="b" and step<3 and host.visual.current==["move_box","phone_reply","box_message"][step] and (phase>=0.96 or not host.visual.animation.is_playing()): session.gesture_done_step=step
	if clip=="move_box" and phase>=0.3: cue_once("b/"+session.action+"/0/box","paper",host.global_position)
	if clip=="phone_reply" and phase>=0.2: cue_once("b/"+session.action+"/1/phone","phone",host.global_position)
	if clip=="box_message":
		if phase>=0.13: cue_once("b/"+session.action+"/2/slide","paper",host.global_position)
		if phase>=0.38: cue_once("b/"+session.action+"/2/fall","box",OfficeRooms.point(game,"b","box_edge"))
		if phase>=0.40: cue_once("b/"+session.action+"/2/phone","phone",host.global_position)
	var start := OfficeRooms.point(game,"b","box_start")
	var table := OfficeRooms.point(game,"b","box_table")
	var edge := OfficeRooms.point(game,"b","box_edge")
	var floor_position := OfficeRooms.point(game,"b","box_floor")
	if step<1: box.global_position=start.lerp(table,smoothstep(0.10,0.82,phase)) if clip=="move_box" else start
	elif step==1: box.global_position=table
	elif clip=="box_message":
		if phase<0.22: box.global_position=table.lerp(edge,smoothstep(0.02,0.22,phase))
		elif phase<0.39: box.global_position=edge.lerp(Vector3(edge.x,floor_position.y,edge.z),smoothstep(0.22,0.39,phase))
		else: box.global_position=Vector3(edge.x,floor_position.y,edge.z).lerp(floor_position,smoothstep(0.39,0.55,phase))
		if phase>=0.55: session.box_drop_done=true
	else: box.global_position=floor_position if session.get("box_drop_done",false) or step>2 or session.get("status")=="completed" else table
	var holding: bool=clip=="phone_reply" and phase>0.17 and phase<0.83 or clip=="box_message" and phase>0.35 and phase<0.84
	table_phone.visible=not holding
	host.visual.scene_phone.visible=holding

func update_a_props() -> void:
	var papers: Node3D=OfficeRooms.object(game,"a","InterviewPapersA")
	var table_phone: Node3D=OfficeRooms.object(game,"a","InterviewPhoneA")
	if not papers or not table_phone: return
	var session: Dictionary=sessions.get("a",{})
	var host: OfficeNPC=game.npc_for_role(HOSTS.get(session.get("action",""),""))
	var animation: AnimationPlayer=host.visual.animation if host else null
	var is_active: bool=active_firm()=="a" and host and animation.is_playing()
	var clip: String=host.visual.current if is_active else ""
	var phase: float=animation.current_animation_position/maxf(0.1,animation.current_animation_length) if is_active else 0
	if active_firm()=="a" and host and (session.get("action")=="interview_lead" and int(session.get("step",-1))==1 or session.get("action")=="interview_boss" and int(session.get("step",-1))==2) and host.visual.current=="phone_reply" and (phase>=0.96 or not animation.is_playing()): session.gesture_done_step=int(session.step)
	if clip=="read" and phase>=0.25: cue_once("a/"+session.action+"/"+str(session.step)+"/paper","paper",host.global_position)
	if clip=="phone_reply" and phase>=0.2: cue_once("a/"+session.action+"/"+str(session.step)+"/phone","phone",host.global_position)
	var page: MeshInstance3D=papers.get_node("TopPage")
	var turning: float=sin(phase*TAU) if clip=="read" else 0
	page.rotation.y=turning*0.22
	page.position.x=0.04+turning*0.035
	var holding: bool=clip=="phone_reply" and phase>0.17 and phase<0.83
	table_phone.visible=not holding
	for role in ["a_hr","a_lead","a_boss"]:
		var colleague: OfficeNPC=game.npc_for_role(role)
		if colleague and colleague!=host and colleague.visual.scene_phone: colleague.visual.scene_phone.visible=false
	if host and host.visual.scene_phone: host.visual.scene_phone.visible=holding

func cue_once(key: String,kind: String,position: Vector3) -> void:
	if heard_cues.has(key): return
	heard_cues[key]=true
	game.interview_audio.cue(kind,position)

func closing(action: String) -> String:
	return {"interview_hr":"林岚：周工在里面，简历你拿好。", "interview_lead":"周工：方总接下来有空。我把意见发给他了。", "interview_boss":"方总：明天十点前，等林岚消息。", "interview_b":"阿诚：明天十点前联系你，路上慢点。"}[action]

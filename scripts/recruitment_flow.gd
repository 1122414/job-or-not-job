class_name RecruitmentFlow
extends RefCounted
var game: Node3D
var applications := {"a":blank(),"b":blank()}
var messages: Array=[]
var selected := "a"
var message_page := 0
# Reserved v11 state, populated by subsequent experience stages.
var scenes := {}
var work := {}
var promises: Array=[]
static func blank() -> Dictionary:
	return {"phase":"idle","feedback_at":0,"report_at":0}
func stamp(minute: int) -> String:
	return "第%d天 %02d:%02d"%[minute/1440+1,minute%1440/60,minute%60]
func send(firm: String,key: String,body: String) -> void:
	var id := firm+":"+key
	for item in messages:
		if item.id==id: return
	var person: OfficeNPC=game.npc_for_role(firm+"_hr")
	messages.append({"id":id,"firm":firm,"minute":game.payroll.minute,"sender":person.title if person else "招聘接待","body":body,"read":false})
	game.say("收到招聘消息 · N查看")
	game.queue_save()
func finish(action: String) -> String:
	var result: String=game.career.apply(action)
	if action in ["interview_boss","interview_b"]:
		var firm := "b" if action=="interview_b" else "a"
		if applications[firm].phase=="idle" and game.career.recruit[firm]>=(3 if firm=="a" else 1):
			applications[firm].phase="waiting"
			applications[firm].feedback_at=(game.payroll.minute/1440+1)*1440+600
			return "今天先到这里。"+stamp(applications[firm].feedback_at)+"前联系你。"
	return result
func tick() -> void:
	for firm in ["a","b"]:
		var state: Dictionary=applications[firm]
		if state.phase=="waiting" and game.payroll.minute>=state.feedback_at:
			if game.story.active():
				game.story.offer(firm)
				continue
			state.phase="offered"
			send(firm,"offer","业务面试评价可以。不过正式HC暂时没有批下来。可以先以实习身份进组，看看表现，再讨论转正。愿意的话回复我，报到时间另约。" if firm=="a" else "赵总说可以。我们流程简单，大家互相帮忙。你确认后我安排报到，职责和交接到时跟阿乐对一下。")
func reserved() -> String:
	if game.career.employer!="": return game.career.employer
	for firm in ["a","b"]:
		if applications[firm].phase=="accepted": return firm
	return ""
func accept(firm: String) -> void:
	if game.story.active() and (firm=="b" or game.story.campus()): return
	if not applications[firm].phase in ["offered","deferred","declined"]: return
	if reserved()!="": game.say("已有待报到安排或雇佣，先取消安排或办理离职。"); return
	if game.career.conflict[firm]>=2 or game.career.former.has(firm): game.say("这家公司当前不再接受入职。"); return
	game.career.facts.guide_company=firm
	applications[firm].phase="accepted"
	applications[firm].report_at=(game.payroll.minute/1440+1)*1440+540
	send(firm,"report_"+str(applications[firm].report_at),"报到安排："+stamp(applications[firm].report_at)+"，到前台找招聘接待。"+("身份为实习生，转正另行评估。" if firm=="a" else "先办手续，再去找阿乐。"))
	if game.story.active(): game.story.accepted()
	game.queue_save()
func postpone(firm: String) -> void:
	var state: Dictionary=applications[firm]
	if state.phase!="accepted": return
	state.report_at=(maxi(game.payroll.minute,int(state.report_at))/1440+1)*1440+540
	send(firm,"report_"+str(state.report_at),"报到已改约至"+stamp(state.report_at)+"。")
func report(firm: String) -> void:
	var state: Dictionary=applications[firm]
	if state.phase!="accepted" or game.career.employer!="": return
	if game.payroll.minute<state.report_at: game.say("报到时间是"+stamp(state.report_at)+"，现在可以先看看。"); return
	if game.payroll.minute>=int(state.report_at)/1440*1440+1080: game.say("已错过当天接待时间，N消息页可重新约报到。"); return
	var npc: OfficeNPC=game.npc_for_role(firm+"_hr")
	if not npc or not npc.available() or npc.position.distance_to(game.player.position)>3.5: game.say("请到前台，当面确认报到。"); return
	if game.story.active() and not game.story.data.get("call_done",false):
		game.say("导师来电还未处理。到公交站按E接听，再来报到。")
		return
	var step: int=int(work.get("intake_"+firm,0))
	if step<2:
		game.speaker=npc
		game.conversation={"text":("林岚：我核对一下，今天报到，身份是实习生。通知上写的正式HC还没批，业务评价和转正不是同一次审批。确认按这个条件办理吗？" if firm=="a" else "阿诚：约的是今天。先登记岗位，现场协作和资料交接。临时增加的事情找请求人核对，不填进这张固定职责表。") if step==0 else "接待把工牌放到你面前：账号申请显示已完成。先收好工牌，等一下带你去工位；登录不了再来找我，我只能查工单状态。",
			"choices":[["确认，继续办理" if step==0 else "领取工牌，完成报到","report_confirm_"+firm],["我再考虑一下","report_pause"]]}
		if game.story.active() and step==0: game.conversation.text="林岚：秋招实习转正安排，有正式HC，交付考核达标后转正。先领取实习工牌，四周后评审。确认按这个安排报到吗？"
		game.queue_save()
		return
	var result: String=game.career.apply("join_"+firm)
	game.say(result)
	if game.career.employer==firm:
		state.phase="reported"
		work["account_"+firm]=false
		game.onboarding.issue_badge(firm)
		send(firm,"account","入职账号申请：已完成。报到身份："+game.career.grade+"。如无法登录，请联系前台核对账号所属组织。")
		game.onboarding.start(firm)
		if game.story.active(): game.story.joined()
	game.queue_save()
func next_time() -> int:
	var result: int=game.story.search.next_time()
	for state in applications.values():
		var time: int=state.feedback_at if state.phase=="waiting" else state.report_at if state.phase=="accepted" else 0
		if time>game.payroll.minute and (result==0 or time<result): result=time
	return result
func handle(action: String) -> bool:
	if action in ["join_a","join_b"]:
		accept(action.trim_prefix("join_")); game.close_interaction(); return true
	if action=="report_pause": game.close_interaction(); return true
	if action in ["report_confirm_a","report_confirm_b"]:
		var firm := action.trim_prefix("report_confirm_")
		if applications[firm].phase!="accepted": return true
		work["intake_"+firm]=mini(2,int(work.get("intake_"+firm,0))+1)
		report(firm)
		if game.career.employer!="": game.close_interaction()
		return true
	if action in ["report_a","report_b"]:
		report(action.trim_prefix("report_"))
		if game.career.employer!="": game.close_interaction()
		return true
	if action=="rest_next":
		var time := next_time()
		if time>0: game.advance_time(time-game.payroll.minute)
		game.close_interaction(); return true
	return false
func options(npc: OfficeNPC,fallback: Dictionary) -> Dictionary:
	if npc.role!="hr" or game.career.employer!="": return fallback
	var firm := npc.company
	var state: Dictionary=applications[firm]
	match state.phase:
		"waiting": return {"text":"内部还在确认。我们约好"+stamp(state.feedback_at)+"联系。","choices":[["查看已有消息","open_messages"]]}
		"offered","deferred","declined": return {"text":"结果已经发给你了，条件和时间看过再决定。","choices":[["查看并回复邀请","open_messages"]]}
		"rejected": return {"text":"岗位已取消，暂不继续招聘。你可以查看原通知，也可以和同事聊聊。","choices":[["查看招聘回复","open_messages"]]}
		"accepted": return {"text":"报到安排："+stamp(state.report_at),"choices":[["我来确认报到","report_"+firm],["查看安排或改约","open_messages"]]}
	return fallback
func message_action(index: int) -> void:
	var state: Dictionary=applications[selected]
	if state.phase in ["offered","deferred","declined"]:
		if index==0: accept(selected)
		elif index==1: state.phase="deferred"
		elif index==2: state.phase="declined"
	elif state.phase=="accepted":
		if index==0: postpone(selected)
		elif index==1: state.phase="deferred"; state.report_at=0
	message_page=0
	game.queue_save()
func objective() -> Dictionary:
	if game.career.employer!="": return {}
	var firm: String=game.career.facts.get("guide_company","")
	if not firm in ["a","b"]: return {}
	var state: Dictionary=applications[firm]
	if state.phase=="rejected": return {"title":"该岗位已取消，未形成录用 · J可查看其他机会","id":""}
	if state.phase=="waiting": return {"title":"等待"+stamp(state.feedback_at)+"的反馈 · 可去另一家公司，N查看消息","id":"rest"}
	if state.phase in ["offered","deferred","declined"]: return {"title":"招聘反馈已到 · N查看条件并决定是否接受","id":""}
	if state.phase=="accepted": return {"title":"报到："+stamp(state.report_at)+" · 去前台，N可改约","id":firm+"_hr"}
	return {}
func snapshot() -> Dictionary:
	return {"applications":applications.duplicate(true),"messages":messages.duplicate(true),"scenes":scenes.duplicate(true),"work":work.duplicate(true),"promises":promises.duplicate(true)}
func restore(data: Dictionary) -> void:
	applications=data.get("applications",{"a":blank(),"b":blank()}).duplicate(true)
	messages=data.get("messages",[]).duplicate(true)
	scenes=data.get("scenes",{}).duplicate(true)
	work=data.get("work",{}).duplicate(true)
	promises=data.get("promises",[]).duplicate(true)
func migrate() -> void:
	for firm in ["a","b"]:
		if game.career.employer==firm: applications[firm].phase="reported"
		elif not game.career.former.has(firm) and game.career.recruit[firm]>=(3 if firm=="a" else 1):
			applications[firm].phase="offered"
			send(firm,"legacy_offer","此前面试结果保留。请确认邀请并约报到，无需重新面试。")
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("applications") is Dictionary or not value.get("messages") is Array: return false
	for key in ["scenes","work"]:
		if not value.get(key) is Dictionary: return false
	if not value.get("promises") is Array or not WorkProjects.valid(value.work): return false
	if not WorkPromises.valid(value.promises): return false
	for firm in value.scenes:
		var cursor: Variant=value.scenes[firm]
		if not firm in ["a","b"] or not cursor is Dictionary or not cursor.get("key") is String: return false
		if not (cursor.get("line") is int or cursor.get("line") is float) or not is_finite(cursor.line) or cursor.line<0 or cursor.line!=int(cursor.line): return false
	for firm in ["a","b"]:
		if value.work.has("intake_"+firm):
			var step: Variant=value.work["intake_"+firm]
			if not (step is int or step is float) or not is_finite(step) or step!=int(step) or step<0 or step>2: return false
		if value.work.has("account_"+firm) and not value.work["account_"+firm] is bool: return false
	var accepted := 0
	for firm in ["a","b"]:
		var state: Variant=value.applications.get(firm)
		if not state is Dictionary or not state.get("phase") in ["idle","waiting","offered","deferred","declined","accepted","reported","rejected"]: return false
		for key in ["feedback_at","report_at"]:
			if not (state.get(key) is int or state.get(key) is float) or not is_finite(state[key]) or state[key]<0: return false
		if state.phase=="accepted": accepted+=1
	if accepted>1: return false
	var ids := {}
	for item in value.messages:
		if not item is Dictionary or not item.get("id") is String or ids.has(item.id) or not item.get("firm") in ["a","b"] or not item.get("sender") is String or not item.get("body") is String or not item.get("read") is bool: return false
		if not (item.get("minute") is int or item.get("minute") is float) or not is_finite(item.minute) or item.minute<0: return false
		ids[item.id]=true
	return true

func ask_conditions() -> void:
	if game.story.active():
		game.story.ask_conditions(selected)
		return
	if not applications[selected].phase in ["offered","deferred","declined","accepted"]: return
	send(selected,"conditions","你问：实习后能保证转正吗？\n回复：不能承诺正式名额。业务评价与编制审批是两回事，先按实习报到，待遇按实习标准结算。" if selected=="a" else "你问：交接和加班算谁的职责？\n回复：先按岗位入职。临时的事互相搭把手，具体截止时间跟请求人确认，不能替别人答应。")

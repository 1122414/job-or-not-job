class_name ObjectiveGuide
extends RefCounted

static func current(game: Node3D) -> Dictionary:
	if game.friend_handover.data.get("phase")=="walking" and game.friend_handover.safe_meeting():
		return {"title":"自愿陪同 · 和阿乐到赵总面前确认截止时间；离开可暂缓","id":"b_boss"}
	var story_goal: Dictionary=game.story.objective()
	if not story_goal.is_empty(): return story_goal
	var introduction: Dictionary=game.onboarding.objective()
	if not introduction.is_empty(): return introduction
	var recruitment: Dictionary=game.recruitment.objective()
	if not recruitment.is_empty(): return recruitment
	var c: Career=game.career
	if c.employer!="" and not game.onboarding.account_ready() and c.facts.has("account_failed_"+c.employer):
		return {"title":"电脑无法登录 · 找前台核对已完成的账号工单","id":c.employer+"_hr"}
	var id := ""
	var title := c.objective()
	for pending in game.office.pending_visits():
		if c.facts.get("guide_visit","")==pending.key:
			id=pending.npc
			var person: OfficeNPC=game.npc_for_role(id)
			return {"title":"可选交谈 · "+(person.title if person else "岗位正在安排接替")+"（J可取消导航）","id":id}
	if c.employer=="":
		var selected: Variant=c.facts.get("guide_company","")
		var firm: String=selected if selected is String and selected in ["a","b"] else ""
		if firm=="": return {"title":"选择一家公司，了解招聘 · J 查看两家公司","id":""}
		if c.conflict[firm]>=2 or c.former.has(firm): return {"title":"该公司当前不再招聘你 · J 可选择另一家公司","id":""}
		id=firm+"_hr"
		if firm=="a":
			id=["a_hr","a_lead","a_boss","a_hr"][c.recruit.a]
			title=["规程科技 · 找林岚了解岗位与面试","第二轮 · 找周工了解技术面试","第三轮 · 找方总确认岗位条件","录用决定 · 找林岚办理实习入职"][c.recruit.a]
		else: title="自己人网络 · 找阿诚了解招聘" if c.recruit.b==0 else "录用决定 · 找阿诚办理入职"
		if c.facts.has("offer_declined_"+firm):
			title="邀请已暂缓 · J 比较另一家公司，或找招聘接待重新考虑"
			id=firm+"_hr"
	elif c.employer=="a":
		match c.stage:
			1:
				if not c.facts.has("desk_a_arrived"): id="desk_a"
				elif not c.facts.has("brief"): id="a_lead"
				elif not c.facts.has("data"): id="archive"
				elif not c.facts.has("prepared"): id="desk_a"
				elif c.facts.has("shortcut") or c.facts.has("confirm"): id="demo"
				elif c.facts.has("permission"): id="a_hr"
				else: id="a_friend"
			2: id="a_lead"
			3: id="a_group"
			4: id="backup"
			5: id="a_boss"
			6: id=""
	else:
		id={"pending":"b_friend","helping":"handover","refused":"b_friend","negotiating":"b_boss","helped":"b_friend","negotiated":"b_friend"}.get(c.b_event,"")
		if not game.handover.data.is_empty():
			title=game.handover.screen_text().replace("\n"," · ");id=""
	var selected_firm: String=c.facts.get("guide_company","") if c.facts.get("guide_company","") is String else ""
	var session: Dictionary=game.interviews.sessions.get(selected_firm,{})
	if c.employer=="" and not session.is_empty() and session.status in ["scheduled","active"] and c.conflict.get(selected_firm,3)<2:
		id="interview_"+selected_firm
		title="前往01面试室 · 落座交流，可随时离开或继续"
	var visit: Dictionary=game.office.visit()
	if not visit.is_empty() and c.facts.get("visit_state_"+visit.key,"") =="arrived":
		var visitor: OfficeNPC=game.npc_for_role(visit.npc)
		if visitor:
			id=visit.npc
			title="待交谈 · "+visitor.title.split(" · ")[0]+"有事找你（可稍后）"
	return {"title":title,"id":id}

static func target(game: Node3D) -> Node3D:
	var response_target: Node3D=game.story.response.target()
	if response_target: return response_target
	var id: String=current(game).id
	var actor: OfficeNPC=game.npc_for_role(id)
	if actor: return actor
	for node in game.targets():
		if node.stable_id==id and not node is OfficeNPC: return node
	return null

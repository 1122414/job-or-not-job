class_name ObjectiveGuide
extends RefCounted

static func current(game: Node3D) -> Dictionary:
	var c: Career=game.career
	var id := ""
	var title := c.objective()
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
	var visit: Dictionary=game.office.visit()
	if not visit.is_empty() and c.facts.get("visit_state_"+visit.key,"") in ["arrived","deferred"]:
		var visitor: OfficeNPC=game.npc_for_role(visit.npc)
		if visitor:
			id=visit.npc
			title="待交谈 · "+visitor.title.split(" · ")[0]+"有事找你（可稍后）"
	return {"title":title,"id":id}

static func target(game: Node3D) -> Node3D:
	var id: String=current(game).id
	var actor: OfficeNPC=game.npc_for_role(id)
	if actor: return actor
	for node in game.targets():
		if node.stable_id==id and not node is OfficeNPC: return node
	return null

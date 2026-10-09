class_name WorkPromises
extends RefCounted
var game: Node3D
var page := 0
func heard(session: Dictionary,npc: OfficeNPC) -> void:
	if not npc or int(session.step) not in [1,2]: return
	if not ((session.action=="interview_hr" and session.step==1) or (session.action in ["interview_lead","interview_boss","interview_b"] and session.step==2)): return
	var key: String=npc.stable_id+"_"+session.action+"_"+str(session.step)
	for item in game.recruitment.promises:
		if item.key==key: return
	var beat: Array=game.interviews.pages(session.action)[session.step]
	game.recruitment.promises.append({"key":key,"person":npc.stable_id,"role":npc.role_id,"name":npc.title,"minute":game.payroll.minute,"quote":beat[2][session.reply],"reply":session.answers.back(),"action":session.action})
	game.queue_save()
func latest(role: String) -> Dictionary:
	for i in range(game.recruitment.promises.size()-1,-1,-1):
		if game.recruitment.promises[i].role==role: return game.recruitment.promises[i]
	return {}
func review(npc: OfficeNPC) -> void:
	var promise := latest("a_lead")
	var quote: String=promise.get("quote","")
	var text := "业务评价通过。HC还没批，这次仍然不能转正。"
	if quote!="": text+="\n你翻出记录：「"+quote.left(28)+( "…" if quote.length()>28 else "")+"」"
	if not promise.is_empty() and promise.person!=npc.stable_id: text="我接手了这份业务评价，但名额还没批。\n此前约定保留在交接记录里。"
	game.speaker=npc
	game.conversation={"text":npc.title.split(" · ")[0]+"："+text,"choices":[["请把通过评价和未批名额分别写下来","promise_written"],["请带着已完成成果，联系能接收的团队","promise_referral"],["先保留记录，我再考虑是否继续","promise_defer"]]}
func handle(action: String,npc: Node3D) -> bool:
	if action=="no_hc" and npc is OfficeNPC:
		if npc.role_id!="a_lead" or game.career.employer!="a" or game.career.stage!=2 or game.career.conflict.a>=2: return true
		if game.story.active() and not game.story.review_ready():
			game.say("周工：成果通过了。按约定四周后评审，你可以在公交站推进到评审日。")
			game.close_interaction(); return true
		game.career.apply(action)
		game.story.arc.review(npc)
		review(npc)
		return true
	if action in ["promise_written","promise_referral","promise_defer"] and npc is OfficeNPC:
		if npc.role_id!="a_lead" or game.career.employer!="a" or game.career.stage!=3: return true
		var result := "周工：好，先保留。我不能给你一个今天还没批的日期。"
		if action=="promise_written":
			game.career.record("written_review","已取得书面业务评价：通过；正式HC未批准。")
			game.social.remember(npc,action,"你要求把业务评价与编制问题分开记录。",-1,2)
			result="周工：我写：业务考核通过，正式HC未批。这不是你演示没做好，但也不是我能直接改的。"
		elif action=="promise_referral":
			game.career.record("group_referral","主管已将第一份交付记录转给二组，尚不等于取得正式名额。")
			game.social.remember(npc,action,"你请他带着已有成果，联系接收团队。",2,3)
			result="周工：我转给许姐，连同这次通过的记录。她那边也先按实习接，你听过条件再决定。"
		else: game.social.remember(npc,action,"你没有当场继续承诺，保留了评估记录。")
		game.career.record("promise_reviewed","交付后，你对照此前约定讨论了通过但无HC的结果。")
		game.close_interaction(); game.say(OfficeDialogue.voice(npc,result)); game.queue_save(); return true
	if action=="transfer" and npc is OfficeNPC and game.career.stage==3:
		if npc.role_id!="a_group" or game.career.employer!="a": return true
		game.conversation={"text":"许姐：上次交付我看到了，不重做。这里只接现场投影恢复，身份仍是实习。你确认转过来，我才安排新工位。","choices":[["保留第一次成果，确认转组","transfer_confirm"],["我先考虑，稍后再谈","promise_pause"]]}
		game.conversation.text=OfficeDialogue.voice(npc,game.conversation.text)
		return true
	if action=="defend" and npc is OfficeNPC and game.career.stage==5:
		if npc.role_id!="a_boss" or game.career.employer!="a": return true
		if game.story.arc.active() and not game.story.arc.ready(12):
			game.close_interaction();game.say("两份成果已保留。第12周确认最终结果；公交站可跳过普通日。");return true
		game.conversation={"text":"方总：第一份是演示交付，第二份是现场恢复。把两份实际记录摆出来，我们今天确认结果。","choices":[["展示两份已归档成果，要求明确结论","defend_confirm"],["稍后再来","promise_pause"]]}
		game.conversation.text=OfficeDialogue.voice(npc,game.conversation.text)
		return true
	if action in ["transfer_confirm","defend_confirm"]:
		if not npc is OfficeNPC or npc.role_id!=("a_group" if action=="transfer_confirm" else "a_boss"): return true
		if game.career.employer!="a" or game.career.stage!=(3 if action=="transfer_confirm" else 5): return true
		if action=="defend_confirm" and game.story.arc.active():
			if not game.story.arc.ready(12): return true
			game.career.facts["internship_final_ready"]=true
		var result: String=game.career.apply("transfer" if action=="transfer_confirm" else "defend")
		game.close_interaction()
		if action=="defend_confirm" and game.story.active() and game.career.facts.has("conversion_failed"):
			game.story.arc.finish(npc)
			game.story.show_verdict(npc)
		else: game.say(OfficeDialogue.voice(npc,result) if npc is OfficeNPC else result)
		game.queue_save(); return true
	if action=="promise_pause": game.close_interaction(); return true
	return false
func support_available() -> bool:
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	return npc!=null and game.social.willing(npc) and game.social.state(npc).trust>=8
static func valid(items: Array) -> bool:
	var keys := {}
	for item in items:
		if not item is Dictionary: return false
		for key in ["key","person","role","name","quote","reply","action"]:
			if not item.get(key) is String: return false
		if keys.has(item.key): return false
		keys[item.key]=true
		if not (item.get("minute") is int or item.get("minute") is float) or not is_finite(item.minute) or item.minute<0: return false
	return true

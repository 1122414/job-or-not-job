class_name InternshipArc
extends RefCounted

# Dates belong to this internship, not to the global day counter.
var game: Node3D

static func blank(enabled: bool=false) -> Dictionary:
	return {"enabled":enabled,"reviewed_at":0,"renewed_at":0,"ended_at":0}

func state() -> Dictionary:
	return game.story.data.placement

func active() -> bool:
	return game.story.active() and state().enabled

func working() -> bool:
	return active() and game.story.data.phase=="internship" and game.career.employer=="a" and game.career.conflict.a<2

func date(week: int) -> int:
	return int(game.story.data.started_at)+week*7*Payroll.DAY

func ready(week: int) -> bool:
	return working() and game.payroll.minute>=date(week)

func pending_week() -> int:
	if not working(): return 0
	if game.career.stage==2: return 4
	if game.career.stage==4 and state().renewed_at==0: return 8
	if game.career.stage==5: return 12
	return 0

func objective() -> Dictionary:
	var week := pending_week()
	if week==0: return {}
	if not ready(week): return {"title":"实习第%d周节点 · 可继续生活，或到公交站跳过普通日" % week,"id":"rest"}
	return {"title":{4:"第4周 · 第一份成果通过，找周工兑现转正承诺",8:"第8周 · 找许姐再次核对HC与最终答辩安排",12:"第12周 · 带着两份成果找方总确认结果"}[week],"id":{4:"a_lead",8:"a_group",12:"a_boss"}[week]}

func summary() -> String:
	if not active(): return ""
	if not game.career.facts.has("a_join"): return "实习安排：第4周评审；后续以现场确认的记录为准。"
	if game.career.employer!="a" and state().ended_at==0: return "实习已提前中止 · 保留已完成成果与约定，没有完成12周答辩。"
	var now: int=int(state().ended_at) if state().ended_at>0 else game.payroll.minute
	var days := maxi(0,(now-int(game.story.data.started_at))/Payroll.DAY)
	return "同一段实习 · 已过%d天\n第4周：%s  /  第8周：%s  /  第12周：%s" % [days,"评价通过、名额未批" if state().reviewed_at>0 else "待评审","再次承诺已留存" if state().renewed_at>0 else "待当面确认","成果通过、未转正" if state().ended_at>0 else "待最终答辩"]

func remember(npc: OfficeNPC,key: String,reply: String,quote: String) -> void:
	for item in game.recruitment.promises:
		if item.key==key: return
	game.recruitment.promises.append({"key":key,"person":npc.stable_id,"role":npc.role_id,"name":npc.title,"minute":game.payroll.minute,"reply":reply,"quote":quote,"action":key})

func review(npc: OfficeNPC) -> void:
	if not active() or game.career.stage!=3 or state().reviewed_at>0: return
	state().reviewed_at=game.payroll.minute
	remember(npc,"internship_week4","四周前说有HC，成果通过就能转正。","你的交付通过了。本组的名额还没批；可以带着这份评价去二组，实习时间接着算。")
	game.queue_save()

func finish(npc: OfficeNPC) -> void:
	if not active() or not game.career.facts.has("conversion_failed") or state().ended_at>0: return
	state().ended_at=game.payroll.minute
	remember(npc,"internship_week12","两份成果都已通过，请对照最初和第八周的承诺给出结论。","两份成果都合格。但最终没有正式HC，实习今天结束。之前说有名额，现在不能兑现。")
	game.career.record("twelve_weeks_completed","经历第4周评审、第8周再承诺、第12周答辩；同一段长期实习，成果通过但承诺落空。")

func decorate(target: Node3D,fallback: Dictionary) -> Dictionary:
	if not active(): return fallback
	var id: String=target.role_id if target is OfficeNPC else target.stable_id
	var week := pending_week()
	if id=="rest" and week>0 and not ready(week):
		fallback.choices.push_front(["跳过普通日 · 到第%d周节点（工资按原规则结算）" % week,"story_milestone_wait"])
	if id=="a_group" and working() and game.career.stage==4 and state().renewed_at==0:
		fallback.text="许姐：第一份成果保留。我们到第8周再当面核对名额和下一次答辩安排。你可以先熟悉工位，也可以现在离开。"
		if ready(8): fallback.choices.push_front(["已经第8周了，这次到底有没有转正HC？","story_renewal"])
	if id=="backup" and working() and game.career.stage==4 and state().renewed_at==0:
		fallback.text="二组投影仍待恢复。第8周先与许姐确认任务范围、HC和最终答辩安排，再决定是否继续。"
		fallback.choices=fallback.choices.filter(func(choice): return choice[1]!="backup")
	return fallback

func handle(action: String) -> bool:
	if not active(): return false
	var target: Node3D=game.speaker
	if action=="story_milestone_wait":
		var week := pending_week()
		if not target is WorkStation or target.stable_id!="rest" or week==0 or ready(week): return true
		game.rest_until(date(week))
		game.close_interaction();game.say("第%d周节点到了。时间和应得工资已推进；工作成果和承诺需要当面确认。" % week)
		game.queue_save();return true
	if action in ["story_renewal","story_renewal_written","story_renewal_scope"]:
		if not target is OfficeNPC or target.role_id!="a_group" or not ready(8) or game.career.stage!=4 or state().renewed_at>0: return true
		if action=="story_renewal":
			game.conversation={"text":"许姐：八周了，两组还是同一段实习，时间不清零。正式HC按项目保留，第12周两份成果达标后转正；换组不重算实习时间。你把现场恢复做好，我们一起答辩。\n你看见工牌仍写着“实习”。","choices":[["请留下明确日期和有HC的书面回复","story_renewal_written"],["只接约定的现场恢复，不重做第一份成果","story_renewal_scope"],["先不答应，出去走走","story_pause"]]}
			return true
		var written := action=="story_renewal_written"
		var quote := "正式HC按项目保留，第12周两份成果达标后转正；换组不重算实习时间。"
		state().renewed_at=game.payroll.minute
		game.career.record("internship_renewed","第8周再次确认："+quote)
		game.career.record("renewal_written" if written else "renewal_scope","已取得第8周有HC与第12周答辩的书面回复。" if written else "已确认二组只接现场恢复，第一份成果不重做。")
		remember(target,"internship_week8","请留下书面回复和日期。" if written else "请明确范围，我不重做第一份成果。",quote)
		game.social.remember(target,action,"你要求她留下转正日期与名额的书面回复。" if written else "你明确了工作边界，不重做已经合格的成果。",0,2)
		game.close_interaction();game.say("许姐已回复，原话与日期保留在J→谈过的约定。去投影现场完成约定的恢复任务。")
		game.queue_save();return true
	return false

static func valid(value: Variant,story: Dictionary,career: Dictionary,minute: int,promises: Array) -> bool:
	if not value is Dictionary or not value.get("enabled") is bool: return false
	for key in ["reviewed_at","renewed_at","ended_at"]:
		var n: Variant=value.get(key)
		if not (n is int or n is float) or not is_finite(n) or n<0 or n!=int(n) or n>minute: return false
	if value.enabled!=career.facts.get("internship_extended",false): return false
	if not value.enabled: return value.reviewed_at==0 and value.renewed_at==0 and value.ended_at==0
	if story.mode!="current": return false
	var dates := [value.reviewed_at,value.renewed_at,value.ended_at]
	var keys := ["internship_week4","internship_week8","internship_week12"]
	for i in range(dates.size()):
		var found := false
		for item in promises:
			if item.key==keys[i]:
				if dates[i]==0 or item.minute!=dates[i] or item.role!=["a_lead","a_group","a_boss"][i]: return false
				found=true
		if (dates[i]>0)!=found: return false
		if dates[i]>0:
			if not career.facts.has("a_join") or dates[i]<story.started_at+(i+1)*28*Payroll.DAY: return false
			if i>0 and (dates[i-1]==0 or dates[i]<dates[i-1]): return false
	if (career.stage>=3)!=(value.reviewed_at>0): return false
	if value.renewed_at>0 and career.stage<4: return false
	if career.stage>=5 and value.renewed_at==0: return false
	if (value.renewed_at>0)!=(career.facts.has("renewal_written") or career.facts.has("renewal_scope")): return false
	if career.facts.has("renewal_written") and career.facts.has("renewal_scope"): return false
	if (value.ended_at>0)!=career.facts.has("internship_final_ready"): return false
	if (value.ended_at>0)!=career.facts.has("twelve_weeks_completed"): return false
	if (value.renewed_at>0)!=career.facts.has("internship_renewed"): return false
	if (value.ended_at>0)!=career.facts.has("conversion_failed"): return false
	if career.facts.has("a_join") and story.review_at!=story.started_at+28*Payroll.DAY: return false
	return true

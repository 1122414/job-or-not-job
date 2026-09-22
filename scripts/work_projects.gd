class_name WorkProjects
extends RefCounted
var game: Node3D
var document := 0
var feedback := "选择左侧资料阅读，再配置工作成果。"
const A_DOCS := [
["正式产品说明 · v1.2 / 已确认","演示范围：查询已脱敏的订单样例，显示编号、状态和汇总。\n当前版本不包含自动退款。负责人：周工。\n验收：现场可重复运行，来源与版本明确，不把待确认功能当作已交付能力。"],
["未确认草稿 · v2 / 销售转发","设想：自动退款、实时客户数据。\n状态：产品与客户尚未确认，不能作为对外承诺。\n文件名虽然带‘最终’，页脚仍写着讨论稿。请对照正式说明。"],
["离线运行说明 · 小夏","离线样例保存在本机，不连接生产环境，不读取实时客户资料。\n运行生产环境才需要权限。离线版可取消多余审批，但先向原作者小夏核实适用范围。\n预览只验证作品；交付请到演示台展示。"]]
const B_DOCS := [
["请求记录 · 赵总转发","赵总：今晚尽快把交接发一下，都是自己人。\n请求人：客户陈工；接收人：陈工与次日值班同事。\n阿乐：我把资料留这儿了，你看过以后再决定能不能接。"],
["交接清单 · 已核对","交付内容：设备清单、已处理事项、未关闭问题及负责人。\n完整包含上述四项；旧包缺少未关闭问题，接手人会以为全部完成。\n发送前请检查版本，不能只看压缩包名称。"],
["原始截止时间 · 陈工消息","陈工：明天11:00之前发给我就行，我们上午才开始。\n今晚不要求在线，也不要求今晚发出。\n如果要改为明早，请把内容、接收人和时间一起向赵总确认。"]]
func state(firm: String) -> Dictionary:
	var key := "project_"+firm
	if not game.recruitment.work.has(key):
		game.recruitment.work[key]={"read":[],"source":"","mode":"offline","preview":"","delivered":false,"approval":"none"} if firm=="a" else {"read":[],"package":"","deadline":"","preview":"","sent":false,"proposal":false}
	var result: Dictionary=game.recruitment.work[key]
	result.read=result.read.map(func(value): return int(value))
	return result
func open(station: WorkStation) -> void:
	var firm: String=game.career.employer
	if firm=="" or (station.stable_id!=game.office.assigned_desk() and not (firm=="b" and station.stable_id=="handover")): return
	if station.stable_id.begins_with("desk_"):
		if game.office.desk_damaged(station): game.say("设备已损坏，请先登记维修。"); return
		game.office.open_desk(station)
	if not game.onboarding.account_ready(): game.say("账号所属组织仍是候选人，请联系前台核对已完成的工单。"); return
	if firm=="a" and not game.career.facts.has("data"): game.say("桌面还没有工作资料。先听周工交代，再从资料柜取得文件。"); return
	var current := state(firm)
	document=0
	feedback="先读材料，再选择依据和运行方式。" if firm=="a" else "对照请求、交接内容和原始截止时间，决定发送或协商。"
	feedback=current.get("note",feedback)
	game.panels.show_page("computer")
func key(index: int) -> void:
	var firm: String=game.career.employer
	if not firm in ["a","b"]: return
	var s := state(firm)
	if index<=3:
		document=index-1
		if not index in s.read: s.read.append(index)
	elif firm=="a":
		if s.delivered: feedback="这份成果已经交付归档，不能修改历史版本。"; return
		if index==4: s.source="draft" if s.source=="official" else "official"; invalidate(s)
		if index==5: s.mode="production" if s.mode=="offline" else "offline"; invalidate(s)
		if index==6: preview_a()
	else:
		if s.sent: feedback="交接包已发送，保留原始内容与接收时间。"; return
		if index==4: s.package="old" if s.package=="complete" else "complete"; s.preview=""; s.proposal=false
		if index==5: s.deadline="tomorrow" if s.deadline=="tonight" else "tonight"; s.proposal=false
		if index==6: preview_b()
		if index==7: send_b()
	s["note"]=feedback
	game.queue_save()
func invalidate(s: Dictionary) -> void:
	s.preview=""
	game.career.facts.erase("prepared")
func preview_a() -> void:
	var s := state("a")
	s.approval="confirmed" if game.career.facts.has("confirm") else "permission" if game.career.facts.has("permission") else "none"
	if s.source=="": feedback="未选择演示依据：按4选择正式资料或草稿。"
	elif not (1 if s.source=="official" else 2) in s.read: feedback="请先阅读所选版本，确认它实际包含的内容。"
	elif s.source=="draft": feedback="预览错误：自动退款仍是未确认功能；实时客户数据也没有来源。换正式资料后重试。"
	elif s.mode=="production" and not game.career.facts.has("permission"): feedback="无法连接：尚未取得生产运行权限。可找周工申请，或研究离线说明。"
	else:
		s.preview="订单样例 A-017 / 已处理；A-018 / 待确认。汇总：2条。来源：正式说明 v1.2。"
		game.career.apply("prepare")
		feedback="预览成功。样例和正式说明一致。到演示台展示才能完成交付。"
		return
	s.preview="error"
	game.career.facts.erase("prepared")
func preview_b() -> bool:
	var s := state("b")
	if s.read.size()<3: feedback="请核对请求记录、交接清单和原始截止时间。"; return false
	if s.package!="complete": feedback="检查失败：旧包缺少未关闭问题和负责人。请改为完整交接包。"; s.preview="error"; return false
	if s.deadline=="": feedback="尚未填写计划交付时间。"; return false
	s.preview="设备清单 ✓ 已处理事项 ✓ 未关闭问题与负责人 ✓ 接收人：陈工/值班同事"
	feedback="交接检查通过。计划"+("明早10:00发送（外部截止11:00）。" if s.deadline=="tomorrow" else "今晚发送（外部截止其实在明天11:00）。")
	return true
func send_b() -> void:
	if not preview_b(): return
	var s := state("b")
	if game.career.b_event=="helping":
		if s.deadline!="tonight": feedback="你选择了明早发送，请带着这份安排与阿乐一起向赵总确认。"; return
		game.career.apply("handover")
		s.sent=game.career.b_event=="helped"
		feedback="已发送给陈工和值班同事。阿乐收到完成通知，可以离开工位。"
	elif game.career.b_event=="negotiating" and s.deadline=="tomorrow":
		s.proposal=true
		feedback="协商材料已准备：完整包、陈工、明早10:00。关闭电脑，带阿乐去找赵总确认。"
	else: feedback="先与阿乐确定由你接手，或提出一起核对安排。"
func handle(action: String) -> bool:
	if action in ["prepare","computer_open","handover"] and game.speaker is WorkStation:
		open(game.speaker)
		return true
	if action=="shortcut" and not 3 in state("a").read:
		game.say("小夏：先看一下那份离线运行说明，拿着具体条件来，我们才好核对。")
		game.close_interaction(); return true
	if action=="submit":
		var s := state("a")
		var allowed: bool=(s.mode=="offline" and game.career.facts.has("shortcut")) or (s.mode=="production" and game.career.facts.has("permission") and game.career.facts.has("confirm"))
		if s.source!="official" or s.preview in ["","error"] or not allowed:
			game.say("还不能交付：先用正确资料预览，再核实离线条件，或完成生产权限及提交人确认。")
			game.close_interaction(); return true
		var result: String=game.career.apply("submit")
		if game.career.facts.has("output_one"): s.delivered=true
		game.close_interaction(); game.say(result); game.queue_save(); return true
	if action=="settle" and not state("b").proposal:
		game.say("赵总：具体什么内容、几点发、客户原话是什么？先把交接安排带过来。")
		game.close_interaction(); return true
	return false
func migrate() -> void:
	if game.career.facts.has("prepared") or game.career.facts.has("output_one"):
		var s := state("a")
		if s.source=="":
			s.source="official"; s.read=[1,2,3]; s.mode="offline" if game.career.facts.has("shortcut") else "production"
			s.preview="旧档有效演示：正式资料 / 已验证。"
			s.delivered=game.career.facts.has("output_one")
	if game.career.facts.has("b_help"):
		var s := state("b")
		s.read=[1,2,3]; s.package="complete"; s.deadline="tonight"; s.sent=true; s.preview="旧档完整交接包 / 已发送"
static func valid(work: Dictionary) -> bool:
	for firm in ["a","b"]:
		if not work.has("project_"+firm): continue
		var s: Variant=work["project_"+firm]
		if not s is Dictionary or not s.get("read") is Array or not s.get("preview") is String: return false
		if s.read.size()>3 or (s.has("note") and not s.note is String): return false
		var seen := {}
		for index in s.read:
			if not (index is int or index is float) or (index!=1 and index!=2 and index!=3): return false
			if seen.has(int(index)): return false
			seen[int(index)]=true
		if firm=="a":
			if not s.get("source") in ["","official","draft"] or not s.get("mode") in ["offline","production"] or not s.get("delivered") is bool or not s.get("approval") in ["none","permission","confirmed"]: return false
		else:
			if not s.get("package") in ["","complete","old"] or not s.get("deadline") in ["","tonight","tomorrow"] or not s.get("sent") is bool or not s.get("proposal") is bool: return false
	return true

class_name AutumnSearch
extends RefCounted

const JOBS := [
	{"id":"ai","company":"远桥数据","title":"校招 · 资料协作助理","listing":"面向本届毕业生，参与资料整理、样例核对及项目支持。接受相关实习经历。\n发布时仍显示招聘中。","delay":1},
	{"id":"experience","company":"启衡服务","title":"校招 · 项目交付助理","listing":"应届毕业生可投，参与演示和现场交付。简历请注明个人职责与成果。\n优先考虑能独立承担业务的人选。","delay":1},
	{"id":"silence","company":"星序软件","title":"校招 · 初级工程岗位","listing":"应届招聘，提交简历与项目说明。合适者会收到进一步沟通。\n岗位页没有显示本轮截止日期。","delay":3}
]
const STATUS := {"sent":"已投递，等待回复","cancelled":"岗位已取消","invited":"收到线上沟通邀请","rejected":"未通过本轮招聘","silent":"投递三天，暂无回复","followup":"已追问，等待回复","silent_final":"追问后仍无回复"}
const INTERVIEW := [
	["招聘者：你只有这一段实习吗？我们现在希望招进来就能独立接项目的人。",["展示两份考核通过的实际成果","解释没有更早实习是导师不允许","问清校招岗位提供什么培养"],["招聘者：成果我看到了，但这还是同一家公司的一段实习，我们更希望有多个业务环境的经历。","招聘者：学校的情况我们理解，但筛选时只能按已有经历比较。","招聘者：今年没有额外的带教安排。我们把一些初级工作交给现有人和AI工具做，新增人要能直接负责。"]],
	["招聘者：你之前没有转正，是能力考核没过吗？",["拿出考核通过与无HC的两份记录","说明公司招人时承诺有名额","追问为什么应届岗位要求成熟经验"],["招聘者：我看到了，考核确实通过。但这个岗位还是希望更成熟的业务经验，这次不继续。","招聘者：那是你和上一家公司的情况。我们这边按现在的岗位要求筛选，这次不继续。","招聘者：岗位名称还在校招里，要求按业务现在的需要来。这次先到这里。"]]
]
var game: Node3D
var story: AutumnStory:
	get: return game.story
var selected := 0

func available() -> bool:
	return story.active() and story.data.phase in ["late_autumn","ending"]

func records() -> Dictionary:
	if not story.data.has("search"): story.data.search={}
	return story.data.search

func state(id: String) -> Dictionary:
	return records().get(id,{})

func select(index: int) -> void:
	selected=clampi(index,0,JOBS.size()-1)
	var item := state(JOBS[selected].id)
	if not item.is_empty(): item.seen=true
	story.game.queue_save()

func submit() -> void:
	if not available() or not story.game.career.facts.has("internship_certificate"): return
	var job: Dictionary=JOBS[selected]
	if records().has(job.id): return
	var minute: int=story.game.payroll.minute
	records()[job.id]={"status":"sent","submitted":minute,"due":minute+int(job.delay)*Payroll.DAY,"seen":true,"step":0,"reply":-1,"answers":[],"body":"简历已提交：应届研究生，一段规程科技实习；演示交付与现场恢复两份成果。","followed":false}
	story.game.career.record("application_"+job.id,"秋招后段投递"+job.company+"：一段实习和两份实际成果。")
	story.game.queue_save()

func next_time() -> int:
	if not available(): return 0
	var next := 0
	for item in records().values():
		if item.due>story.game.payroll.minute and (next==0 or item.due<next): next=int(item.due)
	return next

func tick() -> void:
	if not available(): return
	for id in records():
		var item: Dictionary=records()[id]
		if item.due<=0 or story.game.payroll.minute<item.due: continue
		item.due=0; item.seen=false
		if id=="ai":
			item.status="cancelled"
			item.body="远桥数据：团队引入AI工具后，资料整理和基础核对由现有员工承担。本轮初级岗位取消，不再新增应届人选。不是你补交一份材料就能继续。"
		elif id=="experience":
			item.status="invited"
			item.body="启衡服务：看过你的简历，请在这里回复招聘者，进行线上沟通。"
		elif item.followed:
			item.status="silent_final"
			item.body="追问已发出两天。对方没有回复，也没有提供面试安排。\n这不是一封拒信；目前能确认的只是仍无录用。"
		else:
			item.status="silent"
			item.body="投递三天，系统仍显示已提交。没有面试邀请，也没有拒信。可以追问一次进度。"
		story.game.say("秋招投递状态有变化 · N进入投递记录查看")
		story.game.queue_save()

func follow_up() -> void:
	var item := state("silence")
	if not available() or item.get("status")!="silent": return
	item.followed=true; item.status="followup"; item.seen=true
	item.due=story.game.payroll.minute+2*Payroll.DAY
	item.body="你：想确认岗位是否仍在招聘，是否需要补充项目成果？\n追问已发送，尚无回复。"
	story.game.career.record("application_followup","向星序软件追问岗位与材料要求，等待真实回复。")
	story.game.queue_save()

func answer(index: int) -> void:
	var item := state("experience")
	if not available() or item.get("status")!="invited" or item.reply>=0 or index<0 or index>2: return
	item.reply=index; item.answers.append(index); item.seen=true
	story.game.queue_save()

func continue_interview() -> void:
	var item := state("experience")
	if not available() or item.get("status")!="invited" or item.reply<0: return
	item.step+=1; item.reply=-1
	if item.step==INTERVIEW.size():
		item.status="rejected"; item.seen=true
		item.body="启衡服务：已确认你在上一家公司的业务考核通过。但当前没有培养初级员工的安排，需要更成熟的业务经验，本轮不继续。\n一段实习、两份成果，没有换来录用。"
		story.game.career.record("application_experience_rejected","招聘者看过考核通过和无HC记录，仍以业务经验不足拒绝；没有将转正失败改写成能力考核失败。")
	story.game.queue_save()

func ready_to_end() -> bool:
	for i in range(JOBS.size()):
		var item := state(JOBS[i].id)
		if item.get("status")!=["cancelled","rejected","silent_final"][i] or not item.get("seen",false): return false
	return true

func finish() -> void:
	if not available() or not ready_to_end(): return
	story.data.phase="ending"
	story.game.career.record("autumn_no_offer","秋招后段：AI调整取消初级岗位，另一岗位拒绝一段实习的经验，追问后仍有投递无回复。业务成果保留，目前仍未找到工作。")
	story.game.queue_save()

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if not id in ["ai","experience","silence"]: return false
		var item: Variant=value[id]
		if not item is Dictionary or not item.get("status") in STATUS: return false
		for key in ["submitted","due","step","reply"]:
			if not (item.get(key) is int or item.get(key) is float) or not is_finite(item[key]) or item[key]!=int(item[key]): return false
		if item.submitted<0 or item.due<0 or item.step<0 or item.step>2 or item.reply< -1 or item.reply>2: return false
		if not item.get("seen") is bool or not item.get("followed") is bool or not item.get("body") is String or not item.get("answers") is Array: return false
		if item.answers.size()!=int(item.step)+(1 if item.reply>=0 else 0): return false
		for answer_index in item.answers:
			if not (answer_index is int or answer_index is float) or answer_index!=int(answer_index) or answer_index<0 or answer_index>2: return false
		var statuses: Array={"ai":["sent","cancelled"],"experience":["sent","invited","rejected"],"silence":["sent","silent","followup","silent_final"]}[id]
		if not item.status in statuses: return false
		if (item.status in ["sent","followup"])!=(item.due>0): return false
		if item.due>0 and item.due<=item.submitted: return false
		if id!="experience" and (item.step!=0 or item.reply!=-1): return false
		if id=="experience" and ((item.status=="rejected")!=(item.step==2) or item.status=="sent" and (item.step!=0 or item.reply!=-1)): return false
		if item.followed!=(item.status in ["followup","silent_final"]): return false
	return true

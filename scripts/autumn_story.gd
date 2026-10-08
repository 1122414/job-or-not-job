class_name AutumnStory
extends RefCounted

const CAMPUS_SPAWN := Vector3(0,40.15,2)
const STREET_SPAWN := Vector3(-14,0.2,5)
const MENTOR_LINES := [
	["导师：实习先别想。我们那个年代都没有实习这个概念，不也找到工作了？你现在的任务是把研究做好。",["现在秋招会看实习经历，我想提前准备","项目已经做完了，我可以安排好交接","您之前说项目做完就可以再谈"],["导师：企业列什么条件你就跟着跑？先把学位拿到，比那些重要。","导师：项目做完还有论文。你人去了公司，组里的事情谁接？","导师：再谈不等于答应。情况在变，你不能只记着那一句。"]],
	["导师：公司让你去几个月，回来论文还做不做？别人的节奏不能打乱我们组的安排。",["我每周回来汇报，论文计划不变","我只去暑期，秋招前回来","那秋招没有经历怎么办"],["导师：两边跑，哪边都做不好。我不同意。","导师：暑期正是集中出成果的时候，也不行。","导师：把研究做好，找工作自然会有办法。你不要现在就想着外面的事情。"]],
	["导师：这件事就这么定了，不许去。把下周汇报的材料准备好。",["我不同意，但知道您的决定了","我会继续准备秋招","结束谈话，先离开"],["导师：你以后就知道我为什么这么要求了。","导师：先顾眼前，找工作的事到时候再说。","导师：出去记得把门带上。"]]
]
var game: Node3D
var data := blank()
var room: Node3D
var points: Array[AutumnStoryPoint] = []

static func blank(mode: String="legacy") -> Dictionary:
	return {"mode":mode,"phase":"mentor" if mode=="current" else "legacy","beat":0,"reply":-1,"answers":[],"mentor_interrupted":false,"call_done":false,"call_reply":"","started_at":0,"review_at":0}

func active() -> bool:
	return data.mode=="current"

func campus() -> bool:
	return active() and data.phase in ["mentor","campus_exit"]

func build() -> void:
	room=Node3D.new()
	room.name="GraduatePrologue"
	game.add_child(room)
	room.position=Vector3(0,40,0)
	Shapes.solid(room,Vector3(12,.2,14),Vector3(0,-.1,2),Color("a6a19a"))
	for wall in [[Vector3(12,3.5,.2),Vector3(0,1.75,-5)],[Vector3(.2,3.5,14),Vector3(-6,1.75,2)],[Vector3(.2,3.5,14),Vector3(6,1.75,2)],[Vector3(12,3.5,.2),Vector3(0,1.75,9)]]:
		Shapes.solid(room,wall[0],wall[1],Color("d3d0c3"))
	Shapes.solid(room,Vector3(12,.15,14),Vector3(0,3.5,2),Color("d9d6cb"))
	# Doorway divides the office and corridor; walking remains under player control.
	for x in [-3.65,3.65]: Shapes.solid(room,Vector3(4.7,3.5,.15),Vector3(x,1.75,5),Color("a6b7b3"))
	Shapes.solid(room,Vector3(2.5,.12,1),Vector3(0,.8,-1),Color("9a795d"))
	for x in [-1.05,1.05]: Shapes.solid(room,Vector3(.12,.8,.8),Vector3(x,.4,-1),Color("52585b"))
	Shapes.box(room,Vector3(.7,.035,.45),Vector3(.5,.88,-.8),Color("f0ead9"))
	Shapes.box(room,Vector3(.8,.5,.06),Vector3(-.6,1.1,-1.15),Color("34454a"))
	for i in range(3):
		Shapes.solid(room,Vector3(1.3,.8,.5),Vector3(-4.8,.4+i*.8,-3),Color("8e7a62"))
		Shapes.box(room,Vector3(1.1,.5,.35),Vector3(-4.8,.65+i*.8,-2.9),Color("617c86"))
	var sign := Shapes.label(room,"研究生导师办公室",Vector3(0,2.8,-4.85),34)
	sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	var light := OmniLight3D.new()
	light.position=Vector3(0,2.8,0); light.omni_range=12; light.light_energy=2.0
	room.add_child(light)
	add_point("story_mentor","导师 · 讨论暑期实习",Vector3(0,40,-2.2),true)
	add_point("story_exit","走廊 · 离校与秋招",Vector3(0,40,7.2))
	sync_scene()

func add_point(id: String,title: String,at: Vector3,person: bool=false) -> void:
	var point := AutumnStoryPoint.new()
	point.story=self; point.stable_id=id; point.title=title; point.person=person
	game.add_child(point); point.position=at
	points.append(point)

func start_new() -> void:
	data=blank("current")
	game.career.facts["autumn_story"]=true
	game.player.position=CAMPUS_SPAWN
	game.player.yaw=0; game.player.pitch=-.08
	sync_scene()

func sync_scene() -> void:
	if room: room.visible=campus()
	for point in points: point.visible=campus()

func objective() -> Dictionary:
	if not active(): return {}
	if data.phase=="mentor": return {"title":"秋招前 · 与导师讨论暑期实习（可走开或结束谈话）","id":"story_mentor"}
	if data.phase=="campus_exit": return {"title":"实习未获允许 · 走到办公室外的走廊","id":"story_exit"}
	if data.phase=="mentor_call": return {"title":"秋招接收通知已到 · 公交站接听导师来电","id":"rest"}
	if data.phase=="internship" and game.career.stage==2 and not review_ready(): return {"title":"成果已通过 · 公交站可推进到四周后的转正评审","id":"rest"}
	if data.phase=="departure": return {"title":"未能转正 · 找林岚领取实习证明，原成果保留","id":"a_hr"}
	if data.phase=="late_autumn": return {"title":"秋招后段 · 公交站查看岗位，重新投递","id":"rest"}
	return {}

func open(point: AutumnStoryPoint) -> void:
	if not campus(): return
	game.speaker=point
	if point.stable_id=="story_exit":
		game.conversation={"text":"暑期实习的确认期限已经过去。你留在学校做项目。\n毕业学年，秋招开始。简历的实习经历一栏仍是空白。","choices":[["带上简历，进入秋招","story_autumn"],["回办公室再谈谈","story_pause"]]} if data.phase=="campus_exit" else {"text":"实习还没有得到允许。可以回去继续争辩，也可以结束这次谈话。","choices":[["不再争辩，离开办公室","story_leave"],["回去继续谈","story_pause"]]}
	elif data.phase=="campus_exit":
		game.conversation={"text":"导师：实习的事已经说过了，不许去。下周照常汇报。","choices":[["结束谈话","story_pause"]]}
	elif data.reply>=0:
		game.conversation={"text":MENTOR_LINES[data.beat][2][data.reply],"choices":[["继续听","story_next"],["结束争辩，离开","story_leave"]]}
	else:
		var beat: Array=MENTOR_LINES[data.beat]
		var choices: Array=[]
		for i in range(beat[1].size()): choices.append([beat[1][i],"story_answer_"+str(i)])
		choices.append(["结束争辩，离开","story_leave"])
		game.conversation={"text":beat[0],"choices":choices}

func refuse(interrupted: bool=false) -> void:
	data.phase="campus_exit"
	data.mentor_interrupted=interrupted
	game.career.record("mentor_refused","秋招前争取暑期实习，导师拒绝批准。实习机会错过，留校完成研究。")
	game.close_interaction(); game.queue_save()
	sync_scene()

func handle(action: String) -> bool:
	if not action.begins_with("story_"): return false
	if not campus(): return career_action(action)
	var point: AutumnStoryPoint=game.speaker as AutumnStoryPoint
	if not point: return true
	if action=="story_pause": game.close_interaction(); return true
	if action=="story_leave": refuse(); return true
	if action=="story_autumn" and data.phase=="campus_exit" and point.stable_id=="story_exit":
		data.phase="early_autumn"
		game.career.record("autumn_started","毕业学年参加秋招。没有企业实习经历，保留研究项目与成果。")
		game.close_interaction()
		game.player.position=STREET_SPAWN; game.player.velocity=Vector3.ZERO
		game.player.yaw=0; game.player.pitch=-.08
		game.say("秋招前段 · 应届研究生。两家公司都可以先去了解，J查看安排。")
		sync_scene(); game.queue_save(); return true
	if data.phase!="mentor" or point.stable_id!="story_mentor": return true
	if action.begins_with("story_answer_") and data.reply==-1:
		var answer := int(action.trim_prefix("story_answer_"))
		if answer<0 or answer>=3: return true
		data.reply=answer; data.answers.append(answer)
	elif action=="story_next" and data.reply>=0:
		data.beat+=1; data.reply=-1
		if data.beat==MENTOR_LINES.size(): refuse(); return true
	open(point); game.queue_save()
	return true

func restore(saved: Dictionary) -> void:
	data=blank()
	data.merge(saved.duplicate(true),true)
	sync_scene()

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("mode") in ["legacy","current"]: return false
	if not value.get("phase") in ["legacy","mentor","campus_exit","early_autumn","mentor_call","internship","departure","late_autumn"]: return false
	if (value.mode=="legacy")!=(value.phase=="legacy"): return false
	for key in ["beat","reply"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(value[key]) or value[key]!=int(value[key]): return false
	if value.beat<0 or value.beat>3 or value.reply< -1 or value.reply>2: return false
	if value.phase=="mentor" and value.beat>=3: return false
	if not value.get("answers") is Array or value.answers.size()!=int(value.beat)+(1 if value.reply>=0 else 0): return false
	for answer in value.answers:
		if not (answer is int or answer is float) or answer!=int(answer) or answer<0 or answer>2: return false
	for key in ["started_at","review_at"]:
		var number: Variant=value.get(key,0)
		if not (number is int or number is float) or not is_finite(number) or number<0 or number!=int(number): return false
	if not value.get("call_done",false) is bool or not value.get("call_reply","") is String: return false
	return value.get("mentor_interrupted") is bool

func chapter_text() -> String:
	if campus(): return "序章 · 秋招之前：未获允许的实习"
	if data.phase in ["early_autumn","mentor_call"]: return "第一章 · 秋招前段：有名额，先来实习"
	if data.phase=="internship": return "第二章 · 同一段实习：成果与名额"
	if data.phase=="departure": return "第三章 · 转正失败：带走实习证明"
	if data.phase=="late_autumn": return "第四章 · 秋招后段：重新投递"
	return ""

func offer(firm: String) -> void:
	var flow: RecruitmentFlow=game.recruitment
	if firm=="b":
		flow.applications.b.phase="rejected"
		flow.send("b","offer","这轮初级协作岗位取消了。赵总决定由现有同事使用AI工具处理资料，不新增应届编制。今天的面试没有形成录用。你仍可以来见阿乐，但我们无法安排入职。")
	else:
		flow.applications.a.phase="offered"
		flow.send("a","offer","秋招接收通知：应届项目岗位，有正式HC。先实习四周，实际交付考核达标后转正，不是仅做短期项目。业务面试已通过，请确认后预约报到。")

func ask_conditions(firm: String) -> void:
	if firm=="b":
		game.recruitment.send("b","conditions","你问：取消岗位以后还能先入职吗？\n阿诚：不能，没有录用。阿乐可以和你聊，但不能替公司给你岗位。")
	elif game.career.stage<3:
		game.recruitment.send("a","conditions","你问：有正式HC、考核达标就能转正吗？\n林岚：有HC，达标后转正。业务会保留交付评价，不是让你做完项目就走。请留好这份通知。")
	else:
		game.recruitment.send("a","conditions_after_review","你追问之前的有HC承诺。\n林岚：招人时按业务报的需求回复，现在只能按最终批准的名额办理。业务评价通过，不等于这次有名额。\n原接收通知保留，不覆盖。")

func accepted() -> void:
	if not data.get("call_done",false): data.phase="mentor_call"
	game.career.record("hc_promised","秋招接收通知明确写有HC，先实习四周、交付达标后转正。你按这个安排投入实习，其他秋招机会仍在流逝。")
	game.say("导师来电 · 到公交站按E接听，再按预约报到。")

func open_call(target: Node3D,reply: bool=false) -> void:
	game.speaker=target
	game.conversation={"text":"导师（电话）：既然已经有单位接收，就按毕业实习办，论文别耽误。", "choices":[["之前想去实习时，您不是这样说的","story_call_question"],["公司说有HC，实习达标后转正","story_call_offer"],["知道了，我会安排论文","story_call_accept"]]}
	if reply:
		game.conversation={"text":data.get("call_reply","")+"\n电话那头等着你结束通话。","choices":[["结束通话，保留招聘通知","story_call_done"],["先放下手机，稍后继续","story_pause"]]}

func joined() -> void:
	data.phase="internship"
	data.started_at=game.payroll.minute
	data.review_at=game.payroll.minute+28*Payroll.DAY
	game.queue_save()

func review_ready() -> bool:
	return not active() or game.payroll.minute>=int(data.get("review_at",0)) and int(data.get("review_at",0))>0

func decorate(target: Node3D,fallback: Dictionary) -> Dictionary:
	if not active(): return fallback
	var id: String=target.role_id if target is OfficeNPC else target.stable_id
	if id=="rest":
		if data.phase=="mentor_call": fallback.choices.push_front(["接听导师来电 · 秋招接收安排","story_call"])
		elif data.phase=="internship" and game.career.stage==2 and not review_ready(): fallback.choices.push_front(["推进到四周实习评审 · 保留成果与应得工资","story_review_wait"])
	if id=="a_lead" and game.career.stage<3:
		fallback.text="周工：有HC，转正看实际成果。先把这份演示交出来，来源明确、现场能运行，我就认通过。"
	if id=="a_boss" and game.career.stage<3:
		fallback.text="方总：先入组做项目，有转正名额，达标之后走转正。"
	if id=="a_boss" and game.career.facts.has("conversion_failed"):
		fallback={"text":"方总：成果合格我承认，但最终没有正式名额。你可以找林岚拿实习证明。","choices":[["对照原来的名额承诺","story_verdict"]]}
	if id=="a_hr" and data.phase=="departure":
		fallback={"text":"林岚：实习证明已经准备好了。同一家公司换组仍算同一段实习，两份成果都写进去。正式录用这次办不了。","choices":[["核对并领取实习证明","story_certificate"],["保留原来有HC的接收通知","story_original_offer"]]}
	return fallback

func show_verdict(target: Node3D) -> void:
	data.phase="departure"
	game.speaker=target
	game.conversation={"text":"方总：演示交付和现场恢复都合格。但是最终没有正式HC，这次不能转正。实习今天结束。\n你拿出接收通知：有HC，交付达标后转正。", "choices":[["当时为什么明确说有名额","story_verdict_why"],["所以失败的不是我的考核","story_verdict_result"],["保留通知和成果，去领取实习证明","story_pause"]]}
	game.queue_save()

func career_action(action: String) -> bool:
	if not active(): return false
	var target: Node3D=game.speaker
	match action:
		"story_call":
			if data.phase=="mentor_call": open_call(target,data.get("call_reply","")!="")
		"story_call_question", "story_call_offer", "story_call_accept":
			if data.phase!="mentor_call": return true
			data.call_reply={"story_call_question":"导师：那时候是让你先顾学校，现在单位都定了，两回事。","story_call_offer":"导师：那就好好做，把工作定下来。论文也不能落下。","story_call_accept":"导师：嗯，论文进度定期发我。找工作的事情你自己把握。"}[action]
			open_call(target,true)
		"story_call_done":
			if data.phase!="mentor_call" or data.get("call_reply","")=="": return true
			data.call_done=true; data.phase="early_autumn"
			game.career.record("mentor_released","秋招收到公司接收通知后，导师改口：已有单位接收，可以去，论文别耽误。此前错过的暑期实习没有补回。")
			game.close_interaction(); game.say("通话结束。按N里的预约报到，原招聘承诺已保留。")
		"story_review_wait":
			if data.phase!="internship" or game.career.stage!=2 or game.career.employer!="a" or review_ready(): return true
			game.advance_time(int(data.review_at)-game.payroll.minute)
			game.close_interaction(); game.say("四周实习过去。成果已经通过，秋招仍在继续。去找周工确认转正。")
		"story_verdict":
			if game.career.facts.has("conversion_failed"): show_verdict(target)
		"story_verdict_why", "story_verdict_result":
			if data.phase!="departure": return true
			game.conversation={"text":"方总：当时项目确实缺人，我们按需求招的。现在名额没批，我只能给你写考核通过。" if action=="story_verdict_why" else "方总：对，你的成果没有问题。没有名额是公司的事，但这次你留不下来。","choices":[["保留回复，去领取实习证明","story_pause"]]}
			game.career.record("hc_broken","公司承认业务成果通过，却把最初的有HC承诺改称用人需求；转正失败由求职者承担。")
		"story_original_offer":
			game.conversation={"text":"原接收通知：有正式HC。先实习四周，实际交付考核达标后转正。\n现在的回复：无正式名额，实习结束。两份记录同时保留。","choices":[["核对并领取实习证明","story_certificate"],["收起通知","story_pause"]]}
		"story_certificate":
			if data.phase!="departure" or not game.career.facts.has("conversion_failed"): return true
			data.phase="late_autumn"
			game.career.record("internship_certificate","领取一段规程科技实习证明：演示交付、换组现场恢复，业务考核通过，未转正。没有新增第二段实习经历。")
			game.conversation={"text":"证明上写着一段实习和两份合格成果。你重新打开秋招岗位，有些批次已经结束。\n接下来：回公交站查看秋招后段的招聘信息。","choices":[["收好证明，重新找工作","story_pause"]]}
		"story_pause": game.close_interaction()
		_: return false
	game.queue_save()
	return true

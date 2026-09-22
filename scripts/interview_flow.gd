class_name InterviewFlow
extends RefCounted

var game: Node3D
var sessions: Dictionary = {}
const ACTIONS := ["interview_hr","interview_lead","interview_boss","interview_b"]
const HOSTS := {"interview_hr":"a_hr","interview_lead":"a_lead","interview_boss":"a_boss","interview_b":"b_hr"}
# Each page is a workplace decision, followed by an explicit response, not a quiz score.
const CONTENT := {
"interview_hr":[
["林岚：先把岗位说清楚。我们招的是演示项目实习生，整理资料、验证演示、协调交付都会碰到。你希望先确认什么？",["确认具体产出和评价标准","了解团队怎样支持新人","先听听一天通常怎么过"],["第一份产出是一套可以运行的演示；能否交付和正式名额是两件事，我会分别说明。","周工负责要求，小夏熟悉原始资料。遇到信息不一致可以追问，不需要一个人猜流程。","入职后分配工位，同事会来说明工作。你可以探索办公室、查资料，不需要反复点击打卡。"]],
["林岚：招聘信息里写了培养机会，但现在没有已批准的正式名额。我不想等你做完实习才第一次听到这件事。你怎么看？",["要求把实习身份和名额状态说清楚","接受了解，但暂不承诺入职","询问是否有其他团队的机会"],["可以。录用决定会明确写实习，不把完成工作等同于保证转正。","面试通过后也可以离开，你不需要当场接受。另一家公司就在街对面。","跨组机会可以沟通，原有成果不应该被清零，但新团队会说明自己的任务。"]],
["林岚：假设交付当天，你拿到两个相互矛盾的说法：主管说要审批，原始说明写离线版无需审批。你准备先做什么？",["拿原始说明找负责人核实","先走审批，确保提交人明确","先暂停，列出还不知道的条件"],["把依据带到现场，比反复转述有用。入职后你会真的遇到这个处境。","这条路线可以走，不过也要区分必需手续和大家习惯做的手续。","可以先厘清条件。我们不按你点击了多少次按钮评价工作。"]],
["林岚：假如你认为要求不合理，可以拒绝、离职或换公司。我们希望讨论的是实际约定，而不是要求你表现得永远积极。",["我会先说明自己的边界","我会先找能改变安排的人","我想再了解技术工作"],["边界会被听见。拒绝工作安排和伤害同事不是一回事，后者会有公司处分。","先找对应负责人沟通，这也是为什么每个阶段都应有能联系的人。","下一轮由周工说明交付任务。你可以继续问清楚再决定。"]]
],
"interview_lead":[
["周工：我们有个演示要交付，资料不完整，现场也不能访问生产环境。今天不考背题，谈谈你怎么确定第一个可验证的结果。",["先验证离线最小演示","先整理权限与环境依赖","先和使用者确认演示目标"],["这能快速排除错误方向，不过交付时要明确离线结果能说明什么、不能说明什么。","依赖清单有用，但不要把不需要的生产权限变成离线演示的前置条件。","先确认要展示的能力，可以避免做出没人需要的整套系统。"]],
["周工：你发现旧说明的作者就在隔壁，而群里已经转述了三版互相冲突的流程。你打算如何形成可以交付的依据？",["带着原文直接找作者","按当前负责人的流程推进","把冲突说明整理后共同确认"],["作者是小夏。她能说明离线版的条件，但不会替你签一份没做过的成果。","可以，我会对自己的审批负责；你也可以问为什么需要这些环节。","把具体版本与条件摆出来，比争论谁的印象正确更有效。"]],
["周工：假设演示已经能运行，但一个流程节点还没给答复。这里需要区分技术风险和流程等待，你会怎样向我汇报？",["展示已验证结果与剩余限制","只汇报目前被谁卡住","给出常规和备用两种交付路线"],["这让我知道成果已经到了哪一步，也能明确需要我处理的阻碍。","说明阻碍还不够，最好同时告诉我已完成什么，避免把你的成果一起隐藏。","两条路线都写明适用条件，我可以判断是否需要继续等待。"]],
["周工：如果最终考核通过，却没有转正名额，你的成果仍然属于已完成的工作。你希望我如何交代后续？",["明确记录通过与无名额的区别","介绍能接收成果的其他团队","让我自行决定是否继续留下"],["我应分别说明，不会把名额问题包装成你又差一点。","许姐的团队可以谈，是否接收由她说明，第一次成果不用重新证明。","你可以离开，工资和已经认可的成果不会因此被抹掉。"]]
],
"interview_boss":[
["方总：前两轮交流已经记录。我需要说明最终条件：这次可以发实习邀请，但当前组的正式名额冻结，不能在面试时承诺已有名额。",["我需要明确的转正路径","我先了解，不立刻接受","名额冻结时为什么继续招聘"],["先完成第一份演示，组内无名额时可以谈转组；第二次成果和答辩必须得到明确结论。","录用邀请会保留，你可以回前台决定，也可以到另一家公司看看。","这是合理的问题。实习工作需求与正式编制审批不同，你应知道差别后再决定是否承担。"]],
["方总：换组时，有人可能要求从头再做一遍。你准备怎样说明自己已通过的成果，而不只是说以前的人答应过？",["带上已记录的交付结果","要求前后负责人共同确认","如果成果不被承认就离开"],["已交付结果应被承认。新组要解决新的现场问题，不是再做一次同样的演示。","可以让两边确认交接，避免你承担组织之间的信息损耗。","这是你的选择。不能靠无限延长实习来回避正式决定。"]],
["方总：答辩不是表演工作量。请选一种你会用来解释成果的方式，我们也据此约定最后看什么。",["说明问题、行动与可见结果","对照两次交付记录","说明哪些冗余流程被取消"],["两份实际成果会形成答辩依据，不额外要求你刷重复劳动。","第一份演示与第二份现场恢复都应该展示出来。","能取消不必要的流程也是成果，但不能伪造没有发生的交付。"]],
["方总：最后再确认，实习邀请和正式员工身份不是同一件事。你完成后续两份成果和答辩，游戏会给出明确转正结果，不会无限重复。",["按这些条件继续了解录用","要求把约定带回前台","我仍然保留拒绝的权利"],["好，回林岚处查看邀请并办理入职，之后才会分配个人工位。","这些约定随本轮结果记录；前台会说明实习身份，不会换一套说法。","当然。面试通过不等于替你接受工作，最后由你选择。"]]
],
"interview_b":[
["阿诚：我们只有这一轮面试。工作以资料交接和现场协作为主，同事关系近，但‘都是自己人’也容易把职责说模糊。你想先问什么？",["谁负责分配工作和确定截止时间","正常交接具体要完成什么","临时加班能否协商或拒绝"],["赵总负责安排。截止时间应该有实际原因，不应只靠一句大家帮忙。","资料包通常已经准备好，需要明确谁接手、发给谁、何时算完成。","你可以问清楚并选择，不会因为一次拒绝就清空同事关系。"]],
["阿诚：如果同事阿乐把备用设备让给你，当晚又被安排额外交接，你会怎样回应他的请求？",["先问具体范围，再决定是否接手","感谢帮助，但明确今晚不加班","一起找老板确认真正的截止时间"],["帮忙可以，但最好明确一次交接的结束点，而不是接下所有未来工作。","感谢和拒绝可以同时表达。他帮助过你，不代表买下了你的每一个晚上。","你们可以共同交涉；有些紧急只是习惯说法，需要当面确认。"]],
["阿诚：有人会把拒绝理解成不合群。这里不会给你一个‘最会讨好人’的标准答案，我想知道你怎样处理具体冲突。",["说明边界，同时提供可行替代","坚持拒绝，允许对方暂时失望","让安排工作的人承担解释责任"],["提供替代是一个选择，不是拒绝的资格考试。明早处理也可能满足真正需求。","关系可以有摩擦，一次拒绝不等于友谊结束。","应该找到有权改变安排的人，不能让同事互相承担压力。"]],
["阿诚：如果愿意加入，阿乐会让出备用终端帮你安顿。入职后仍然可以反悔或离职，已得工资与个人关系各自保留。",["愿意继续了解录用安排","先看看办公室再决定","再确认工作结束的标准"],["交流结束后由你明确选择入职，不会在这句话后自动替你签下决定。","可以直接离开面试室看看。录用入口仍在招聘接待处。","发送交接包、拒绝或协商出新的安排，都要有清楚结果，不靠无尽加班维持状态。"]]
]}
const COMMON := [
["面试官：还有两件现实的问题应该说清楚。你在职期间按游戏内时间计薪，固定发薪日结算；离职前应得部分会保留，不按你重复操作的次数扣减。",["确认工资与工作量分开","想查看到账记录的位置","了解了，继续确认后续"],["结算与成果分别记录。今天没有多点几次工作按钮，不会让已经应得的工资消失。","L可以查看全部到账明细，跨公司产生的应付也分开保存。","最后我们确认下一步和你保留的选择，再结束本轮交流。"]],
["面试官：如果中途离开，这轮尚未聊完的内容会保留，可以再回来。若当前负责人无法到岗，公司会安排接替人员；公司对主动冲突的处分则独立处理。",["我会按自己的节奏继续","确认可以拒绝邀请","结束前再确认下一步"],["你可以随时离开或探索，不需要把整段流程一次看完。","通过面试不会自动入职，邀请可以暂缓或拒绝，个人工位只在接受后分配。","结束本轮后，任务会指向下一位负责人或录用办理处，你不必靠猜寻找入口。"]]
]

func active_firm() -> String:
	for firm in sessions:
		if sessions[firm].status=="active": return firm
	return ""

func pages(action: String) -> Array:
	return CONTENT[action]+COMMON

func schedule(action: String) -> void:
	var firm := "b" if action=="interview_b" else "a"
	if game.career.conflict[firm]>=2:
		game.say("公司处分仍在生效，当前不接受面试。")
		return
	if not sessions.has(firm) or sessions[firm].action!=action or sessions[firm].status=="completed":
		sessions[firm]={"action":action,"step":0,"status":"scheduled","phase":"question","answers":[],"reply":0}
	else: sessions[firm].status="scheduled"
	game.career.facts["guide_company"]=firm
	game.close_interaction()
	game.say("已安排面试 · 前往后方01面试室，坐下交流；可随时离开。")
	game.queue_save()

func host_target(npc: OfficeNPC) -> Variant:
	var session: Dictionary=sessions.get(npc.company,{})
	if session.is_empty() or session.status not in ["scheduled","active"] or HOSTS[session.action]!=npc.role_id: return null
	return OfficeRooms.INTERVIEW_HOSTS[npc.company]

func host_seated(npc: OfficeNPC) -> bool:
	var target: Variant=host_target(npc)
	return target!=null and not npc.dead and npc.down<=0 and npc.hostile<=0 and npc.position.distance_to(target)<0.35

func player_seated() -> bool:
	return game.player.seated and active_firm()!=""

func room_options(firm: String) -> Dictionary:
	var session: Dictionary=sessions.get(firm,{})
	if session.is_empty() or session.status=="completed": return {"text":"01 面试室 · 请先联系招聘接待安排面试。","choices":[]}
	var host: OfficeNPC=game.npc_for_role(HOSTS[session.action])
	if not host: return {"text":"岗位正在安排接替人员。原交流进度保留，稍后可继续。","choices":[]}
	if not host_seated(host): return {"text":host.title+"正在前来。可以先看看环境，等他到位后按E继续。","choices":[]}
	return {"text":host.title+"：请坐。我们把具体工作和条件聊清楚，你可以随时离开。","choices":[["坐下，开始或继续这轮交流","interview_seat_"+firm],["暂时不参加，保留进度","interview_leave"]]}

func question(firm: String) -> Dictionary:
	var session: Dictionary=sessions[firm]
	var items := pages(session.action)
	if session.step>=items.size(): return {"text":"本轮交流结束。你提出的选择已保留，是否记录本轮结果？通过面试仍需单独接受录用。","choices":[["记录约定，结束本轮交流","interview_finish"],["暂不继续，保留选择与进度","interview_leave"]]}
	var item: Array=items[session.step]
	if session.phase=="reply": return {"text":item[2][session.reply],"choices":[["继续交流","interview_next"],["先离开，稍后继续","interview_leave"]]}
	var choices: Array=[]
	for i in range(item[1].size()): choices.append([item[1][i],"interview_answer_"+str(i)])
	choices.append(["暂停这轮交流，稍后再来","interview_leave"])
	return {"text":item[0],"choices":choices}

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
		game.conversation=question(firm)
		return true
	var firm := active_firm()
	if firm=="" or not action.begins_with("interview_"): return false
	var session: Dictionary=sessions[firm]
	if action.begins_with("interview_answer_") and session.phase=="question":
		var answer := int(action.trim_prefix("interview_answer_"))
		if answer<0 or answer>=3 or session.step>=pages(session.action).size(): return true
		session.answers.append(pages(session.action)[session.step][1][answer])
		session.reply=answer
		session.phase="reply"
	elif action=="interview_next" and session.phase=="reply":
		session.step+=1
		session.phase="question"
	elif action=="interview_finish" and session.step==pages(session.action).size():
		session.status="completed"
		game.career.record("terms_"+session.action,"面试约定："+"；".join(PackedStringArray(session.answers)))
		var result: String=game.career.apply(session.action)
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
	if not host or host.down>0 or not game.player.seated:
		game.close_interaction()
		game.say("面试已中断，未完成的交流可稍后继续。")

class_name Career
extends RefCounted

var recruit := {"a":0,"b":0}
var employer := ""
var grade := "求职者"
var stage := 0
var facts: Dictionary = {}
var conflict := {"a":0,"b":0}
var warning_action := {"a":-1,"b":-1}
var seen_actions := {"a":[],"b":[]}
var b_event := "none"
var records: Array[String] = []
var former: Array[String] = []

func record(key: String, text: String) -> void:
	if facts.has(key): return
	facts[key]=true
	records.append(text)

func apply(action: String) -> String:
	var a_actions := ["interview_hr","interview_lead","interview_boss","join_a","brief","prepare","permission","confirm","shortcut","submit","no_hc","transfer","backup","defend"]
	if action in a_actions and conflict.a>=2: return "规程科技已关闭当前职业机会。此前成果保留，可以离开。"
	if action in ["interview_b","join_b","help","refuse","negotiate","settle","handover"] and conflict.b>=2: return "自己人网络已停止合作，个人关系单独保留。"
	match action:
		"decline_a", "decline_b":
			var firm := action.trim_prefix("decline_")
			record("offer_declined_"+firm,"暂不接受录用；保留面试结果，可重新考虑或选择另一家公司。")
			return "邀请已暂缓。不会自动入职，也不会分配工位。"
		"interview_b":
			if recruit.b==0:
				recruit.b=1
				return "阿诚：面试通过。这里流程短，讲的是人情；愿意的话就入职。"
		"join_b":
			if recruit.b==1 and employer=="" and not former.has("b"):
				employer="b"
				grade="自己人网络员工"
				b_event="pending"
				record("b_join","自己人网络入职：阿乐腾出备用终端帮你安顿，晚上却被安排接额外工作。")
				return "阿乐把备用终端让给你。现在老板要你们今晚接手，看起来又是‘自己人’的事。"
		"help":
			if employer=="b" and b_event in ["pending","refused"]:
				b_event="helping"
				return "阿乐：谢谢。把右侧终端的交接包发送出去，我就能走了。"
		"handover":
			if employer=="b" and b_event=="helping":
				b_event="helped"
				record("b_help","接手并发送交接包，阿乐提前离开工位。")
				return "交接包发送完毕。阿乐收起了桌上的文件：走，透口气。"
		"refuse":
			if employer=="b" and b_event=="pending":
				b_event="refused"
				record("b_refuse","拒绝加班，阿乐接下交接工作；一次拒绝没有抹掉友谊。")
				return "阿乐：行，我先去处理。你不欠我一个晚上。"
		"negotiate":
			if employer=="b" and b_event in ["pending","refused"]:
				b_event="negotiating"
				return "阿乐：我跟你一起找赵总，问清楚为什么非得今晚。"
		"settle":
			if employer=="b" and b_event=="negotiating":
				b_event="negotiated"
				record("b_negotiate","与阿乐现场交涉：交接改为明早，今晚两人都能离开。")
				return "赵总：既然没有今晚的外部截止，就明早交。阿乐放下文件，准备离开。"
		"interview_hr":
			if recruit.a==0:
				recruit.a=1
				return "HR 面试交流完成。下一轮联系周工，他会到01面试室与你谈技术工作。"
		"interview_lead":
			if recruit.a==1:
				recruit.a=2
				return "技术面试交流完成。下一轮联系方总，再到01面试室确认岗位条件。"
		"interview_boss":
			if recruit.a==2:
				recruit.a=3
				return "三轮通过！但正式名额冻结了。回 HR 处可接受实习，也可直接离开。"
		"join_a":
			if recruit.a==3 and employer=="" and not former.has("a"):
				employer="a"
				grade="一组实习生"
				stage=1
				record("a_join","规程科技：三轮面试通过，接受一组实习。")
				return "第一章 · 实习第一天。右侧第一排是你的工位，HR 和主管会来找你。"
		"brief":
			if employer=="a" and stage==1:
				record("brief","演示资料在蓝色资料台；听说运行需要权限。")
				return "周工：资料在蓝台。先找原始说明，别急着跑流程。"
		"data":
			record("data","拿到演示资料：原始说明注明离线版无需权限审批。")
			return "原始说明：离线演示不访问生产环境，不需要审批。可以找小夏核实。"
		"prepare":
			if employer=="a" and stage==1 and facts.has("data"):
				record("prepared","在自己的工位整理已有资料，演示预览成功；生成可交付的演示包。")
				return "演示预览成功，屏幕已显示交付包。选择离线捷径或常规权限方式后，到演示台交付。"
		"permission":
			if employer=="a" and stage==1 and facts.has("data"):
				record("permission","已取得演示权限，HR 可以确认提交人。")
				return "权限批了。HR 还要确认一下提交人。"
		"confirm":
			if employer=="a" and stage==1 and facts.has("permission"):
				record("confirm","提交人已确认。")
				return "确认完毕。去演示台提交即可。"
		"shortcut":
			if employer=="a" and stage==1 and facts.has("data"):
				record("shortcut","小夏确认离线版有效：取消权限审批和提交人确认，不必补做。")
				return "小夏：原作者就是我。用离线版，权限和确认都取消，直接交。"
		"submit":
			if employer=="a" and stage==1 and facts.has("data") and facts.has("prepared") and (facts.has("shortcut") or (facts.has("permission") and facts.has("confirm"))):
				stage=2
				record("output_one","第一份演示交付完成，考核明确通过。")
				return "考核通过！成果已记录。找周工谈转正。"
		"no_hc":
			if employer=="a" and stage==2:
				stage=3
				record("no_hc","考核通过，但本组没有 HC；可找许姐换组继续实习。")
				return "周工：你达标了，但没有 HC。许姐的二组愿意接，还是实习。"
		"transfer":
			if employer=="a" and stage==3:
				stage=4
				grade="二组实习生"
				record("transfer","转入二组，前次成果保留；这次只需切换现场备用投影。")
				return "许姐：不用重做演示。右后方投影失灵，切换备用线路就能交付。"
		"backup":
			if employer=="a" and stage==4:
				stage=5
				record("output_two","切换备用投影，二组现场恢复；第二份成果完成。")
				return "投影亮了。第二份成果完成，可找方总答辩。"
		"defend":
			if employer=="a" and stage==5:
				stage=6
				grade="正式员工"
				record("regular","答辩展示两份成果，已正式转正。没有第三次实习。")
				return "方总：演示交付、现场恢复都已确认。正式名额生效，你转正了。"
		"resign":
			if employer!="":
				former.append(employer)
				employer=""
				grade="已离职"
				return "已离职。成果与个人关系保留；当前雇佣结束。"
	return "当前条件尚未满足，已完成的成果不会丢失。"

func objective() -> String:
	if conflict.a>=2 and conflict.b>=2: return "两家公司职业机会均已关闭 · 仍可自由活动、见人、使用道具"
	if employer=="b":
		return {"pending":"找阿乐聊聊今晚的交接", "helping":"到右侧交接终端发送资料", "refused":"阿乐正在处理 · 可以离开，也可改为交涉", "negotiating":"与阿乐一起找后方赵总", "helped":"交接完成 · 阿乐在门外等你", "negotiated":"交接改为明早 · 今晚自由了", "conflict":"现场工作被中断 · 后果已经记录"}.get(b_event,"自由活动")
	if employer=="a":
		match stage:
			1:
				if not facts.has("desk_a_arrived"): return "第一章 · 实习第一天：右侧第一排，E 查看自己的工位"
				if not facts.has("brief"): return "实习：周工会到工位找你，也可主动去找他"
				if not facts.has("data"): return "查看蓝色资料台的原始说明"
				if not facts.has("prepared"): return "实习：回自己的工位，整理资料并预览演示包"
				if not facts.has("shortcut") and not facts.has("confirm"): return "找小夏核实离线版，或找周工走权限流程"
				return "到演示台提交成果"
			2: return "考核通过 · 找周工谈转正"
			3: return "没有 HC · 找右后方许姐谈换组"
			4: return "第二章 · 换组实习：后方中间新工位 / 右后方投影现场"
			5: return "第三章 · 转正答辩：两份成果就绪，找方总"
			6: return "已转正 · 可以继续上班，也可以离开"
	if former.has("a"): return "成果保留 · 可去自己人网络应聘"
	return ["规程科技 HR / 自己人网络 · 都可自由前往","下一轮：左侧周工","最后一轮：后方方总","正式名额冻结 · 可找 HR 接受实习"][recruit.a]

func aggression(company: String, action: int, current_action: int) -> String:
	if seen_actions[company].has(action): return ""
	seen_actions[company].append(action)
	if conflict[company]>=3: return ""
	# An already launched projectile cannot become a new escalation after a warning.
	if conflict[company]>0 and action<=warning_action[company]: return ""
	conflict[company]+=1
	warning_action[company]=current_action
	if company=="b" and employer=="b" and b_event in ["pending","helping","negotiating","refused"]:
		b_event="conflict"
		record("b_conflict","人情现场因主动冲突中断，工作停止；这不算正常交付。")
	if conflict[company]==1:
		record(company+"_warning","收到明确警告：继续主动动手将失去职业机会，再升级将永久决裂。")
		return "警告：继续主动动手将失去当前职业机会，再次升级将永久决裂！"
	if conflict[company]==2:
		if employer==company: apply("resign")
		record(company+"_lost","警告后继续主动升级：公司关闭职业机会，已有成果保留。")
		return "当前职业机会已取消。再次主动升级将与这家公司永久决裂。"
	record(company+"_severed","再次主动升级，与这家公司永久决裂；不影响另一家公司。")
	return "与本公司永久决裂。个人关系、成果与另一家公司独立保留。"

class_name OfficeDialogue
extends RefCounted

static func options(target: Node3D, c: Career) -> Dictionary:
	var id: String = target.role_id if target is OfficeNPC else target.stable_id
	var text: String = target.title
	var choices: Array = []
	match id:
		"a_hr":
			text="林岚：是来面试的吗？简历带了吗？我查一下今天的安排。"
			if c.recruit.a==0: choices.append(["参加 HR 面试：先把岗位说清楚","interview_hr"])
			if c.recruit.a==3 and c.employer=="" and not c.former.has("a"): choices.append(["接受实习邀请，办理入职","join_a"]); choices.append(["暂不接受录用，保留其他选择","decline_a"])
			if c.employer=="a" and c.facts.has("permission") and not c.facts.has("confirm"): choices.append(["确认演示提交人","confirm"])
			if c.employer=="a": choices.append(["主动离职，保留已有成果","resign"])
		"a_lead":
			text="周工：先做出成果，名额的事……做完再谈。"
			if c.recruit.a==1: choices.append(["技术面试：我会先找最短可行路径","interview_lead"])
			if c.employer=="a":
				if c.stage==1:
					choices.append(["了解演示要求","brief"])
					if c.facts.has("data"): choices.append(["按常规申请运行权限","permission"])
				if c.stage==2: choices.append(["考核已通过，要求确认转正","no_hc"])
		"a_boss":
			text="方总：公司看重结果。当然，名额由另一套流程决定。"
			if c.recruit.a==2: choices.append(["老板面试：结果应该被承认","interview_boss"])
			if c.employer=="a" and c.stage==5: choices.append(["答辩：展示演示交付与现场恢复两份成果","defend"])
			if c.stage==6: text="方总：正式员工身份已经生效，不会再让你实习一遍。"
		"a_friend":
			text="小夏：等一下，这个版本我先存好。你找我有事？"
			if c.employer=="a" and c.stage==1 and c.facts.has("data"): choices.append(["拿原始说明核实：离线版需要审批吗？","shortcut"])
			if c.employer=="a" and c.facts.has("data"): choices.append(["能先签字，之后再补演示吗？","boundary"])
		"a_group":
			text="许姐：你的上次考核通过了，我认。二组只看现场恢复。"
			if c.employer=="a" and c.stage==3: choices.append(["转入二组继续实习，保留原成果","transfer"])
		"b_hr":
			text="阿诚：流程就一轮，大家都是自己人。你愿不愿意先了解再决定？"
			if c.recruit.b==0: choices.append(["参加面试：把职责说清楚","interview_b"])
			elif c.employer=="" and not c.former.has("b"): choices.append(["接受录用，办理入职","join_b"]); choices.append(["暂不接受录用，保留其他选择","decline_b"])
			if c.employer=="b": choices.append(["主动离职","resign"])
		"b_friend":
			text="阿乐：备用终端你先用。今晚这份交接，老板说‘帮家里一把’。"
			if c.employer=="b" and c.b_event in ["pending","refused"]:
				choices.append(["我来接手：去交接终端完成","help"])
				if c.b_event=="pending": choices.append(["今晚拒绝加班","refuse"])
				choices.append(["一起找赵总问清截止时间","negotiate"])
			if c.b_event in ["helped","negotiated"]: text="阿乐：谢谢你。欠的人情不是无限加班的借口。"
			if c.b_event=="conflict": text="阿乐：我懂你憋屈，但打我或同事不行。今天先停下。"
		"b_boss":
			text="赵总：都是自己人，多做一点怎么了？"
			if c.employer=="b" and c.b_event=="negotiating": choices.append(["和阿乐共同交涉：没有今晚截止，改明早交","settle"])
		"handover":
			text="交接终端 / 阿乐让出的备用设备"
			if c.employer=="b" and c.b_event=="helping": choices.append(["发送已有交接包，接替阿乐","handover"])
		"rest":
			text="公交站 / 坐一会儿，世界会继续。"
			choices=[["休息到傍晚","rest_evening"],["休息一天","rest_day"]]
		"archive":
			text="原始演示资料 / 小夏编写"
			choices.append(["拿取资料并阅读原始说明","data"])
		"demo":
			text="演示台：离线包与常规权限方式均有效。"
			if c.employer=="a" and c.stage==1: choices.append(["提交演示，接受考核","submit"])
		"backup":
			text="现场投影：主线路无信号，备用开关就在此处。"
			if c.employer=="a" and c.stage==4: choices.append(["切换备用线路，恢复现场投影","backup"])
		_: text="今天也可以什么都不证明。"
	var firm := "a" if id.begins_with("a_") else "b" if id.begins_with("b_") else ""
	if firm!="" and c.conflict[firm]>=2:
		text="公司已关闭职业机会，已有成果和个人关系保留。你仍可自由离开。"
		choices=[]
	if target is OfficeNPC: text=voice(target,text)
	return {"text":text,"choices":choices}

static func voice(npc: OfficeNPC,line: String) -> String:
	var separator := line.find("：")
	if separator>=0 and line.left(separator) in ["林岚","周工","方总","小夏","许姐","阿诚","阿乐","赵总","面试官"]:
		return npc.title.split(" · ")[0]+line.substr(separator)
	return line

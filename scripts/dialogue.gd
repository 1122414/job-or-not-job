class_name OfficeDialogue
extends RefCounted

static func options(target: Node3D, c: Career) -> Dictionary:
	var id: String = target.stable_id
	var text: String = target.title
	var choices: Array = []
	match id:
		"a_hr":
			text="林岚：我们需要能适应变化的人，包括岗位名额的变化。"
			if c.recruit.a==0: choices.append(["参加 HR 面试：先把岗位说清楚","interview_hr"])
			if c.recruit.a==3 and c.employer=="" and not c.former.has("a"): choices.append(["接受实习邀请","join_a"])
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
			text="小夏：我愿意帮你省事，但不会替你造假。"
			if c.employer=="a" and c.stage==1 and c.facts.has("data"): choices.append(["拿原始说明核实：离线版需要审批吗？","shortcut"])
			choices.append(["请你在没做完时替我签字","boundary"])
		"a_group":
			text="许姐：你的上次考核通过了，我认。二组只看现场恢复。"
			if c.employer=="a" and c.stage==3: choices.append(["转入二组继续实习，保留原成果","transfer"])
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
	return {"text":text,"choices":choices}

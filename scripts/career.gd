class_name Career
extends RefCounted

var recruit := {"a":0,"b":0}
var employer := ""
var grade := "求职者"
var stage := 0
var facts: Dictionary = {}
var records: Array[String] = []
var former: Array[String] = []

func record(key: String, text: String) -> void:
	if facts.has(key): return
	facts[key]=true
	records.append(text)

func apply(action: String) -> String:
	match action:
		"interview_hr":
			if recruit.a==0:
				recruit.a=1
				return "HR 面试通过。周工在左侧工位，下一轮只谈一件事。"
		"interview_lead":
			if recruit.a==1:
				recruit.a=2
				return "技术面试通过。方总在办公室后方等你。"
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
				return "入职。一组需要一个演示，请找周工了解情况。"
		"brief":
			if employer=="a" and stage==1:
				record("brief","演示资料在蓝色资料台；听说运行需要权限。")
				return "周工：资料在蓝台。先找原始说明，别急着跑流程。"
		"data":
			record("data","拿到演示资料：原始说明注明离线版无需权限审批。")
			return "原始说明：离线演示不访问生产环境，不需要审批。可以找小夏核实。"
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
			if employer=="a" and stage==1 and facts.has("data") and (facts.has("shortcut") or (facts.has("permission") and facts.has("confirm"))):
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
	if employer=="a":
		match stage:
			1:
				if not facts.has("brief"): return "找周工了解第一份演示"
				if not facts.has("data"): return "查看蓝色资料台的原始说明"
				if not facts.has("shortcut") and not facts.has("confirm"): return "找小夏核实离线版，或找周工走权限流程"
				return "到演示台提交成果"
			2: return "考核通过 · 找周工谈转正"
			3: return "没有 HC · 找右后方许姐谈换组"
			4: return "二组 · 到右后方投影台切换备用线路"
			5: return "两份成果就绪 · 找方总答辩"
			6: return "已转正 · 可以继续上班，也可以离开"
	if former.has("a"): return "成果保留 · 可去自己人网络应聘"
	return ["规程科技 HR / 自己人网络 · 都可自由前往","下一轮：左侧周工","最后一轮：后方方总","正式名额冻结 · 可找 HR 接受实习"][recruit.a]

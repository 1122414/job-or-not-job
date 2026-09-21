extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func _initialize() -> void:
	for shortcut in [false,true]:
		var c := Career.new()
		c.apply("data") # Early exploration remains valid after hiring.
		c.apply("join_a")
		check(c.employer=="","不能跳过面试")
		for action in ["interview_hr","interview_lead","interview_boss","join_a","brief"]: c.apply(action)
		check(c.stage==1 and c.grade=="一组实习生","三轮后仅实习")
		c.apply("submit")
		check(c.stage==1,"缺条件不能直接通过")
		if shortcut: c.apply("shortcut")
		else:
			c.apply("permission")
			c.apply("confirm")
		c.apply("submit")
		check(c.stage==2 and c.facts.has("output_one"),"第一份考核通过")
		for action in ["no_hc","transfer","backup","defend"]: c.apply(action)
		check(c.stage==6 and c.grade=="正式员工" and c.facts.has("output_two"),"无HC换组产出答辩真正转正")
		check(not shortcut or not c.facts.has("permission"),"捷径确实不补做审批")
		var count := c.records.size()
		c.apply("defend")
		check(c.records.size()==count,"重复答辩不重复成果")
		c.apply("resign")
		check(c.employer=="" and c.facts.has("regular"),"离职保留成果")
	print("CAREER_TEST failures=",failures)
	quit(failures)

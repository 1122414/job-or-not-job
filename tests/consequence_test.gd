extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func _initialize() -> void:
	var c := Career.new()
	c.apply("interview_b")
	c.apply("join_b")
	check(c.employer=="b" and c.recruit.a==0,"第二家可首进入职")
	c.apply("refuse")
	check(c.b_event=="refused" and c.employer=="b","拒绝保留工作")
	c.apply("negotiate")
	c.apply("settle")
	check(c.b_event=="negotiated","人情交涉结果")
	c.aggression("b",10,12)
	c.aggression("b",10,12)
	c.aggression("b",11,12)
	check(c.conflict.b==1,"同次连锁及警告前已发出攻击不得升级")
	c.aggression("b",13,13)
	check(c.conflict.b==2 and c.employer=="","警告后动手取消机会但未永久决裂")
	c.aggression("b",14,14)
	check(c.conflict.b==3 and c.conflict.a==0,"再次主动升级决裂且公司隔离")
	c.apply("join_b")
	check(c.employer=="","决裂不允许返聘")
	for action in ["interview_hr","interview_lead","interview_boss","join_a"]: c.apply(action)
	check(c.employer=="a","另一家公司仍可入职")
	var h := Career.new()
	for action in ["interview_b","join_b","help","handover"]: h.apply(action)
	check(h.b_event=="helped" and h.facts.has("b_help"),"帮助必须完成现场交接")
	print("CONSEQUENCE_TEST failures=",failures)
	quit(failures)

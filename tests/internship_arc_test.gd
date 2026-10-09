extends SceneTree
var failures := 0

func check(ok: bool,message: String) -> void:
	if not ok: push_error(message);failures+=1

func _initialize() -> void:
	call_deferred("run")

func json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func money(game: Node3D) -> int:
	return int(game.payroll.balance+game.payroll.pending.a+game.payroll.pending.b)

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);root.set_disable_input(true)
	for frame in range(10): await physics_frame
	# Isolated domain fixture. autumn_full_story_test covers the real recruitment/walking path.
	var baseline: Dictionary=SaveGame.snapshot(game)
	var pristine: Dictionary=json(baseline)
	check(SaveGame.restore(game,baseline),"首次恢复可复用的基线快照")
	game.story.start_new();game.career.recruit.a=3;game.career.apply("join_a");game.story.joined();game.story.sync_scene()
	var arc: InternshipArc=game.story.arc
	var lead: OfficeNPC=game.npc_for_role("a_lead")
	var group: OfficeNPC=game.npc_for_role("a_group")
	var boss: OfficeNPC=game.npc_for_role("a_boss")
	var rest: WorkStation
	for station in game.stations:
		if station.stable_id=="rest": rest=station
	var original_minute: int=game.payroll.minute
	game.speaker=rest;arc.handle("story_milestone_wait")
	check(game.payroll.minute==original_minute,"没有第一份成果时不能跳过工作")
	for action in ["data","prepare","shortcut","submit"]: game.career.apply(action)
	var earned := money(game)
	game.promises.handle("no_hc",lead)
	check(game.career.stage==2 and arc.state().reviewed_at==0,"第一份成果不会提前触发评审")
	game.speaker=group;arc.handle("story_milestone_wait")
	check(game.payroll.minute==original_minute,"跳日期必须在公交站发起")
	game.speaker=rest;arc.handle("story_milestone_wait")
	check(game.payroll.minute==arc.date(4) and game.career.stage==2,"到第4周，不自动评审")
	check(money(game)-earned==28*Payroll.DAY*Payroll.CENTS_PER_MINUTE,"跨4周工资按既有规则结算，无额外奖励")
	game.promises.handle("no_hc",boss)
	check(game.career.stage==2,"错误岗位不能代替主管评审")
	game.promises.handle("no_hc",lead)
	check(arc.state().reviewed_at==arc.date(4) and game.career.stage==3,"第4周当面确认通过但名额未批")
	game.promises.handle("promise_written",lead)
	game.promises.handle("transfer",group);game.promises.handle("transfer_confirm",group)
	game.career.apply("backup")
	check(game.career.stage==4,"未重新确认安排不能直接完成二组任务")
	var week4: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,json(week4)),"第4周JSON恢复")
	game.speaker=group;arc.handle("story_renewal_written")
	check(arc.state().renewed_at==0,"第8周之前不能伪造再次承诺")
	game.speaker=rest;arc.handle("story_milestone_wait")
	check(game.payroll.minute==arc.date(8) and not game.career.facts.has("output_two"),"跳至第8周不自动产生第二份成果")
	game.speaker=group;arc.handle("story_renewal");game.story.handle("story_pause")
	check(arc.state().renewed_at==0 and not game.career.facts.has("internship_renewed"),"只听到条件后取消，不算接受")
	game.speaker=boss;arc.handle("story_renewal_written")
	check(arc.state().renewed_at==0,"错误岗位不能生成再次承诺")
	game.speaker=group;arc.handle("story_renewal");arc.handle("story_renewal_written")
	check(arc.state().renewed_at==arc.date(8) and game.career.facts.has("renewal_written"),"书面回复分支记录日期和选择")
	var count: int=game.recruitment.promises.size()
	game.speaker=group;arc.handle("story_renewal_written")
	check(game.recruitment.promises.size()==count,"重复确认不重复记承诺")
	game.career.apply("backup")
	game.promises.handle("defend",boss);game.promises.handle("defend_confirm",boss);game.career.apply("defend")
	check(game.career.stage==5 and game.career.employer=="a","第8周既不能前端提前答辩，也不能绕过确认")
	var week8: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,json(week8)),"第8周成果与约定JSON恢复")
	game.speaker=rest;arc.handle("story_milestone_wait")
	check(game.payroll.minute==arc.date(12) and not game.career.facts.has("conversion_failed"),"第12周日期到达仍需亲自答辩")
	game.promises.handle("defend",boss);game.promises.handle("promise_pause",boss)
	check(game.career.stage==5,"答辩确认可以取消")
	game.promises.handle("defend_confirm",group)
	check(game.career.stage==5,"许姐不能代替方总给最终结论")
	game.promises.handle("defend",boss);game.promises.handle("defend_confirm",boss)
	check(game.career.stage==6 and game.career.employer=="" and arc.state().ended_at==arc.date(12),"满12周、两份成果通过、未转正")
	check(game.recruitment.promises.size()==count+1,"最终结论留存，不覆盖此前承诺")
	var final_state: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,json(final_state)),"最终日期与原话JSON恢复")
	earned=money(game);game.advance_time(Payroll.DAY)
	check(money(game)==earned,"实习结束后无新工资")
	for kind in ["missing","type","future","early","order","quote","fact","end","disabled"]:
		var bad: Dictionary=json(final_state)
		match kind:
			"missing": bad.autumn_story.erase("placement")
			"type": bad.autumn_story.placement.renewed_at="8"
			"future": bad.autumn_story.placement.ended_at=bad.payroll.minute+1
			"early": bad.autumn_story.placement.reviewed_at=1
			"order": bad.autumn_story.placement.renewed_at=0
			"quote": bad.recruitment.promises.pop_back()
			"fact": bad.career.facts.erase("internship_renewed")
			"end": bad.autumn_story.placement.ended_at=0
			"disabled": bad.autumn_story.placement.enabled=false
		var before: Dictionary=json(SaveGame.snapshot(game))
		check(not SaveGame.restore(game,bad),"拒绝坏档："+kind)
		check(json(SaveGame.snapshot(game))==before,"坏档无部分修改："+kind)
	check(SaveGame.restore(game,json(week4)),"恢复第4周分支")
	game.career.apply("resign");earned=money(game)
	game.speaker=rest;arc.handle("story_milestone_wait")
	game.advance_time(84*Payroll.DAY)
	check(arc.state().ended_at==0 and arc.state().renewed_at==0 and money(game)==earned,"提前离职，不补做节点或继续领工资")
	check(arc.summary().contains("提前中止") and not game.story.objective().get("title","").contains("跳过普通日"),"提前离职不显示12周完成或引导继续实习")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"提前离职存档有效")
	check(SaveGame.restore(game,json(week4)),"恢复第4周以测试范围选择")
	game.speaker=rest;arc.handle("story_milestone_wait")
	game.speaker=group;arc.handle("story_renewal");arc.handle("story_renewal_scope")
	check(game.career.facts.has("renewal_scope") and not game.career.facts.has("renewal_written"),"范围分支与书面分支有不同事实记录")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"范围分支存档有效")
	var old: Dictionary=json(week4)
	old.version=28;old.autumn_story.erase("placement");old.career.facts.erase("internship_extended")
	old.recruitment.promises=old.recruitment.promises.filter(func(item): return not item.key.begins_with("internship_week"))
	check(SaveGame.restore(game,old),"v28已有实习恢复")
	check(not arc.active() and game.career.stage==4,"旧档不强制补8/12周")
	game.career.apply("backup");game.promises.handle("defend",boss);game.promises.handle("defend_confirm",boss)
	check(game.career.facts.has("conversion_failed") and not game.career.facts.has("twelve_weeks_completed"),"旧路线原结局保留，不伪造长期投入")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"迁移后可保存为v29")
	old.mentor.hp="invalid"
	check(not SaveGame.valid(old,game),"v28导师原校验不因新版放宽")
	check(json(baseline)==pristine,"恢复后的职业/工资变化不反向改写原快照")
	check(SaveGame.restore(game,baseline),"隔离世界恢复")
	game.queue_free();await process_frame
	print("INTERNSHIP_ARC_TEST failures=",failures);quit(failures)

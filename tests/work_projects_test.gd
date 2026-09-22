extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	for i in range(10): await physics_frame
	for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data"]: game.career.apply(action)
	var project: WorkProjects=game.projects
	for key in [1,2,3,4,4,6]: project.key(key)
	check(project.state("a").preview=="error" and not game.career.facts.has("prepared"),"草稿具体错误且不可交付")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))),"错误作品读档")
	check(project.state("a").get("note","").contains("自动退款"),"具体错误原因持久保存")
	project.key(4); project.key(6)
	check(game.career.facts.has("prepared") and project.state("a").preview.contains("A-017"),"改用正式资料得到实际演示内容")
	game.projects.handle("submit")
	check(game.career.stage==1,"预览不等于交付，仍需核实运行条件")
	game.career.apply("shortcut"); game.projects.handle("submit")
	check(game.career.stage==2 and project.state("a").delivered,"核实离线条件后现场交付")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"工作成果JSON恢复")
	check(project.state("a").delivered and project.state("a").source=="official","来源和交付结果保留")
	game.career.apply("no_hc"); game.career.apply("transfer")
	check(project.state("a").delivered,"转组不抹掉成果")
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"重置独立测试分支")
	for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data"]: game.career.apply(action)
	for key in [1,4,5,6]: project.key(key)
	check(project.state("a").preview=="error","生产模式没有权限不能运行")
	game.career.apply("permission"); project.key(6); game.projects.handle("submit")
	check(game.career.stage==1,"常规路径需要提交人确认")
	game.career.apply("confirm"); game.projects.handle("submit")
	check(game.career.stage==2,"常规权限确认路径可交付")
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"重置独立测试分支")
	for action in ["interview_b","join_b","negotiate"]: game.career.apply(action)
	check(project.handle("settle") and game.career.b_event=="negotiating","不能只按协商就解决")
	for key in [1,2,3,4,4,5,5,6]: project.key(key)
	check(project.state("b").preview=="error","交接旧包缺项反馈")
	project.key(4); project.key(7)
	check(project.state("b").proposal and not project.handle("settle"),"根据原始截止时间准备完整协商材料，允许现场确认")
	game.career.b_event="helping"
	project.key(5); project.key(7)
	check(game.career.b_event=="helped" and project.state("b").sent,"正确包实际发送后才完成帮忙")
	game.career.b_event="helping"
	game.career.apply("negotiate")
	check(game.career.b_event=="negotiating","接手后发现原始期限仍能改为现场协商")
	game.queue_free()
	await process_frame
	print("WORK_PROJECTS_TEST failures=",failures)
	quit(failures)

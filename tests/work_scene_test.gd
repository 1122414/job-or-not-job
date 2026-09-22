extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	var stations := {}
	for station in game.stations: stations[station.stable_id]=station
	for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data"]: game.career.apply(action)
	game.career.facts.welcome_a=true
	game.career.facts.visit_brief=true
	game.player.sit_at(stations.desk_a.position)
	await frames(2)
	check(game.nearest()==stations.desk_a,"坐在工位优先工作，不抢成拿键盘")
	var monitor: OfficeProp
	for prop in game.props:
		if prop.kind=="monitor" and absf(prop.position.x-stations.desk_a.position.x)<0.1 and prop.position.distance_to(stations.desk_a.position)<2: monitor=prop
	check(monitor!=null and stations.desk_a.screen.global_position.z>monitor.position.z+0.06,"工位文字在显示器前表面外")
	game.office.start_preview(stations.desk_a)
	check(game.career.facts.has("desk_a_arrived"),"直接运行预览也会记录工位到达，不残留开局目标")
	await frames(40)
	check(not game.career.facts.has("prepared") and stations.desk_a.screen.text.contains("%"),"预览是场景内过程，不能开始即成功")
	game.player.stand_up()
	await frames(2)
	check(game.office.preview_station==null and not game.career.facts.has("prepared"),"起身中断，资料保留且不伪造结果")
	game.office.start_preview(stations.desk_a)
	await frames(200)
	check(game.career.facts.has("prepared"),"完整运行后生成预览成果")
	for action in ["shortcut","submit"]: game.career.apply(action)
	await frames(2)
	check(stations.demo.result_board.text.contains("已归档"),"首次交付在场景显示成果")
	for action in ["no_hc","transfer","backup","defend"]: game.career.apply(action)
	await frames(2)
	check(stations.backup.result_board.text.contains("已恢复") and stations.desk_a2.screen.text.contains("正式员工"),"二次交付投影恢复，工位显示正式身份")
	var saved: Dictionary=SaveGame.snapshot(game)
	game.career.apply("resign")
	check(game.career.facts.has("output_one") and game.career.facts.has("output_two"),"离职成果保留")
	check(SaveGame.restore(game,saved),"成果存档可恢复")
	for branch in ["help","refuse","negotiate"]:
		SaveGame.restore(game,game.initial_state.duplicate(true))
		for action in ["interview_b","join_b",branch]: game.career.apply(action)
		if branch=="help": game.career.apply("handover")
		if branch=="negotiate": game.career.apply("settle")
		await frames(2)
		var expected: String={"help":"交接完成","refuse":"今晚不接手","negotiate":"交接改明早"}[branch]
		check(stations.desk_b.screen.text.contains(expected),"B公司个人终端反馈分支："+branch)
	game.player.collect(monitor)
	await frames(2)
	check(not stations.desk_a.screen.visible and not stations.desk_a.screen_back.visible,"收走显示器不会留下悬浮文字和画面")
	game.queue_free()
	await process_frame
	print("WORK_SCENE_TEST failures=",failures)
	quit(failures)

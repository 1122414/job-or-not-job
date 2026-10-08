extends "res://tests/full_route_test.gd"

func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	capture_viewport=root
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1280,800); viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.set_disable_input(true); root.add_child(viewport); capture_viewport=viewport
	capture_viewport.add_child(game)
	root.set_disable_input(true); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	game.story.start_new()
	# Prologue has its own real-input route; start this test from its saved exit.
	game.story.refuse()
	game.player.position=game.story.points[1].position+Vector3(0,0,-1.5)
	game.story.open(game.story.points[1]); game.choose(0)
	check(game.story.data.phase=="early_autumn","从序章出口进入当前主线")
	for step in [["b_hr","interview_b"],["rest","rest_next"]]:
		if not await perform(game,step[0],step[1]): failures+=1; finish(game); return
	check(game.recruitment.applications.b.phase=="rejected","先选B仍可面试，取消岗位不伪装录用")
	check(not game.objective_text().contains("办理入职"),"岗位取消后目标不能仍要求入职")
	game.recruitment.accept("b"); game.career.apply("join_b")
	check(game.career.employer=="","B不能绕过失业结局")
	var route := [["a_hr","interview_hr"],["a_lead","interview_lead"],["a_boss","interview_boss"],["a_hr","join_a"],["a_hr","tour_begin"],["a_hr","tour_greet"],["a_hr","tour_settle"],["desk_a","desk_open"],["a_hr","service_account"],["a_lead","brief"],["archive","data"],["desk_a","prepare"],["a_friend","shortcut"],["demo","submit"],["a_lead","no_hc"],["a_group","transfer"],["desk_a2","desk_open"],["backup","backup"],["a_boss","defend"]]
	for step in route:
		print("AUTUMN_ROUTE_STEP ",step)
		if not await perform(game,step[0],step[1]): failures+=1; finish(game); return
		if step[1]=="join_a":
			check(game.career.facts.has("mentor_released") and game.story.data.call_done,"秋招接收通知之后导师才改口")
			game.recruitment.ask_conditions()
			check(game.recruitment.messages.back().body.contains("有HC，达标后转正"),"追问仍保留明确承诺")
			check(game.story.data.review_at==game.story.data.started_at+28*Payroll.DAY,"明确四周评审日期")
		if step[1]=="submit":
			check(not game.story.review_ready(),"交付不瞬间经过四周")
			check(game.office.visit().get("key","")!="visit_review","未到评审不会提前泄露无HC")
		if step[1] in ["join_a","no_hc","defend"]:
			await capture(game,step[1])
			check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))),"章节JSON恢复："+step[1])
	check(game.career.stage==6 and game.career.employer=="" and not game.career.facts.has("regular") and game.career.facts.has("conversion_failed"),"两份成果通过但最终未转正")
	check(game.story.data.phase=="departure" and game.career.facts.has("output_one") and game.career.facts.has("output_two"),"保留成果与失败原因")
	var pending: float=game.payroll.pending.a
	game.advance_time(5)
	check(game.payroll.pending.a==pending,"结束实习后不新增工资，应得部分保留")
	if not await perform(game,"a_hr","story_original_offer"): failures+=1; finish(game); return
	check(game.conversation.text.contains("有正式HC") and game.conversation.text.contains("无正式名额"),"原通知与新口径并存")
	game.choose(0)
	check(game.story.data.phase=="late_autumn" and game.career.facts.has("internship_certificate"),"领取一段实习证明后重返秋招")
	await capture(game,"certificate")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"结束档有效")
	finish(game)

func capture(game: Node3D,name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(10): await physics_frame
	paused=true
	for frame in range(3): await process_frame
	RenderingServer.force_draw()
	var folder := "res://docs/evidence/2026-10-08-autumn-career"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_viewport.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"图形证据保存")
	paused=false

func finish(game: Node3D) -> void:
	game.queue_free()
	print("AUTUMN_CAREER_TEST failures=",failures)
	quit(failures)

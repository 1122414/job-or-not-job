extends "res://tests/work_handover_test.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);root.set_disable_input(true)
	for i in range(10):await physics_frame
	game.set_process(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from-route="):
			var file := argument.trim_prefix("--from-route=")
			var saved := SaveGame.read(file,game)
			check(not saved.is_empty() and SaveGame.restore(game,saved),"actual route restored in independent process")
			check(JSON.parse_string(JSON.stringify(game.handover.data))==saved.get("work_handover",{}),"all actual work fields restored")
			check(SaveGame.valid(SaveGame.snapshot(game),game),"actual complete world valid")
			finish(file);return
	decide("negotiated")
	var original := SaveGame.snapshot(game)
	var corruptions := ["missing","type","phase","kind","arranged_future","due_changed","elapsed_negative","elapsed_nan","elapsed_complete","elapsed_early","completed_early","sender_pending","sent_pending","proposal_missing","wrong_choice","missing_fact","clock_type"]
	for issue in corruptions:
		var bad := original.duplicate(true)
		match issue:
			"missing":bad.erase("work_handover")
			"type":bad.work_handover=[]
			"phase":bad.work_handover.phase="finished"
			"kind":bad.work_handover.kind="unknown"
			"arranged_future":bad.work_handover.arranged_at=bad.payroll.minute+1
			"due_changed":bad.work_handover.due_at+=1
			"elapsed_negative":bad.work_handover.elapsed=-1
			"elapsed_nan":bad.work_handover.elapsed=NAN
			"elapsed_complete":bad.work_handover.elapsed=WorkHandover.SECONDS
			"elapsed_early":bad.work_handover.elapsed=1
			"completed_early":bad.work_handover.completed_at=1
			"sender_pending":bad.work_handover.sender="b_friend"
			"sent_pending":bad.recruitment.work.project_b.sent=true
			"proposal_missing":bad.recruitment.work.project_b.proposal=false
			"wrong_choice":bad.career.b_event="helped"
			"missing_fact":bad.career.facts.erase("b_negotiate")
			"clock_type":bad.payroll.minute="tomorrow"
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"invalid save atomically refused: "+issue)
	game.advance_time(960)
	await frames(3000)
	check(game.handover.data.phase=="delivered","natural completion before completed-save cases")
	var delivered := SaveGame.snapshot(game)
	for issue in ["sender_unknown","sender_wrong_role","timestamp_future","unsent","incomplete_package","missing_record","empty_record"]:
		var bad := delivered.duplicate(true)
		match issue:
			"sender_unknown":bad.work_handover.sender="absent"
			"sender_wrong_role":bad.work_handover.sender="a_hr"
			"timestamp_future":bad.work_handover.completed_at=bad.payroll.minute+1
			"unsent":bad.recruitment.work.project_b.sent=false
			"incomplete_package":bad.recruitment.work.project_b.package="old"
			"missing_record":bad.career.facts.erase("b_handover_receipt")
			"empty_record":bad.work_handover={}
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"invalid completed save atomically refused: "+issue)
	for version in range(1,24):
		var old: Dictionary=game.initial_state.duplicate(true);old.version=version;old.erase("work_handover")
		if version<20:old.city_population.crossings.erase("office")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"legacy v%d JSON"%version)
		check(game.handover.data.is_empty(),"fresh legacy does not invent a task")
	var old := original.duplicate(true);old.version=23;old.erase("work_handover")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"legacy negotiated save")
	check(game.handover.data.phase=="unconfirmed" and game.handover.data.due_at==-1 and not game.projects.state("b").sent,"unknown historical date is not invented")
	var npc: OfficeNPC=game.npc_for_role("b_friend")
	game.speaker=npc
	check(game.handover.handle("handover_reconfirm") and game.handover.data.phase=="pending" and game.handover.data.due_at==2040,"legacy schedule explicitly reconfirmed")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"reconfirmed full world valid")
	decide("refused")
	old=SaveGame.snapshot(game);old.version=23;old.erase("work_handover")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"legacy refused save")
	check(game.handover.data.phase=="unconfirmed" and game.career.b_event=="refused","legacy refusal is preserved without invented completion")
	game.speaker=game.npc_for_role("b_friend")
	check(game.handover.handle("handover_reconfirm") and game.handover.data.due_at==game.payroll.minute,"legacy refusal reconfirms current responsibility")
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"fresh fixture for legacy sent work")
	for action in ["interview_b","join_b","help","handover"]:game.career.apply(action)
	game.projects.migrate()
	old=SaveGame.snapshot(game);old.version=23;old.erase("work_handover")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"legacy player-sent save")
	check(game.projects.state("b").sent and game.career.facts.has("b_help") and game.handover.data.is_empty(),"legacy known delivery remains sent without fictional receipt date")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"legacy sent work remains valid in v24")
	finish()

func finish(route: String="") -> void:
	print("WORK_HANDOVER_SAVE_TEST failures=",failures," invalid_cases=24 legacy_versions=23 legacy_work_branches=3" if route.is_empty() else " actual_route="+route)
	game.queue_free();await process_frame;quit(failures)

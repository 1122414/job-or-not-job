extends SceneTree
const Driver=preload("res://tests/scene_driver.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func select(game: Node3D,action: String) -> bool:
	var npc: OfficeNPC=game.onboarding.guide()
	game.speaker=npc
	game.conversation=game.onboarding.options(npc)
	for i in range(game.conversation.choices.size()):
		if game.conversation.choices[i][1]==action:
			game.choose(i)
			return true
	return false
func capture(game: Node3D,label: String) -> void:
	if DisplayServer.get_name()=="headless" or not "--capture" in OS.get_cmdline_user_args(): return
	game.speaker=game.onboarding.guide()
	game.conversation=game.onboarding.options(game.speaker)
	for i in range(40): await physics_frame
	paused=true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/evidence/2026-09-22-onboarding")
	root.get_texture().get_image().save_png("res://docs/evidence/2026-09-22-onboarding/"+label+".png")
	game.close_interaction()
	paused=false
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	var fresh: Dictionary=SaveGame.snapshot(game)
	for firm in ["a","b"]:
		SaveGame.restore(game,fresh)
		for action in (["interview_hr","interview_lead","interview_boss","join_a"] if firm=="a" else ["interview_b","join_b"]): game.career.apply(action)
		game.onboarding.start(firm)
		var guide: OfficeNPC=game.onboarding.guide()
		game.player.position=guide.position+Vector3(0,0,1.5)
		select(game,"tour_pause")
		check(game.onboarding.tour.paused,"可以先自由探索")
		var snapshot: Dictionary=SaveGame.snapshot(game)
		check(SaveGame.restore(game,snapshot) and game.onboarding.tour.paused,"暂停带领可读档续接")
		select(game,"tour_resume")
		select(game,"tour_begin")
		check(game.office.visit().is_empty(),"带领时工作来访不抢占")
		check(await Driver.follow(self,game,guide,game.onboarding.destination()),"连续行走认识同事："+firm)
		for i in range(3): await physics_frame
		check(game.onboarding.tour.phase=="introduce","抵达后等待实际介绍")
		await capture(game,firm+"_introduce")
		select(game,"tour_greet")
		var friend: OfficeNPC=game.npc_for_role(firm+"_friend")
		check(game.social.state(friend).met,"同事介绍记入人物页")
		check(await Driver.follow(self,game,guide,game.onboarding.destination()),"连续带到工位："+firm)
		for i in range(3): await physics_frame
		await capture(game,firm+"_desk")
		check(select(game,"tour_settle"),"确认分配工位")
		var station: WorkStation
		for item in game.stations:
			if item.stable_id==game.office.assigned_desk(): station=item
		check(await Driver.walk(self,game,station.position+Vector3(0,0,1)),"自行走到工位")
		game.player.yaw=0
		game.interact()
		check(game.speaker==station,"工位交互优先于收纳")
		game.choose(0)
		check(not game.onboarding.active() and game.career.facts.has("tour_done_"+firm),"落座才完成入职安顿")
		print("ONBOARDING_ROUTE ",firm," phase=",game.onboarding.tour.phase)
	SaveGame.restore(game,fresh)
	game.career.recruit.a=3
	game.career.apply("join_a")
	game.onboarding.start("a")
	var guide: OfficeNPC=game.onboarding.guide()
	guide.care_state="away"
	check(game.onboarding.objective().title.contains("休养") and game.onboarding.npc_target(guide)==null,"救助期间可等待，不误称带领中")
	guide.care_state="awake"
	check(game.onboarding.objective().id=="a_hr","原人返岗后可恢复")
	guide.dead=true
	guide.hp=0
	check(game.onboarding.objective().title.contains("接替"),"死亡岗位接替前说明原因")
	var old: Dictionary=fresh.duplicate(true)
	old.version=9
	old.erase("onboarding")
	check(SaveGame.restore(game,old) and game.onboarding.tour.is_empty(),"旧档不强制重走带领")
	game.queue_free()
	await process_frame
	print("ONBOARDING_TEST failures=",failures)
	quit(failures)

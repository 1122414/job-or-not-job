extends "res://tests/city_bookshop_test.gd"

var initial := {}
var rest: WorkStation
var observations := []

func fixture(minute: int,kind: String="",stage: String="walking",venue: String="") -> void:
	check(SaveGame.restore(game,initial),"跨日用例恢复独立初态")
	game.payroll.minute=minute
	game.player.position=rest.position+Vector3(0,0,1.2)
	game.player.yaw=0
	game.update_daylight()
	if kind!="":
		game.social.outing={"person":"a_friend","kind":kind,"stage":stage,"elapsed":0.0}
		if venue!="": game.social.outing["venue"]=venue

func choose_action(action: String) -> bool:
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]==action:
			key(KEY_1+i)
			return true
	check(false,"实际数字键选项缺失 "+action+" "+str(game.conversation))
	return false

func rest_action(action: String) -> bool:
	key(KEY_E)
	check(game.speaker==rest,"实际E打开休息点")
	return choose_action(action)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3h")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.set_process(false)
	for station in game.stations:
		if station.stable_id=="rest": rest=station
	initial=SaveGame.snapshot(game)
	for scenario in [
		["offered",1140,"walk","offered","","rest_day","",2580],
		["garden_overnight",1140,"walk","walking","garden","rest_day","paused",2580],
		["bookshop_morning",1140,"walk","walking","bookshop","rest_morning","paused",1980],
		["lunch_to_evening",780,"lunch","walking","","rest_evening","paused",1080],
		["tea_overnight",660,"tea","walking","","rest_morning","paused",1980],
		["legacy_walk",1140,"walk","walking","","rest_day","paused",2580],
		["afternoon_tea",900,"tea","walking","","rest_evening","paused",1080]
	]:
		fixture(scenario[1],scenario[2],scenario[3],scenario[4])
		var before: Vector3=game.npc_for_role("a_friend").position
		var relationship: Dictionary=game.social.people.duplicate(true)
		var affinity: int=game.npc_for_role("a_friend").affinity
		check(rest_action(scenario[5]),"执行休息 "+scenario[0])
		check(game.payroll.minute==scenario[7],"立即到明确时刻 "+scenario[0])
		check(game.social.outing.get("stage","")==scenario[6],"跨时段释放人物并保留已接受约定 "+scenario[0])
		check(game.npc_for_role("a_friend").position==before and game.social.npc_target(game.npc_for_role("a_friend"))==null,"跳时不传送人物，也不继续占用私人目标")
		check(game.social.people==relationship and game.npc_for_role("a_friend").affinity==affinity,"暂缓或未回应不改变关系/记忆")
		check(SaveGame.valid(SaveGame.snapshot(game),game),"跨日状态可保存 "+scenario[0])
		observations.append({"case":scenario[0],"minute":game.payroll.minute,"outing":game.social.outing.duplicate(true)})
	# Natural clock crossing uses the same boundary, without any explicit skip.
	fixture(839,"lunch")
	game._process(2.1)
	check(game.payroll.minute==840 and game.social.outing.stage=="paused","自然经过午饭结束时刻立即暂缓")
	fixture(719,"tea")
	game._process(2.1)
	check(game.payroll.minute==720 and game.social.outing.stage=="paused","茶歇跨入午饭时段暂缓")
	fixture(599,"walk","walking","garden")
	var other: OfficeNPC=game.npc_for_role("b_hr")
	game.speaker=other;game.conversation={"text":"另一人的工作话题","choices":[["继续","interview_b"]]}
	game.social.tick(0)
	check(game.speaker==other and game.conversation.text=="另一人的工作话题","私人时段结束不关闭别人的交谈")
	# A same-person work conversation is also independent of private planning.
	fixture(1199,"walk","walking","bookshop")
	game.speaker=game.npc_for_role("a_friend")
	game.conversation={"text":"核对原始资料","choices":[["继续核对","data"],["聊聊近况与相处","people_menu"]]}
	game.advance_time(1)
	check(game.social.outing.stage=="paused" and game.conversation.text=="核对原始资料","书屋闭馆不关闭同事的工作话题")
	# Confirmed work following preserves a private plan and its timer.
	fixture(1140,"walk","offered")
	game.social.outing.person="b_friend";game.career.b_event="negotiating"
	game.advance_time(1440)
	check(game.social.outing.stage=="offered" and game.social.outing.elapsed==0,"工作接管期间保留私人安排")
	fixture(540,"tea","offered")
	game.speaker=game.npc_for_role("a_friend"); game.conversation=game.social.options(game.speaker)
	game.advance_time(31)
	check(game.social.outing.is_empty(),"短跳时也计入尚未接受邀请的原60秒窗口")
	check(game.conversation.is_empty(),"过期邀请关闭自己的旧接受选项")
	# Public rest UI previews the exact date, including exact-time boundaries.
	for pair in [[539,540],[540,1980],[1439,1980],[1800,1980]]:
		fixture(pair[0])
		key(KEY_E)
		var preview := ""
		for choice in game.conversation.choices:
			if choice[1]=="rest_morning": preview=choice[0]
		check(preview.contains(game.recruitment.stamp(pair[1])),"上午选项预告实际日期")
		check(choose_action("rest_morning") and game.payroll.minute==pair[1],"上午选择与预告一致")
	fixture(1080)
	check(rest_action("rest_evening") and game.payroll.minute==2520,"恰好18点选择下一次傍晚，不空操作")
	fixture(540)
	game.recruitment.applications.a={"phase":"waiting","feedback_at":600,"report_at":0}
	var original_sky: Color=game.environment.sky.sky_material.sky_horizon_color
	check(rest_action("rest_evening"),"招聘反馈通过既有休息入口")
	check(game.recruitment.applications.a.phase=="offered" and game.recruitment.messages.size()==1,"无需下一帧，招聘反馈已经送达")
	check(game.environment.sky.sky_material.sky_horizon_color!=original_sky,"无需下一帧，天空与时钟一致")
	fixture(540)
	game.recruitment.applications.a={"phase":"waiting","feedback_at":2040,"report_at":0}
	check(rest_action("rest_next") and game.payroll.minute==2040 and game.recruitment.applications.a.phase=="offered","下一安排同样立即同步")
	# Jumping through the scheduled bus stop also respects a closing venue.
	fixture(1199,"walk","walking","bookshop")
	game.player.position=CityLayout.STOPS[1].platform
	await frames(3)
	var waited: bool=game.transit.wait_for_bus(1)
	if not waited:
		check(game.payroll.minute==1199 and game.hud.toast.contains("被挡"),"有车占用站点时保留时刻和约定")
		# The initial traffic_0 is physically crossing this platform. Let it leave;
		# never remove traffic or bypass the existing occupied-stop guard.
		for i in range(600):
			await physics_frame
			if game.transit.wait_for_bus(1): waited=true; break
	check(waited,"实际车辆驶离后可跳过等车")
	check(game.payroll.minute>=1200 and game.social.outing.stage=="paused","等车跨过闭馆时间，同行暂缓")
	# Resume/end and real JSON persist the same accepted plan, without rewards.
	fixture(780,"lunch")
	check(rest_action("rest_evening"),"午饭暂缓前置")
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.social.handle("people_resume",npc)
	check(game.social.outing.stage=="paused","错误时段不恢复午饭同行")
	var paused := SaveGame.snapshot(game)
	var path := "res://build/c3h/paused-lunch.json"
	check(SaveGame.write(game,path)==OK,"v21暂缓约定实际JSON写盘")
	check(SaveGame.restore(game,SaveGame.read(path,game)) and game.social.outing==paused.social.outing,"v21完整恢复暂缓约定")
	game.advance_time(1440+780-game.payroll.minute)
	game.player.position=npc.position+Vector3(0,0,1.4);game.player.yaw=0
	key(KEY_E)
	check(game.speaker==npc and choose_action("people_resume"),"真实E/数字键恢复原午饭约定")
	check(game.social.outing.stage=="walking" and game.social.npc_target(npc)!=null,"合适时段恢复人物路线")
	game.social.pause_outing("先各自安排")
	key(KEY_E)
	check(choose_action("people_decline") and game.social.outing.is_empty(),"真实入口主动结束保留的约定")
	for label in ["old_pause","sharing_without_venue","guiding_without_venue","unknown_kind","unknown_person"]:
		var bad: Dictionary=paused.duplicate(true)
		match label:
			"old_pause": bad.version=20
			"sharing_without_venue": bad.social.outing.stage="sharing"
			"guiding_without_venue": bad.social.outing.guiding=true
			"unknown_kind": bad.social.outing.kind="sleep"
			"unknown_person": bad.social.outing.person="missing"
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"坏档原子拒绝 "+label)
	for version in range(1,21):
		var old: Dictionary=initial.duplicate(true);old.version=version
		if version>=9: old.social.outing={"person":"a_friend","kind":"walk","stage":"walking","elapsed":12.0}
		if version<20: old.city_population.crossings.erase("office")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"旧v%d真实JSON夹具兼容"%version)
		if version>=9: check(not game.social.outing.has("venue") and game.social.outing.stage=="walking","旧约定恢复时不偷换地点或自动完成")
	fixture(540)
	game.career.employer="a"
	game.advance_time(Payroll.PERIOD*2)
	check(game.payroll.payments.size()==2 and game.payroll.balance==(Payroll.PERIOD*2-540)*Payroll.CENTS_PER_MINUTE,"跨发薪日只结算实际应得工资")
	var paid := SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(paid))) and game.payroll.payments.size()==2,"读档不重复发薪")
	check(not game.career.facts.has("output_one") and game.city_life.result=="","时间推进不代做工作或完成活动")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.persistence_enabled,"测试不捕获鼠标、不写玩家存档")
	FileAccess.open("res://build/c3h/after.json",FileAccess.WRITE).store_string(JSON.stringify(observations,"\t")+"\n")
	game.queue_free();await process_frame
	print("CITY_DAY_CYCLE_TEST failures=",failures," rest_cases=7 legacy_versions=20 malformed_cases=5")
	quit(failures)

extends SceneTree

var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	var life: CityLife=game.city_life
	var walk: CityStoryWalk=life.walk
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from-route="):
			var loaded := SaveGame.read(argument.trim_prefix("--from-route="),game)
			check(not loaded.is_empty() and SaveGame.restore(game,loaded),"独立进程读取真实路线完成档")
			# JSON numbers become floats; compare both complete states in the same wire representation.
			var restored: Dictionary=JSON.parse_string(JSON.stringify(walk.snapshot()))
			check(walk.stage==5 and (walk.board.visible or walk.album.visible) and restored==loaded.city_walk,"重启后公开内容及实体展陈一致")
			finish(); return
	var initial := SaveGame.snapshot(game)
	check(SaveGame.valid(initial,game),"新v17空走访有效")
	life.method="paper"; life.prepared=true; life.joined=true; life.elapsed=18; life.result="paper"
	life.participants.assign(["resident_zhou_ning","resident_lin_qiao"])
	check(walk.start(CityStoryWalk.GUIDES[1]),"可以约林巧带路")
	var person := walk.person_for(walk.partner)
	# Deliberate boundary fixtures; natural travel is checked by city_story_walk_test.
	walk.stage=2; walk.meeting=false; walk.notes.assign(["daily"]); walk.authors.assign([CityStoryWalk.GUIDES[0]])
	var file := "user://city-story-save-test.json"
	check(SaveGame.write(game,file)==OK,"中途走访实际写盘")
	var saved := SaveGame.read(file,game)
	walk.restore({})
	check(SaveGame.restore(game,saved) and walk.partner==person.stable_id and walk.authors[0]==CityStoryWalk.GUIDES[0],"恢复当前带路人及不同的原口述者")
	for corruption in ["missing","schema","stage","fraction","notes","order","author","partner","bool","day","early","source","many","meeting","last_author"]:
		var bad := saved.duplicate(true)
		match corruption:
			"missing": bad.erase("city_walk")
			"schema": bad.city_walk.schema=2
			"stage": bad.city_walk.stage=6
			"fraction": bad.city_walk.stage=2.5
			"notes": bad.city_walk.notes=[]
			"order": bad.city_walk.notes=["wall"]
			"author": bad.city_walk.authors=["resident_unknown"]
			"partner": bad.city_walk.partner="resident_unknown"
			"bool": bad.city_walk.paused=1
			"day": bad.city_walk.ready_day=0
			"early","last_author","meeting":
				bad.city_walk.stage=5; bad.city_walk.notes=["daily","named","album"]; bad.city_walk.authors=[person.stable_id,person.stable_id,person.stable_id]; bad.city_walk.ready_day=1
				if corruption!="early": bad.payroll.minute=1980
				if corruption=="last_author": bad.city_walk.authors[2]=CityStoryWalk.GUIDES[0]
				if corruption=="meeting": bad.city_walk.meeting=true
			"source": bad.city_life=initial.city_life
			"many": bad.city_walk.authors.append(person.stable_id)
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"拒绝坏档并保持全世界 "+corruption)
	for version in range(1,17):
		var old := initial.duplicate(true)
		old.version=version; old.erase("city_walk")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))) and walk.stage==0,"旧v%d JSON初始化走访" % version)
	check(SaveGame.restore(game,saved),"恢复中途档测试中断")
	await frames(5)
	var before_notes := walk.notes.duplicate()
	person.fear=20
	await frames(2)
	check(walk.paused and walk.notes==before_notes,"危险自动暂停且不清除记录")
	walk.answer(person,"walk_resume")
	check(walk.paused,"仍害怕时不能继续")
	person.fear=0
	game.payroll.minute=1200
	walk.answer(person,"walk_resume")
	check(walk.paused,"闭馆不能继续")
	game.payroll.minute=540
	walk.answer(person,"walk_resume")
	check(not walk.paused and walk.notes==before_notes,"开馆恢复同一地点和笔记")
	game.player.position=Vector3(55,0,58)
	walk.answer(person,"walk_note_named")
	check(walk.stage==2 and walk.notes==before_notes,"远处不能记下下一段")
	person.hp=0; person.state="dead"; person.route.clear(); person.crossing=""
	await frames(2)
	check(walk.paused and person.hp==0,"死亡保留且暂停")
	check(walk.target()==life.point_for("notice") and walk.status_text().contains("无法同行"),"无法同行时引导到公告而不是要求与死者交谈")
	check(walk.start(CityStoryWalk.GUIDES[0]) and walk.meeting and walk.notes==before_notes and person.hp==0,"换人重新实际会合，不复活或重写原记录")
	var guide := walk.person_for(walk.partner)
	guide.crossing="market"
	check(not walk.waits(guide),"即使玩家远离也不能在车道等候")
	guide.crossing=""
	# Completed alternative intentionally bypasses travel to test display and repeat effects.
	walk.stage=5; walk.meeting=false; walk.paused=false; walk.ready_day=1
	walk.notes.assign(["daily","named","album"]); walk.authors.assign([guide.stable_id,guide.stable_id,guide.stable_id])
	game.payroll.advance(1980-game.payroll.minute,game.career.employer)
	walk.sync_scene()
	check(walk.album.visible and not walk.board.visible and walk.exhibit_text().contains("梁伯") and walk.exhibit_text().contains("普通的相遇"),"另一选择形成署名生活图册")
	check(life.resident_line(guide).contains("我的话") and not life.resident_line(game.population.residents[1]).contains("我的话"),"实际口述者保留共同经历，未参加者不冒认")
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.social.meet(npc)
	game.social.handle("people_chat",npc)
	check(game.conversation.choices[0][1]=="people_story_walk","同事实际聊天入口可谈走访")
	game.social.handle("people_story_walk",npc)
	var memory: Dictionary=game.social.state(npc).duplicate(true)
	var affinity: int=npc.affinity
	game.social.handle("people_story_walk",npc)
	check(game.social.state(npc)==memory and npc.affinity==affinity,"交流一次记忆，不重复刷关系")
	check(game.career.employer=="" and game.payroll.balance==0,"没有职业或金钱奖励")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) and walk.album.visible,"图册分支与关系JSON恢复")
	game.close_interaction()
	for id in ["city-walk","city-clear"]:
		game.panels.show_page("city")
		for i in range(4): await process_frame
		var button: Button=game.panels.view.buttons[id]
		game.panels.view.scroll.ensure_control_visible(button)
		for i in range(4): await process_frame
		for pressed in [true,false]:
			var click := InputEventMouseButton.new()
			click.position=button.get_global_rect().get_center(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=pressed
			root.push_input(click,true)
		check(walk.guiding==(id=="city-walk") and game.panels.page=="" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"真实地图点击导航/返回职业目标 "+id)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	finish()

func finish() -> void:
	print("CITY_STORY_SAVE_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

extends "res://tests/city_bookshop_test.gd"

func walk_to(target: Vector3) -> bool:
	game.close_interaction()
	var stalled := 0
	var detour := 0
	var turn := 0.0
	for i in range(1800):
		var offset: Vector3=target-game.player.position
		offset.y=0
		if offset.length()<.22:
			press("forward",false)
			await frames(3)
			return true
		if stalled>=30:
			var colliders: Array[String]=[]
			for index in range(game.player.get_slide_collision_count()):
				var contact: KinematicCollision3D=game.player.get_slide_collision(index)
				if absf(contact.get_normal().y)<.5: colliders.append(str(contact.get_collider().name))
			print("STORY_WALK_PLAYER_DETOUR blockers=",colliders)
			turn=1.1 if turn<=0 else -1.1
			detour=40; stalled=0
		game.player.yaw=atan2(-offset.x,-offset.z)+(turn if detour>0 else 0.0)
		detour=maxi(0,detour-1)
		var before: Vector3=game.player.position
		press("forward",true)
		await physics_frame
		stalled=stalled+1 if game.player.position.distance_to(before)<.004 else 0
	press("forward",false)
	check(false,"真实输入绕行后仍未抵达 "+str(target)+" actual="+str(game.player.position))
	return false

func talk_action(person: CityResident,action: String) -> bool:
	if not await walk_to(person.position+Vector3(0,0,1.35)): return false
	var direction: Vector3=person.position-game.player.position
	game.player.yaw=atan2(-direction.x,-direction.z)
	await frames(3)
	key(KEY_E)
	check(game.speaker==person,"E实际交谈带路人，actual="+str(game.speaker))
	if game.speaker!=person: return false
	var index := -1
	for i in range(game.conversation.choices.size()):
		if game.conversation.choices[i][1]==action: index=i
	check(index>=0,"实际选项存在 "+action+" "+str(game.conversation))
	if index<0: return false
	key(KEY_1+index)
	return true

func follow(person: CityResident) -> bool:
	game.close_interaction()
	var walk: CityStoryWalk=game.city_life.walk
	var travelled := 0.0
	var previous := person.position
	var crossed: Array[String]=[]
	for i in range(24000):
		if walk.at_stop(person):
			press("forward",false)
			await frames(3)
			print("STORY_WALK_ARRIVED stage=",walk.stage," metres=",travelled," crossed=",crossed)
			return true
		var offset: Vector3=person.position-game.player.position
		offset.y=0
		if offset.length()>2.1:
			game.player.yaw=atan2(-offset.x,-offset.z)
			press("forward",true)
		else: press("forward",false)
		await physics_frame
		travelled+=person.position.distance_to(previous)
		previous=person.position
		if person.crossing!="" and not person.crossing in crossed: crossed.append(person.crossing)
	press("forward",false)
	check(false,"同行未到达 stage="+str(walk.stage)+" player="+str(game.player.position)+" person="+str(person.snapshot()))
	return false

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var life: CityLife=game.city_life
	var walk: CityStoryWalk=life.walk
	var alternative := "--lin-qiao" in OS.get_cmdline_user_args()
	var selected := 1 if alternative else 0
	var theme := "daily" if alternative else "work"
	var credit := "named" if alternative else "anonymous"
	var format := "album" if alternative else "wall"
	var prefix := "lin-qiao-" if alternative else ""
	DirAccess.make_dir_recursive_absolute("res://build/c3c")
	# Prior sharing is a fixture; the following outing uses live residents and real input.
	life.method="paper"; life.prepared=true; life.joined=true; life.elapsed=18; life.result="paper"
	life.participants.assign(["resident_zhou_ning","resident_lin_qiao"])
	game.player.position=Vector3(-50,0,42)
	await frames(3)
	await use_point("notice",selected)
	check(walk.stage==1 and walk.meeting and walk.partner==CityStoryWalk.GUIDES[selected],"真实公告约带路人，尚未取得记录")
	var person := walk.person_for(walk.partner)
	for i in range(12000):
		await physics_frame
		if person.route.is_empty() and person.position.distance_to(CityPopulation.POINTS.bookshop_entry)<1.3: break
	check(person.position.distance_to(CityPopulation.POINTS.bookshop_entry)<1.3,"居民实际走到书屋会合")
	if not await walk_to(person.position+Vector3(0,0,1.8)): finish(); return
	if not await talk_action(person,"walk_depart"): finish(); return
	check(not walk.meeting and walk.notes.is_empty(),"见面出发不自动完成走访")
	# Remain at the doorstep: guide advances only to a safe waiting distance.
	await frames(700)
	check(person.position.distance_to(game.player.position)<8 and person.state=="waiting" and person.crossing=="","落后时带路人在路边等待")
	game.panels.show_page("city")
	var held := person.position
	await frames(60)
	check(person.position==held,"地图暂停实际同行")
	game.panels.show_page("")
	if not await follow(person): finish(); return
	check(SaveGame.write(game,"res://build/c3c/"+prefix+"market.json")==OK,"保存真实广场到场取证点")
	if not await talk_action(person,"walk_note_"+theme): finish(); return
	check(walk.stage==2 and walk.notes==[theme] and walk.authors==[person.stable_id],"广场实到记录主题及口述身份")
	var mid := JSON.parse_string(JSON.stringify(SaveGame.snapshot(game))) as Dictionary
	check(SaveGame.restore(game,mid),"两地点之间JSON恢复")
	await frames(6)
	if not await follow(person): finish(); return
	check(SaveGame.write(game,"res://build/c3c/"+prefix+"seaside.json")==OK,"保存真实海边到场取证点")
	if not await talk_action(person,"walk_note_"+credit): finish(); return
	check(walk.stage==3 and walk.notes[1]==credit,"海边实际交谈选择署名方式")
	if not await follow(person): finish(); return
	if not await talk_action(person,"walk_note_"+format): finish(); return
	check(walk.stage==4 and not walk.board.visible and not walk.album.visible and walk.ready_day==1,"回书屋整理后等待次日，未提前生成展览")
	await walk_to(Vector3(-48.7,0,36))
	await use_point("walk",0)
	check(walk.stage==4,"当天不能发布次日展陈")
	game.close_interaction()
	for point in [Vector3(-52,0,35),Vector3(-52,0,43),Vector3(-56,0,52),Vector3(-64,0,58),Vector3(0,0,58),Vector3(0,0,18)]:
		if not await walk_to(point): finish(); return
	var rest: Node3D
	for station in game.stations:
		if station.stable_id=="rest": rest=station
	if not await walk_to(rest.position+Vector3(0,0,1.5)): finish(); return
	var direction: Vector3=rest.position-game.player.position
	game.player.yaw=atan2(-direction.x,-direction.z)
	await frames(3)
	key(KEY_E)
	var rest_index := -1
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]=="rest_day": rest_index=i
	check(game.speaker==rest and rest_index>=0,"实际公交站提供自愿休息一天")
	if rest_index<0: finish(); return
	key(KEY_1+rest_index)
	for point in [Vector3(0,0,18),Vector3(0,0,58),Vector3(-64,0,58),Vector3(-56,0,52),Vector3(-52,0,43),Vector3(-52,0,35),Vector3(-48.7,0,36)]:
		if not await walk_to(point): finish(); return
	await frames(5)
	await use_point("walk",0)
	check(walk.stage==5 and walk.board.visible==not alternative and walk.album.visible==alternative,"次日开馆实际E布置所选展陈")
	if alternative: check(walk.exhibit_text().contains("普通的相遇") and walk.exhibit_text().contains("林巧") and walk.exhibit_text().contains("安静"),"图册公开日常主题、实际口述者和相应原话")
	else: check(walk.exhibit_text().contains("工作的人") and walk.exhibit_text().contains("一位街区邻居") and not walk.exhibit_text().contains("梁伯"),"墙展对应主题且不泄露匿名姓名")
	check(game.career.facts.has("city_story_walk") and game.career.employer=="" and game.payroll.balance==0,"完成经历不替代就业或工资")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) and walk.board.visible==not alternative and walk.album.visible==alternative,"完整展陈JSON恢复可见")
	DirAccess.make_dir_recursive_absolute("res://build/c3c")
	check(SaveGame.write(game,"res://build/c3c/"+prefix+"walk-completed.json")==OK,"实际路线完成写盘供独立进程恢复")
	finish()

func finish() -> void:
	print("CITY_STORY_WALK_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

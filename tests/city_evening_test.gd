extends "res://tests/city_bookshop_test.gd"
const Driver=preload("res://tests/scene_driver.gd")

var journeys := []

func arrive_all(label: String,targets: Dictionary,save_midway: bool=false) -> bool:
	var tracking := {}
	var saved_crossing := false
	for id in targets:
		var npc: OfficeNPC=game.npc_for_role(id)
		tracking[id]={"previous":npc.position,"metres":0.0,"max_step":0.0,"road_frames":0,"overlaps":0}
	for frame in range(24000):
		await physics_frame
		var arrived := true
		for id in targets:
			var npc: OfficeNPC=game.npc_for_role(id)
			var sample: Dictionary=tracking[id]
			var step: float=npc.position.distance_to(sample.previous)
			sample.metres+=step; sample.max_step=maxf(sample.max_step,step); sample.previous=npc.position
			if npc.position.distance_to(targets[id])>.65: arrived=false
			if CityFootRoutes.crossing_at(npc.position)!="":
				sample.road_frames+=1
			for vehicle in [game.transit.bus]+game.driving.cars:
				var local: Vector3=vehicle.to_local(npc.position)
				if absf(local.x)<1.2 and absf(local.z)<(3.6 if vehicle==game.transit.bus else 2.2)+.25: sample.overlaps+=1
		if label=="first" and not saved_crossing:
			for id in targets:
				var npc: OfficeNPC=game.npc_for_role(id)
				if CityFootRoutes.crossing_at(npc.position)=="office" and npc.position.z>6 and npc.position.z<12:
					var before := npc.position
					var file := "res://build/c3g/office-crossing.json"
					check(SaveGame.write(game,file)==OK and SaveGame.restore(game,SaveGame.read(file,game)),"公司过街中实际JSON恢复")
					check(npc.position.distance_to(before)<.001,"过街读档保持实际位置")
					saved_crossing=true
					break
		if frame==600 and save_midway:
			var path := "res://build/c3g/"+label+"-mid.json"
			check(SaveGame.write(game,path)==OK,"自主行程实际写盘")
			check(SaveGame.restore(game,SaveGame.read(path,game)),"自主行程实际JSON恢复")
			for id in targets: tracking[id].previous=game.npc_for_role(id).position
		if arrived:
			if label=="first": check(saved_crossing,"确实经过公司斑马线且途中保存恢复")
			for id in targets:
				var sample: Dictionary=tracking[id]
				sample.erase("previous"); sample["person"]=id; sample["stage"]=label
				journeys.append(sample)
				check(sample.max_step<.1,"自主行程无传送 "+id+" "+label)
				check(sample.overlaps==0,"自主过街与实际车流无重叠 "+id+" "+label)
			print("EVENING_ARRIVED ",label," ",JSON.stringify(tracking))
			return true
	check(false,"自主行程未到达 "+label+" targets="+str(targets)+" actual="+str(game.npcs.map(func(n): return [n.role_id,n.position,n.route,n.care_state])))
	return false

func approach(npc: OfficeNPC) -> bool:
	game.close_interaction()
	var target: Vector3=npc.position+Vector3(0,0,1.7)
	var path: PackedVector3Array=game.walking.route(game.player.position,target,null,game.player)
	if path.is_empty(): return false
	for point in path:
		# The last public graph anchor may be occupied by the person we approach.
		# Aim at the nearby free conversation spot once its final segment is clear.
		if point.distance_to(npc.position)<1.1 and game.walking.clear_segment(game.player.position,target): break
		if not await move_around_people(point): return false
	if not await move_around_people(target): return false
	var direction: Vector3=npc.position-game.player.position
	game.player.yaw=atan2(-direction.x,-direction.z)
	await frames(8)
	return game.nearest()==npc

func move_around_people(target: Vector3) -> bool:
	for frame in range(3600):
		var offset: Vector3=target-game.player.position
		offset.y=0
		if offset.length()<.22:
			press("forward",false); await frames(3); return true
		var direction := Driver.steer_around_people(game,offset)
		game.player.yaw=atan2(-direction.x,-direction.z)
		press("forward",true)
		await physics_frame
	press("forward",false)
	check(false,"绕行未到达 "+str(target)+" actual="+str(game.player.position))
	return false

func choose_action(action: String) -> bool:
	var choices: Array=game.conversation.get("choices",[])
	for i in range(choices.size()):
		if choices[i][1]==action:
			key(KEY_1+i)
			return true
	check(false,"真实对话选项缺失 "+action+" "+str(game.conversation))
	return false

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3g")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.set_process(false)
	var initial := SaveGame.snapshot(game)
	game.payroll.minute=1140
	var targets := {}
	for id in CityEvening.PLANS: targets[id]=CityEvening.destination(game.npc_for_role(id))
	if not await arrive_all("first",targets,true): game.queue_free(); await process_frame; quit(failures); return
	check(game.social.outing.is_empty(),"无人邀请也会自主外出")
	for id in targets: check(CityEvening.at_place(game.npc_for_role(id))!="","只在实际到场提供偶遇 "+id)
	check(SaveGame.write(game,"res://build/c3g/first-arrived.json")==OK,"保存自然到场场面")
	var arrived := SaveGame.snapshot(game)
	for item in [["a_friend","people_listen"],["a_group","people_boundary"],["b_friend","people_city_quiet"]]:
		if not await approach(game.npc_for_role(item[0])): check(false,"真实步行接近 "+item[0]); break
		var npc: OfficeNPC=game.npc_for_role(item[0])
		var place := CityEvening.at_place(npc)
		key(KEY_E)
		check(game.speaker==npc and game.conversation.text==CityEvening.greeting(npc),"真实E进入公共偶遇 "+item[0])
		if not choose_action("people_evening_join"): break
		check(CityOuting.at_place(game.social,npc),"原地加入不伪造到场")
		if not choose_action("people_share"): break
		var career := SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)
		var balance: int=game.payroll.balance
		if not choose_action(item[1]): break
		check(game.social.outing.is_empty() and game.social.state(npc).city.has(place),"偶遇形成真实地点经历")
		check(SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)==career and game.payroll.balance==balance,"偶遇不发工资或职业成果")
		game.close_interaction()
		await frames(45)
		check(CityEvening.at_place(npc)==place,"交谈结束继续自己的公共活动")
		if item[0] in ["a_friend","b_friend"]:
			game.career.employer=npc.company; game.career.facts["brief"]=true; game.career.facts["welcome_b"]=true
			game.social.tick(1)
			check(game.social.outing.is_empty(),"完成相处当天不立即再次自动邀请")
			game.speaker=npc
			game.social.handle("people_invite_walk",npc)
			check(game.conversation.choices.any(func(c): return c[1]=="people_city_go_garden"),"仍可主动邀请")
			game.close_interaction()
			game.career.employer=""
	check(SaveGame.write(game,"res://build/c3g/encounters.json")==OK,"三种偶遇结果实际写盘")
	check(SaveGame.restore(game,SaveGame.read("res://build/c3g/encounters.json",game)),"偶遇结果恢复")
	game.payroll.minute=1200
	for id in targets: targets[id]=CityEvening.destination(game.npc_for_role(id))
	if not await arrive_all("second",targets,true): game.queue_free(); await process_frame; quit(failures); return
	check(SaveGame.write(game,"res://build/c3g/second-arrived.json")==OK,"保存第二公共场所")
	game.payroll.minute=1260
	for id in targets: targets[id]=CityEvening.FOYERS[id]
	if not await arrive_all("return",targets): game.queue_free(); await process_frame; quit(failures); return
	game.payroll.minute=1980
	for id in targets: targets[id]=game.npc_for_role(id).home
	if not await arrive_all("work",targets): game.queue_free(); await process_frame; quit(failures); return
	check(SaveGame.restore(game,arrived),"优先级检查恢复真实到场世界")
	await frames(8)
	var friend: OfficeNPC=game.npc_for_role("b_friend")
	game.career.b_event="negotiating"
	check(CityEvening.at_place(friend)=="","工作协商优先于公共偶遇")
	check(await arrive_all("work-follow",{"b_friend":game.player.position+Vector3(1.5,0,0)}),"晚间真实返回处理工作协商")
	check(SaveGame.restore(game,arrived),"危险检查恢复")
	await frames(8)
	friend=game.npc_for_role("a_friend")
	friend.hit(Vector3.FORWARD,200,7791,true)
	await frames(10)
	check(friend.dead and CityEvening.at_place(friend)=="","致命伤害不被日程清除")
	game.payroll.minute=1980
	await frames(60)
	check(friend.dead and friend.hp==0,"次日不复活")
	check(SaveGame.restore(game,initial),"最终恢复原世界")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"自动测试不捕获鼠标")
	FileAccess.open("res://build/c3g/journeys.json",FileAccess.WRITE).store_string(JSON.stringify(journeys,"\t")+"\n")
	print("CITY_EVENING_TEST failures=",failures," routes=",journeys.size())
	game.queue_free(); await process_frame; quit(failures)

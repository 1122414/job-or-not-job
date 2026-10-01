extends SceneTree

var failures := 0
var game: Node3D
var outcomes := {}
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true)
func press(name: String,pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action=name; event.pressed=pressed
	Input.parse_input_event(event)

func walk_to(target: Vector3) -> bool:
	game.close_interaction()
	for i in range(1800):
		var offset: Vector3=target-game.player.position
		offset.y=0
		if offset.length()<.22:
			press("forward",false)
			await frames(3)
			return true
		game.player.yaw=atan2(-offset.x,-offset.z)
		press("forward",true)
		await physics_frame
	press("forward",false)
	check(false,"真实行走未到达 "+str(target)+" actual="+str(game.player.position))
	return false

func use_point(id: String,index: int) -> void:
	var point: CityActivityPoint=game.city_life.point_for(id)
	var offset: Vector3=point.position-game.player.position
	game.player.yaw=atan2(-offset.x,-offset.z)
	await frames(3)
	key(KEY_E)
	check(game.speaker==point,"真实E交互到 "+id+" actual="+str(game.speaker))
	if game.speaker==point: key(KEY_1+index)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var life: CityLife=game.city_life
	var original := SaveGame.snapshot(game)
	check(SaveGame.valid(original,game),"新世界v15有效")
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"公共/室内路段扫掠 "+str(link))
	for method in CityLife.METHODS:
		check(SaveGame.restore(game,original.duplicate(true)),"重置独立方案世界")
		await frames(6)
		# Begin at the public doorstep; every subsequent venue transition uses real movement.
		game.player.position=Vector3(-52,0,43)
		await frames(3)
		await walk_to(Vector3(-50,0,42))
		await use_point("notice",CityLife.METHODS.keys().find(method))
		check(life.method==method and not life.prepared,"公告只选择处理方式，不直接完成 "+method)
		await frames(120)
		check(life.elapsed==0 and life.result=="","没有现场准备不完成活动 "+method)
		if method=="garden":
			for p in [Vector3(-52,0,43),Vector3(-56,0,52),Vector3(-64,0,58),Vector3(0,0,58),Vector3(38,0,55.2)]:
				if not await walk_to(p): break
			await use_point("garden",0)
		else:
			if not await walk_to(Vector3(-52,0,35)): break
			if method=="screen":
				await walk_to(Vector3(-49.2,0,29.7))
				await use_point("screen",0)
				check(life.checked and not life.prepared,"先检查故障，不直接准备完成")
				key(KEY_1)
			else:
				await walk_to(Vector3(-55.7,0,30.5))
				await use_point("paper",0)
		check(life.prepared,"现场准备完成 "+method)
		await walk_to(life.center()+Vector3(0,0,3))
		var first_join := -1
		for i in range(18000):
			await physics_frame
			if life.elapsed>0: first_join=i; break
		check(first_join>=0,"居民自然行走到活动现场 "+method+" residents="+str(game.population.snapshot().people))
		if first_join<0: break
		var partial := SaveGame.snapshot(game)
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(partial))),"分享开始后实际JSON恢复")
		await frames(3)
		game.panels.show_page("city")
		var paused := life.snapshot()
		await frames(20)
		check(paused==life.snapshot(),"地图暂停冻结活动进度")
		game.panels.show_page("")
		# Boundary fixture: leaving the site cannot finish an unattended scene.
		var player_position: Vector3=game.player.position
		game.player.position=Vector3(0,0,18)
		var elapsed_before := life.elapsed
		await frames(180)
		check(life.elapsed==elapsed_before and life.result=="","离场停止分享进度 "+method)
		if method!="garden":
			game.player.position=Vector3(-59,0,31)
			await frames(30)
			check(life.elapsed==elapsed_before and life.caption()=="","隔墙站在室外不能算参与或显示现场字幕")
		game.player.position=player_position
		var victim: CityResident=game.population.residents[CityLife.AUDIENCE[0]]
		game.player.position=victim.position+Vector3(0,0,.75)
		game.player.yaw=0
		game.player.cooldown=0
		var attack := InputEventAction.new()
		attack.action="attack"; attack.pressed=true
		root.push_input(attack,true)
		attack=attack.duplicate(); attack.pressed=false
		root.push_input(attack,true)
		for frame in range(34):
			await physics_frame
			if victim.hits>0: break
		var elapsed_at_hit := life.elapsed
		check(victim.hits>0 and victim.fear>0,"真实攻击使参加者受伤避险")
		await frames(120)
		check(life.elapsed==elapsed_at_hit,"实际命中与目击避险后现场分享停止推进")
		game.player.position=player_position
		for index in CityLife.AUDIENCE: game.population.residents[index].fear=0
		for i in range(6000):
			await physics_frame
			if life.result!="": break
		check(life.result==method and life.participants.size()>=2,"完成三条现场路线 "+method)
		check(game.career.facts.has("city_bookshop_shared") and game.career.employer=="" and game.payroll.balance==0,"只记录经历，不替玩家入职或添加工资")
		outcomes[method]={"wait_frames":first_join,"participants":life.participants.duplicate(),"elapsed":life.elapsed}
		if method!="garden":
			await walk_to(Vector3(-52,0,35))
			await walk_to(Vector3(-52,0,43))
			check(game.player.position.z>42,"活动结束可实走离开书屋")
		game.payroll.minute=1200
		await frames(3600)
		for person in game.population.residents:
			check(not (person.position.x> -58.3 and person.position.x< -45.7 and person.position.z>25.7 and person.position.z<38.4),"闭馆居民实际离开室内 "+person.stable_id)
		check(not life.is_open(),"20时闭馆")
		game.payroll.minute=539
		check(not life.is_open(),"8:59尚未营业")
		game.payroll.minute=540
		check(life.is_open(),"9时重新开放")
	print("CITY_BOOKSHOP_TEST failures=",failures," outcomes=",outcomes)
	game.queue_free()
	await process_frame
	quit(failures)

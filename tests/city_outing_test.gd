extends SceneTree
const Driver=preload("res://tests/scene_driver.gd")
var failures := 0
var game: Node3D
var records: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame

func follow(npc: OfficeNPC,target: Vector3,label: String) -> bool:
	var path := PackedVector3Array()
	var previous := npc.position
	var metres := 0.0
	var maximum := 0.0
	var road_frames := 0
	var waiting := 0
	var overlaps := 0
	for frame in range(18000):
		var step := npc.position.distance_to(previous)
		metres+=step; maximum=maxf(maximum,step); previous=npc.position
		if CityFootRoutes.crossing_at(npc.position)!="":
			road_frames+=1
			for vehicle in [game.transit.bus]+game.driving.cars:
				var local: Vector3=vehicle.to_local(npc.position)
				var half_length := 3.6 if vehicle==game.transit.bus else 2.2
				if absf(local.x)<1.2 and absf(local.z)<half_length+.25: overlaps+=1
		if npc.street_request!="": waiting+=1
		var distance: float=game.player.position.distance_to(npc.position)
		if npc.position.distance_to(target)<.7 and distance<2.8:
			Input.action_release("forward")
			records.append({"route":label,"metres":metres,"max_step":maximum,"road_frames":road_frames,"request_frames":waiting,"vehicle_overlap_samples":overlaps})
			print("OUTING_ROUTE ",records[-1])
			check(maximum<.1,"自然同行没有瞬移 "+label)
			check(overlaps==0,"实际车流与同行者不重叠 "+label)
			return true
		if frame%30==0: path=game.walking.route(game.player.position,npc.position,null,game.player)
		while not path.is_empty() and game.player.position.distance_to(path[0])<.15: path.remove_at(0)
		if distance>1.65 and not path.is_empty():
			var offset: Vector3=path[0]-game.player.position
			game.player.yaw=atan2(-offset.x,-offset.z)
			Input.action_press("forward")
		else: Input.action_release("forward")
		if frame==600:
			var file := "res://build/c3e/"+label+"-mid.json"
			check(SaveGame.write(game,file)==OK,"真实同行中写盘")
			var loaded := SaveGame.read(file,game)
			check(not loaded.is_empty() and SaveGame.restore(game,loaded),"真实同行中JSON恢复")
			previous=npc.position
		await physics_frame
	Input.action_release("forward")
	push_error("同行超时 "+label+" player="+str(game.player.position)+" npc="+str(npc.position)+" target="+str(target)+" route="+str(npc.route))
	return false

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3e")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.set_process(false)
	var initial := SaveGame.snapshot(game)
	var cases := [["a_friend","bookshop","people_listen"],["b_friend","garden","people_boundary"],["a_friend","waterfront","people_city_quiet"]]
	for item in cases:
		check(SaveGame.restore(game,initial),"每条路线从独立初始状态开始")
		game.payroll.minute=1110
		await frames(8)
		var npc: OfficeNPC=game.npc_for_role(item[0])
		var foyer := Vector3(-8,0,12) if npc.company=="a" else Vector3(8,0,12)
		check(await Driver.walk(self,game,foyer+Vector3(-1.5,0,0)),"玩家实际走到下班会合处 "+item[0]+" player="+str(game.player.position)+" npc="+str(npc.position))
		for i in range(1800):
			if npc.position.distance_to(foyer)<.7: break
			await physics_frame
		check(npc.position.distance_to(foyer)<.7,"同事实际离开工位")
		game.social.meet(npc)
		game.speaker=npc
		game.social.handle("people_invite_walk",npc)
		check(game.conversation.choices.any(func(c): return c[1]=="people_city_go_"+item[1]),"正常入口提供地点选择")
		game.social.handle("people_city_go_"+item[1],npc)
		check(game.social.outing.get("venue")==item[1],"接受实际地点")
		var target: Vector3=CityOuting.VENUES[item[1]][1]
		if not await follow(npc,target,item[0]+"-"+item[1]): failures+=1; break
		game.speaker=npc
		game.conversation=game.social.options(npc)
		check(game.conversation.choices[0][1]=="people_share","实际到场才可进入话题")
		game.choose(0)
		check(SaveGame.write(game,"res://build/c3e/"+item[1]+"-arrival.json")==OK,"实际到场档供图形复核")
		var money: int=game.payroll.balance
		var career := SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)
		game.social.handle(item[2],npc)
		check(game.social.outing.is_empty() and game.social.state(npc).city.has(item[1]),"回应形成地点记忆")
		check(game.payroll.balance==money and SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)==career,"同行不伪造工资或工作成果")
		game.social.handle("people_chat",npc)
		check(game.conversation.text.contains(CityOuting.VENUES[item[1]][0]),"后续交谈记得共同地点")
		game.close_interaction()
		if not await follow(npc,foyer,item[0]+"-"+item[1]+"-return"): failures+=1; break
		check(SaveGame.write(game,"res://build/c3e/"+item[1]+"-completed.json")==OK,"真实完成与返程档")
	FileAccess.open("res://build/c3e/routes.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t")+"\n")
	game.queue_free(); await process_frame
	print("CITY_OUTING_TEST failures=",failures)
	quit(failures)

extends SceneTree
var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.set_process(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from-route="):
			var saved := SaveGame.read(argument.trim_prefix("--from-route="),game)
			check(not saved.is_empty() and SaveGame.restore(game,saved),"独立进程重读真实同行档")
			check(JSON.stringify(SaveGame.snapshot(game).social)==JSON.stringify(saved.social),"人物经历和约定完整恢复")
			finish(); return
	var initial := SaveGame.snapshot(game)
	# The main path and the commons subdivision occupy the same corridor.
	# Check both directions across rounding boundaries, not just one waypoint.
	for i in range(100):
		var from := Vector3(-.00000001,-.004057,24+i*.1)
		var to := Vector3(-.505724,0,34.47178)
		for endpoints in [[from,to],[to,from]]:
			var route: PackedVector3Array=game.walking.route(endpoints[0],endpoints[1],null,game.player)
			while not route.is_empty() and endpoints[0].distance_to(route[0])<.15: route.remove_at(0)
			check(not route.is_empty() and (route[0].z-endpoints[0].z)*(endpoints[1].z-endpoints[0].z)>0,"重叠步道应朝目的地前进 %d" % i)
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.payroll.minute=1110
	game.social.meet(npc)
	# Boundary fixtures, independent of the six continuous routes in city_outing_test.
	npc.position=Vector3(42,0,54); game.player.position=Vector3(42,0,56)
	game.speaker=npc
	game.social.handle("people_city_go_garden",npc)
	check(game.social.outing.get("venue")=="garden","开始公共同行")
	game.social.handle("people_listen",npc)
	check(not game.social.state(npc).has("city"),"不能跳过现场话题结算")
	game.social.handle("people_share",npc)
	var file := "user://city-outing-save-test.json"
	check(SaveGame.write(game,file)==OK,"新同行状态实际写盘")
	var saved := SaveGame.read(file,game)
	check(SaveGame.restore(game,saved) and game.social.outing.stage=="sharing","恢复待回应现场")
	game.speaker=npc
	game.player.position=Vector3(0,0,18)
	game.social.handle("people_boundary",npc)
	check(not game.social.state(npc).has("city"),"远处不能回应结算")
	game.player.position=Vector3(42,0,56)
	game.social.handle("people_boundary",npc)
	check(game.social.state(npc).city.garden.reply=="boundary","表达边界记录对应回应")
	var affinity: int=npc.affinity
	game.social.handle("people_city_go_garden",npc); game.speaker=npc
	game.social.handle("people_share",npc); game.social.handle("people_listen",npc)
	check(npc.affinity==affinity and game.social.state(npc).city.garden.reply=="boundary","当天重复不刷关系、不覆盖首次经历")
	check(SaveGame.restore(game,saved),"回到正在同行的边界")
	game.social.handle("people_pause",npc)
	check(game.social.outing.stage=="paused" and game.social.npc_target(npc)==null,"暂缓保留地点且释放人物")
	game.social.handle("people_city_resume",npc)
	check(game.social.outing.stage=="walking","方便时继续原地点")
	game.social.outing.venue="bookshop"; game.payroll.minute=1200
	game.social.tick(.1)
	check(game.social.outing.stage=="paused","闭馆自动保留约定")
	game.social.handle("people_city_resume",npc)
	check(game.social.outing.stage=="paused","闭馆不可硬恢复")
	game.social.handle("people_city_menu",npc)
	check(not game.conversation.choices.any(func(c): return c[1]=="people_city_go_bookshop"),"闭馆正常入口提供户外替代")
	game.social.handle("people_decline",npc)
	check(game.social.outing.is_empty(),"拒绝结束约定")
	for label in ["venue","kind","stage","missing_venue","unknown_person","elapsed","guiding","legacy_guiding","city_type","city_place","reply","day","fraction_day"]:
		var bad: Dictionary=saved.duplicate(true)
		match label:
			"venue": bad.social.outing.venue="unknown"
			"kind": bad.social.outing.kind="lunch"
			"stage": bad.social.outing.stage="offered"
			"missing_venue": bad.social.outing.erase("venue")
			"unknown_person": bad.social.outing.person="unknown"
			"elapsed": bad.social.outing.elapsed=-1
			"guiding": bad.social.outing.guiding="yes"
			"legacy_guiding": bad.social.outing.erase("venue"); bad.social.outing.stage="walking"
			_:
				bad.social.people[npc.stable_id].city={"garden":{"day":0,"reply":"listen"}}
				var visits: Dictionary=bad.social.people[npc.stable_id].city
				if label=="city_type": bad.social.people[npc.stable_id].city=[]
				if label=="city_place": visits.unknown=visits.garden
				if label=="reply": visits.garden.reply="money"
				if label=="day": visits.garden.day=-1
				if label=="fraction_day": visits.garden.day=.5
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"坏档不部分改变世界 "+label)
	for version in range(1,19):
		var old := initial.duplicate(true); old.version=version
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"旧v%d完整JSON兼容" % version)
	check(SaveGame.restore(game,saved),"恢复有效地点状态检查阻断")
	game.speaker=npc
	game.player.position=Vector3(42,0,56)
	var wall := Shapes.solid(game,Vector3(3,2,.2),Vector3(42,1,55),Color.GRAY)
	await frames(3)
	game.social.handle("people_listen",npc)
	check(game.social.outing.stage=="sharing","距离足够但隔墙不能回应结算")
	wall.queue_free(); await frames(3)
	game.player.hp=0
	game.social.handle("people_listen",npc)
	check(game.social.outing.stage=="sharing","玩家倒地不结算")
	game.player.hp=100
	game.transit.riding=true
	game.social.handle("people_listen",npc)
	check(game.social.outing.stage=="sharing","玩家在车内不结算")
	game.transit.riding=false
	game.social.hurt(npc,game.next_action())
	check(game.social.outing.is_empty() and not game.social.willing(npc),"真实伤害关系入口终止私人同行，伤害记忆保留")
	check(SaveGame.restore(game,initial),"工作优先夹具从独立初态开始")
	var colleague: OfficeNPC=game.npc_for_role("b_friend")
	game.social.outing={"person":colleague.stable_id,"kind":"walk","venue":"waterfront","stage":"walking","elapsed":8.0}
	game.career.b_event="negotiating"
	check(game.social.npc_target(colleague)==null,"街区同行让已确认工作跟随优先")
	game.social.tick(2)
	check(game.social.outing.elapsed==8.0,"工作期间街区约定保留")
	game.career.b_event="negotiated"
	check(game.social.npc_target(colleague)!=null,"工作结束后可继续街区同行")
	check(SaveGame.restore(game,saved),"近处行人与同行者选择夹具")
	game.close_interaction()
	npc.position=Vector3(42,0,54); npc.set_physics_process(false)
	game.player.position=Vector3(40,0,54)
	var pedestrian: CityResident=game.population.residents[4]
	pedestrian.position=Vector3(40.6,0,54.5); pedestrian.set_physics_process(false)
	await frames(2)
	game.player.yaw=-PI/2
	check(game.nearest()==npc,"正面可见同行者不会被侧面近路人抢走交互")
	game.interact()
	check(game.speaker==npc,"实际E入口选择同行者")
	game.close_interaction()
	var offset: Vector3=pedestrian.position-game.player.position
	game.player.yaw=atan2(-offset.x,-offset.z)
	check(game.nearest()==pedestrian,"转向路人仍可主动选择路人")
	npc.set_physics_process(true); pedestrian.set_physics_process(true)
	check(SaveGame.restore(game,initial),"同行结束后绕开站立玩家的独立场景")
	await frames(4)
	game.payroll.minute=1110
	colleague.position=Vector3(42.18342,0,53.84516)
	colleague.route.clear(); colleague.route_clock=0
	game.player.position=Vector3(40.57299,0,54.13592)
	var standing_player: Vector3=game.player.position
	var return_start: Vector3=colleague.position
	var player_collisions := 0
	var maximum_step := 0.0
	var previous: Vector3=colleague.position
	for i in range(600):
		await physics_frame
		maximum_step=maxf(maximum_step,colleague.position.distance_to(previous)); previous=colleague.position
		for slide in range(colleague.get_slide_collision_count()):
			if colleague.get_slide_collision(slide).get_collider()==game.player: player_collisions+=1
	var return_distance := colleague.position.distance_to(return_start)
	print("OUTING_STANDING_PLAYER distance=",return_distance," contacts=",player_collisions," max_step=",maximum_step," npc=",colleague.position," player=",game.player.position)
	check(return_distance>5 and maximum_step<.1,"同事实际绕开站立玩家继续返程，无瞬移")
	check(Vector2(game.player.position.x-standing_player.x,game.player.position.z-standing_player.z).length()<.02,"绕行不移动或推走玩家")
	var old_walk := initial.duplicate(true); old_walk.version=18
	old_walk.social.outing={"person":npc.stable_id,"kind":"walk","stage":"walking","elapsed":12.0}
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old_walk))) and game.social.destination(npc,"walk")==Vector3(-5,0,12.8),"旧同行保留已约定的公交站目的地")
	finish()
func finish() -> void:
	game.queue_free(); await process_frame
	print("CITY_OUTING_SAVE_TEST failures=",failures)
	quit(failures)

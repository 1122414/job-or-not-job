extends SceneTree

var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		root.push_input(event,true)
func action(name: String) -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action=name
		event.pressed=pressed
		root.push_input(event,true)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.set_process(false)
	game.driving.set_physics_process(false)
	game.transit.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var population: CityPopulation=game.population
	var original := SaveGame.snapshot(game)
	check(SaveGame.valid(original,game),"v14初始居民世界有效")
	for person in population.residents: person.set_physics_process(false)
	var person: CityResident=population.residents[0]
	person.position=Vector3(0,0,58)
	person.from_node="center"
	person.destination="center"
	person.route.clear()
	person.state="activity"
	person.activity_left=1
	person.phase=population.time_phase()
	var witness: CityResident=population.residents[1]
	witness.position=Vector3(2,0,58)
	game.player.position=Vector3(0,0,60)
	game.player.yaw=0
	await frames(3)
	key(KEY_E)
	check(game.speaker==person and person.met and not game.conversation.is_empty(),"真实E近处居民交谈")
	key(KEY_1)
	check(person.conversations==1 and game.conversation.text.contains("斑马线"),"真实数字回应获得本地路线信息")
	key(KEY_1)
	check(game.speaker==null,"告别结束会话")
	person.set_physics_process(true)
	await frames(120)
	check(person.state=="walking" and person.position.distance_to(Vector3(0,0,58))>.5,"交谈后恢复原活动计时并离开")
	person.set_physics_process(false)
	person.position=Vector3(0,0,58)
	person.from_node="center"; person.route.clear(); person.crossing=""
	game.player.position=Vector3(0,0,58.75)
	await frames(3)
	action("attack")
	await frames(34)
	check(person.hp==88 and person.fear>0 and person.hits==1,"玩家攻击动作触发居民受伤与避险")
	check(witness.witnessed==1 and witness.fear>0,"附近居民目击危险后选择避险")
	for i in range(20):
		game.player.cooldown=0
		action("attack")
		await frames(34)
	check(person.hp==1 and person.down>0,"连续普通攻击最多使居民倒地")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))),"倒地与目击后果可以JSON恢复")
	person.fear=0
	person.down=0
	person.hp=100
	person.state="activity"
	person.position=Vector3(0,0,70)
	person.update_body()
	game.player.position=Vector3(0,0,72.8)
	var thrown: OfficeProp
	for prop in game.props:
		if prop.kind=="monitor": thrown=prop; break
	check(thrown!=null,"场景有可投掷重物")
	game.player.pick(thrown)
	await frames(15)
	check(thrown.position.z>60 and game.player.held==thrown,"物件带出旧办公室边界后仍由玩家持有")
	action("throw")
	await frames(45)
	check(person.hp<100,"真实投掷输入与飞行重物碰撞会伤及公共居民")
	game.player.position=Vector3(8,0,58)
	thrown.linear_velocity=Vector3.ZERO
	thrown.position=thrown.home
	person.hp=100; person.down=0; person.fear=0; person.state="activity"
	person.position=Vector3(0,0,58)
	var car: CityCar=game.driving.car_for("car_office")
	car.position=Vector3(0,0,65)
	car.rotation.y=0
	car.speed=17
	await frames(3)
	for i in range(12):
		car.drive(.1,1,0,false)
		await physics_frame
		if person.hp==0: break
	car.speed=0
	check(person.hp==0 and person.state=="dead","玩家车辆高速实际接触有致命后果")
	var saved := SaveGame.snapshot(game)
	var file := "user://city-residents-"+str(Time.get_ticks_usec())+".json"
	check(SaveGame.write(game,file)==OK,"包含居民与车辆后果的真实JSON写入")
	check(SaveGame.restore(game,SaveGame.read(file,game)),"真实JSON恢复居民和过街状态")
	person.set_physics_process(true)
	await frames(120)
	check(person.hp==0 and person.hits>0 and witness.witnessed>0,"恢复后死亡不复活、伤害与目击记忆保留")
	check(person.body.position.distance_to(Vector3(-.65,.28,0).rotated(Vector3.UP,person.visual.rotation.y))<.001,"倒地碰撞跟随人物朝向")
	person.set_physics_process(false)
	for pair in [["hp",NAN],["position",[0,5,58]],["state","unknown"],["route",["missing"]],["crossing","missing"],["fear",100],["journey",1.5]]:
		var invalid := saved.duplicate(true)
		invalid.city_population.people[person.stable_id][pair[0]]=pair[1]
		var before := population.snapshot()
		check(not SaveGame.restore(game,invalid) and before==population.snapshot(),"非法居民状态拒绝且不改变世界 "+pair[0])
	for change in ["missing_person","extra_person","missing_gate","bad_gate","open_without_people"]:
		var invalid := saved.duplicate(true)
		match change:
			"missing_person": invalid.city_population.people.erase(person.stable_id)
			"extra_person": invalid.city_population.people.unknown=person.snapshot()
			"missing_gate": invalid.city_population.crossings.erase("market")
			"bad_gate": invalid.city_population.crossings.market.remaining=-1
			"open_without_people": invalid.city_population.crossings.market={"people":false,"remaining":1,"opened":true}
		var before := population.snapshot()
		check(not SaveGame.restore(game,invalid) and before==population.snapshot(),"非法居民集合/过街状态拒绝且世界不变 "+change)
	for version in range(1,14):
		var legacy := original.duplicate(true)
		legacy.version=version
		legacy.erase("city_population")
		if version<13: legacy.erase("city_driving")
		if version<12: legacy.erase("city_transit")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(legacy))) and person.hp==100 and not person.met,"v%d旧JSON保留原世界并初始化居民" % version)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	print("CITY_RESIDENTS_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

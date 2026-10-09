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
		event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.set_process(false)
	game.transit.set_physics_process(false)
	game.driving.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for person in game.population.residents:
		person.set_physics_process(false)
		person.position=Vector3(26+person.index*2,0,24)
	var response: CityResponse=game.response
	var initial := SaveGame.snapshot(game)
	check(SaveGame.valid(initial,game),"v16初始世界有效")
	var person: CityResident=game.population.residents[2]
	person.position=Vector3(-76,0,58)
	person.from_node="west_in"; person.destination="market"; person.route.assign(["west_out","market"]); person.crossing="market"
	person.hit(Vector3.FORWARD,10,game.next_action())
	preload("res://tests/legacy_damage_fixture.gd").resident(game,person)
	person.set_physics_process(true)
	await frames(120)
	check(response.cases.is_empty(),"没有实际目击者时现场不会凭空报告")
	game.player.position=person.position+Vector3(0,0,1.8)
	game.player.yaw=0
	await frames(3)
	key(KEY_E)
	check(game.speaker==person and game.conversation.choices[0][1]=="response_report","真实E打开现场求助")
	key(KEY_1)
	check(response.cases.has(person.stable_id) and response.cases[person.stable_id].reporter=="player","真实数字选择报告现场")
	check(not response.report(person,"player") and response.sequence==1,"重复求助不创建多个小组或重复案件")
	game.player.position=Vector3(-65,0,64)
	var barrier := Shapes.solid(game,Vector3(70,2,.5),Vector3(0,1,64),Color.GRAY)
	await frames(240)
	check(response.cases[person.stable_id].phase=="approaching" and response.crew.position.z>64,"障碍存在时没有穿过屏障或传送到现场")
	barrier.queue_free()
	var carried := false
	var received := false
	var restored := false
	var pause_checked := false
	var max_step := 0.0
	var previous: Vector3=response.crew.position
	var before_hits := person.hits
	var file := "user://city-response-test.json"
	for i in range(16000):
		await physics_frame
		max_step=maxf(max_step,response.crew.position.distance_to(previous))
		previous=response.crew.position
		if response.cases[person.stable_id].phase=="assessing" and not pause_checked:
			var progress := response.elapsed
			game.panels.show_page("city")
			for j in range(20): await process_frame
			check(response.elapsed==progress,"地图暂停时现场进度停止")
			game.panels.show_page("")
			var bystander: CityResident=game.population.residents[1]
			bystander.position=response.crew.position+Vector3(4,0,0)
			bystander.hit(Vector3.FORWARD,1,game.next_action(),false)
			await frames(120)
			check(response.elapsed==progress,"危险仍在时暂缓评估")
			previous=response.crew.position
			pause_checked=true
		if response.carried(person):
			carried=true
			if not restored:
				check(SaveGame.write(game,file)==OK,"转运中的真实JSON写盘")
				var saved := SaveGame.read(file,game)
				check(not saved.is_empty() and SaveGame.restore(game,saved),"转运中的真实JSON恢复")
				check(response.carried(person) and person.hp==0 and person.hits==before_hits,"恢复后持续同一转运且不复活或清除伤害")
				previous=response.crew.position
				restored=true
		if response.resting(person): received=true; break
	check(carried and received and restored and pause_checked,"实际到场、评估、持续转运、接收全过程："+str(response.snapshot()))
	check(max_step<.04,"救助小组逐物理帧连续行走，不瞬移："+str(max_step))
	await frames(450)
	check(person.hp==0 and person.visible and person.position.distance_to(CityResponse.bay(person.index))<1 and person.crossing=="","死者仍可见地留在接收区，死亡与位置持续，路口身份已释放")
	check(game.player.test_move(Transform3D(Basis.IDENTITY,CityResponse.bay(person.index)+Vector3(1.6,0,0)),Vector3(-1.4,0,0)),"接收床和人员保留实体阻挡，不可穿行")
	check(not game.population.occupied("market") and not game.population.crossings.market.people,"身体和小组离开后路口恢复车辆通行")
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) and response.resting(person),"接收事实和停放位置JSON可恢复")
	check(SaveGame.restore(game,initial),"恢复独立目击场景")
	for resident in game.population.residents: resident.set_physics_process(false)
	person=game.population.residents[0]
	person.position=Vector3(16,0,69)
	person.state="activity"; person.route.clear(); person.crossing=""
	var witness: CityResident=game.population.residents[1]
	witness.position=Vector3(18,0,69)
	person.hit(Vector3.FORWARD,10,game.next_action(),false)
	check(response.cases.get(person.stable_id,{}).get("reporter")==witness.stable_id,"实际附近居民报告非致命现场")
	var second: CityResident=game.population.residents[3]
	second.position=Vector3(19,0,68)
	second.hit(Vector3.FORWARD,10,game.next_action())
	preload("res://tests/legacy_damage_fixture.gd").resident(game,second)
	check(response.cases.size()==2 and response.sequence==2,"两个现场保留独立队列")
	person.set_physics_process(true)
	var first_done := false
	var second_done := false
	for i in range(8000):
		await physics_frame
		if response.cases[person.stable_id].phase=="recovered": first_done=true
		if response.resting(second): second_done=true; break
	check(first_done and second_done and person.hp>0 and person.hits>0 and second.hp==0,"同一小组依次完成伤者与死者，结果和记忆不同")
	check(SaveGame.restore(game,initial),"恢复自行苏醒场景")
	person.position=Vector3(-94,0,58)
	person.from_node="market"; person.destination="market"; person.route.clear(); person.crossing=""
	person.hit(Vector3.FORWARD,10,game.next_action(),false)
	response.report(person,"player")
	person.set_physics_process(true)
	var unnecessary_transfer := false
	for i in range(1000):
		await physics_frame
		unnecessary_transfer=unnecessary_transfer or response.carried(person)
	check(person.available() and response.cases[person.stable_id].phase=="recovered" and not unnecessary_transfer,"远处伤者自行苏醒后取消转运，不搬走健康居民")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"全部交互与恢复始终保持鼠标可见")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	print("CITY_RESPONSE_TEST failures=",failures," carried=",carried," received=",received," max_step=",max_step," queued_cases=",response.sequence)
	game.queue_free()
	await process_frame
	quit(failures)

extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6): await physics_frame
	game.set_process(false)
	var original := SaveGame.snapshot(game)
	var response: CityResponse=game.response
	var file := "user://city-response-save.json"
	var person: CityResident=game.population.residents[0]
	person.hp=0; person.state="dead"; person.route.clear(); person.crossing=""
	response.report(person,"player")
	var queued := SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(queued))) and response.active=="","等待案件真实JSON恢复")
	response.active=person.stable_id
	for phase in ["approaching","assessing"]:
		response.cases[person.stable_id].phase=phase
		response.elapsed=2.5 if phase=="assessing" else 0.0
		response.plan(person.position+Vector3(0,0,2))
		if phase=="assessing":
			response.crew.position=person.position+Vector3(0,0,2)
			response.route.clear()
		check(SaveGame.write(game,file)==OK and SaveGame.restore(game,SaveGame.read(file,game)),"接近/评估状态实际写盘读取 "+phase)
		check(response.cases[person.stable_id].phase==phase and response.elapsed==(2.5 if phase=="assessing" else 0.0),"恢复阶段与现场计时 "+phase)
	response.cases[person.stable_id].phase="transporting"
	response.plan(CityResponse.bay(person.index))
	response.sync_person(person)
	check(SaveGame.write(game,file)==OK,"关联转运状态写盘")
	var saved := SaveGame.read(file,game)
	check(not saved.is_empty() and SaveGame.restore(game,saved),"关联转运状态读盘恢复")
	for corruption in ["missing","schema","unknown","phase","order","duplicate_order","reporter","active","second_worker","position","yaw","route","empty_route","wrong_bay","elapsed","patient_position","patient_crossing","received_alive","remote_assessment"]:
		var bad := saved.duplicate(true)
		var entry: Dictionary=bad.city_response.cases[person.stable_id]
		match corruption:
			"missing": bad.erase("city_response")
			"schema": bad.city_response.schema=2
			"unknown": bad.city_response.cases.unknown=entry.duplicate()
			"phase": entry.phase="resurrect"
			"order": entry.order=1.5
			"duplicate_order": bad.city_response.cases[game.population.residents[1].stable_id]=entry.duplicate()
			"reporter": entry.reporter="unknown"
			"active": bad.city_response.active="missing"
			"second_worker":
				bad.city_response.sequence=2
				bad.city_response.cases[game.population.residents[1].stable_id]={"phase":"approaching","reporter":"player","order":2,"helped":true}
			"position": bad.city_response.position=[2000,0,0]
			"yaw": bad.city_response.yaw=NAN
			"route": bad.city_response.route=[[0,9,0]]
			"empty_route": bad.city_response.route=[]
			"wrong_bay": bad.city_response.route[-1]=[0,0,0]
			"elapsed": bad.city_response.elapsed=-1
			"patient_position": bad.city_population.people[person.stable_id].position=[0,0,0]
			"patient_crossing": bad.city_population.people[person.stable_id].crossing="market"
			"received_alive":
				entry.phase="received"; bad.city_response.active=""
				bad.city_population.people[person.stable_id].hp=50
				bad.city_population.people[person.stable_id].state="activity"
			"remote_assessment": entry.phase="assessing"; bad.city_response.position=[0,0,0]
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and before==SaveGame.snapshot(game),"坏档拒绝且完整世界未部分修改 "+corruption)
	for version in range(1,16):
		var old := original.duplicate(true)
		old.version=version; old.erase("city_response")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))) and response.cases.is_empty() and response.crew.position==CityResponse.DEPOT,"v%d初始化服务且保留旧世界" % version)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	print("CITY_RESPONSE_SAVE_TEST failures=",failures," invalid_cases=19 legacy_versions=15")
	game.queue_free()
	await process_frame
	quit(failures)

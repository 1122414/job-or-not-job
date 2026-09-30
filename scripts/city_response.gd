class_name CityResponse
extends Node3D

const DEPOT := Vector3(16,0,72)
const PHASES := ["queued","approaching","assessing","transporting","received","recovered"]
var game: Node3D
var crew: CharacterBody3D
var helpers: Array[HumanVisual]=[]
var cases := {}
var active := ""
var sequence := 0
var route: Array[Vector3]=[]
var elapsed := 0.0
var quiet := 10.0
var blocked := false
var notice: Label3D
var beds: Array[Node3D]=[]

func _ready() -> void:
	name="CityResponse"
	build_station()
	crew=CharacterBody3D.new()
	crew.name="ResponseCrew"
	crew.collision_layer=1
	crew.collision_mask=3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.55
	capsule.height=1.8
	shape.shape=capsule
	shape.position.y=.9
	crew.add_child(shape)
	add_child(crew)
	crew.position=DEPOT
	Shapes.box(crew,Vector3(.65,.09,1.9),Vector3(0,.72,0),Color("537c80"))
	for side in [-1,1]:
		var helper := HumanVisual.new()
		helper.outfit="office"
		helper.personality="medic"
		helper.carrying=true
		crew.add_child(helper)
		helper.position.z=side*1.25
		helpers.append(helper)
	Shapes.label(crew,"街区救助",Vector3(0,2.3,0),24).pixel_size=.004

func build_station() -> void:
	Shapes.box(self,Vector3(16,.03,16),Vector3(16,0,82),Color("c4c7bb"))
	for wall in [[Vector3(.25,3.3,16),Vector3(8,1.65,82)],[Vector3(.25,3.3,16),Vector3(24,1.65,82)],[Vector3(16,3.3,.25),Vector3(16,1.65,90)],[Vector3(5,3.3,.25),Vector3(10.5,1.65,74)],[Vector3(5,3.3,.25),Vector3(21.5,1.65,74)]]:
		Shapes.solid(self,wall[0],wall[1],Color("a2b7b2"))
	Shapes.solid(self,Vector3(16,.2,16),Vector3(16,3.4,82),Color("688b85"))
	OfficeRooms.plaque(self,"街区应急接收站",Vector3(16,2.7,73.8),5)
	notice=Shapes.label(self,"救助人员待命",Vector3(16,2.05,73.7),26)
	notice.pixel_size=.0035
	for i in range(CityPopulation.PROFILES.size()):
		var bed := StaticBody3D.new()
		bed.collision_layer=0
		bed.collision_mask=0
		add_child(bed)
		bed.position=bay(i)
		Shapes.collider(bed,Vector3(.7,.7,1.95),Vector3(0,.35,0))
		Shapes.box(bed,Vector3(.7,.12,1.95),Vector3(0,.65,0),Color("687f85"))
		for x in [-.26,.26]:
			for z in [-.7,.7]: Shapes.box(bed,Vector3(.06,.6,.06),Vector3(x,.3,z),Color("687476"))
		bed.visible=false
		beds.append(bed)

static func bay(index: int) -> Vector3:
	return Vector3(11 if index%2==0 else 21,0,77.5+floori(index/2.0)*2.1)

func person_for(id: String) -> CityResident:
	for person in game.population.residents:
		if person.stable_id==id: return person
	return null

func pending(person: CityResident) -> bool:
	return cases.has(person.stable_id) and cases[person.stable_id].phase not in ["received","recovered"]

func carried(person: CityResident) -> bool:
	return cases.get(person.stable_id,{}).get("phase","")=="transporting"

func resting(person: CityResident) -> bool:
	return person.hp==0 and cases.get(person.stable_id,{}).get("phase","")=="received"

func report(person: CityResident,reporter: String) -> bool:
	if person.available() or pending(person) or resting(person) or game.passengers and game.passengers.aboard(person): return false
	if reporter!="player" and person_for(reporter)==null: return false
	if game.commons: game.commons.release(person)
	sequence+=1
	cases[person.stable_id]={"phase":"queued","reporter":reporter,"order":sequence,"helped":reporter=="player"}
	game.career.record("public_help_"+person.stable_id+"_"+str(sequence),person.title.split(" · ")[0]+"的街区现场已报告，救助人员将沿路到场。")
	game.say("已报告街区现场。救助人员正在处理现场，请留出通路。")
	game.queue_save()
	return true

func alarm(person: CityResident) -> void:
	if active=="" or crew.position.distance_to(person.position)<12: quiet=0
	if person.available(): return
	for witness in game.population.residents:
		if witness==person or not witness.available(): continue
		if witness.position.distance_to(person.position)<=12 and game.can_see(witness,person):
			report(person,witness.stable_id)
			return

func open_person(person: CityResident) -> void:
	game.close_interaction()
	game.speaker=person
	var phase: String=cases.get(person.stable_id,{}).get("phase","")
	var text := person.title.split(" · ")[0]+("已死亡。可以联系街区人员处理现场。" if person.hp==0 else "倒地暂时无法交谈。")
	text+="\n"+{"queued":"现场已报告，等待救助人员。","approaching":"救助人员正在沿路赶来。","assessing":"救助人员正在现场评估，请留出空间。","transporting":"正由救助人员转往接收站。","received":"已转入街区接收站，等待后续处置。"}.get(phase,"")
	var choices: Array=[]
	if phase=="" or phase=="recovered": choices.append(["报告位置，请街区人员到场","response_report"])
	choices.append(["留出通路","response_leave"])
	game.conversation={"text":text,"choices":choices}

func answer(person: CityResident,action: String) -> void:
	if action=="response_report": report(person,"player")
	game.close_interaction()

func on_crossing(point: Vector3,id: String,margin: float=2.0) -> bool:
	var ends: Array=CityPopulation.CROSSINGS[id]
	return point.distance_to(Geometry3D.get_closest_point_to_segment(point,CityPopulation.POINTS[ends[0]],CityPopulation.POINTS[ends[1]]))<margin

func closed(id: String) -> bool:
	for person in game.population.residents:
		if pending(person) and not person.available() and on_crossing(person.position,id): return true
	return occupied(id)

func occupied(id: String) -> bool:
	return on_crossing(crew.position,id,2.2)

func requests(id: String) -> bool:
	if route.is_empty(): return false
	var ends: Array=CityPopulation.CROSSINGS[id]
	var middle: Vector3=(CityPopulation.POINTS[ends[0]]+CityPopulation.POINTS[ends[1]])/2
	return crew.position.distance_to(middle)<24 and Geometry3D.get_closest_point_to_segment(middle,crew.position,route[0]).distance_to(middle)<2.5

func plan(target: Vector3) -> void:
	target.y=0
	route.clear()
	var start := crew.position
	# Leave the ward by its central aisle; every patient has a persistent bay.
	if start.x>8 and start.x<24 and start.z>74:
		route.append(Vector3(16,0,start.z))
		route.append(CityPopulation.POINTS.service_hall)
		start=CityPopulation.POINTS.service_hall
	for node in game.population.path(start,game.population.closest(target)): route.append(CityPopulation.POINTS[node])
	if target.x>8 and target.x<24 and target.z>74: route.append(Vector3(16,0,target.z))
	route.append(target)

func move_crew(delta: float) -> void:
	blocked=false
	crew.velocity=Vector3.ZERO
	while not route.is_empty() and crew.position.distance_to(route[0])<.23: route.pop_front()
	if not route.is_empty():
		var admitted := true
		for id in CityPopulation.CROSSINGS:
			if requests(id) and not occupied(id) and not game.population.safe_to_cross(id): admitted=false
		if admitted:
			var direction := route[0]-crew.position
			direction.y=0
			direction=direction.normalized()
			if crew.test_move(crew.transform,direction*.7):
				var side := Vector3(-direction.z,0,direction.x)
				var alternate := (direction+side*1.5).normalized()
				if not crew.test_move(crew.transform,alternate*.7): direction=alternate
				elif not crew.test_move(crew.transform,(direction-side*1.5).normalized()*.7): direction=(direction-side*1.5).normalized()
				else: blocked=true
			if not blocked:
				crew.rotation.y=lerp_angle(crew.rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*6))
				crew.velocity=direction*1.8
		else: blocked=true
	crew.rotation.y=wrapf(crew.rotation.y,-PI,PI)
	crew.move_and_slide()
	for helper in helpers: helper.pose(crew.velocity.length(),false,false,false,false)

func _physics_process(delta: float) -> void:
	quiet=minf(10,quiet+delta)
	# Only an actual nearby observer can discover an unreported scene, including old saves.
	for person in game.population.residents:
		if not person.available() and not pending(person) and not resting(person):
			for witness in game.population.residents:
				if witness!=person and witness.available() and witness.position.distance_to(person.position)<=12 and game.can_see(witness,person): report(person,witness.stable_id); break
	if active=="":
		var first := 1000001
		for id in cases:
			if cases[id].phase=="queued" and cases[id].order<first: active=id; first=cases[id].order
		if active!="":
			cases[active].phase="approaching"
			var person := person_for(active)
			var near: Vector3=CityPopulation.POINTS[game.population.closest(person.position)]
			var approach := (near-person.position).normalized()
			if approach.length()<.1: approach=Vector3.BACK
			plan(person.position+approach*1.8)
			elapsed=0
			game.queue_save()
	if active!="":
		var person := person_for(active)
		var entry: Dictionary=cases[active]
		if entry.phase in ["approaching","assessing"] and person.available():
			finish(person,"recovered")
		elif entry.phase=="approaching" and crew.position.distance_to(person.position)<2.5 and game.can_see(crew,person):
			route.clear()
			entry.phase="assessing"
			elapsed=0
			game.queue_save()
		elif entry.phase=="assessing":
			if quiet>=4: elapsed+=delta
			if elapsed>=6:
				entry.phase="transporting"
				person.route.clear(); person.crossing=""
				person.collision_layer=0; person.collision_mask=0
				crew.add_collision_exception_with(person)
				plan(bay(person.index))
				game.close_interaction()
				game.queue_save()
		elif entry.phase=="transporting" and route.is_empty():
			finish(person,"received" if person.hp==0 else "recovered")
	# Continuing violence pauses nearby work, including carrying; it never heals a victim.
	var stopped := active!="" and quiet<4 and crew.position.distance_to(person_for(active).position)<12
	if stopped:
		crew.velocity=Vector3.ZERO
		for helper in helpers: helper.pose(0,false,false)
	else: move_crew(delta)
	for person in game.population.residents:
		if carried(person) or resting(person): sync_person(person)
	notice.text="救助人员待命" if active=="" and route.is_empty() else "正在处置街区现场" if active!="" else "救助人员返站中"
	if blocked: notice.text="通路受阻 · 等待通道恢复"

func finish(person: CityResident,phase: String) -> void:
	cases[person.stable_id].phase=phase
	if phase=="received":
		person.position=bay(person.index)
		person.visual.rotation.y=0
		beds[person.index].visible=true
		beds[person.index].collision_layer=1
		crew.add_collision_exception_with(beds[person.index])
	else:
		person.collision_layer=1; person.collision_mask=3
		crew.remove_collision_exception_with(person)
		person.hp=maxi(person.hp,25)
		person.down=0
		person.state="activity"
		person.activity_left=1
		person.visual.position.y=0
		person.update_body()
	game.career.record("public_resolved_"+person.stable_id+"_"+str(cases[person.stable_id].order),person.title.split(" · ")[0]+("已被送至街区接收站，现场转运完成。" if phase=="received" else "已恢复行动，救助人员结束了本次处置。"))
	active=""
	elapsed=0
	plan(DEPOT)
	game.queue_save()

func sync_person(person: CityResident) -> void:
	person.velocity=Vector3.ZERO
	person.collision_layer=0; person.collision_mask=0
	person.state="dead" if person.hp==0 else "fallen"
	if carried(person):
		person.position=crew.position+Vector3(0,0,-.65).rotated(Vector3.UP,crew.rotation.y)
		person.visual.rotation.y=wrapf(crew.rotation.y+PI/2,-PI,PI)
	else:
		person.position=bay(person.index)+Vector3(0,0,-.65)
		person.visual.rotation.y=PI/2
		person.collision_layer=1
		person.update_body()
		person.body.position.y=1.2
	person.visual.position.y=.92
	person.visual.rotation.z=PI/2
	person.visual.pose(0,false,true,false,false)

func snapshot() -> Dictionary:
	var path := []
	for point in route: path.append(SaveGame.vector(point))
	return {"schema":1,"cases":cases.duplicate(true),"active":active,"sequence":sequence,"position":SaveGame.vector(crew.position),"yaw":crew.rotation.y,"route":path,"elapsed":elapsed,"quiet":quiet}

func status_text() -> String:
	var queued := 0
	for entry in cases.values():
		if entry.phase=="queued": queued+=1
	if active=="": return "街区救助：人员待命。伤者附近按 E 可报告位置，目击居民也会求助。" if route.is_empty() else "街区救助：人员正在返站。"
	var text: String={"approaching":"沿路赶往现场","assessing":"现场评估","transporting":"转往接收站"}.get(cases[active].phase,"")
	if blocked: text="通路受阻，等待通道恢复"
	elif quiet<4: text="等待现场危险解除"
	return "街区救助："+text+(" · 另有 %d 处现场等待" % queued if queued>0 else "")

func valid(data: Variant,people: Dictionary) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("cases") is Dictionary or not data.get("active") is String: return false
	if not CityPopulation.number(data.get("sequence"),0,1000000,true) or not CityPopulation.number(data.get("elapsed"),0,6.1) or not CityPopulation.number(data.get("quiet"),0,10) or not CityPopulation.number(data.get("yaw"),-PI,PI): return false
	if not ground_point(data.get("position")) or not data.get("route") is Array or data.route.size()>100: return false
	for point in data.route:
		if not ground_point(point): return false
	var orders := {}
	var workers := 0
	for id in data.cases:
		var entry: Variant=data.cases[id]
		if not id in people or not entry is Dictionary or not entry.get("phase") in PHASES or not entry.get("helped") is bool: return false
		if entry.get("reporter")!="player" and not entry.get("reporter") in people: return false
		if not CityPopulation.number(entry.get("order"),1,data.sequence,true) or orders.has(entry.order): return false
		orders[entry.order]=true
		if entry.phase in ["approaching","assessing","transporting"]:
			workers+=1
			if id!=data.active: return false
		if entry.phase=="received" and (people[id].hp!=0 or people[id].crossing!=""): return false
		if entry.phase=="assessing" and SaveGame.unvector(people[id].position).distance_to(SaveGame.unvector(data.position))>2.6: return false
		if entry.phase=="transporting" and (people[id].crossing!="" or people[id].state not in ["fallen","dead"]): return false
		if entry.phase=="received" and SaveGame.unvector(people[id].position).distance_to(bay(person_for(id).index)+Vector3(0,0,-.65))>.1: return false
		if entry.phase=="transporting":
			var expected: Vector3=SaveGame.unvector(data.position)+Vector3(0,0,-.65).rotated(Vector3.UP,data.yaw)
			if SaveGame.unvector(people[id].position).distance_to(expected)>.1: return false
			var destination := bay(person_for(id).index)
			if data.route.is_empty():
				if SaveGame.unvector(data.position).distance_to(destination)>.25: return false
			elif SaveGame.unvector(data.route[-1]).distance_to(destination)>.1: return false
	if (data.active=="")!=(workers==0) or workers>1: return false
	return data.active=="" or data.cases.has(data.active)

static func ground_point(value: Variant) -> bool:
	if not SaveGame.valid_vector(value): return false
	var point := SaveGame.unvector(value)
	return absf(point.y)<.1 and CityLayout.BOUNDS.has_point(Vector2(point.x,point.z))

func restore(data: Dictionary) -> void:
	for person in game.population.residents:
		crew.remove_collision_exception_with(person)
		person.collision_layer=1; person.collision_mask=3
	for bed in beds:
		bed.visible=false
		bed.collision_layer=0
		crew.remove_collision_exception_with(bed)
	cases=data.get("cases",{}).duplicate(true)
	active=data.get("active","")
	sequence=int(data.get("sequence",0))
	elapsed=float(data.get("elapsed",0))
	quiet=float(data.get("quiet",10))
	crew.position=SaveGame.unvector(data.get("position",SaveGame.vector(DEPOT)))
	crew.rotation.y=float(data.get("yaw",0))
	crew.velocity=Vector3.ZERO
	blocked=false
	route.clear()
	for point in data.get("route",[]): route.append(SaveGame.unvector(point))
	for person in game.population.residents:
		if carried(person) or resting(person):
			crew.add_collision_exception_with(person)
			beds[person.index].visible=resting(person)
			if resting(person):
				beds[person.index].collision_layer=1
				crew.add_collision_exception_with(beds[person.index])
			sync_person(person)

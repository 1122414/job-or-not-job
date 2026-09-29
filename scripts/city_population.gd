class_name CityPopulation
extends Node3D

const POINTS := {
	"office":Vector3(-24,0,18),"south":Vector3(0,0,18),"center":Vector3(0,0,58),
	"west_path":Vector3(-64,0,58),"shop_walk":Vector3(-56,0,52),"bookshop":Vector3(-58,0,44),
	"west_in":Vector3(-68,0,58),"west_out":Vector3(-84,0,58),"market":Vector3(-94,0,58),
	"homes":Vector3(58,0,58),"garden":Vector3(42,0,54),"east_in":Vector3(68,0,58),
	"east_out":Vector3(84,0,58),"east_garden":Vector3(86,0,68),
	"north_in":Vector3(0,0,97),"north_out":Vector3(0,0,112),
	"sea_west":Vector3(-28,0,116),"sea_east":Vector3(28,0,116),
	"bookshop_entry":Vector3(-52,0,41),"bookshop_room":Vector3(-52,0,35),
	"reading_west":Vector3(-54,0,31),"reading_center":Vector3(-52,0,31),"reading_east":Vector3(-49.5,0,31),
	"paper_west":Vector3(-56.5,0,30.5),"paper_center":Vector3(-54.3,0,30),"paper_east":Vector3(-52.9,0,28.6),
	"garden_west":Vector3(36,0,56),"garden_center":Vector3(38,0,58),"garden_east":Vector3(40,0,56)
}
const LINKS := [["office","south"],["south","center"],["center","west_path"],["west_path","shop_walk"],["shop_walk","bookshop"],["west_path","west_in"],["west_in","west_out"],["west_out","market"],["center","homes"],["center","garden"],["garden","homes"],["homes","east_in"],["east_in","east_out"],["east_out","east_garden"],["center","north_in"],["north_in","north_out"],["north_out","sea_west"],["north_out","sea_east"],["bookshop","bookshop_entry"],["bookshop_entry","bookshop_room"],["bookshop_room","reading_west"],["bookshop_room","reading_center"],["bookshop_room","reading_east"],["bookshop_room","paper_west"],["bookshop_room","paper_center"],["bookshop_room","paper_east"],["garden","garden_west"],["garden","garden_center"],["garden","garden_east"]]
const CROSSINGS := {"market":["west_in","west_out"],"homes":["east_in","east_out"],"waterfront":["north_in","north_out"]}
const TITLES := {"office":"下班路","bookshop":"社区书屋门口","market":"榕树街广场","homes":"东里社区","garden":"社区花园","east_garden":"东里东街","sea_west":"海风步道西段","sea_east":"海风步道东段","reading_west":"书屋阅览区","reading_center":"书屋阅览区","reading_east":"书屋阅览区"}
const PROFILES := [
	["zhou_ning","周宁","casual","homes"],["chen_yu","陈雨","office_female","garden"],
	["liang_bo","梁伯","casual","market"],["lin_qiao","林巧","office_female","bookshop"],
	["xu_hang","许航","office","office"],["song_an","宋安","casual","sea_west"],
	["he_yue","何悦","office_female","sea_east"],["wu_fan","吴帆","office","east_garden"],
	["zhao_lin","赵林","casual","south"],["tang_ke","唐可","office_female","shop_walk"],
	["lu_yang","陆扬","office","west_path"],["su_wan","苏晚","office_female","north_out"]
]
const PLANS := [["bookshop","office","market","homes"],["garden","bookshop","market","sea_east"],["sea_west","sea_east","garden","market"],["homes","east_garden","homes","office"]]
var game: Node3D
var residents: Array[CityResident]=[]
var graph := AStar3D.new()
var point_ids: Array=[]
var crossings := {}
var crossing_offsets := {}

func _ready() -> void:
	name="CityPopulation"
	point_ids=POINTS.keys()
	for i in range(point_ids.size()): graph.add_point(i,POINTS[point_ids[i]])
	for link in LINKS: graph.connect_points(point_ids.find(link[0]),point_ids.find(link[1]))
	for id in CROSSINGS:
		var ends: Array=CROSSINGS[id]
		var middle: Vector3=(POINTS[ends[0]]+POINTS[ends[1]])/2
		crossing_offsets[id]=game.transit.curve.get_closest_offset(middle)
		crossings[id]={"people":false,"remaining":0.0,"opened":false}
		for i in range(10):
			var pos: Vector3=middle+Vector3((i-4.5)*1.2,0.022,0) if id!="waterfront" else middle+Vector3(0,0.022,(i-4.5)*1.2)
			Shapes.box(self,Vector3(.65,.015,3) if id!="waterfront" else Vector3(3,.015,.65),pos,Color("dddacb"))
	for i in range(PROFILES.size()):
		var person := CityResident.new()
		person.population=self
		person.game=game
		person.index=i
		person.stable_id="resident_"+PROFILES[i][0]
		person.title=PROFILES[i][1]+" · 街区居民"
		person.position=POINTS[PROFILES[i][3]]+Vector3(.65 if i%2==0 else -.65,0,.6)
		person.from_node=PROFILES[i][3]
		residents.append(person)
		add_child(person)

func time_phase() -> int:
	var minute: int=game.payroll.minute%1440
	return 3 if minute<360 or minute>=1260 else 0 if minute<720 else 1 if minute<1020 else 2

func destination(person: CityResident) -> String:
	var choices: Array=PLANS[time_phase()]
	var next: String=choices[(person.index+person.journey)%choices.size()]
	if next==person.destination: next=choices[(person.index+person.journey+1)%choices.size()]
	if next=="bookshop" and game.city_life and game.city_life.is_open(): next=CityLife.INDOOR[person.index%3]
	return next

func closest(point: Vector3) -> String:
	return point_ids[graph.get_closest_point(point)]

func path(from: Vector3,to: String) -> Array[String]:
	var result: Array[String]=[]
	for id in graph.get_id_path(graph.get_closest_point(from),point_ids.find(to)): result.append(point_ids[id])
	return result

func crossing_for(from: String,to: String) -> String:
	for id in CROSSINGS:
		var ends: Array=CROSSINGS[id]
		if from in ends and to in ends and from!=to: return id
	return ""

func waiting(id: String) -> bool:
	for person in residents:
		if person.available() and person.crossing=="" and person.requested_crossing()==id: return true
	return false

func occupied(id: String) -> bool:
	for person in residents:
		if person.crossing==id: return true
	return false

func _physics_process(delta: float) -> void:
	for id in crossings:
		var gate: Dictionary=crossings[id]
		gate.remaining=maxf(0,gate.remaining-delta)
		if not gate.people:
			if gate.remaining==0 and waiting(id):
				gate.people=true
				gate.opened=false
		elif not gate.opened:
			if safe_to_cross(id): gate.opened=true; gate.remaining=4.0
		elif gate.remaining==0 and not occupied(id):
			# Close admission, drain the crossing, then reserve seven seconds for traffic.
			gate.people=false
			gate.opened=false
			gate.remaining=7.0

func may_cross(id: String) -> bool:
	var gate: Dictionary=crossings[id]
	return gate.people and gate.opened and gate.remaining>0 and safe_to_cross(id)

func route_gap(id: String,offset: float) -> float:
	var length: float=game.transit.curve.get_baked_length()
	var distance: float=fposmod(crossing_offsets[id]-offset,length)
	return distance if distance<length/2 else distance-length

func safe_to_cross(id: String) -> bool:
	var vehicles: Array=[game.transit.bus]+game.driving.cars
	var ends: Array=CROSSINGS[id]
	for vehicle in vehicles:
		if vehicle==game.transit.bus or vehicle.traffic:
			var is_bus: bool=vehicle==game.transit.bus
			var speed: float=game.transit.speed if is_bus else vehicle.speed
			var distance := route_gap(id,game.transit.distance if is_bus else vehicle.route_distance)
			var half_length := 3.6 if is_bus else 2.2
			var braking := CityTransit.ACCELERATION if is_bus else CityCar.BRAKING
			var approach := maxf(13.0,speed*speed/(2*braking)+3.5)
			if distance> -half_length-1 and distance<half_length+1.5: return false
			if distance>=half_length+1.5 and distance<half_length+approach and speed>.25: return false
		else:
			# A parked or player-driven car can approach from any direction.
			var future: Vector3=vehicle.position-vehicle.basis.z*vehicle.speed*2.0
			var near := Geometry3D.get_closest_points_between_segments(POINTS[ends[0]],POINTS[ends[1]],vehicle.position,future)
			if near[0].distance_to(near[1])<3.0: return false
	return true

func speed_limit(offset: float,braking: float,front: float) -> float:
	var limit := INF
	for id in crossings:
		if not crossings[id].people and not occupied(id): continue
		var distance := route_gap(id,offset)
		# Vehicles already over the line must clear it instead of deadlocking on it.
		if distance>front+1.5 and distance<24:
			limit=minf(limit,sqrt(2*braking*maxf(0,distance-front-2.5)))
	return limit

func alarm(victim: Node3D,action: int) -> void:
	for person in residents:
		if person==victim or not person.available() or person.last_alarm==action: continue
		if person.position.distance_to(victim.position)>12 or not game.can_see(person,victim): continue
		person.last_alarm=action
		person.witnessed+=1
		person.avoid(game.player.position)
	game.queue_save()

func refuge(person: CityResident,threat: Vector3) -> String:
	var best := closest(person.position)
	var score := -INF
	for id in TITLES:
		var distance: float=person.position.distance_to(POINTS[id])
		if distance>45: continue
		var candidate: float=POINTS[id].distance_to(threat)-distance*.5
		if candidate>score: best=id; score=candidate
	return best

func talk(person: CityResident) -> void:
	if not person.available(): game.say("对方已死亡。" if person.hp==0 else "对方受伤倒地，暂时无法交谈。"); return
	if person.crossing!="": game.say("先让对方走到路边。"); return
	if person.fear>0: game.say("对方正在避开危险。"); return
	game.close_interaction()
	game.speaker=person
	person.state="talking"
	person.met=true
	var text := person.title.split(" · ")[0]+"："+("又见面了。" if person.conversations>0 else "你好。")
	if person.hits>0: text+="上次你动过手，我还记得。" if not person.apologized else "道歉我听到了，让我缓一缓。"
	elif person.witnessed>0: text+="刚才那场冲突让我有点担心。"
	else: text+="我准备去"+TITLES.get(person.destination,"街口")+"。"
	game.conversation={"text":text,"choices":[["附近有什么地方可以走走？","resident_places"],["那你先忙，回头见","resident_bye"]]}
	if person.hits>0 and not person.apologized: game.conversation.choices.push_front(["为之前动手道歉","resident_apology"])
	game.queue_save()

func answer(person: CityResident,action: String) -> void:
	if not person.available(): game.close_interaction(); return
	person.conversations+=1
	if action=="resident_places":
		game.conversation={"text":person.title.split(" · ")[0]+"："+game.city_life.resident_line(person)+"沿中间步道往北，过斑马线就是海边。过街先看车。","choices":[["谢谢，回头见","resident_bye"]]}
	elif action=="resident_apology":
		person.apologized=true
		game.conversation={"text":person.title.split(" · ")[0]+"：希望不会再发生。我先回去休息。","choices":[["好","resident_bye"]]}
	else: game.close_interaction()
	game.queue_save()

func snapshot() -> Dictionary:
	var people := {}
	for person in residents: people[person.stable_id]=person.snapshot()
	return {"schema":1,"people":people,"crossings":crossings.duplicate(true)}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("people") is Dictionary or not data.get("crossings") is Dictionary: return false
	if data.people.size()!=residents.size() or data.crossings.size()!=crossings.size(): return false
	for person in residents:
		if not person.valid(data.people.get(person.stable_id)): return false
	for id in crossings:
		var gate: Variant=data.crossings.get(id)
		if not gate is Dictionary or not gate.get("people") is bool or not gate.get("opened") is bool: return false
		if not number(gate.get("remaining"),0,7) or gate.opened and not gate.people: return false
	return true

static func number(value: Variant,minimum: float,maximum: float,integer: bool=false) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=minimum and value<=maximum and (not integer or value==floor(value))

func restore(data: Dictionary) -> void:
	for id in crossings: crossings[id]=data.get("crossings",{}).get(id,{"people":false,"remaining":0.0,"opened":false}).duplicate(true)
	for person in residents: person.restore(data.get("people",{}).get(person.stable_id,{}))

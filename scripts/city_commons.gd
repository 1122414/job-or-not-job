class_name CityCommons
extends Node

const PLACES := {"west":"榕树里","east":"东里","north":"海风里"}
const TOPICS := {"work":"下班后的打算","street":"街区里的人和事","quiet":"一起安静歇了会儿"}
var game: Node3D
var benches: Dictionary={}
var visits: Dictionary={}
var memories: Dictionary={}
var player_slot := ""
var clock := 0.0

func _ready() -> void:
	for bench in game.get_node("ConnectedDistrict/Streetscape").get_children():
		if bench is CityBench: benches[bench.stable_id]=bench

func _physics_process(delta: float) -> void:
	clock=fmod(clock+delta,120)
	if player_slot!="" and (not game.player.seated or game.player.position.distance_to(point(player_slot))>.12):
		game.player.seated=false
		if game.player.seat_body: game.player.remove_collision_exception_with(game.player.seat_body)
		game.player.seat_body=null
		player_slot=""
		game.queue_save()

func slot_bench(slot: String) -> CityBench:
	return benches.get(slot.get_slice("/",0))

func point(slot: String) -> Vector3:
	return slot_bench(slot).seat_point(int(slot.get_slice("/",1)))

func occupied(slot: String) -> bool:
	if player_slot==slot: return true
	for visit in visits.values():
		if visit.slot==slot: return true
	return false

func clear_seat(slot: String,actor: CharacterBody3D) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius=.28; shape.height=1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape; query.collision_mask=3; query.margin=.005
	query.exclude=[actor.get_rid(),slot_bench(slot).get_rid()]
	query.transform.origin=point(slot)+Vector3.UP*.9
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func reserve(person: CityResident,preferred: String) -> String:
	for id in [preferred]+benches.keys().filter(func(id): return id!=preferred):
		for side in range(2):
			var slot: String=id+"/"+str(side)
			if not occupied(slot) and clear_seat(slot,person):
				visits[person.stable_id]={"slot":slot,"seated":false}
				return id
	return "center"

func release(person: CityResident) -> void:
	visits.erase(person.stable_id)
	# Keep the bench collision exception until the body has physically left it.
	# This also lets injured residents get up without being pushed below the floor.
	if person.pastime_book: person.pastime_book.hide()

func sitting(person: CityResident) -> bool:
	var visit: Dictionary=visits.get(person.stable_id,{})
	return not visit.is_empty() and visit.seated and person.available() and person.fear==0 and person.position.distance_to(point(visit.slot))<.12

func attend(person: CityResident,delta: float) -> bool:
	if person.seat_body and person.position.distance_to(person.seat_body.position)>1.65:
		person.remove_collision_exception_with(person.seat_body)
		person.seat_body=null
	var visit: Dictionary=visits.get(person.stable_id,{})
	if visit.is_empty(): return false
	if not person.available() or person.fear>0 or person.destination!=visit.slot.get_slice("/",0):
		release(person); return false
	if not person.route.is_empty(): return false
	if person.state in ["walking","waiting"]:
		person.state="activity"
		person.journey+=1
		if not person.destination in person.visits: person.visits.append(person.destination)
		game.queue_save()
	var bench := slot_bench(visit.slot)
	if person.seat_body!=bench:
		if person.seat_body: person.remove_collision_exception_with(person.seat_body)
		person.seat_body=bench
		person.add_collision_exception_with(bench)
	var offset := point(visit.slot)-person.position
	offset.y=0
	if offset.length()>.12: visit.seated=false
	if offset.length()>.045:
		person.velocity=offset.normalized()*minf(1.1,offset.length()/delta)
		return true
	person.velocity=Vector3.ZERO
	if not visit.seated:
		visit.seated=true
		person.activity_left=42+person.index%3*7
		game.queue_save()
	if game.speaker!=person:
		person.activity_left=maxf(0,person.activity_left-delta)
		if person.activity_left==0 or person.phase!=game.population.time_phase():
			release(person)
			person.phase=game.population.time_phase()
			person.plan(game.population.destination(person))
	return true

func companion(person: CityResident) -> CityResident:
	if not sitting(person): return null
	for other in game.population.residents:
		if other!=person and sitting(other) and other.position.distance_to(person.position)<1.5: return other
	return null

func reading(person: CityResident) -> bool:
	return sitting(person) and game.speaker!=person and companion(person)==null and person.index%2==0

func telling(person: CityResident) -> bool:
	var other := companion(person)
	return other!=null and game.speaker!=person and game.speaker!=other and (int(clock/6)%2==0)==(person.index<other.index)

func caption() -> String:
	if game.in_vehicle() or game.player.hp<=0: return ""
	for person in game.population.residents:
		if not telling(person) or person.position.distance_to(game.player.position)>6 or not game.can_see(game.player,person): continue
		var lines := ["今天就坐这儿歇一会儿，事情回去再说。","海边风大，走累了来这儿坐坐。","书屋的老图画我看过，有空一起去。"]
		return person.title.split(" · ")[0]+"："+lines[(int(clock/12)+person.index)%lines.size()]
	return ""

func player_bench() -> CityBench:
	return slot_bench(player_slot)

func use_bench(bench: CityBench) -> void:
	if player_bench()==bench and game.player.seated:
		game.player.stand_up(); return
	if game.in_vehicle() or not game.player.stand_up(): return
	var options := [0,1]
	options.sort_custom(func(a,b): return bench.seat_point(a).distance_to(game.player.position)<bench.seat_point(b).distance_to(game.player.position))
	for side in options:
		var slot := bench.stable_id+"/"+str(side)
		if occupied(slot) or not clear_seat(slot,game.player): continue
		# Only allow approach from the open face, not through the core or backrest.
		var local := bench.to_local(game.player.position)
		if local.z>-.3 or game.player.position.distance_to(bench.seat_point(side))>2.4:
			game.say("走到长凳前面，就可以坐下。"); return
		game.close_interaction()
		game.player.sit_at(point(slot),bench,bench.rotation.y)
		player_slot=slot
		game.say("在"+PLACES[bench.stable_id.get_slice("_",1)]+"歇一会儿 · 移动即可起身，面对邻座按 E 聊聊")
		game.queue_save()
		return
	game.say("这张长凳暂时没有空位，旁边还有座位。")

func can_chat(person: CityResident) -> bool:
	return game.player.seated and player_bench()!=null and sitting(person) and person.position.distance_to(game.player.position)<2.0 and (person.hits==0 or person.apologized)

func options(person: CityResident) -> void:
	if not can_chat(person): return
	game.conversation.choices=[["回头见","resident_bye"]]
	game.conversation.choices.push_front(["聊聊下班后的打算","commons_work"])
	game.conversation.choices.push_front(["聊聊这片街区","commons_street"])
	game.conversation.choices.push_front(["一起安静坐一会儿","commons_quiet"])

func memory_line(person: CityResident) -> String:
	var memory: Dictionary=memories.get(person.stable_id,{})
	if memory.is_empty(): return ""
	return "上次在"+PLACES[memory.place]+"，"+{"work":"你和我聊过下班后的打算。","street":"我们聊过街区里的人和事。","quiet":"我们一起安静坐了会儿。"}[memory.topic]

func answer(person: CityResident,action: String) -> void:
	if not can_chat(person): game.close_interaction(); return
	var topic := action.trim_prefix("commons_")
	if not topic in TOPICS: return
	var place := player_bench().stable_id.get_slice("_",1)
	var day := int(game.payroll.minute/1440)
	var previous: Dictionary=memories.get(person.stable_id,{})
	var repeated: bool=previous.get("day",-1)==day and previous.get("topic")==topic
	memories[person.stable_id]={"day":day,"place":place,"topic":topic}
	var line := "这边不催人，坐一会儿再走。"
	if topic=="work": line="刚上班那阵，我回家还总想着工作。现在下班会先走一段路，把时间留一点给自己。" if game.career.employer!="" else "找工作的日子也可以给自己留个下午。两家公司都去看看，不必在门口就决定。"
	if topic=="street": line="书屋那次分享我记得。比起图画，我更记得大家凑在一起的样子。" if person.stable_id in game.city_life.participants else "我常走中间这条步道。有人去书屋，有人过街去海边，走着走着就混熟了。"
	if repeated: line="刚才聊的我记得。今天就在这儿歇歇吧。"
	game.conversation={"text":person.title.split(" · ")[0]+"："+line,"choices":[["回头见","resident_bye"]]}
	game.queue_save()

func snapshot() -> Dictionary:
	return {"schema":1,"visits":visits.duplicate(true),"memories":memories.duplicate(true),"player_slot":player_slot}

func valid(data: Variant,world: Dictionary) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("visits") is Dictionary or not data.get("memories") is Dictionary or not data.get("player_slot") is String: return false
	var slots := {}
	for id in data.visits:
		if not id in world.city_population.people: return false
		var visit: Variant=data.visits[id]
		if not visit is Dictionary or not visit.get("slot") is String or not visit.get("seated") is bool: return false
		if not valid_slot(visit.slot) or slots.has(visit.slot): return false
		slots[visit.slot]=true
		var person: Dictionary=world.city_population.people[id]
		if person.destination!=visit.slot.get_slice("/",0) or person.hp==0 or person.down>0 or person.fear>0: return false
		if visit.seated and (person.state not in ["activity","talking"] or person.crossing!="" or not person.route.is_empty() or SaveGame.unvector(person.position).distance_to(point(visit.slot))>.12): return false
	for id in data.memories:
		var memory: Variant=data.memories[id]
		if not id in world.city_population.people or not memory is Dictionary: return false
		if not CityPopulation.number(memory.get("day"),0,int(world.payroll.minute/1440),true) or not memory.get("place") in PLACES or not memory.get("topic") in TOPICS: return false
	if data.player_slot!="":
		if not valid_slot(data.player_slot) or slots.has(data.player_slot): return false
		if world.player.hp<=0 or world.city_transit.riding or world.city_driving.active!="" or SaveGame.unvector(world.player.position).distance_to(point(data.player_slot))>.12: return false
	return true

func valid_slot(slot: String) -> bool:
	return slot.split("/").size()==2 and benches.has(slot.get_slice("/",0)) and slot.get_slice("/",1) in ["0","1"]

func restore(data: Dictionary) -> void:
	for person in game.population.residents:
		if person.seat_body: person.remove_collision_exception_with(person.seat_body)
		person.seat_body=null
	visits=data.get("visits",{}).duplicate(true)
	memories=data.get("memories",{}).duplicate(true)
	player_slot=data.get("player_slot","")
	for person in game.population.residents:
		var visit: Dictionary=visits.get(person.stable_id,{})
		if not visit.is_empty() and person.position.distance_to(slot_bench(visit.slot).position)<1.65:
			person.seat_body=slot_bench(visit.slot)
			person.add_collision_exception_with(person.seat_body)
		person.update_body()
	if player_slot!="":
		var bench := player_bench()
		game.player.seat_body=bench
		game.player.add_collision_exception_with(bench)
		game.player.seated=true

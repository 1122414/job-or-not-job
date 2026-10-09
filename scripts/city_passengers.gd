class_name CityPassengers
extends Node

# The front-right seat stays reserved for the player. Public passengers are the
# existing residents, with the same identity, health and destination after a ride.
const SEATS := [Vector3(-.65,.40,-.4),Vector3(-.65,.40,1),Vector3(.65,.40,1),Vector3(-.65,.40,2.4),Vector3(.65,.40,2.4)]
const COMMUTERS := [4,5,6,8,9,10,11]
const STATIONS := ["office","market","waterfront","homes"]
var game: Node3D
var trips := {}

static func wait_node(stop: int,slot: int) -> String:
	return "bus_"+STATIONS[stop]+"_"+str(slot)

func aboard(person: CityResident) -> bool:
	return trips.get(person.stable_id,{}).get("stage")=="riding"

func prepare(person: CityResident,goal: String) -> String:
	if game.transit.bus.taken: return goal
	if not person.index in COMMUTERS or person.journey%3!=0 or person.fear>0 or not person.available() or trips.has(person.stable_id): return goal
	if person.position.distance_to(CityPopulation.POINTS[goal])<60: return goal
	var origin := closest_stop(person.position)
	var destination := closest_stop(CityPopulation.POINTS[goal])
	var hops := posmod(destination-origin,4)
	if hops==0 or hops>2: return goal
	for slot in range(3):
		if trips.values().any(func(trip): return trip.origin==origin and trip.queue==slot and trip.stage!="riding"): continue
		if game.commons: game.commons.release(person)
		trips[person.stable_id]={"origin":origin,"destination":destination,"queue":slot,"goal":goal,"seat":-1,"stage":"walking","early_exit":false}
		return wait_node(origin,slot)
	return goal

func closest_stop(point: Vector3) -> int:
	var nearest := 0
	for i in range(1,4):
		if CityLayout.STOPS[i].platform.distance_to(point)<CityLayout.STOPS[nearest].platform.distance_to(point): nearest=i
	return nearest

func cancel_wait(person: CityResident) -> void:
	if not aboard(person): trips.erase(person.stable_id)

func free_seat() -> int:
	for i in range(SEATS.size()):
		if not trips.values().any(func(trip): return trip.seat==i): return i
	return -1

func wants_exit(person: CityResident,trip: Dictionary) -> bool:
	if game.transit.bus.taken: return absf(game.transit.bus.speed)<.35
	return game.transit.current_stop>=0 and (game.transit.current_stop==trip.destination or trip.early_exit or not person.available() or person.fear>0)

func holds_departure() -> bool:
	for person in game.population.residents:
		if aboard(person) and wants_exit(person,trips[person.stable_id]): return true
	return false

func attach(person: CityResident) -> void:
	if person.seat_body: person.remove_collision_exception_with(person.seat_body)
	person.seat_body=game.transit.bus
	person.add_collision_exception_with(game.transit.bus)
	game.transit.bus.add_collision_exception_with(person)
	person.route.clear();person.crossing=""
	sync(person)

func sync(person: CityResident) -> void:
	if not aboard(person): return
	person.position=game.transit.bus.to_global(SEATS[int(trips[person.stable_id].seat)])
	person.velocity=Vector3.ZERO
	person.state="dead" if person.hp==0 else "fallen" if person.down>0 else "riding"
	person.visual.rotation=Vector3(0,game.transit.bus.rotation.y,0)
	person.visual.position.y=person.visual.seated_offset.y
	person.visual.scene_action=""
	person.visual.pose(0,false,false,false,true,false,game.speaker==person)
	person.pastime_book.hide()
	person.body.shape.height=1.3;person.body.basis=Basis.IDENTITY;person.body.position=Vector3(0,.68,0)

func sync_all() -> void:
	for person in game.population.residents:
		if aboard(person): sync(person)

func detach(person: CityResident) -> void:
	person.remove_collision_exception_with(game.transit.bus)
	game.transit.bus.remove_collision_exception_with(person)
	if person.seat_body==game.transit.bus: person.seat_body=null
	trips.erase(person.stable_id)
	person.visual.position.y=0
	person.update_body()

func exit_at_stop(person: CityResident,trip: Dictionary) -> bool:
	var stop: int=game.transit.current_stop
	if stop<0 and not game.transit.bus.taken: return false
	for point in (game.transit.manual_exits() if game.transit.bus.taken else exit_points(stop)):
		if not clear_exit(person,point): continue
		if game.transit.bus.taken and not game.transit.manual_exit_clear(person,point): continue
		finish_exit(person,trip,point)
		return true
	return false

func clear_exit(person: CityResident,point: Vector3) -> bool:
	if not game.position_clear(person,point): return false
	# Several people can alight within one physics tick. Their node positions are
	# current even before the physics broad phase sees the preceding handoff.
	for other in [game.player]+game.npcs+game.population.residents:
		if other!=person and other.position.distance_to(point)<.8: return false
	return true

func exit_points(stop: int) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var transform: Transform3D=game.transit.vehicle_transform(game.transit.stop_offsets[stop])
	for offset in [0.0,1.1,-1.1,2.2,-2.2]: points.append(CityLayout.STOPS[stop].platform+transform.basis.z*offset)
	return points

func finish_exit(person: CityResident,trip: Dictionary,point: Vector3) -> void:
	var goal: String=trip.goal
	detach(person)
	person.position=point;person.from_node=game.population.closest(point)
	person.state="dead" if person.hp==0 else "fallen" if person.down>0 else "activity"
	person.activity_left=1
	if person.available():
		if person.fear>0: goal=game.population.refuge(person,game.player.position)
		elif goal.begins_with("commons_"): goal=game.commons.reserve(person,goal)
		person.plan(goal)
	game.queue_save()

func skipped_exits(stops: Array[int]) -> Variant:
	# An explicit player time skip may pass a resident's destination. Preflight
	# all exits before changing anything; blocked platforms reject the whole skip.
	var exits := {}
	var reserved: Array[Vector3]=[]
	for person in game.population.residents:
		if not aboard(person): continue
		var trip: Dictionary=trips[person.stable_id]
		for stop in stops:
			if stop!=trip.destination and not trip.early_exit and person.available() and person.fear==0: continue
			var found := false
			for point in exit_points(stop):
				if not clear_exit(person,point) or reserved.any(func(other):return other.distance_to(point)<.8): continue
				exits[person.stable_id]={"stop":stop,"point":point}
				reserved.append(point);found=true;break
			if not found: return null
			break
	return exits

func attend(person: CityResident,delta: float) -> bool:
	var trip: Dictionary=trips.get(person.stable_id,{})
	if trip.is_empty(): return false
	if trip.stage=="riding":
		person.fear=maxf(0,person.fear-delta);person.down=maxf(0,person.down-delta)
		if wants_exit(person,trip) and exit_at_stop(person,trip): return false
		sync(person)
		return true
	if game.transit.bus.taken:
		cancel_wait(person);person.plan(trip.goal);return false
	if not person.available() or person.fear>0 or person.destination!=wait_node(trip.origin,trip.queue):
		cancel_wait(person);return false
	if not person.route.is_empty() or game.speaker==person: return false
	if trip.stage=="walking":
		trip.stage="waiting"
		# The bus stop is part of this trip, not another completed daily activity.
		if not person.destination in person.visits: person.visits.append(person.destination)
		game.queue_save()
	person.state="waiting";person.velocity=Vector3.ZERO
	person.visual.scene_action="";person.visual.position.y=0
	person.visual.pose(0,false,false)
	var towards: Vector3=CityLayout.STOPS[trip.origin].point-person.position
	person.visual.rotation.y=lerp_angle(person.visual.rotation.y,atan2(-towards.x,-towards.z),1-exp(-delta*5))
	if game.transit.current_stop==trip.origin and person.position.distance_to(CityPopulation.POINTS[person.destination])<.85:
		var seat := free_seat()
		if seat>=0:
			trip.stage="riding";trip.seat=seat
			attach(person)
			game.transit.dwell=maxf(2,game.transit.dwell)
			game.queue_save()
	return true

func description(person: CityResident) -> String:
	var trip: Dictionary=trips.get(person.stable_id,{})
	if trip.is_empty(): return ""
	return ("坐101到" if trip.stage=="riding" else "准备在这里坐101到")+CityLayout.STOPS[trip.destination].title.split(" · ")[0]+"，然后去"+CityPopulation.TITLES.get(trip.goal,"街区里办点事")+"。"

func snapshot() -> Dictionary:
	return {"schema":1,"trips":trips.duplicate(true)}

func valid(data: Variant,people: Dictionary,transit: Dictionary) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("trips") is Dictionary or data.trips.size()>COMMUTERS.size(): return false
	var seats := {};var queues := {}
	for id in data.trips:
		var trip: Variant=data.trips[id]
		if not people.has(id) or not trip is Dictionary or not trip.get("early_exit") is bool: return false
		var person: CityResident=game.response.person_for(id)
		if not person or not person.index in COMMUTERS: return false
		for key in ["origin","destination","queue","seat"]:
			if not CityPopulation.number(trip.get(key),-1 if key=="seat" else 0,4 if key=="seat" else 2 if key=="queue" else 3,true): return false
		if trip.origin==trip.destination or not trip.get("goal") in CityPopulation.POINTS or trip.goal.begins_with("bus_") or not trip.get("stage") in ["walking","waiting","riding"]: return false
		var actor: Dictionary=people[id]
		if actor.destination!=wait_node(trip.origin,trip.queue): return false
		if trip.stage=="riding":
			if trip.seat<0 or seats.has(int(trip.seat)) or not actor.route.is_empty() or actor.crossing!="" or actor.state not in ["riding","fallen","dead"]: return false
			seats[int(trip.seat)]=true
			var expected: Vector3=game.transit.stored_transform(transit)*SEATS[int(trip.seat)]
			if expected.distance_to(SaveGame.unvector(actor.position))>.08: return false
		else:
			var queue := wait_node(trip.origin,trip.queue)
			if trip.seat!=-1 or queues.has(queue) or actor.hp<=0 or actor.down>0 or actor.fear>0: return false
			queues[queue]=true
			if trip.stage=="waiting" and (not actor.route.is_empty() or SaveGame.unvector(actor.position).distance_to(CityPopulation.POINTS[queue])>.85): return false
	for id in people:
		if people[id].state=="riding" and data.trips.get(id,{}).get("stage")!="riding": return false
	return true

func reset() -> void:
	for person in game.population.residents:
		if aboard(person): detach(person)
	trips.clear()

func restore(data: Dictionary) -> void:
	reset()
	trips=data.get("trips",{}).duplicate(true)
	for person in game.population.residents:
		if aboard(person): attach(person)

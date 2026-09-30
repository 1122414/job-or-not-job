class_name CityResident
extends CharacterBody3D

var population: CityPopulation
var game: Node3D
var index := 0
var stable_id := ""
var title := ""
var visual: HumanVisual
var body: CollisionShape3D
var seat_body: PhysicsBody3D
var pastime_book: Node3D
var state := "activity"
var destination := ""
var from_node := ""
var route: Array[String]=[]
var crossing := ""
var activity_left := 0.0
var phase := -1
var journey := 0
var visits: Array[String]=[]
var hp := 100
var down := 0.0
var fear := 0.0
var hits := 0
var witnessed := 0
var met := false
var apologized := false
var conversations := 0
var last_hit := -1
var last_alarm := -1
var stuck := 0.0

func _ready() -> void:
	name=stable_id
	collision_layer=1
	collision_mask=3
	body=CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.27
	capsule.height=1.75
	body.shape=capsule
	body.position.y=.88
	add_child(body)
	visual=HumanVisual.new()
	visual.outfit=CityPopulation.PROFILES[index][2]
	visual.variation=index
	visual.personality=["friend","lead","group","hr"][index%4]
	add_child(visual)
	make_pastime_book()
	visual.animation.mixer_applied.connect(sync_pastime_book)
	activity_left=2.0+index*1.4
	destination=from_node
	phase=population.time_phase()

func available() -> bool:
	return hp>0 and down<=0 and (not game.response or not game.response.carried(self))

func plan(to: String) -> void:
	if game.passengers and trips_to_other_stop(to): game.passengers.cancel_wait(self)
	if game.commons and game.commons.visits.get(stable_id,{}).get("slot","").get_slice("/",0)!=to: game.commons.release(self)
	destination=to
	route=population.path(position,to)
	from_node=population.closest(position)
	crossing=""
	state="walking"
	stuck=0

func trips_to_other_stop(to: String) -> bool:
	var trip: Dictionary=game.passengers.trips.get(stable_id,{})
	return not trip.is_empty() and to!=CityPassengers.wait_node(trip.origin,trip.queue)

func requested_crossing() -> String:
	return population.crossing_for(from_node,route[0]) if not route.is_empty() else ""

func _physics_process(delta: float) -> void:
	if game.response and (game.response.carried(self) or game.response.resting(self)):
		game.response.sync_person(self)
		return
	if game.passengers and game.passengers.attend(self,delta): return
	fear=maxf(0,fear-delta)
	down=maxf(0,down-delta)
	if game.city_life: game.city_life.redirect(self)
	if hp==0: state="dead"
	elif down>0: state="fallen"
	elif state in ["fallen","dead"]:
		hp=maxi(hp,25)
		# Finish an interrupted crossing before choosing another destination.
		state="walking" if crossing!="" and not route.is_empty() else "activity"
		activity_left=1.0
	if not available():
		velocity=Vector3.ZERO
	elif game.speaker==self:
		state="talking"
		velocity=Vector3.ZERO
	elif game.meals and game.meals.attend(self,delta):
		pass
	elif game.commons and game.commons.attend(self,delta):
		if state=="talking": state="activity"
	else:
		if state=="talking": state="walking" if not route.is_empty() else "activity"
		if state=="activity":
			activity_left=maxf(0,activity_left-delta)
			if activity_left==0 or phase!=population.time_phase():
				phase=population.time_phase()
				plan(population.destination(self))
		if state in ["walking","waiting"]: walk(delta)
		else: velocity=Vector3.ZERO
	var falling := state in ["fallen","dead"]
	visual.rotation.z=move_toward(visual.rotation.z,PI/2 if falling else 0,delta*7)
	var seated: bool=game.commons!=null and game.commons.sitting(self)
	visual.position.y=move_toward(visual.position.y,.27 if falling else visual.seated_offset.y if seated else 0.0,delta*2.5)
	if seat_body and game.commons and game.commons.slot_bench(game.commons.visits.get(stable_id,{}).get("slot",""))==seat_body:
		visual.rotation.y=lerp_angle(visual.rotation.y,seat_body.rotation.y,1-exp(-delta*8))
	elif velocity.length()>.1:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-velocity.x,-velocity.z),1-exp(-delta*8))
	elif state=="talking" and not seated:
		var direction: Vector3=game.player.position-position
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*5))
	var sharing: bool=game.city_life!=null and game.city_life.present(self)
	if sharing:
		var look: Vector3=game.city_life.performance.facing(self)-position
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-look.x,-look.z),1-exp(-delta*5))
	if seated: visual.rotation.y=lerp_angle(visual.rotation.y,seat_body.rotation.y,1-exp(-delta*8))
	if game.meals:
		var meal_facing: Variant=game.meals.facing(self)
		if meal_facing!=null:
			var direction: Vector3=meal_facing-position
			visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*8))
	var reading: bool=game.commons!=null and game.commons.reading(self)
	visual.scene_action="read" if reading else game.city_life.performance.action(self) if game.city_life else ""
	visual.pose(Vector2(velocity.x,velocity.z).length(),false,falling,seated,seated,false,state=="talking" or game.commons!=null and game.commons.telling(self))
	if not reading: pastime_book.hide()
	visual.rotation.y=wrapf(visual.rotation.y,-PI,PI)
	update_body()
	if not is_on_floor(): velocity.y=-4
	var before := position
	move_and_slide()
	# Character-root rotation/motion may run between mixer evaluations.
	# Reapply scene-owned props so the palms and book use the same frame.
	if game.city_life and game.city_life.performance: game.city_life.performance.apply(self)
	if game.meals: game.meals.scene.apply(self)
	if not falling and velocity.length()>.4 and position.distance_to(before)<delta*.15: stuck+=delta
	else: stuck=0
	if stuck>2: velocity=Vector3.ZERO

func update_body() -> void:
	var falling := hp==0 or down>0
	var seated: bool=game.commons!=null and game.commons.sitting(self)
	body.shape.height=1.3 if seated else 1.75
	var facing := Basis(Vector3.UP,visual.rotation.y)
	body.basis=facing*Basis(Vector3.BACK,PI/2) if falling else Basis.IDENTITY
	body.position=facing*Vector3(-.65,.28,0) if falling else Vector3(0,.68 if seated else .88,0)

func walk(_delta: float) -> void:
	if route.is_empty():
		state="activity"
		activity_left=18.0+index%4*7
		journey+=1
		if not destination in visits: visits.append(destination)
		velocity=Vector3.ZERO
		game.queue_save()
		return
	if game.city_life and game.city_life.walk.waits(self):
		state="waiting"
		velocity=Vector3.ZERO
		return
	var target: Vector3=CityPopulation.POINTS[route[0]]
	if Vector2(target.x-position.x,target.z-position.z).length()<.62:
		from_node=route.pop_front()
		if crossing!="" and from_node in CityPopulation.CROSSINGS[crossing]: crossing=""
		velocity=Vector3.ZERO
		return
	var requested := requested_crossing()
	if requested!="" and crossing=="":
		if not population.may_cross(requested): state="waiting"; velocity=Vector3.ZERO; return
		crossing=requested
	state="walking"
	var direction := target-position
	direction.y=0
	direction=direction.normalized()
	var side := Vector3(-direction.z,0,direction.x)
	if crossing!="":
		# Opposing walkers retain separate lanes inside the crossing. Aiming both
		# at its centreline can lock their capsules together and hold all traffic.
		var start: Vector3=CityPopulation.POINTS[from_node]
		var axis := (target-start).normalized()
		var lane_side := Vector3(-axis.z,0,axis.x)
		var lateral := (position-start).dot(lane_side)
		direction=(axis+lane_side*clampf((.4-lateral)*2.8,-1,1)).normalized()
	else:
		# Keep to one side of shared paths and steer around actual nearby bodies.
		var lane_target := target+side*.4
		direction=(lane_target-position).normalized()
		for other in population.residents+[game.player]:
			if other==self: continue
			var away: Vector3=position-other.position
			away.y=0
			if away.length()>.01 and away.length()<1.3 and direction.dot(-away.normalized())>.05:
				direction=(direction+side*clampf((1.3-away.length())*2,0,1.5)).normalized()
		# Static or parked obstacles can be skirted only when the swept alternate is clear.
		if test_move(transform,direction*1.0):
			var alternate := (direction+side*1.8).normalized()
			if not test_move(transform,alternate*1.0): direction=alternate
			else:
				alternate=(direction-side*1.8).normalized()
				if not test_move(transform,alternate*1.0): direction=alternate
				else: velocity=Vector3.ZERO; return
	velocity=direction*(2.8 if fear>0 else 1.5+index%3*.08)

func avoid(threat: Vector3) -> void:
	if game.meals: game.meals.cancel(stable_id)
	if game.commons: game.commons.release(self)
	fear=20.0
	if game.speaker==self: game.close_interaction()
	if game.passengers:
		if game.passengers.aboard(self): game.passengers.trips[stable_id].early_exit=true;return
		game.passengers.cancel_wait(self)
	if crossing=="" and available(): plan(population.refuge(self,threat))

func hit(direction: Vector3,strength: float,action: int,dangerous: bool=true) -> void:
	if hp==0 or action==last_hit or not dangerous and not available(): return
	if game.meals: game.meals.cancel(stable_id)
	if game.commons: game.commons.release(self)
	if game.passengers:
		if game.passengers.aboard(self): game.passengers.trips[stable_id].early_exit=true
		else: game.passengers.cancel_wait(self)
	last_hit=action
	hits+=1
	apologized=false
	hp=maxi(0 if dangerous else 1,hp-roundi(strength*24))
	if hp<=1: down=12.0 if hp>0 else 0.0
	if game.speaker==self: game.close_interaction()
	if hp==0:
		state="dead"
		game.career.record("death_"+stable_id,title.split(" · ")[0]+"在街区冲突中死亡，原居民不会复活。")
	else: avoid(position-direction*3)
	population.alarm(self,action)
	if game.response: game.response.alarm(self)
	game.say(title.split(" · ")[0]+("已死亡。" if hp==0 else "受伤倒地。" if down>0 else "：停手！"))
	game.queue_save()

func snapshot() -> Dictionary:
	return {"position":SaveGame.vector(position),"yaw":wrapf(visual.rotation.y,-PI,PI),"state":state,"destination":destination,"from_node":from_node,"route":route.duplicate(),"crossing":crossing,"activity_left":activity_left,"phase":phase,"journey":journey,"visits":visits.duplicate(),"hp":hp,"down":down,"fear":fear,"hits":hits,"witnessed":witnessed,"met":met,"apologized":apologized,"conversations":conversations}

func valid(data: Variant,on_bus: bool=false) -> bool:
	if not data is Dictionary or not SaveGame.valid_vector(data.get("position")): return false
	var point := SaveGame.unvector(data.position)
	if not CityLayout.BOUNDS.has_point(Vector2(point.x,point.z)) or absf(point.y-(.4 if on_bus else 0.0))>.1: return false
	if not data.get("state") in ["activity","walking","waiting","talking","fallen","dead","riding"]: return false
	if not data.get("destination") in CityPopulation.POINTS or not data.get("from_node") in CityPopulation.POINTS: return false
	if not data.get("route") is Array or data.route.size()>CityPopulation.POINTS.size() or not data.get("visits") is Array or data.visits.size()>CityPopulation.POINTS.size(): return false
	var previous: String=data.from_node
	for id in data.route:
		if not id in CityPopulation.POINTS or id!=previous and not population.graph.are_points_connected(population.point_ids.find(previous),population.point_ids.find(id)): return false
		previous=id
	if not data.route.is_empty() and data.route[-1]!=data.destination: return false
	var seen := {}
	for id in data.visits:
		if not id in CityPopulation.POINTS or seen.has(id): return false
		seen[id]=true
	if not data.get("crossing") is String: return false
	if data.crossing!="" and (not data.crossing in CityPopulation.CROSSINGS or data.route.is_empty() or population.crossing_for(data.from_node,data.route[0])!=data.crossing): return false
	for key in ["met","apologized"]:
		if not data.get(key) is bool: return false
	for limits in [["yaw",-PI,PI,false],["activity_left",0,60,false],["phase",-1,3,true],["journey",0,1000000,true],["hp",0,100,true],["down",0,12,false],["fear",0,20,false],["hits",0,1000000,true],["witnessed",0,1000000,true],["conversations",0,1000000,true]]:
		if not CityPopulation.number(data.get(limits[0]),limits[1],limits[2],limits[3]): return false
	return (data.hp!=0 or data.state=="dead") and (data.state!="dead" or data.hp==0)

func restore(data: Dictionary) -> void:
	velocity=Vector3.ZERO
	last_hit=-1
	last_alarm=-1
	stuck=0
	if data.is_empty():
		position=CityPopulation.POINTS[CityPopulation.PROFILES[index][3]]+Vector3(.65 if index%2==0 else -.65,0,.6)
		from_node=CityPopulation.PROFILES[index][3]
		destination=from_node
		route.clear(); visits.clear()
		crossing=""
		state="activity"
		phase=-1; journey=0; hp=100; down=0; fear=0; hits=0; witnessed=0; conversations=0
		met=false; apologized=false
		activity_left=2.0+index*1.4
		visual.rotation=Vector3.ZERO
		update_body()
		return
	position=SaveGame.unvector(data.position)
	visual.rotation.y=data.yaw
	for key in ["state","destination","from_node","crossing","activity_left","phase","journey","hp","down","fear","hits","witnessed","met","apologized","conversations"]: set(key,data[key])
	route.assign(data.route)
	visits.assign(data.visits)
	if state=="talking": state="walking" if not route.is_empty() else "activity"
	update_body()

func make_pastime_book() -> void:
	pastime_book=Node3D.new()
	add_child(pastime_book)
	Shapes.box(pastime_book,Vector3(.36,.018,.25),Vector3.ZERO,Color("477473"))
	Shapes.box(pastime_book,Vector3(.34,.014,.23),Vector3(0,.013,0),Color("e4d8b9"))
	Shapes.box(pastime_book,Vector3(.004,.004,.22),Vector3(0,.023,0),Color("786c59"))
	for side in [-1,1]:
		for line in range(6): Shapes.box(pastime_book,Vector3(.12,.002,.004),Vector3(side*.085,.023,-.07+line*.025),Color("776e5e"))
	pastime_book.hide()

func sync_pastime_book() -> void:
	if game.city_life and game.city_life.performance: game.city_life.performance.apply(self)
	if game.meals: game.meals.scene.apply(self)
	if not pastime_book or not game.commons: return
	if game.commons.sitting(self) and not game.commons.reading(self):
		var other: Node3D=game.player if game.speaker==self else game.commons.companion(self)
		if other:
			var toward := visual.to_local(other.global_position)-visual.to_local(global_position)
			var head := visual.skeleton.find_bone("head")
			var turn := clampf(atan2(-toward.x,-toward.z),-.5,.5)
			visual.skeleton.set_bone_pose_rotation(head,visual.skeleton.get_bone_pose_rotation(head)*Quaternion(Vector3.UP,turn))
	pastime_book.visible=game.commons.reading(self) and visual.current=="read"
	if not pastime_book.visible: return
	pastime_book.global_transform=visual.global_transform*Transform3D(Basis(Vector3.RIGHT,.35),Vector3(0,visual.standing_height*.65,-.36))
	for side in ["L","R"]:
		var support := Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),Vector3(-.13 if side=="L" else .13,-.015,0))
		visual.contacts.reach(side,pastime_book.global_transform*support)
		visual.contacts.fingers(side,.10)

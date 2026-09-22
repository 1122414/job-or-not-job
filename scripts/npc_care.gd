class_name NPCCare
extends RefCounted
var game: Node3D
var crews := {}

func clear() -> void:
	for crew in crews.values(): crew.queue_free()
	crews.clear()

func build_crew(npc: OfficeNPC) -> Node3D:
	var crew := Node3D.new()
	game.add_child(crew)
	crew.position=npc.rescue_position
	Shapes.box(crew,Vector3(0.52,0.07,1.9),Vector3(0,0.63,0),Color("547c82"))
	for side in [-1,1]:
		var person := HumanVisual.new()
		person.outfit="office"
		person.personality="medic"
		person.carrying=true
		crew.add_child(person)
		person.position.z=side*1.15
		person.pose(2.0,false,false,false,false)
	crews[npc.stable_id]=crew
	return crew

func tick(delta: float) -> void:
	for npc in game.npcs:
		if npc.dead:
			if crews.has(npc.stable_id): crews[npc.stable_id].queue_free(); crews.erase(npc.stable_id)
			continue
		if npc.care_state=="away":
			if game.payroll.minute>=npc.return_minute:
				npc.care_state="awake"
				npc.hp=100
				npc.down=0
				npc.position=game.safe_spawn(Vector3(-14 if npc.company=="a" else 14,0,3))
				npc.sync_care()
				npc.mood="已返岗，暂时不想谈私事"
				game.say(npc.title.split(" · ")[0]+"已返岗 · 受伤经历与关系保留")
				game.queue_save()
			continue
		if npc.care_state not in ["unconscious","carried"]: continue
		npc.care_elapsed+=delta
		if npc.care_elapsed<5: continue
		var crew: Node3D=crews.get(npc.stable_id)
		if not is_instance_valid(crew):
			crew=build_crew(npc)
			game.say("救助人员已到入口，正在接近伤者")
		var previous_position: Vector3=crew.position
		var exit_point := Vector3(-14 if npc.company=="a" else 14,0,4)
		var target: Vector3=exit_point if npc.care_state=="carried" else npc.position
		if npc.care_state=="unconscious" and crew.position.distance_to(target)<1.5 and game.walking.clear_segment(crew.position,target):
			npc.care_state="carried"
			crew.set_meta("route_clock",0.0)
			npc.hostile=0
			npc.sync_care()
			game.say(npc.title.split(" · ")[0]+"已由救助人员接走，将在次日上午返岗")
			game.queue_save()
		if npc.care_state=="carried" and crew.position.distance_to(exit_point)<0.35:
			npc.care_state="away"
			npc.return_minute=(game.payroll.minute/1440+1)*1440+9*60
			npc.sync_care()
			crew.queue_free()
			crews.erase(npc.stable_id)
			game.queue_save()
			continue
		# Replan against moved furniture; blocked corridors wait for clearance, never teleport.
		var clock: float=crew.get_meta("route_clock",0.0)-delta
		var path: PackedVector3Array=crew.get_meta("route",PackedVector3Array())
		if clock<=0:
			path=game.walking.route(crew.position,target)
			clock=0.8
		while not path.is_empty() and crew.position.distance_to(path[0])<0.12: path.remove_at(0)
		if not path.is_empty():
			var next: Vector3=crew.position.move_toward(path[0],delta*1.5)
			if game.walking.clear_segment(crew.position,next):
				var direction: Vector3=next-crew.position
				if direction.length()>0.001: crew.rotation.y=lerp_angle(crew.rotation.y,atan2(-direction.x,-direction.z),delta*6)
				crew.position=next
		for child in crew.get_children():
			if child is HumanVisual: child.pose(crew.position.distance_to(previous_position)/maxf(delta,0.001),false,false)
		crew.set_meta("route",path)
		crew.set_meta("route_clock",clock)
		npc.rescue_position=crew.position
		if npc.care_state=="carried":
			npc.position=crew.position+Vector3(0,0.65,-0.75*npc.fall_side).rotated(Vector3.UP,crew.rotation.y)
			npc.visual.rotation.y=crew.rotation.y+PI/2
			npc.visual.rotation.z=npc.fall_side*PI/2
			npc.visual.position.y=0.27
			npc.visual.pose(0,false,true,false,false)

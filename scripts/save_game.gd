class_name SaveGame
extends RefCounted

const VERSION := 7
const BASE_NPCS := ["a_hr","a_lead","a_boss","a_friend","a_group","a_guard","b_hr","b_friend","b_boss","b_guard"]
const LEGACY_PROPS := ["a_keyboard","a_cup","a_table","a_chair","a_printer","b_keyboard","b_cup","b_table","b_chair","b_printer"]
const PATH := "user://neighborhood.json"
const CAREER_FIELDS := ["recruit","employer","grade","stage","facts","records","former","conflict","warning_action","seen_actions","b_event"]
const PAYROLL_FIELDS := ["minute","fraction","next_payday","balance","pending","payments"]

static func vector(v: Vector3) -> Array:
	return [v.x,v.y,v.z]

static func unvector(v: Array) -> Vector3:
	return Vector3(v[0],v[1],v[2])

static func fields(object: RefCounted, names: Array) -> Dictionary:
	var result := {}
	for name in names: result[name]=object.get(name)
	return result.duplicate(true)

static func snapshot(game: Node3D) -> Dictionary:
	var data := {"version":VERSION,"career":fields(game.career,CAREER_FIELDS),"payroll":fields(game.payroll,PAYROLL_FIELDS),"action_counter":game.action_counter,"props":{},"npcs":{},"player":{"position":vector(game.player.position),"yaw":game.player.yaw,"pitch":game.player.pitch,"hp":game.player.hp,"protection":game.player.protection},"shake":game.shake_enabled,"staffing":game.staffing.calm.duplicate(),"interviews":game.interviews.sessions.duplicate(true)}
	for prop in game.props:
		var location := "held" if game.player.held==prop else "bag" if game.player.inventory.has(prop) else "world"
		data.props[prop.stable_id]={"position":vector(prop.position),"rotation":vector(prop.rotation),"location":location,"damaged":prop.damaged,"durability":prop.durability,"tipped":prop.tipped}
	for npc in game.npcs:
		data.npcs[npc.stable_id]={"position":vector(npc.position),"affinity":npc.affinity,"mood":npc.mood,"down":npc.down,"fall_side":npc.fall_side,"facing":npc.visual.rotation.y,"hostile":npc.hostile,"hp":npc.hp,"dead":npc.dead,"role_id":npc.role_id,"title":npc.title,"company":npc.company,"role":npc.role,"home":vector(npc.home)}
	return data

static func valid_vector(value: Variant) -> bool:
	if not value is Array or value.size()!=3: return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)) or absf(number)>1000: return false
	return true

static func valid(data: Variant, game: Node3D) -> bool:
	if not data is Dictionary: return false
	if data.get("version")!=1 and data.get("version")!=2 and data.get("version")!=3 and data.get("version")!=4 and data.get("version")!=5 and data.get("version")!=6 and data.get("version")!=VERSION: return false
	for field in ["career","payroll","props","npcs","player"]:
		if not data.get(field) is Dictionary: return false
	for field in CAREER_FIELDS:
		if not data.career.has(field): return false
	for field in PAYROLL_FIELDS:
		if not data.payroll.has(field): return false
	var c: Dictionary = data.career
	var p: Dictionary = data.payroll
	if not c.employer in ["","a","b"] or not c.stage is float and not c.stage is int: return false
	if c.stage<0 or c.stage>6 or not c.grade is String or not c.b_event is String: return false
	for key in ["recruit","facts","conflict","warning_action","seen_actions"]:
		if not c[key] is Dictionary: return false
	for key in ["records","former"]:
		if not c[key] is Array: return false
		for entry in c[key]:
			if not entry is String: return false
	for key in ["minute","fraction","next_payday","balance"]:
		if not (p[key] is int or p[key] is float) or not is_finite(p[key]) or p[key]<0: return false
	if p.next_payday<=p.minute or not p.payments is Array or not p.pending is Dictionary: return false
	for firm in ["a","b"]:
		for key in ["recruit","conflict","warning_action"]:
			if not (c[key].get(firm) is float or c[key].get(firm) is int): return false
		if c.conflict[firm]<0 or c.conflict[firm]>3 or c.recruit[firm]<0 or c.recruit[firm]>3: return false
		if not c.seen_actions.get(firm) is Array: return false
		if not (p.pending.get(firm) is float or p.pending.get(firm) is int) or p.pending[firm]<0: return false
	var payment_ids := {}
	for payment in p.payments:
		if not payment is Dictionary or not payment.get("id") is String or not payment.get("company") in ["a","b"]: return false
		if not payment.has("cents") or not (payment.cents is float or payment.cents is int) or payment.cents<0: return false
		if payment_ids.has(payment.id): return false
		payment_ids[payment.id]=true
	if not valid_vector(data.player.get("position")): return false
	for key in ["yaw","pitch","hp","protection"]:
		if not (data.player.get(key) is float or data.player.get(key) is int) or not is_finite(data.player[key]): return false
	if data.player.hp<0 or data.player.hp>100: return false
	if not (data.get("action_counter") is float or data.get("action_counter") is int): return false
	for id in BASE_NPCS:
		if not data.npcs.has(id): return false
	if data.version<5 and data.npcs.size()!=BASE_NPCS.size(): return false
	if data.version>=5:
		if not data.get("staffing") is Dictionary: return false
		for firm in ["a","b"]:
			var calm: Variant=data.staffing.get(firm)
			if not (calm is float or calm is int) or not is_finite(calm) or calm<0: return false
	if data.version>=2 and data.props.size()!=game.props.size(): return false
	var known := {}
	for prop in game.props: known[prop.stable_id]=true
	for id in data.props:
		if not known.has(id): return false
	for id in LEGACY_PROPS:
		if not data.props.has(id): return false
	var held_count := 0
	for prop in game.props:
		if data.version==1 and not data.props.has(prop.stable_id): continue
		var entry: Variant = data.props.get(prop.stable_id)
		if not entry is Dictionary: return false
		if not valid_vector(entry.get("position")) or not valid_vector(entry.get("rotation")): return false
		if not entry.get("location") in ["world","held","bag"] or not entry.get("damaged") is bool: return false
		if entry.location!="world" and not prop.portable(): return false
		var durability: Variant=entry.get("durability",0.0 if entry.damaged else prop.max_durability())
		if not (durability is float or durability is int) or not is_finite(durability) or durability<0 or durability>prop.max_durability(): return false
		if data.version>=4 and (not entry.has("durability") or entry.damaged!=(durability==0) or not entry.get("tipped") is bool): return false
		if entry.location=="held": held_count+=1
	if held_count>1: return false
	for id in data.npcs:
		var entry: Variant = data.npcs[id]
		if not entry is Dictionary or not valid_vector(entry.get("position")) or not entry.get("mood") is String: return false
		if data.version>=5:
			if not entry.get("role_id") in BASE_NPCS or not valid_vector(entry.get("home")) or not entry.get("title") is String: return false
			var role_id: String=entry.role_id
			if entry.get("company")!=role_id.substr(0,1) or entry.get("role")!=role_id.substr(2): return false
			if id!=role_id:
				var prefix := role_id+"_replacement_"
				if not id.begins_with(prefix) or not id.trim_prefix(prefix).is_valid_int() or int(id.trim_prefix(prefix))<1: return false
		if not entry.get("dead",false) is bool: return false
		var health: Variant=entry.get("hp",100)
		if not (health is int or health is float) or not is_finite(health) or health<0 or health>100: return false
		if entry.get("dead",false)!=(health==0): return false
		if data.version>=7:
			if not (entry.get("fall_side") is float or entry.get("fall_side") is int): return false
			if entry.fall_side!=1 and entry.fall_side!=-1: return false
			if not (entry.get("facing") is float or entry.get("facing") is int) or not is_finite(entry.facing): return false
		for key in ["affinity","down","hostile"]:
			if not (entry.get(key) is float or entry.get(key) is int) or not is_finite(entry[key]): return false
	if data.version>=6:
		if not data.get("interviews") is Dictionary: return false
		for firm in data.interviews:
			var session: Variant=data.interviews[firm]
			if not firm in ["a","b"] or not session is Dictionary: return false
			if not session.get("action") in InterviewFlow.ACTIONS or (firm=="b")!=(session.action=="interview_b"): return false
			if not session.get("status") in ["scheduled","active","completed"] or not session.get("phase") in ["question","reply"]: return false
			for key in ["step","reply"]:
				var value: Variant=session.get(key)
				if not (value is int or value is float) or not is_finite(value) or value!=int(value) or value<0: return false
			if session.step>6 or session.reply>2 or not session.get("answers") is Array: return false
			if session.answers.size()!=int(session.step)+(1 if session.phase=="reply" else 0): return false
			for answer in session.answers:
				if not answer is String: return false
	var occupied := {}
	for id in data.npcs:
		var entry: Dictionary=data.npcs[id]
		if entry.get("dead",false): continue
		var role_id: String=entry.get("role_id",id)
		if occupied.has(role_id): return false
		occupied[role_id]=true
	return true

static func read(path: String, game: Node3D) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("checksum") is String: return {}
	if envelope.payload.sha256_text()!=envelope.checksum: return {}
	if parser.parse(envelope.payload)!=OK: return {}
	var data: Variant = parser.data
	return data if valid(data,game) else {}

static func write(game: Node3D, path: String = PATH) -> Error:
	var data := snapshot(game)
	if not valid(data,game): return ERR_INVALID_DATA
	var payload := JSON.stringify(data)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"payload":payload,"checksum":payload.sha256_text()}))
	file.flush()
	file.close()
	if read(path+".tmp",game).is_empty(): return ERR_FILE_CORRUPT
	if not read(path,game).is_empty():
		var error := DirAccess.copy_absolute(path,path+".bak")
		if error!=OK: return error
	elif FileAccess.file_exists(path):
		var error := DirAccess.copy_absolute(path,path+".corrupt-"+str(Time.get_unix_time_from_system()))
		if error!=OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)

static func restore(game: Node3D, data: Dictionary) -> bool:
	if not valid(data,game): return false
	game.restore_revision+=1
	game.close_interaction()
	game.office.preview_station=null
	game.office.preview_elapsed=0
	game.focus_target=null
	for npc in game.npcs.duplicate():
		if not data.npcs.has(npc.stable_id):
			game.npcs.erase(npc)
			npc.get_parent().remove_child(npc)
			npc.queue_free()
	for id in data.npcs:
		var exists := false
		for npc in game.npcs:
			if npc.stable_id==id: exists=true
		if not exists:
			var entry: Dictionary=data.npcs[id]
			game.add_npc(id,entry.title,unvector(entry.position),entry.company,entry.role,entry.role_id)
	game.staffing.calm=data.get("staffing",{"a":0.0,"b":0.0}).duplicate()
	game.interviews.sessions=data.get("interviews",{}).duplicate(true)
	game.interviews.interrupt()
	game.player.inventory.clear()
	game.player.held=null
	for pair in [[game.career,CAREER_FIELDS,data.career],[game.payroll,PAYROLL_FIELDS,data.payroll]]:
		for field in pair[1]:
			if pair[0].get(field) is Array: pair[0].get(field).assign(pair[2][field])
			else: pair[0].set(field,pair[2][field])
	if data.version<5:
		for firm in ["a","b"]:
			if game.career.facts.has("fatal_"+firm):
				game.career.facts.erase("fatal_"+firm)
				game.career.conflict[firm]=mini(3,game.career.seen_actions[firm].size())
	game.action_counter=int(data.action_counter)
	game.shake_enabled=data.get("shake",true)
	for prop in game.props:
		var entry: Dictionary = data.props.get(prop.stable_id,{"position":vector(prop.home),"rotation":[0,0,0],"location":"world","damaged":false})
		prop.position=unvector(entry.position)
		if data.version<3 and prop.anchored(): prop.position.y=prop.home.y
		if data.version<6 and "_-11" in prop.stable_id and prop.position.distance_to(prop.home-Vector3(0,0,1.5))<0.6:
			prop.position.z+=1.5
		prop.rotation=unvector(entry.rotation)
		prop.linear_velocity=Vector3.ZERO
		prop.angular_velocity=Vector3.ZERO
		prop.thrown=false
		prop.hits.clear()
		prop.damaged=entry.damaged
		prop.durability=float(entry.get("durability",0.0 if entry.damaged else prop.max_durability()))
		prop.tipped=entry.get("tipped",false)
		prop.last_damage_action=-1
		prop.apply_damage_state()
		prop.label.text=prop.title+(" · 已损坏" if prop.damaged else "")
		prop.freeze=prop.anchored() or entry.location!="world"
		prop.collision_layer=prop.world_layer() if entry.location=="world" else 0
		prop.collision_mask=3 if entry.location=="world" else 0
		prop.visible=entry.location!="bag"
		if entry.location=="bag": game.player.inventory.append(prop)
		elif entry.location=="held": game.player.held=prop
	for npc in game.npcs:
		var entry: Dictionary = data.npcs[npc.stable_id]
		npc.position=unvector(entry.position)
		npc.home=unvector(entry.get("home",vector(npc.home)))
		if data.version<6 and npc.role=="hr":
			var previous_home: Vector3=npc.home
			npc.home=OfficeRooms.RECEPTIONS[npc.company]+Vector3(0,0,-0.85)
			if npc.position.distance_to(previous_home)<0.6: npc.position=npc.home
		if data.version<6 and absf(npc.home.z+9.9)<0.1:
			var old_home: Vector3=npc.home
			npc.home.z+=1.5
			if npc.position.distance_to(old_home)<0.6: npc.position.z+=1.5
		npc.visit_wait=0
		npc.reaction=0
		npc.stuck_time=0
		npc.affinity=int(entry.affinity)
		npc.mood=entry.mood
		npc.hp=int(entry.get("hp",100))
		npc.dead=entry.get("dead",false)
		npc.down=maxf(0,entry.down)
		npc.fall_side=float(entry.get("fall_side",1.0))
		npc.visual.rotation.y=float(entry.get("facing",0.0))
		npc.visual.rotation.z=npc.fall_side*PI/2 if npc.down>0 or npc.dead else 0.0
		npc.body_pose=""
		npc.hit_stun=0

		npc.hostile=maxf(0,entry.hostile)
		npc.velocity=Vector3.ZERO
		npc.last_hit=-1
		npc.route.clear()
		npc.route_clock=0
	game.player.position=unvector(data.player.position)
	game.player.yaw=data.player.yaw
	game.player.pitch=data.player.pitch
	game.player.hp=int(data.player.hp)
	game.player.protection=maxf(1,data.player.protection)
	game.player.seated=false
	if game.player.seat_body:
		game.player.remove_collision_exception_with(game.player.seat_body)
		game.player.seat_body=null
	game.player.dead=0
	game.player.bag_open=false
	game.player.bag_page=0
	game.navigation_dirty=0.1
	game.player.cooldown=0
	game.player.swing=0
	game.player.velocity=Vector3.ZERO
	game.player.visual.rotation.z=0
	if game.player.hp==0: game.player.respawn()
	for station in game.stations:
		if station.stable_id=="backup": station.label.text="投影已恢复 · 成果已记录" if game.career.facts.has("output_two") else station.title
	if data.version<6: game.call_deferred("repair_migrated_positions",game.restore_revision)
	return true

static func archives(directory: String = "user://restarts") -> Array[String]:
	var result: Array[String]=[]
	if not DirAccess.dir_exists_absolute(directory): return result
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".json"): result.append(directory.path_join(filename))
	result.sort()
	result.reverse()
	return result

static func archive(game: Node3D, directory: String = "user://restarts") -> String:
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return ""
	var stamp := "%020d-%016d" % [int(Time.get_unix_time_from_system()*1000000),Time.get_ticks_usec()]
	var path := directory.path_join(stamp+".json")
	if write(game,path)!=OK: return ""
	return path if not read(path,game).is_empty() else ""

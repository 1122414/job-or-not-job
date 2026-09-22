class_name OfficeLife
extends RefCounted

var game: Node3D
var preview_station: WorkStation
var preview_elapsed := 0.0
const PREVIEW_SECONDS := 3.0
const DESKS := {"desk_a":Vector3(-8,0,-0.9),"desk_a2":Vector3(-14,0,-13.5),"desk_b":Vector3(20,0,-0.9)}

func assigned_desk() -> String:
	if game.career.employer=="b": return "desk_b"
	if game.career.employer=="a": return "desk_a2" if game.career.stage>=4 else "desk_a"
	return ""

func offers() -> Array:
	var c: Career=game.career
	return [
		["welcome_a","a_hr","林岚：你的工位在右侧第一排。过去看看，周工会来说明第一份工作。",c.employer=="a" and c.stage==1 and not c.facts.has("desk_a_arrived")],
		["visit_brief","a_lead","周工：我过来跟你说演示的事。准备好了就聊；你也可以先看看资料。",c.employer=="a" and c.facts.has("desk_a_arrived") and c.stage==1 and not c.facts.has("brief")],
		["visit_review","a_lead","周工：你的演示已经通过。我来跟你说明这次转正名额的情况。",c.employer=="a" and c.stage==2],
		["visit_group","a_group","许姐：后方中间是你的新工位。上次成果保留，这次只处理现场投影。",c.employer=="a" and c.stage==4],
		["visit_defense","a_boss","方总：两份成果都收到了。你准备好后可以直接找我答辩。",c.employer=="a" and c.stage==5],
		["welcome_b","b_friend","阿乐：右侧第一排的终端给你用。我来帮你安顿，顺便聊聊今晚的交接。",c.employer=="b" and c.b_event=="pending"]
	]

func visit() -> Dictionary:
	var c: Career=game.career
	if c.employer=="" or game.payroll.after_work() or c.conflict[c.employer]>=2: return {}
	for item in offers():
		if item[3] and not c.facts.has(item[0]): return {"key":item[0],"npc":item[1],"line":item[2]}
	return {}

func pending_visits() -> Array[Dictionary]:
	var pending: Array[Dictionary]=[]
	for item in offers():
		if not game.career.facts.has(item[0]) and game.career.facts.get("visit_state_"+item[0],"") in ["arrived","deferred"]:
			pending.append({"key":item[0],"npc":item[1],"line":item[2]})
	return pending

func offer_for(npc: OfficeNPC) -> Dictionary:
	var current := visit()
	if current.get("npc")==npc.role_id: return current
	for pending in pending_visits():
		if pending.npc==npc.role_id: return pending
	return {}

func visit_target(npc: OfficeNPC) -> Variant:
	var offer := visit()
	if offer.is_empty() or offer.npc!=npc.role_id or game.career.facts.get("visit_state_"+offer.key,"")=="deferred": return null
	var p: OfficePlayer=game.player
	if p.dead>0 or npc.dead or npc.hostile>0 or npc.down>0: return null
	# Visitors wait in their own workplace if the player leaves; no cross-company pursuit.
	if p.position.z>1.5 or p.position.z< -15.5 or absf(p.position.x-(-14 if npc.company=="a" else 14))>11: return null
	var center := -14.0 if npc.company=="a" else 14.0
	var side := -1.0 if p.position.x>center else 1.0
	return Vector3(p.position.x+side*1.8,0,clampf(p.position.z,-14.5,0.3))

func tick(delta: float = 0.0) -> void:
	tick_preview(delta)
	var offer := visit()
	if offer.is_empty() or not game.conversation.is_empty(): return
	for npc in game.npcs:
		if npc.role_id!=offer.npc or visit_target(npc)==null: continue
		if npc.position.distance_to(game.player.position)<2.8 and game.can_see(npc,game.player):
			if game.career.facts.get("visit_state_"+offer.key,"")!="arrived":
				game.career.facts["visit_state_"+offer.key]="arrived"
				npc.visit_wait=25.0
				game.say(npc.title.split(" · ")[0]+"来找你了 · E交谈，也可稍后再聊")
				game.queue_save()

func desk_choices(station: WorkStation) -> Dictionary:
	if station.stable_id!=assigned_desk():
		return {"text":"工位尚未分配给你。可以先面试，或去另一家公司看看。","choices":[]}
	var choices: Array=[["坐下查看工作资料（随时移动起身）","desk_open"]]
	if game.career.employer=="a" and game.career.stage==1 and game.career.facts.has("data"):
		choices.append(["整理已有资料并预览演示包","prepare"])
	return {"text":"你的工位 / "+game.career.grade,"choices":choices}

func open_desk(station: WorkStation) -> void:
	if station.stable_id!=assigned_desk(): return
	var key: String=station.stable_id+"_arrived"
	game.career.record(key,"已在自己的工位安顿："+game.career.grade)
	game.player.sit_at(station.position)
	game.say("已在工位坐下。移动、跳跃或动手立即起身；同事会过来找你。")
	game.queue_save()

func visit_choices(npc: OfficeNPC, fallback: Dictionary) -> Dictionary:
	var offer := offer_for(npc)
	if offer.is_empty() or offer.npc!=npc.role_id: return fallback
	return {"text":OfficeDialogue.voice(npc,offer.line),"choices":[["我准备好了，继续说","visit_confirm"],["稍后再聊，我会来找你","visit_defer"]]}

func answer_visit(npc: OfficeNPC, confirm: bool) -> void:
	var offer := offer_for(npc)
	if offer.is_empty() or offer.npc!=npc.role_id: return
	game.career.facts["visit_state_"+offer.key]="completed" if confirm else "deferred"
	if confirm:
		game.career.record(offer.key,OfficeDialogue.voice(npc,offer.line))
		var action: String={"visit_brief":"brief","visit_review":"no_hc"}.get(offer.key,"")
		if action!="": game.say(game.career.apply(action))
		else: game.say(OfficeDialogue.voice(npc,offer.line))
	else: game.say("已记下待交谈事项，可通过目标找到对方继续。")
	npc.visit_wait=0
	game.queue_save()

func start_preview(station: WorkStation) -> void:
	if station.stable_id!=assigned_desk() or game.career.employer!="a" or game.career.stage!=1 or not game.career.facts.has("data"): return
	open_desk(station)
	preview_station=station
	preview_elapsed=0
	game.say("正在运行演示预览 · 可移动起身中断")

func tick_preview(delta: float) -> void:
	if not is_instance_valid(preview_station): return
	if not game.player.seated or game.player.dead>0 or game.career.employer!="a" or game.career.stage!=1 or game.player.position.distance_to(preview_station.position)>0.6:
		preview_station=null
		preview_elapsed=0
		game.say("预览已中断，资料保留，可回工位重新运行。")
		return
	preview_elapsed+=delta
	if preview_elapsed>=PREVIEW_SECONDS:
		preview_station=null
		game.say(game.career.apply("prepare"))
		game.queue_save()

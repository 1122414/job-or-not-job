class_name Onboarding
extends RefCounted
var game: Node3D
var tour := {}

func active() -> bool:
	return not tour.is_empty() and tour.get("phase")!="done" and tour.get("firm")==game.career.employer

func guide() -> OfficeNPC:
	return game.npc_for_role("a_hr" if tour.get("firm")=="a" else "b_friend")

func start(firm: String) -> void:
	if game.career.facts.has("tour_done_"+firm): return
	tour={"firm":firm,"phase":"offered","paused":false}
	game.say("入职手续已办好 · 找"+("林岚" if firm=="a" else "阿乐")+"带你认识同事和工位，也可自行探索")
	game.queue_save()

func destination() -> Vector3:
	if tour.get("phase")=="leading": return Vector3(-11,0,-3.1) if tour.firm=="a" else Vector3(8.5,0,-4)
	return Vector3(-10,0,0.2) if tour.get("firm")=="a" else Vector3(18,0,0.2)

func npc_target(npc: OfficeNPC) -> Variant:
	if not active() or npc!=guide() or not npc.available(): return null
	if tour.paused or tour.phase in ["offered","introduce","desk"]: return npc.position
	if npc.position.distance_to(game.player.position)>5 or game.speaker==npc: return npc.position
	return destination()

func options(npc: OfficeNPC) -> Dictionary:
	if not active() or npc!=guide(): return {}
	if tour.paused: return {"text":"刚才说到一半。还需要我继续带你吗？","choices":[["继续带我看看","tour_resume"],["我自己先逛逛","tour_pause"],["先说工作上的事","people_work"]]}
	match tour.phase:
		"offered": return {"text":"手续办好了。我带你认一下同事和自己的工位，走一小段就到。","choices":[["好，麻烦带一下路","tour_begin"],["我先自己看看，稍后再来","tour_pause"]]}
		"introduce":
			return {"text":"这是小夏，你邻座的同事。原始资料有疑问可以问他；第一份成果由周工验收。" if tour.firm=="a" else "我叫阿乐，就坐在这里。设备不熟可以问我；交接的事也可以商量，不用现在就答应。","choices":[["打个招呼，认识一下","tour_greet"],["我先忙别的，稍后继续","tour_pause"]]}
		"desk": return {"text":"这张是你的工位。你可以坐下看资料，其他事情等你安顿好再聊。","choices":[["明白了，我去坐下看看","tour_settle"],["稍后再安顿","tour_pause"]]}
	return {"text":"跟我来，我会等你。要先逛逛也没关系。","choices":[["继续走","tour_continue"],["先自己探索，暂停带领","tour_pause"]]}

func handle(action: String) -> bool:
	if not action.begins_with("tour_"): return false
	if not active(): return true
	match action:
		"tour_begin": tour.phase="leading"; tour.paused=false
		"tour_pause": tour.paused=true
		"tour_resume": tour.paused=false
		"tour_greet":
			var friend: OfficeNPC=game.npc_for_role(tour.firm+"_friend")
			if not friend or not friend.available(): game.say("同事暂时不在，返岗后可以再认识。工位先给你安排好。"); tour.phase="to_desk"
			else:
				game.social.meet(friend)
				game.social.remember(friend,"onboard","入职时，你们在工位旁正式打过招呼。",4,3)
				game.say(friend.title.split(" · ")[0]+"：欢迎。工作不懂可以问，先慢慢熟悉这里。")
				tour.phase="to_desk"
		"tour_settle": tour.phase="settling"
	game.close_interaction()
	game.queue_save()
	return true

func objective() -> Dictionary:
	if not active(): return {}
	var npc := guide()
	if not npc: return {"title":"入职引导暂缓 · 等待岗位接替后继续","id":""}
	if not npc.available(): return {"title":"带领者正在休养 · 返岗后继续，也可先去自己的工位","id":game.office.assigned_desk()}
	if tour.paused: return {"title":"自由探索 · 找"+npc.title.split(" · ")[0]+"可继续入职带领","id":npc.role_id}
	if tour.phase=="settling": return {"title":"到自己的工位坐下，查看第一份工作","id":game.office.assigned_desk()}
	return {"title":{"offered":"找带领者认识同事与工位","leading":"跟随带领者，认识邻座同事","introduce":"到了 · E认识同事","to_desk":"跟随带领者前往自己的工位","desk":"到了 · E确认自己的工位"}.get(tour.phase,"继续入职引导"),"id":npc.role_id}

func tick() -> void:
	if not active(): return
	var npc := guide()
	if not npc or not npc.available() or tour.paused: return
	if tour.phase in ["leading","to_desk"] and npc.position.distance_to(destination())<0.7:
		tour.phase="introduce" if tour.phase=="leading" else "desk"
		game.say("到了 · 靠近带领者按E继续，也可以稍后再聊")
		game.queue_save()

func settled() -> void:
	if not active(): return
	game.career.record("tour_done_"+tour.firm,"已在新工位安顿，带领过程结束。")
	game.career.record("welcome_"+tour.firm,"已完成入职安顿。")
	tour.phase="done"
	game.queue_save()

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	return value.get("firm") in ["a","b"] and value.get("phase") in ["offered","leading","introduce","to_desk","desk","settling","done"] and value.get("paused") is bool

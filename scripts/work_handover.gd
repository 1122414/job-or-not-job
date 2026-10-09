class_name WorkHandover
extends RefCounted

const SECONDS := 24.0
var game: Node3D
var data: Dictionary={}

func station() -> WorkStation:
	for item in game.stations:
		if item.stable_id=="handover": return item
	return null

func point() -> Vector3:
	return station().position+Vector3(0,0,.73)

func schedule(kind: String) -> void:
	if data.get("phase")=="delivered": return
	var now: int=game.payroll.minute
	data={"phase":"pending","kind":kind,"arranged_at":now,"due_at":(now/Payroll.DAY+1)*Payroll.DAY+600 if kind=="negotiated" else now,"elapsed":0.0,"completed_at":-1,"sender":""}
	var person: OfficeNPC=game.npc_for_role("b_friend")
	if person: person.route_clock=0
	game.queue_save()

func active() -> bool:
	return data.get("phase")=="pending" and game.career.b_event==data.kind

func due() -> bool:
	if not active() or game.payroll.minute<data.due_at: return false
	var minute: int=game.payroll.minute%Payroll.DAY
	return minute>=540 and minute<(1320 if data.kind=="refused" else 1080)

func owns(person: OfficeNPC) -> bool:
	return person.role_id=="b_friend" and due() and person.available() and person.hostile<=0 and person.reaction<=0 and person.hit_stun<=0 and person.block_time<=0 and game.office.visit_target(person)==null and game.onboarding.npc_target(person)==null and game.interviews.host_target(person)==null

func working(person: OfficeNPC) -> bool:
	return owns(person) and at_terminal(person)

func at_terminal(person: OfficeNPC) -> bool:
	return game.speaker!=person and person.position.distance_to(point())<.06 and Vector2(person.velocity.x,person.velocity.z).length()<.2 and absf(wrapf(person.visual.rotation.y,-PI,PI))<.1

func tick(delta: float) -> void:
	if not active() or game.get_tree().paused: return
	var person: OfficeNPC=game.npc_for_role("b_friend")
	if not person or not owns(person): return
	if game.social.outing.get("person")==person.stable_id and game.social.outing.get("stage")!="paused":
		if game.social.outing.stage=="offered": game.social.expire_offer()
		else: game.social.pause_outing(person.title.split(" · ")[0]+"要先完成已确认的交接，私人约定保留，之后可继续。")
	if not working(person): return
	data.elapsed=minf(SECONDS,float(data.elapsed)+maxf(0,delta))
	if data.elapsed>=SECONDS: complete(person.stable_id)

func complete(sender: String) -> void:
	if data.get("phase")=="delivered": return
	if sender=="player":
		data={"phase":"pending","kind":"helped","arranged_at":game.payroll.minute,"due_at":game.payroll.minute,"elapsed":SECONDS,"completed_at":-1,"sender":""}
	data.phase="delivered";data.completed_at=game.payroll.minute;data.sender=sender;data.elapsed=SECONDS
	var project: Dictionary=game.projects.state("b")
	project.sent=true;project.package="complete"
	project.deadline="tomorrow" if data.kind=="negotiated" else "tonight"
	project.preview="设备清单、已处理事项、未关闭问题与负责人；接收人：陈工 / 值班同事"
	project["note"]=receipt()
	game.career.record("b_handover_receipt",receipt())
	game.recruitment.send("b","handover_receipt","转交交接回执：\n"+receipt()+"\n原来的接手、拒绝或协商选择保留，不需要重复发送。")
	var person: OfficeNPC=game.npc_for_role("b_friend")
	if person: person.route_clock=0
	game.queue_save()

func sender_name() -> String:
	if data.get("sender")=="player": return "你"
	for person in game.npcs:
		if person.stable_id==data.get("sender"): return person.title.split(" · ")[0]
	return "交接经办人"

func receipt() -> String:
	if data.get("phase")!="delivered": return status()
	return game.recruitment.stamp(data.completed_at)+"，"+sender_name()+"已将完整交接包发给陈工和值班同事。"

func status() -> String:
	if data.is_empty(): return ""
	if data.phase=="unconfirmed": return "此前的"+("明早交接约定" if data.kind=="negotiated" else "拒绝加班选择")+"保留；旧记录没有实际发送时间。可与阿乐当面确认后续安排。"
	if data.phase=="delivered": return receipt()
	if data.phase=="suspended": return "现场冲突使交接中断，未记作已发送；原安排和已核对进度保留。"
	var person: OfficeNPC=game.npc_for_role("b_friend")
	var name: String=person.title.split(" · ")[0] if person else "接替同事"
	if not due(): return "交接安排："+game.recruitment.stamp(data.due_at)+"，由"+name+"处理。你可以继续自己的安排。" if game.payroll.minute<data.due_at else "交接尚未完成，保留原安排，下一工作时段继续。"
	if not person or not person.available() or person.hostile>0 or person.reaction>0: return "交接尚未完成，同事或现场暂不可用；不会记作已发送。"
	return name+"正在终端核对并发送交接包。你不必留下等待。" if working(person) else name+"将到交接终端处理，实际发送后会收到回执。"

func screen_text() -> String:
	if data.phase=="delivered": return "已发送 ✓ · "+sender_name()+"\n"+game.recruitment.stamp(data.completed_at)+"\n陈工 / 值班同事"
	if data.phase=="unconfirmed": return "原选择保留\n实际发送时间未记录\n可找同事确认"
	if data.phase=="suspended": return "现场冲突 · 交接中断\n未发送，原安排保留"
	var person: OfficeNPC=game.npc_for_role("b_friend")
	if data.elapsed>0:
		return ("同事核对中" if person and working(person) else "核对暂缓")+" · %d%%\n陈工 / 值班同事"%int(data.elapsed/SECONDS*100)
	return "交接安排\n"+game.recruitment.stamp(data.due_at)+"\n由同事处理"

func decorate(id: String,options: Dictionary) -> Dictionary:
	if data.is_empty() or id not in ["b_friend","handover"]: return options
	options.text=status()
	if data.phase=="delivered": options.choices=options.choices.filter(func(c): return c[1] not in ["help","negotiate","handover"])
	if data.phase=="unconfirmed" and id=="b_friend" and game.career.employer=="b":
		options.choices.push_front(["确认下一日上午10:00由同事发送" if data.kind=="negotiated" else "确认由同事继续处理","handover_reconfirm"])
	return options

func handle(action: String) -> bool:
	if action=="handover_reconfirm":
		if data.get("phase")=="unconfirmed" and game.speaker is OfficeNPC and game.speaker.role_id=="b_friend" and game.speaker.available() and game.career.employer=="b":
			schedule(data.kind);game.close_interaction();game.say(status())
		return true
	if action in ["help","negotiate","settle"] and data.get("phase")=="delivered":
		game.close_interaction();game.say(receipt());return true
	return false

func decided(action: String) -> void:
	if action=="settle" and game.career.b_event=="negotiated": schedule("negotiated")
	elif action=="refuse" and game.career.b_event=="refused": schedule("refused")
	elif action in ["help","negotiate"] and game.career.b_event in ["helping","negotiating"]: data.clear()

func suspend() -> void:
	if data.get("phase")=="pending" and game.career.b_event=="conflict": data.phase="suspended"

func contact(person: OfficeNPC) -> void:
	if working(person): contact_at_terminal(person,float(data.elapsed))

func contact_at_terminal(person: OfficeNPC,elapsed: float) -> void:
	if person.visual.current!="terminal_work": return
	for side in ["L","R"]:
		var normal := Vector3.DOWN;var along := Vector3.FORWARD
		var height := .965+sin(elapsed*5+(0 if side=="L" else PI))*.008
		var target := Transform3D(Basis(along.cross(normal),along,normal),station().global_position+Vector3(-.17 if side=="L" else .17,height,.24))
		person.visual.contacts.reach(side,target)
		person.visual.contacts.fingers(side,.10)

func restore(saved: Dictionary,legacy: bool=false) -> void:
	data=saved.duplicate(true)
	if legacy and game.career.b_event in ["negotiated","refused"] and not game.projects.state("b").sent:
		data={"phase":"unconfirmed","kind":game.career.b_event,"arranged_at":-1,"due_at":-1,"elapsed":0.0,"completed_at":-1,"sender":""}

static func valid(value: Variant,world: Dictionary) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return not world.career.facts.has("b_handover_receipt")
	if not value.get("phase") in ["unconfirmed","pending","suspended","delivered"] or not value.get("kind") in ["negotiated","refused","helped"]: return false
	for key in ["arranged_at","due_at","completed_at"]:
		if not CityPopulation.number(value.get(key),-1,1000000000,true): return false
	if not CityPopulation.number(value.get("elapsed"),0,SECONDS) or not value.get("sender") is String: return false
	if world.career.b_event!=("conflict" if value.phase=="suspended" else value.kind): return false
	var project: Dictionary=world.recruitment.work.get("project_b",{})
	if value.phase=="unconfirmed": return value.kind!="helped" and value.arranged_at==-1 and value.due_at==-1 and value.completed_at==-1 and value.elapsed==0 and value.sender=="" and not project.get("sent",false)
	var fact: String={"negotiated":"b_negotiate","refused":"b_refuse","helped":"b_help"}[value.kind]
	if not world.career.facts.has(fact): return false
	if value.arranged_at<0 or value.arranged_at>world.payroll.minute or value.due_at<value.arranged_at: return false
	if value.kind=="negotiated" and value.due_at!=(int(value.arranged_at)/Payroll.DAY+1)*Payroll.DAY+600: return false
	if value.kind=="negotiated" and (not project.get("proposal",false) or project.get("package")!="complete" or project.get("deadline")!="tomorrow"): return false
	if value.kind!="negotiated" and value.due_at!=value.arranged_at: return false
	if value.phase in ["pending","suspended"]: return value.kind!="helped" and value.elapsed<SECONDS and (value.elapsed==0 or world.payroll.minute>=value.due_at) and value.completed_at==-1 and value.sender=="" and not project.get("sent",false)
	if value.completed_at<value.due_at or value.completed_at>world.payroll.minute or value.elapsed!=SECONDS or not project.get("sent",false) or project.get("package")!="complete": return false
	if not world.career.facts.has("b_handover_receipt"): return false
	return value.sender=="player" if value.kind=="helped" else world.npcs.has(value.sender) and world.npcs[value.sender].role_id=="b_friend"

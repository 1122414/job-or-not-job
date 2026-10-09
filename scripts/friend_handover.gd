class_name FriendHandover
extends RefCounted

var game: Node3D
var data: Dictionary={}
const DOCUMENTS := [
["阿乐分享的请求摘录","赵总：今晚尽快交接，都是自己人。\n阿乐：这是我负责的工作，你没入职，不用替我接单。我只想请你一起看看这几条已分享的信息。"],
["已分享的交接清单","设备清单、已处理事项、未关闭问题及负责人，共四项。\n阿乐手里的旧包少了未关闭问题；只看文件名，会让接收人误以为都完成了。正式资料和账户仍由阿乐管理。"],
["陈工确认的交付窗口","陈工：交接安排确认后，下一日上午11:00前给我就行，不要求当晚在线。\n接收人：陈工与次日值班同事。若安排明早10:00发送，请阿乐和赵总当面确认。"]]

func person() -> OfficeNPC:
	for npc in game.npcs:
		if npc.stable_id==data.get("person","b_friend"): return npc
	return null

func boss() -> OfficeNPC:
	for npc in game.npcs:
		if npc.stable_id==data.get("boss",""): return npc
	return null

func eligible() -> bool:
	return game.story.active() and not game.story.campus() and game.recruitment.applications.b.phase=="rejected" and game.career.employer!="b" and game.career.b_event=="none" and game.handover.data.is_empty()

func calm(npc: OfficeNPC) -> bool:
	return npc!=null and npc.available() and npc.hostile<=0 and npc.reaction<=0 and npc.hit_stun<=0 and npc.block_time<=0

func local(npc: OfficeNPC) -> bool:
	return calm(npc) and game.speaker==npc and game.player.hp>0 and not game.in_vehicle() and game.player.position.distance_to(npc.position)<=3.5 and game.can_see(game.player,npc)

func safe_meeting() -> bool:
	var b := boss()
	return eligible() and calm(person()) and game.social.willing(person()) and calm(b) and game.career.conflict.b<2 and not game.payroll.after_work() and game.payroll.minute/Payroll.DAY==int(data.get("arranged_at",-1))/Payroll.DAY and game.player.hp>0 and not game.in_vehicle() and game.player.position.distance_to(b.position)<22

func due() -> bool:
	var time: int=game.payroll.minute%Payroll.DAY
	return data.get("phase")=="pending" and game.payroll.minute>=data.due_at and time>=540 and time<1320

func owns(npc: OfficeNPC) -> bool:
	if data.is_empty() or npc!=person() or not eligible() or not calm(npc): return false
	if data.get("phase")=="walking": return safe_meeting()
	return due() and game.office.visit_target(npc)==null and game.onboarding.npc_target(npc)==null and game.interviews.host_target(npc)==null

func npc_target(npc: OfficeNPC) -> Variant:
	if not owns(npc) or game.speaker==npc: return null
	return boss().position+Vector3(1.5,0,1.5) if data.phase=="walking" else game.handover.point()

func working(npc: OfficeNPC) -> bool:
	return owns(npc) and data.phase=="pending" and game.handover.at_terminal(npc)

func contact(npc: OfficeNPC) -> void:
	if working(npc): game.handover.contact_at_terminal(npc,float(data.elapsed))

func tick(delta: float) -> void:
	if data.is_empty() or game.get_tree().paused: return
	if data.phase=="walking" and not safe_meeting():
		data.phase="paused";game.queue_save()
	var npc := person()
	if not npc or not owns(npc): return
	if game.social.outing.get("person")==npc.stable_id and game.social.outing.get("stage")!="paused":
		if game.social.outing.stage=="offered": game.social.expire_offer()
		else: game.social.pause_outing("阿乐先处理已确认的交接；私人约定保留，之后可继续。")
	if not working(npc): return
	data.elapsed=minf(WorkHandover.SECONDS,float(data.elapsed)+maxf(delta,0))
	if data.elapsed<WorkHandover.SECONDS: return
	data.phase="delivered";data.completed_at=game.payroll.minute;data.sender=npc.stable_id
	game.social.remember(npc,"friend_delivery",delivery_text(),0,0)
	game.recruitment.send("b","friend_handover_receipt",receipt()+"\n这是朋友事件回执，不是录用或你的工作结算。")
	game.queue_save()

func delivery_text() -> String:
	var npc := person()
	var name: String=npc.title.split(" · ")[0] if npc else "原经办人"
	return name+"用自己的账户将完整交接包发给陈工和值班同事。"

func receipt() -> String:
	return game.recruitment.stamp(data.completed_at)+"，"+delivery_text() if data.get("phase")=="delivered" else ""

func status() -> String:
	if data.is_empty(): return ""
	if data.phase=="delivered": return receipt()+"\n"+{"checked":"你指出了旧包遗漏，核对到这里就结束了。","negotiated":"你们在"+game.recruitment.stamp(data.arranged_at)+"确认了这个交付时间，不再要求阿乐当晚在线。","declined":"你没有接手这件事；阿乐完成了自己的工作。"}[data.choice]
	if data.phase=="walking": return "带着已分享的材料，和阿乐一起到赵总面前确认；可随时暂缓。"
	if data.phase=="paused": return "陪同暂缓，尚未确认截止时间。回到同一工作日的安全现场，可问阿乐是否继续。"
	if data.phase=="review": return "阿乐只分享了三段可核对的信息。看过再决定；离开对话不代表接下工作。"
	if game.payroll.minute<data.due_at: return "约定"+game.recruitment.stamp(data.due_at)+"由阿乐本人发送。你可以先去安排自己的生活。"
	if person()!=null and person().dead: return "交接未发送：阿乐已故，原请求和进度保留，替岗人员不继承私人请求。"
	if not calm(person()): return "交接未发送：原阿乐暂时无法处理，保留安排和进度；替岗人员不继承私人请求。"
	return "阿乐正在自己的终端核对并发送。你不用留在这里等。" if working(person()) else "阿乐将在可工作的时段到终端处理，实际发送后才有回执。"

func decorate(target: Node3D, options: Dictionary) -> Dictionary:
	if not eligible() or not target is OfficeNPC: return options
	if target==person():
		if not calm(target) or not game.social.willing(target): return options
		if data.is_empty():
			options.text="阿乐：岗位取消的事我知道了。这份交接还在我手里，赵总又说今晚尽快。你愿意帮我看看要求，或者陪我问清楚吗？没空也没关系。"
			options.choices.push_front(["先听听是什么事，再决定","friend_open"])
		elif data.phase=="review": return review()
		elif data.phase in ["walking","paused"]:
			options.text=status()
			options.choices.push_front(["先不陪同，回头再决定","friend_cancel"])
			if data.phase=="paused": options.choices.push_front(["现在一起去确认","friend_resume"])
			else: options.choices.push_front(["暂缓这次陪同","friend_pause"])
		else: options.text=status()
	elif target==boss() and data.get("phase")=="walking":
		options.text="赵总：你又没入职，怎么也来了？\n阿乐：是我请朋友一起核对要求。材料由我负责，我们想确认交付时间。"
		options.choices.push_front(["和阿乐展示原始要求，确认明早10:00","friend_confirm"])
	return options

func review(text: String="") -> Dictionary:
	var choices: Array=[]
	for i in range(DOCUMENTS.size()): choices.append([("已读 · " if data.read.has(i) else "阅读 · ")+DOCUMENTS[i][0],"friend_read_"+str(i)])
	if data.read.size()==3:
		choices.append(["指出旧包缺项，核对到这里；由阿乐发送","friend_check"])
		choices.append(["一起带着材料找赵总确认明早发送","friend_negotiate"])
	choices.append(["我今晚有自己的安排，不参与这次交接","friend_decline"])
	choices.append(["先离开，还没决定","friend_close"])
	return {"text":status() if text.is_empty() else text,"choices":choices}

func schedule(choice: String) -> void:
	data.choice=choice;data.phase="pending";data.arranged_at=game.payroll.minute
	data.due_at=(game.payroll.minute/Payroll.DAY+1)*Payroll.DAY+600 if choice=="negotiated" else game.payroll.minute
	data.elapsed=0.0
	var npc := person()
	if choice!="declined": game.social.remember(npc,"friend_"+choice,"你们核对了分享的材料；工作仍由阿乐负责。" if choice=="checked" else "你陪阿乐当面确认了明早的交付安排。",4,4)
	npc.route_clock=0
	game.close_interaction();game.queue_save()
	game.say("阿乐：行，我自己处理。你不欠我一个晚上。" if choice=="declined" else "阿乐：旧包漏项我来补，发送也由我来。谢谢你提醒。" if choice=="checked" else "赵总：既然客户没要求今晚，那就明早10:00发。阿乐：我来发送，今晚不再等着。")

func handle(action: String) -> bool:
	if not action.begins_with("friend_"): return false
	if action=="friend_close": game.close_interaction();return true
	if not eligible(): return true
	if action=="friend_confirm":
		if data.get("phase")=="walking" and safe_meeting() and local(boss()) and person().position.distance_to(boss().position)<3.5 and game.can_see(game.player,person()): schedule("negotiated")
		else: game.say("等阿乐真实到场，并确认现场安全后再一起谈。")
		return true
	var npc := person()
	if not local(npc) or not game.social.willing(npc): return true
	if action=="friend_open" and data.is_empty():
		data={"phase":"review","person":npc.stable_id,"boss":"","read":[],"choice":"","created_at":game.payroll.minute,"arranged_at":-1,"due_at":-1,"elapsed":0.0,"completed_at":-1,"sender":""}
	elif action.begins_with("friend_read_") and data.get("phase")=="review":
		var key := action.trim_prefix("friend_read_")
		if key not in ["0","1","2"]: return true
		var index := int(key)
		if not data.read.has(index): data.read.append(index)
		game.conversation=review(DOCUMENTS[index][0]+"\n"+DOCUMENTS[index][1]);game.queue_save();return true
	elif action=="friend_decline" and data.get("phase")=="review": schedule("declined");return true
	elif action=="friend_check" and data.get("phase")=="review" and data.read.size()==3: schedule("checked");return true
	elif (action=="friend_negotiate" and data.get("phase")=="review" and data.read.size()==3) or (action=="friend_resume" and data.get("phase")=="paused"):
		var b: OfficeNPC=game.npc_for_role("b_boss")
		if not calm(b) or game.payroll.after_work() or game.career.conflict.b>=2:
			game.say("现在不适合找负责人。可以先离开，工作日现场安全时再谈。")
			return true
		data.boss=b.stable_id;data.arranged_at=game.payroll.minute;data.phase="walking";npc.route_clock=0
		game.close_interaction();game.queue_save();game.say(status());return true
	elif action=="friend_pause" and data.get("phase")=="walking": data.phase="paused"
	elif action=="friend_cancel" and data.get("phase") in ["walking","paused"]:
		data.phase="review";data.boss="";data.arranged_at=-1;npc.route_clock=0
	else: return true
	game.conversation=review() if data.phase=="review" else decorate(npc,{"text":"","choices":[]})
	game.queue_save();return true

static func valid(value: Variant, world: Dictionary) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not value.get("phase") in ["review","walking","paused","pending","delivered"] or not value.get("choice") in ["","checked","negotiated","declined"]: return false
	if not value.get("person") is String or not world.npcs.has(value.person) or value.person!="b_friend": return false
	if not value.get("boss") is String or (value.boss!="" and (not world.npcs.has(value.boss) or world.npcs[value.boss].company!="b")): return false
	if not value.get("sender") is String or not value.get("read") is Array: return false
	var seen := {}
	for item in value.read:
		if not CityPopulation.number(item,0,2,true) or seen.has(int(item)): return false
		seen[int(item)]=true
	for key in ["created_at","arranged_at","due_at","completed_at"]:
		if not CityPopulation.number(value.get(key),-1,world.payroll.minute if key!="due_at" else 1000000000,true): return false
	if value.created_at<0 or not CityPopulation.number(value.get("elapsed"),0,WorkHandover.SECONDS): return false
	if world.career.employer=="b" or world.career.b_event!="none" or not world.work_handover.is_empty() or world.recruitment.applications.b.phase!="rejected" or world.autumn_story.mode!="current": return false
	if value.phase in ["review","walking","paused"]:
		return value.choice=="" and value.elapsed==0 and value.due_at==-1 and value.completed_at==-1 and value.sender=="" and ((value.phase=="review" and value.arranged_at==-1 and value.boss=="") or (value.phase!="review" and value.arranged_at>=value.created_at and value.boss!="" and value.read.size()==3))
	if value.choice=="" or value.arranged_at<value.created_at or value.due_at<value.arranged_at: return false
	if value.choice!="declined" and value.read.size()!=3: return false
	if value.choice=="negotiated":
		if value.boss=="" or value.due_at!=(int(value.arranged_at)/Payroll.DAY+1)*Payroll.DAY+600: return false
	elif value.due_at!=value.arranged_at or value.boss!="": return false
	if value.phase=="pending": return value.elapsed<WorkHandover.SECONDS and (value.elapsed==0 or world.payroll.minute>=value.due_at) and value.completed_at==-1 and value.sender==""
	return value.elapsed==WorkHandover.SECONDS and value.completed_at>=value.due_at and value.sender==value.person

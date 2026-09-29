class_name SocialLife
extends RefCounted
var game: Node3D
var people := {}
var outing := {}
const CORE := ["a_hr","a_friend","a_lead","b_friend"]
const PROFILES := {
"a_hr":["林岚","招聘接待与入职引导","说话克制，重视约定和边界。","每天都有人问进展，我也在等别人回我。有时候表上先写了日期，事情却没定。"],
"a_friend":["小夏","邻座同事与原始资料作者","乐于分享方法，也珍惜自己的下班时间。","以前我总怕拒绝会让别人失望，现在想把自己的晚上留出来。"],
"a_lead":["周工","技术主管与第一份成果验收人","在意结果，遇到用工难题时有时会回避。","我知道先做出来听着像推话。可会上问我的永远是交付日期，没人问资料到底齐没齐。"],
"b_friend":["阿乐","帮你安顿设备的同事","热心，不太擅长拒绝别人的请求。","我经常先答应下来，回头才发现自己的事一点没做。"]}

func state(npc: OfficeNPC) -> Dictionary:
	if not people.has(npc.stable_id): people[npc.stable_id]={"met":false,"trust":0,"fear":0,"memories":[],"days":{}}
	return people[npc.stable_id]

func remember(npc: OfficeNPC,key: String,line: String,liking: int=0,trust: int=0,fear: int=0) -> bool:
	var p := state(npc)
	if p.days.has(key): return false
	p.days[key]=game.payroll.minute/1440
	p.memories.append("第%d天 · %s"%[game.payroll.minute/1440+1,line])
	if p.memories.size()>8: p.memories.pop_front()
	p.trust=clampi(int(p.trust)+trust,-100,100)
	p.fear=clampi(int(p.fear)+fear,0,100)
	npc.affinity=clampi(npc.affinity+liking,-100,100)
	game.queue_save()
	return true

func meet(npc: OfficeNPC) -> void:
	state(npc).met=true
	remember(npc,"meet","你们第一次正式交谈。",2)

func hurt(npc: OfficeNPC,action: int) -> void:
	meet(npc)
	state(npc).days["peace"]=game.payroll.minute/1440
	remember(npc,"hurt_"+str(action),"你动手伤害了对方；这件事没有因返岗而消失。",0,-20,25)
	if outing.get("person")==npc.stable_id: outing.clear()

func describe(npc: OfficeNPC) -> String:
	var p := state(npc)
	if npc.dead: return "已故 · 经历保留"
	if npc.care_state!="awake": return "受伤休养 · 暂时无法交谈"
	if p.fear>=20: return "熟悉 · 有戒心" if npc.affinity>=10 else "疏远 · 有戒心"
	if npc.affinity< -10 or p.trust< -10: return "疏远"
	if p.trust>=18 and npc.affinity>=15: return "信任"
	if npc.affinity>=8: return "熟悉"
	return "认识不久" if p.met else "陌生"

func roster() -> Array[OfficeNPC]:
	var result: Array[OfficeNPC]=[]
	for role in CORE:
		for npc in game.npcs:
			if npc.role_id==role: result.append(npc)
	for npc in game.npcs:
		if not result.has(npc) and state(npc).met: result.append(npc)
	return result

func kind_now() -> String:
	var minute: int=game.payroll.minute%1440
	if minute>=12*60 and minute<14*60: return "lunch"
	if minute>=18*60 and minute<22*60: return "walk"
	return "tea" if minute>=9*60 and minute<18*60 else ""

func kind_name(kind: String) -> String:
	return {"tea":"茶水间聊聊","lunch":"一起吃午饭","walk":"下班同行"}.get(kind,"稍后再约")

func destination(npc: OfficeNPC,kind: String) -> Vector3:
	if kind=="walk" and outing.get("person")==npc.stable_id and outing.has("venue"): return CityOuting.VENUES[outing.venue][1]
	if kind=="tea": return OfficeRooms.point(game,npc.company,"tea")
	return Vector3(9,0,12.3) if kind=="lunch" else Vector3(-5,0,12.8)

func options(npc: OfficeNPC) -> Dictionary:
	var p := state(npc)
	if outing.get("person")==npc.stable_id:
		if outing.has("venue"): return CityOuting.options(self,npc)
		if outing.stage=="offered": return {"text":npc.title.split(" · ")[0]+"：要不要"+kind_name(outing.kind)+"？不方便也没关系。","choices":[["好，一起走","people_accept"],["今天先不了","people_decline"],["先说工作上的事","people_work"]]}
		if outing.stage=="walking":
			var arrived: bool=npc.position.distance_to(destination(npc,outing.kind))<0.7 and npc.position.distance_to(game.player.position)<3
			return {"text":"到了。我们聊几句？" if arrived else "我在前面等你。想先忙自己的事也可以。","choices":[["聊聊最近的生活" if arrived else "继续同行","people_share" if arrived else "people_continue"],["先忙别的，稍后再约","people_pause"],["先说工作上的事","people_work"]]}
	var choices: Array=[["聊聊近况","people_chat"]]
	var kind := kind_now()
	if kind!="": choices.append([kind_name(kind),"people_invite_"+kind])
	if p.fear>0 or p.trust<0: choices.append(["为之前动手认真道歉","people_apologize"])
	choices.append(["回到工作话题","people_work"])
	return {"text":npc.title.split(" · ")[0]+" · "+describe(npc),"choices":choices}

func npc_target(npc: OfficeNPC) -> Variant:
	if outing.get("person")!=npc.stable_id or not npc.available(): return null
	if work_following(npc) or game.office.visit_target(npc)!=null or outing.stage=="paused": return null
	if game.speaker==npc and not game.conversation.is_empty(): return npc.position
	if outing.stage in ["walking","sharing"]:
		return npc.position if npc.position.distance_to(game.player.position)>6 and CityFootRoutes.crossing_at(npc.position)=="" else destination(npc,outing.kind)
	return npc.position

func work_following(npc: OfficeNPC) -> bool:
	return npc.role_id=="b_friend" and game.career.b_event=="negotiating"

func willing(npc: OfficeNPC) -> bool:
	var p := state(npc)
	return npc.available() and npc.hostile<=0 and p.fear<20 and p.trust>=-10 and npc.affinity>=0

func handle(action: String,npc: OfficeNPC) -> bool:
	if not action.begins_with("people_"): return false
	var p := state(npc)
	var day := str(game.payroll.minute/1440)
	if CityOuting.handle(self,npc,action): return true
	if action=="people_menu": game.conversation=options(npc); return true
	if action=="people_bookshop": game.city_life.share(npc); return true
	if action=="people_story_walk": game.city_life.walk.share(npc); return true
	if action=="people_work":
		game.conversation=OfficeDialogue.options(npc,game.career)
		return true
	if action=="people_continue": game.close_interaction(); return true
	if action=="people_apologize":
		var repaired := remember(npc,"apology","你道了歉；对方愿意听，但还需要时间观察。",0,3,-5)
		game.close_interaction()
		game.say("我听到了。但我现在还不放心，先让彼此有些距离。" if repaired else "道歉我已经听过了，之后怎么相处更重要。")
		return true
	if action in ["people_pause","people_decline"]:
		outing.clear()
		game.close_interaction()
		game.say("好，你先忙。拒绝邀约不会扣关系。")
		game.queue_save()
		return true
	if action.begins_with("people_invite_") or action=="people_accept":
		var kind: String=outing.get("kind",kind_now()) if action=="people_accept" else action.trim_prefix("people_invite_")
		game.close_interaction()
		if not willing(npc): game.say("现在只谈必要的工作吧，我还不想私下相处。"); return true
		if not outing.is_empty() and outing.person!=npc.stable_id: game.say("先结束原来的约定，再约其他人；暂缓会保留原约定。" if outing.has("venue") else "先结束或暂停正在进行的约定。"); return true
		if kind!=kind_now(): game.say("这个时间不合适，换个时间再约。"); return true
		if kind=="walk": CityOuting.menu(self,npc); return true
		outing={"person":npc.stable_id,"kind":kind,"stage":"walking","elapsed":0.0}
		game.say(npc.title.split(" · ")[0]+"：走吧，我会等你。P人物页可找到我们的约定。")
		game.queue_save()
		return true
	if action=="people_share":
		if outing.get("person")!=npc.stable_id or npc.position.distance_to(destination(npc,outing.kind))>0.7: return true
		var line: String={"tea":"接杯水，歇一会儿。", "lunch":"先吃点东西吧。", "walk":"一起走到公交站吧。"}[outing.kind]+PROFILES.get(npc.role_id,["","","","工作以外，我也想留点时间给自己的生活。"])[3]
		game.conversation={"text":npc.title.split(" · ")[0]+"："+line,"choices":[["听他说完，尊重他的安排","people_listen"],["说说自己的边界和困扰","people_boundary"],["今天先聊到这里","people_pause"]]}
		return true
	if action in ["people_listen","people_boundary"]:
		if outing.get("person")!=npc.stable_id: return true
		remember(npc,"outing_"+day,"你们"+kind_name(outing.kind)+"，认真听了彼此的安排。",6,6,-3)
		outing.clear()
		game.close_interaction()
		game.say("谢谢你愿意听。之后有事也可以来找我。")
		game.queue_save()
		return true
	if action=="people_chat":
		if not willing(npc): game.close_interaction(); game.say("我现在想保持距离，工作需要的事可以照常谈。"); return true
		remember(npc,"chat_"+day,"你们聊过近况，没有把拒绝加班当作不合群。",2,2)
		game.conversation={"text":npc.title.split(" · ")[0]+"："+PROFILES.get(npc.role_id,["","","","今天想把事情做好，也想准时回家。"])[3],"choices":[["谢谢你和我说这些","people_continue"],["回到工作话题","people_work"]]}
		game.conversation.text+=CityOuting.memory_line(self,npc)
		if game.city_life and game.city_life.can_share(npc): game.conversation.choices.push_front(["聊起社区书屋的分享会","people_bookshop"])
		if game.city_life.walk.stage==5 and game.city_life.can_share(npc): game.conversation.choices.push_front(["聊起旧站到海边的走访记录","people_story_walk"])
		return true
	return true

func tick(delta: float) -> void:
	# Time and restraint, not gifts or repeated clicks, allow some fear to subside.
	var day: int=game.payroll.minute/1440
	for npc in game.npcs:
		var p := state(npc)
		if p.fear>0 and p.days.has("apology"):
			var last: int=p.days.get("peace",p.days.apology)
			if day>last and npc.available() and npc.hostile<=0:
				p.fear=maxi(0,int(p.fear)-mini(day-last,7)*4)
				p.trust=mini(0,int(p.trust)+mini(day-last,7)*3) if p.trust<0 else p.trust
				npc.affinity=mini(0,npc.affinity+mini(day-last,7)*3) if npc.affinity<0 else npc.affinity
				p.days["peace"]=day
	if not outing.is_empty():
		var person: OfficeNPC
		for npc in game.npcs:
			if npc.stable_id==outing.person: person=npc
		if not person or not willing(person): outing.clear(); game.queue_save(); return
		# A confirmed work follow takes precedence without cancelling a private plan.
		if work_following(person): return
		CityOuting.tick(self)
		outing.elapsed+=delta
		if outing.stage=="offered" and outing.elapsed>60: outing.clear(); game.queue_save()
		return
	if game.onboarding.active(): return
	if game.career.employer=="" or not game.conversation.is_empty() or kind_now()=="": return
	if game.career.employer=="a" and not game.career.facts.has("brief"): return
	if game.career.employer=="b" and not game.career.facts.has("welcome_b"): return
	var npc: OfficeNPC=game.npc_for_role(game.career.employer+"_friend")
	if not npc or work_following(npc) or not willing(npc) or not state(npc).met or game.office.visit_target(npc)!=null: return
	if npc.position.distance_to(game.player.position)>3: return
	var key := "invite_"+str(day)+"_"+kind_now()
	if state(npc).days.has(key): return
	state(npc).days[key]=day
	outing={"person":npc.stable_id,"kind":kind_now(),"stage":"offered","elapsed":0.0}
	game.say(npc.title.split(" · ")[0]+"邀请你"+kind_name(kind_now())+" · E回应，也可以先忙")
	game.queue_save()

static func valid(data: Variant,npcs: Dictionary) -> bool:
	if not data is Dictionary or not data.get("people") is Dictionary or not data.get("outing") is Dictionary: return false
	for id in data.people:
		if not npcs.has(id): return false
		var p: Variant=data.people[id]
		if not p is Dictionary or not p.get("met") is bool or not p.get("memories") is Array or not p.get("days") is Dictionary: return false
		for key in ["trust","fear"]:
			if not (p.get(key) is int or p.get(key) is float) or not is_finite(p[key]) or p[key]<-100 or p[key]>100: return false
		if p.fear<0: return false
		if p.has("city") and not CityOuting.valid_visit(p.city): return false
		if p.memories.size()>8: return false
		for line in p.memories:
			if not line is String or line.length()>600: return false
		for key in p.days:
			if not (key is String or key is StringName) or not (p.days[key] is int or p.days[key] is float) or not is_finite(p.days[key]) or p.days[key]<0: return false
	var o: Dictionary=data.outing
	if not o.is_empty():
		if not npcs.has(o.get("person","")) or not o.get("kind") in ["tea","lunch","walk"] or not o.get("stage") in ["offered","walking","sharing","paused"]: return false
		if o.has("venue"):
			if o.kind!="walk" or not o.venue in CityOuting.VENUES or o.stage=="offered": return false
			if o.has("guiding") and not o.guiding is bool: return false
		elif not o.stage in ["offered","walking"] or o.has("guiding"): return false
		if not (o.get("elapsed") is int or o.get("elapsed") is float) or not is_finite(o.elapsed) or o.elapsed<0: return false
	return true

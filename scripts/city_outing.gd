class_name CityOuting
extends RefCounted

const VENUES := {"bookshop":["社区书屋",Vector3(-50.5,0,35)],"garden":["社区花园",Vector3(42,0,54)],"waterfront":["海风步道",Vector3(28,0,116)]}
const REPLIES := {"listen":"认真听完对方的打算","boundary":"说清自己的时间与边界","quiet":"一起安静待了一会儿"}

static func place_position(npc: OfficeNPC,venue: String) -> Vector3:
	var point: Vector3=VENUES[venue][1]
	if npc.role_id=="a_group" and venue=="waterfront": return point+Vector3(-2.5,0,0)
	return point+Vector3(-1.2,0,0) if npc.role_id=="a_group" and venue=="garden" else point

static func menu(social: SocialLife,npc: OfficeNPC) -> void:
	var game: Node3D=social.game
	game.speaker=npc
	var choices: Array=[]
	for id in VENUES:
		if id=="bookshop" and not game.city_life.is_open(): continue
		choices.append(["一起去"+VENUES[id][0],"people_city_go_"+id])
	choices.append(["今天先不了","people_decline"])
	game.conversation={"text":npc.title.split(" · ")[0]+"：下班了，一起去街区走走？你来选地方，走到一半也可以各忙各的。"+("书屋已经关门，我们去户外吧。" if not game.city_life.is_open() else ""),"choices":choices}

static func focus(social: SocialLife) -> void:
	social.outing["guiding"]=true
	social.game.city_life.guide=""
	social.game.city_life.walk.guiding=false
	social.game.driving.guide_car=""
	social.game.transit.waypoint=""
	social.game.queue_save()

static func target(social: SocialLife) -> OfficeNPC:
	if not social.outing.has("venue") or not social.outing.get("guiding",false): return null
	for npc in social.game.npcs:
		if npc.stable_id==social.outing.get("person") and npc.available(): return npc
	return null

static func status(social: SocialLife) -> String:
	var npc := target(social)
	if npc==null: return ""
	return "与"+npc.title.split(" · ")[0]+"去"+VENUES[social.outing.venue][0]+(" · 约定暂缓，靠近E继续或结束" if social.outing.stage=="paused" else " · 一起走，到达后E交谈，可随时暂停")

static func at_place(social: SocialLife,npc: OfficeNPC) -> bool:
	var game: Node3D=social.game
	var o: Dictionary=social.outing
	return o.get("person")==npc.stable_id and o.get("venue") in VENUES and o.get("stage") in ["walking","sharing"] and social.willing(npc) and not social.work_following(npc) and game.office.visit_target(npc)==null and game.player.hp>0 and not game.in_vehicle() and npc.position.distance_to(place_position(npc,o.venue))<.7 and game.player.position.distance_to(npc.position)<3 and game.can_see(game.player,npc) and (o.venue!="bookshop" or game.city_life.is_open())

static func options(social: SocialLife,npc: OfficeNPC) -> Dictionary:
	var o: Dictionary=social.outing
	if o.stage=="paused": return {"text":"去"+VENUES[o.venue][0]+"的约定还在。各忙各的也没关系，方便时再继续。","choices":[["继续刚才的同行","people_city_resume"],["换个地方","people_city_menu"],["今天到这里","people_decline"],["先说工作上的事","people_work"]]}
	return {"text":"已经到了"+VENUES[o.venue][0]+"。" if at_place(social,npc) else "一起去"+VENUES[o.venue][0]+"，我会在路边等你。","choices":[["聊聊这里和今天的事" if at_place(social,npc) else "继续同行","people_share" if at_place(social,npc) else "people_continue"],["先忙别的，保留约定","people_pause"],["今天到这里","people_decline"],["先说工作上的事","people_work"]]}

static func topic(social: SocialLife,npc: OfficeNPC) -> String:
	var game: Node3D=social.game
	var venue: String=social.outing.venue
	var line: String=SocialLife.PROFILES.get(npc.role_id,["","","","下班后能自己决定去哪儿，今天才算属于自己。"])[3]
	if venue=="bookshop":
		line="离开办公室，看见别人留下的故事，才觉得一天不只有工作。"+line
		if game.city_life.walk.stage==5: line+="这份《从旧站到海边》是你和邻居一起留下的吧？现在站在这里，和听你讲很不一样。"
	elif venue=="garden": line="刚才在公司总有人等着回答，到了这里可以慢一点。"+line
	else: line="从公司一路走到海边，脑子里那些催促声总算轻了一点。"+line
	if game.career.employer==npc.company: line+="明天的工作明天再说，今晚不用替谁证明什么。"
	elif npc.company in game.career.former: line+="你已经离开那家公司，我们还是能在这里见面。"
	return npc.title.split(" · ")[0]+"："+line

static func memory_line(social: SocialLife,npc: OfficeNPC) -> String:
	var visits: Dictionary=social.state(npc).get("city",{})
	if visits.is_empty(): return ""
	var latest: String=visits.keys()[-1]
	for id in visits:
		if visits[id].day>visits[latest].day: latest=id
	var reply: String=visits[latest].reply
	return "\n上次在"+VENUES[latest][0]+"，"+{"listen":"你听我把话说完了。那件事我后来按自己的想法安排了。","boundary":"你说过要留出自己的时间。我记着，约你之前会先问一声。","quiet":"我们没急着找话说。一起安静待着也很自在。"}[reply]

static func handle(social: SocialLife,npc: OfficeNPC,action: String) -> bool:
	var game: Node3D=social.game
	var o: Dictionary=social.outing
	if action=="people_evening_join":
		var venue := CityEvening.at_place(npc)
		if venue=="" or not social.willing(npc) or game.speaker!=npc or game.player.hp<=0 or game.in_vehicle() or game.player.position.distance_to(npc.position)>3 or not game.can_see(game.player,npc): return true
		# Accept a shared pause where both people actually are; no remote arrival.
		social.outing={"person":npc.stable_id,"kind":"walk","stage":"walking","elapsed":0.0,"venue":venue}
		npc.route_clock=0
		game.conversation=options(social,npc)
		game.queue_save(); return true
	if action=="people_city_menu": menu(social,npc); return true
	if action.begins_with("people_city_go_"):
		var venue := action.trim_prefix("people_city_go_")
		if not venue in VENUES or social.kind_now()!="walk" or not social.willing(npc) or game.in_vehicle() or game.player.hp<=0 or game.player.position.distance_to(npc.position)>3 or not game.can_see(game.player,npc): return true
		if not o.is_empty() and o.person!=npc.stable_id: return true
		if venue=="bookshop" and not game.city_life.is_open(): menu(social,npc); return true
		social.outing={"person":npc.stable_id,"kind":"walk","stage":"walking","elapsed":0.0,"venue":venue}
		npc.route_clock=0
		focus(social)
		game.close_interaction(); game.say("与"+npc.title.split(" · ")[0]+"去"+VENUES[venue][0]+" · P可查看约定，靠近E可暂停或结束")
		game.queue_save(); return true
	if not o.has("venue") or o.get("person")!=npc.stable_id: return false
	if action=="people_city_resume":
		if social.willing(npc) and social.kind_now()=="walk" and (o.venue!="bookshop" or game.city_life.is_open()):
			o.stage="walking"; npc.route_clock=0; game.close_interaction(); game.queue_save()
		else: game.say("现在不方便继续，约定保留；书屋09:00—20:00开放，也可改约户外。")
		return true
	if action=="people_pause":
		o.stage="paused"; npc.route_clock=0; game.close_interaction(); game.say("好，我们先各忙各的。约定保留，之后靠近我再继续。")
		game.queue_save(); return true
	if action=="people_share":
		if not at_place(social,npc): return true
		o.stage="sharing"
		game.conversation={"text":topic(social,npc),"choices":[["听他说完，尊重他的安排","people_listen"],["说说自己的边界和困扰","people_boundary"],["不用急着说话，一起歇会儿","people_city_quiet"],["今天先到这里","people_pause"]]}
		game.queue_save(); return true
	if action in ["people_listen","people_boundary","people_city_quiet"]:
		if o.stage!="sharing" or not at_place(social,npc) or game.speaker!=npc: return true
		var reply: String={"people_listen":"listen","people_boundary":"boundary","people_city_quiet":"quiet"}[action]
		var day: int=game.payroll.minute/1440
		var state := social.state(npc)
		if not state.has("city"): state.city={}
		if state.city.get(o.venue,{}).get("day",-1)!=day:
			state.city[o.venue]={"day":day,"reply":reply}
			social.remember(npc,"city_"+o.venue+"_"+str(day),"你们在"+VENUES[o.venue][0]+REPLIES[reply]+"。")
		social.remember(npc,"outing_"+str(day),"你们下班后在街区相处，保留了各自的安排。",6,6,-3)
		var response: String={"listen":"谢谢你认真听。明天那件事，我会先把自己的安排说清楚。","boundary":"好，我记住了。以后约你会先问时间，也不会把帮忙当成默认。","quiet":"嗯。今天先不用解决什么，在这里待一会儿就很好。"}[reply]
		o.clear(); npc.route_clock=0
		game.conversation={"text":npc.title.split(" · ")[0]+"："+response,"choices":[["回头见","people_continue"],["回到工作话题","people_work"]]}
		game.queue_save(); return true
	return false

static func tick(social: SocialLife) -> void:
	var o: Dictionary=social.outing
	if not o.has("venue") or o.stage=="paused": return
	if social.kind_now()!="walk" or o.venue=="bookshop" and not social.game.city_life.is_open():
		o.stage="paused"
		social.game.close_interaction()
		social.game.say("时间晚了，同行约定保留。书屋已经闭馆时，也可以改去户外。")
		social.game.queue_save()

static func valid_visit(visits: Variant) -> bool:
	if not visits is Dictionary or visits.size()>VENUES.size(): return false
	for id in visits:
		if not id in VENUES or not visits[id] is Dictionary: return false
		if not CityPopulation.number(visits[id].get("day"),0,100000000,true) or not visits[id].get("reply") in REPLIES: return false
	return true

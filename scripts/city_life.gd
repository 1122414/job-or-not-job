class_name CityLife
extends Node3D

const POINTS := {
	"notice":["书屋公告 · 街区记忆分享",Vector3(-49,0,40.5)],
	"screen":["影像播放台",Vector3(-47.5,0,28)],
	"paper":["纸本图画阅览台",Vector3(-56,0,29)],
	"garden":["社区花园 · 展示架",Vector3(38,0,53)]
}
const METHODS := {"screen":"本地投影","paper":"纸本共读","garden":"花园展览"}
const AUDIENCE := [0,3,7]
const INDOOR := ["reading_west","reading_center","reading_east"]
const PAPER := ["paper_west","paper_center","paper_east"]
const OUTDOOR := ["garden_west","garden_center","garden_east"]
const STORIES := ["梁伯留下的手绘图册：这里以前是货运站，大家沿铁轨走去海边。","林巧的图册背面：书屋开张那天，邻居各带来一本旧书。","周宁写下的新约定：下次把家里的老图画也带来，给后来的人讲讲。"]
var game: Node3D
var points: Array[CityActivityPoint]=[]
var room: CityBookshop
var garden_board: Label3D
var garden_art: Node3D
var garden_pictures: Array[Sprite3D]=[]
var method := ""
var checked := false
var prepared := false
var elapsed := 0.0
var result := ""
var participants: Array[String]=[]
var guide := ""
var joined := false
var walk: CityStoryWalk

func _ready() -> void:
	name="CityLife"
	room=game.get_node("ConnectedDistrict/CommunityBookshop")
	for id in POINTS:
		var point := CityActivityPoint.new()
		point.stable_id=id
		point.title=POINTS[id][0]
		point.position=POINTS[id][1]
		points.append(point)
		add_child(point)
	garden_art=Node3D.new()
	add_child(garden_art)
	garden_art.position=Vector3(38,0,51.5)
	Shapes.solid(garden_art,Vector3(3,1.5,.08),Vector3(0,1.7,0),Color("546f65"))
	for x in [-1.2,1.2]: Shapes.solid(garden_art,Vector3(.08,2,.08),Vector3(x,1,0),Color("546f65"))
	garden_board=Shapes.label(garden_art,"社区花园\n今日活动见书屋公告",Vector3(0,2.15,.08),32)
	garden_board.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	garden_board.pixel_size=.0038
	garden_board.outline_size=0
	garden_board.width=700
	garden_board.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in range(3): garden_pictures.append(CityBookshop.picture(garden_art,CityBookshop.IMAGES[i],Vector3((i-1)*.95,1.45,.09),.0011))
	walk=CityStoryWalk.new()
	walk.game=game
	add_child(walk)
	sync_scene()

func is_open() -> bool:
	var minute: int=game.payroll.minute%1440
	return minute>=540 and minute<1200

func point_for(id: String) -> CityActivityPoint:
	for point in points:
		if point.stable_id==id: return point
	return null

func active() -> bool:
	return method!="" and result=="" and prepared and is_open()

func venue_goal(person: CityResident) -> String:
	var slot := AUDIENCE.find(person.index)
	return (OUTDOOR if method=="garden" else PAPER if method=="paper" else INDOOR)[slot] if active() and slot>=0 else ""

func redirect(person: CityResident) -> void:
	if walk and walk.redirect(person): return
	if not person.available() or person.fear>0 or person.crossing!="" or game.speaker==person: return
	var target := venue_goal(person)
	if not is_open() and (person.destination in INDOOR or person.destination in PAPER or person.destination in ["bookshop_entry","bookshop_room"]): target="bookshop"
	if target=="": return
	if person.destination!=target: person.plan(target)
	elif person.state=="activity" and active(): person.activity_left=2

func present(person: CityResident) -> bool:
	var goal := venue_goal(person)
	return goal!="" and person.available() and person.fear==0 and person.position.distance_to(CityPopulation.POINTS[goal])<1.25 and person.state=="activity"

func center() -> Vector3:
	return Vector3(38,0,57) if method=="garden" else Vector3(-55,0,30) if method=="paper" else Vector3(-52,0,31)

func focus_position() -> Vector3:
	return garden_art.position if method=="garden" else room.album.global_position if method=="paper" else room.projection.global_position

func caption() -> String:
	if not active() or not joined or not player_at_event(): return ""
	var count := 0
	for person in game.population.residents:
		if present(person): count+=1
	return STORIES[mini(2,int(elapsed/6))] if count>=2 else "分享暂时中断，等居民回到现场后继续。"

func player_at_event() -> bool:
	var position: Vector3=game.player.position
	if game.player.hp<=0 or game.in_vehicle(): return false
	if method=="garden": return position.distance_to(center())<7
	return position.x> -58.25 and position.x< -45.75 and position.z>25.75 and position.z<38.25 and absf(position.y)<2

func _physics_process(delta: float) -> void:
	var attending: Array[String]=[]
	if active():
		for person in game.population.residents:
			if present(person): attending.append(person.stable_id)
		var near := player_at_event()
		if near and attending.size()>=2:
			if not joined: joined=true; game.say("居民已到场，街区记忆分享开始。你可以随时离开。")
			elapsed=minf(18,elapsed+delta)
			for id in attending:
				if not id in participants: participants.append(id)
			if elapsed>=18:
				result=method
				game.career.record("city_bookshop_shared","在榕树街书屋以"+METHODS[method]+"完成街区记忆分享，参与者记住了这次经历。")
				game.say("分享结束。居民留下了下次带图画来的约定；回公司也可以聊起这段经历。")
				game.queue_save()
	sync_scene()

func sync_scene() -> void:
	if not room: return
	room.announcement.text="09:00—20:00\n"+("欢迎自由阅览" if is_open() else "已闭馆 · 出口保持畅通")
	for lamp in room.lamps: lamp.light_energy=.65 if is_open() else .12
	room.album.visible=true
	room.album.rotation.y=.35 if prepared and method=="paper" else 0.0
	room.projection.visible=prepared and method=="screen"
	room.projection.texture=CityBookshop.IMAGES[mini(2,int(elapsed/6))]
	for picture in garden_pictures: picture.visible=prepared and method=="garden"
	room.screen.text="街区记忆分享\n网络影像暂不可用"
	if prepared and method=="screen": room.screen.text="本地图册 / 榕树街记忆\n货运站 → 街区 → 书屋"
	if method=="paper" and prepared: room.screen.text="今日改用纸本共读\n阅览台见"
	if method=="garden" and prepared: room.screen.text="今日分享移到社区花园\n沿步道向东"
	if result!="": room.screen.text="街区记忆分享已完成\n"+METHODS[result]+" · 下次带上你的图画"
	garden_board.text="榕树街手绘图册展\n货运站 · 老街 · 新邻居" if prepared and method=="garden" else "社区花园\n今日活动见书屋公告"
	if joined and result=="" and active():
		var line: String=STORIES[mini(2,int(elapsed/6))]
		if method=="garden": garden_board.text=line.replace("：","\n")
		else: room.screen.text=line.replace("：","\n")

func status_text() -> String:
	if result!="": return "街区记忆分享已完成 · "+METHODS[result]+"。"+(walk.status_text() if walk else "可回访书屋。")
	if not is_open(): return "书屋已闭馆（09:00—20:00）；准备进度保留，可明天继续。"
	if method=="": return "榕树街书屋开放中：自由阅览，或协助街区记忆分享。"
	if not prepared: return "街区记忆分享 · "+METHODS[method]+"："+{"screen":"去播放台检查故障并启用本地图册。","paper":"去阅览台展开纸本图画。","garden":"去花园展示架布置图画。"}[method]
	return "街区记忆分享 · "+METHODS[method]+"：等待居民到场，在现场听完分享（%d/18秒）。" % int(elapsed)

func open_point(point: CityActivityPoint) -> void:
	if point.stable_id=="walk" or point.stable_id=="notice" and result!="": walk.open_board(point); return
	game.close_interaction()
	game.speaker=point
	var choices: Array=[]
	var text := status_text()
	if point.stable_id=="notice" and result=="" and is_open():
		text+="\n原网络影像不可用。可以切换本地图册、围桌共读纸本，也可以把图画展移到花园。"
		choices=[["尝试恢复室内投影","city_plan_screen"],["围桌共读纸本图画","city_plan_paper"],["改在社区花园办展","city_plan_garden"]]
	elif is_open() and result=="" and method==point.stable_id:
		if method=="screen":
			text+="\n检查结果：网络播放器不可用，设备内保留了本地图册。" if checked else "\n先检查播放台，确认还有什么可以用。"
			choices.append(["启用本地图册" if checked else "检查播放台","city_prepare" if checked else "city_check"])
		elif not prepared: choices.append(["展开图画，邀请邻居共读" if method=="paper" else "展开展板，通知居民到花园","city_prepare"])
	if point.stable_id=="paper" and is_open(): choices.append(["翻看街区手绘图册","city_read"])
	choices.append(["先去做别的","city_leave"])
	game.conversation={"text":text,"choices":choices}

func answer(point: CityActivityPoint,action: String) -> void:
	if action.begins_with("walk_"): walk.answer(point,action); return
	if action=="city_leave": game.close_interaction(); return
	if not is_open(): open_point(point); return
	if action=="city_read":
		game.conversation={"text":"图册背面的手写记录：\n"+"\n".join(PackedStringArray(STORIES)),"choices":[["合上图册","city_leave"]]}
		return
	if result!="": open_point(point); return
	if action.begins_with("city_plan_") and point.stable_id=="notice":
		method=action.trim_prefix("city_plan_")
		checked=false; prepared=false; elapsed=0; joined=false; participants.clear()
		guide=method
		game.driving.guide_car=""
		game.transit.waypoint=""
	elif action=="city_check" and point.stable_id=="screen" and method=="screen":
		checked=true
		open_point(point)
		game.queue_save()
		return
	elif action=="city_prepare" and point.stable_id==method and (method!="screen" or checked):
		prepared=true
		guide="garden" if method=="garden" else "paper"
	else: return
	game.close_interaction()
	sync_scene()
	game.say(status_text())
	game.queue_save()

func resident_line(person: CityResident) -> String:
	if walk.stage==5 and person.stable_id in walk.authors: return "我记得我们一起走过的那条路。"+("墙上的展览" if walk.notes[2]=="wall" else "桌上的图册")+"里，也留下了我的话。"
	if walk.stage==4 and person.stable_id in walk.authors: return "走访的笔记还在整理。明天回书屋，我们把它留给后来的人。"
	if person.stable_id in participants and result!="": return "我记得那次"+METHODS[result]+"，下次带自己的图画来。"
	return "书屋九点到二十点开放，可以看街区图册，也能帮忙办分享会。"

func can_share(npc: OfficeNPC) -> bool:
	return result!="" and npc.role_id in ["a_friend","b_friend"] and game.social.willing(npc)

func share(npc: OfficeNPC) -> void:
	if not can_share(npc): return
	var first: bool=game.social.remember(npc,"bookshop_shared","你讲起在社区以"+METHODS[result]+"完成手绘图册分享的经历。",3,3)
	game.conversation={"text":npc.title.split(" · ")[0]+("：原来不用一直等设备修好，也能把人聚到一起。下班以后有这样的地方挺好。" if first else "：上次书屋的事我记得。下次有新图画再和我说。"),"choices":[["回头再聊","people_continue"],["回到工作话题","people_work"]]}

func snapshot() -> Dictionary:
	return {"schema":1,"method":method,"checked":checked,"prepared":prepared,"elapsed":elapsed,"result":result,"participants":participants.duplicate(),"guide":guide,"joined":joined}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1: return false
	if not data.get("method") in ["","screen","paper","garden"] or not data.get("result") in ["","screen","paper","garden"] or not data.get("guide") in ["","notice","screen","paper","garden"]: return false
	for key in ["checked","prepared","joined"]:
		if not data.get(key) is bool: return false
	if not CityPopulation.number(data.get("elapsed"),0,18) or not data.get("participants") is Array or data.participants.size()>AUDIENCE.size(): return false
	var seen := {}
	for id in data.participants:
		var known := false
		for index in AUDIENCE:
			if id==game.population.residents[index].stable_id: known=true
		if not known or seen.has(id): return false
		seen[id]=true
	if data.method=="" and (data.checked or data.prepared or data.joined or data.elapsed>0 or not data.participants.is_empty() or data.result!=""): return false
	if data.checked and data.method!="screen" or data.prepared and data.method=="screen" and not data.checked: return false
	if not data.prepared and (data.elapsed>0 or data.joined or not data.participants.is_empty()): return false
	if data.joined!=(data.elapsed>0) or data.joined and data.participants.size()<2: return false
	return (data.result=="" and data.elapsed<18) or (data.result==data.method and data.result!="" and data.elapsed==18 and data.prepared)

func restore(data: Dictionary) -> void:
	method=data.get("method",""); checked=data.get("checked",false); prepared=data.get("prepared",false)
	elapsed=data.get("elapsed",0); result=data.get("result",""); guide=data.get("guide",""); joined=data.get("joined",false)
	participants.assign(data.get("participants",[]))
	sync_scene()

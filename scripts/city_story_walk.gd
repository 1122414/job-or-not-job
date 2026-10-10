class_name CityStoryWalk
extends Node3D

const GUIDES := ["resident_liang_bo","resident_lin_qiao"]
const STOPS := ["market","sea_west","bookshop_room"]
const NAMES := ["榕树街广场","海风步道西段","社区书屋"]
const CHOICES := [["work","daily"],["named","anonymous"],["wall","album"]]
var game: Node3D
var stage := 0
var partner := ""
var meeting := false
var paused := false
var guiding := false
var notes: Array[String]=[]
var authors: Array[String]=[]
var ready_day := -1
var board: Node3D
var board_text: Label3D
var album: Node3D
var point_label: Label3D

func _ready() -> void:
	name="StoryWalk"
	var point := CityActivityPoint.new()
	point.stable_id="walk"
	point.title="街区走访 · 留言与展陈"
	point.position=Vector3(-47,0,36)
	game.city_life.points.append(point)
	add_child(point)
	point_label=point.find_children("*","Label3D",true,false)[0]
	board=Node3D.new()
	add_child(board)
	board.position=Vector3(-45.86,1.8,34.8)
	board.rotation.y=-PI/2
	Shapes.box(board,Vector3(3.8,2.4,.04),Vector3.ZERO,Color("42675e"))
	Shapes.box(board,Vector3(3.7,1.92,.025),Vector3(0,-.18,.027),Color("c9b895"))
	var heading := Shapes.label(board,"从旧站到海边",Vector3(0,.92,.05),42)
	heading.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	heading.pixel_size=.0048
	heading.outline_size=0
	CityBookshop.picture(board,CityBookshop.IMAGES[0],Vector3(-.98,-.12,.05),.00165)
	board_text=Shapes.label(board,"",Vector3(-.03,-.14,.06),28)
	board_text.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	board_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	board_text.pixel_size=.0036
	board_text.width=490
	board_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	board_text.outline_size=0
	album=Node3D.new()
	point.add_child(album)
	album.position=Vector3(0,1.04,0)
	Shapes.box(album,Vector3(.55,.035,.35),Vector3.ZERO,Color("e0d6b8"))
	var page := CityBookshop.picture(album,CityBookshop.IMAGES[1],Vector3(0,.021,0),.00056)
	page.rotation.x=-PI/2
	sync_scene()

func person_for(id: String) -> CityResident:
	for person in game.population.residents:
		if person.stable_id==id: return person
	return null

func person_name(id: String) -> String:
	var person := person_for(id)
	return person.title.split(" · ")[0] if person else "邻居"

func active() -> bool:
	return stage in [1,2,3] and not paused and game.city_life.is_open()

func goal() -> String:
	return "bookshop_entry" if meeting else STOPS[stage-1] if stage in [1,2,3] else ""

func redirect(person: CityResident) -> bool:
	if person.stable_id!=partner or not active(): return false
	if not person.available() or person.fear>0 or person.crossing!="" or game.speaker==person: return true
	if person.destination!=goal(): person.plan(goal())
	person.phase=game.population.time_phase()
	if person.state=="activity": person.activity_left=2
	return true

func waits(person: CityResident) -> bool:
	return active() and not meeting and person.stable_id==partner and person.crossing=="" and person.position.distance_to(game.player.position)>7

func at_stop(person: CityResident) -> bool:
	return active() and person.stable_id==partner and person.available() and person.fear==0 and person.crossing=="" and person.route.is_empty() and person.position.distance_to(CityPopulation.POINTS[goal()])<1.3 and game.player.hp>0 and not game.in_vehicle() and person.position.distance_to(game.player.position)<3 and game.can_see(game.player,person)

func release() -> void:
	var person := person_for(partner)
	if person and person.available() and person.fear==0 and person.crossing=="" and game.speaker!=person: person.plan(game.population.destination(person))

func _physics_process(_delta: float) -> void:
	if stage in [1,2,3] and not paused:
		var person := person_for(partner)
		if not game.city_life.is_open() or game.player.hp<=0 or not person.available() or person.fear>0:
			paused=true
			if game.speaker==person: game.close_interaction()
			release()
			game.say("街区走访暂歇，已经记下的内容保留。方便时与带路人交谈，或到书屋公告重新约人。")
			game.queue_save()
	sync_scene()

func status_text() -> String:
	if stage==0: return "街区记忆分享之后，可在书屋约邻居走访旧站与海边。"
	if stage==5: return "《从旧站到海边》已留在书屋。可以重读，也可以与熟悉的同事聊起。"
	if stage==4: return "走访笔记已整理。第%d天09:00起，回书屋留言台亲手布置%s。可先做别的，也可去下班路公交站休息。" % [ready_day+1,"墙面展览" if notes[2]=="wall" else "共读图册"]
	if paused:
		var person := person_for(partner)
		if not person.available() or person.fear>0: return person_name(partner)+"现在无法同行，已经记下的内容会保留。可等待，或去书屋公告约其他邻居。"
		return "街区走访暂歇 · 已记下%d段。与%s交谈可继续，书屋公告可重新约人。" % [notes.size(),person_name(partner)]
	if meeting: return person_name(partner)+"正走来书屋门口。见面交谈后一起出发。"
	return person_name(partner)+"带路 · "+NAMES[stage-1]+"（%d/3）。路边会等你，到达后交谈；可随时暂停。" % stage

func target() -> Node3D:
	if stage in [1,2,3]:
		var person := person_for(partner)
		return game.city_life.point_for("notice") if paused and (not person.available() or person.fear>0) else person
	return game.city_life.point_for("walk")

func start(id: String) -> bool:
	var person := person_for(id)
	if not id in GUIDES or not person or game.city_life.result=="" or not game.city_life.is_open() or stage>=4: return false
	if not person.available() or person.fear>0 or person.hits>0 and not person.apologized: return false
	release()
	partner=id
	if stage==0: stage=1
	meeting=true; paused=false
	set_guide()
	game.queue_save()
	return true

func set_guide() -> void:
	guiding=true
	game.rental.clear_guide()
	game.home.guiding=false
	game.city_life.guide=""
	game.driving.guide_car=""
	game.transit.waypoint=""

func open_board(point: CityActivityPoint) -> void:
	game.close_interaction()
	game.speaker=point
	var choices: Array=[]
	var text := status_text()
	if stage==5:
		text=exhibit_text()+"\n这份记录留在这里，后来的人也能读到。"
	elif game.city_life.result!="" and game.city_life.is_open():
		if stage<4:
			text+="\n梁伯熟悉旧站，林巧记录书屋的日常。可以分几次走完，换带路人也保留原口述者。"
			for id in GUIDES:
				var person := person_for(id)
				if person.available() and person.fear==0 and (person.hits==0 or person.apologized): choices.append(["约"+person_name(id)+"在书屋门口见面","walk_start_"+id])
			if active(): choices.append(["先忙别的，保留笔记","walk_pause"])
		elif int(game.payroll.minute/1440)>=ready_day and point.stable_id=="walk": choices.append(["把整理好的记录留在书屋","walk_publish"])
	choices.append(["合上记录","city_leave"])
	game.conversation={"text":text,"choices":choices}

func options(person: CityResident) -> Dictionary:
	if person.stable_id!=partner or not stage in [1,2,3]: return {}
	var choices: Array=[]
	var text := status_text()
	if paused:
		if game.city_life.is_open() and (person.hits==0 or person.apologized): choices.append(["从上次停下的地方继续","walk_resume"])
	elif at_stop(person):
		if meeting:
			text=person_name(partner)+"：我们从旧站的位置走到海边，最后回书屋。可以写下我的话，署名或匿名都可以；走累了随时歇。"
			choices.append(["一起出发","walk_depart"])
		elif stage==1:
			text=person_name(partner)+("：以前货车在这儿卸货。大家记得车站，但我还记得收工后卖热汤的人。" if partner==GUIDES[0] else "：整理旧照片时，大家都在讲车站。我却总看见照片边上摆摊和等人的邻居。")+"\n你想让后来的人先看到哪一面？这段话也可以公开。"
			choices=[["记录劳动与旧站的历史","walk_note_work"],["记录普通人的日常生活","walk_note_daily"]]
		elif stage==2:
			text=person_name(partner)+("：沿这里走到海边，是我以前下工后的习惯。那时候不觉得这也算故事。" if partner==GUIDES[0] else "：关了书屋，我常来这里坐一会儿。有时就是想安静，不用再回答谁的问题。")+"\n这段话我愿意公开。你可以写我的名字，也可以只写一位邻居。"
			choices=[["保留口述者姓名","walk_note_named"],["隐去姓名，让故事自己说话","walk_note_anonymous"]]
		else:
			text=person_name(partner)+"：走过一遍，图册里的街道就有了人的声音。整理一晚，明天你来把记录放好。做成墙展，路过的人会看见；放成图册，愿意坐下来的人可以慢慢读。"
			choices=[["做成常设墙展","walk_note_wall"],["留作桌上的共读图册","walk_note_album"]]
	if not paused: choices.append(["今天先到这里，保留笔记","walk_pause"])
	choices.append(["继续走，稍后再聊","resident_bye"])
	return {"text":text,"choices":choices}

func answer(speaker: Node3D,action: String) -> void:
	if action=="walk_pause" and stage in [1,2,3]:
		paused=true; guiding=false
		game.close_interaction(); release(); game.queue_save()
		return
	if action.begins_with("walk_start_") and speaker is CityActivityPoint:
		game.close_interaction()
		if not start(action.trim_prefix("walk_start_")): game.say("对方现在不方便同行。已有记录会保留。")
		return
	if action=="walk_publish" and speaker is CityActivityPoint:
		if speaker.stable_id!="walk" or stage!=4 or not game.city_life.is_open() or int(game.payroll.minute/1440)<ready_day or game.player.position.distance_to(speaker.position)>3 or game.player.hp<=0 or game.in_vehicle() or not game.can_see(game.player,speaker): return
		stage=5
		game.career.record("city_story_walk","与街区居民走访旧站和海边，将记录留在了书屋。")
		sync_scene(); open_board(speaker); game.queue_save()
		return
	if not speaker is CityResident or speaker.stable_id!=partner or not speaker.available() or speaker.fear>0 or speaker.crossing!="": return
	if action=="walk_resume" and paused and game.city_life.is_open() and (speaker.hits==0 or speaker.apologized):
		paused=false; set_guide(); game.close_interaction(); game.queue_save()
		return
	if not at_stop(speaker): return
	if action=="walk_depart" and meeting: meeting=false
	elif action.begins_with("walk_note_") and not meeting:
		var choice := action.trim_prefix("walk_note_")
		if not choice in CHOICES[stage-1]: return
		notes.append(choice); authors.append(partner); stage+=1
		if stage==4: ready_day=int(game.payroll.minute/1440)+1
	else: return
	game.close_interaction()
	game.say(status_text())
	sync_scene(); game.queue_save()

func exhibit_text() -> String:
	if notes.size()!=3: return "《从旧站到海边》\n走访记录整理中"
	var focus := "货车在旧站卸货，人们沿步道走向海边。\n一座街区也记得在这里工作的人。" if notes[0]=="work" else "摊边的热汤，书屋里的旧书，海边的长凳。\n日子由这些普通的相遇连起来。"
	var quote := "“下工后沿这条路走到海边，以前没觉得这也算故事。”" if authors[1]==GUIDES[0] else "“关了书屋，来海边坐一会儿，也想给自己留一点安静。”"
	var credit := "口述：一位街区邻居" if notes[1]=="anonymous" else "口述："+person_name(authors[1])
	return "从旧站到海边\n\n"+focus+"\n\n"+quote+"\n"+credit+"\n与你共同走访、整理"

func sync_scene() -> void:
	if not board: return
	board.visible=stage==5 and notes[2]=="wall"
	album.visible=stage==5 and notes[2]=="album"
	point_label.visible=not board.visible
	board_text.text=exhibit_text().trim_prefix("从旧站到海边\n\n")

func share(npc: OfficeNPC) -> void:
	if stage!=5 or not game.city_life.can_share(npc): return
	var first: bool=game.social.remember(npc,"city_story_walk","你们聊起留在书屋的走访记录："+("劳动历史" if notes[0]=="work" else "普通人的日常")+"。",3,3)
	game.conversation={"text":npc.title.split(" · ")[0]+("：工作留下的不只有交付的东西，也有人的经历。你把他们的话留下来了。" if notes[0]=="work" else "：原来散步、坐一会儿也值得被记下来。我也想给自己的晚上留点空。") if first else npc.title.split(" · ")[0]+"：那份书屋记录我记得。听你讲过，才知道那条路对他们意味着什么。","choices":[["回头再聊","people_continue"],["回到工作话题","people_work"]]}

func snapshot() -> Dictionary:
	return {"schema":1,"stage":stage,"partner":partner,"meeting":meeting,"paused":paused,"guiding":guiding,"notes":notes.duplicate(),"authors":authors.duplicate(),"ready_day":ready_day}

func valid(data: Variant,life: Dictionary,minute: float) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not CityPopulation.number(data.get("stage"),0,5,true): return false
	for key in ["meeting","paused","guiding"]:
		if not data.get(key) is bool: return false
	if not data.get("notes") is Array or not data.get("authors") is Array or not CityPopulation.number(data.get("ready_day"),-1,100000000,true): return false
	var count := mini(3,maxi(0,int(data.stage)-1))
	if data.notes.size()!=count or data.authors.size()!=count: return false
	for i in range(count):
		if not data.notes[i] in CHOICES[i] or not data.authors[i] in GUIDES: return false
	if data.stage==0: return data.get("partner")=="" and not data.meeting and not data.paused and not data.guiding and data.ready_day== -1
	if not data.get("partner") in GUIDES or life.get("result","")=="": return false
	if data.stage>=4 and (data.meeting or data.paused or data.ready_day<1 or data.ready_day>int(minute/1440)+1): return false
	if data.stage>=4 and data.authors[-1]!=data.partner: return false
	if data.stage<4 and data.ready_day!= -1: return false
	return data.stage!=5 or data.ready_day<=int(minute/1440)

func restore(data: Dictionary) -> void:
	stage=int(data.get("stage",0)); partner=data.get("partner","")
	meeting=data.get("meeting",false); paused=data.get("paused",false); guiding=data.get("guiding",false)
	notes.assign(data.get("notes",[])); authors.assign(data.get("authors",[]))
	ready_day=int(data.get("ready_day",-1)); sync_scene()

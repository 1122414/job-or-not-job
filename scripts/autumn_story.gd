class_name AutumnStory
extends RefCounted

const CAMPUS_SPAWN := Vector3(0,40.15,2)
const STREET_SPAWN := Vector3(-14,0.2,5)
const MENTOR_LINES := [
	["导师：实习先别想。我们那个年代都没有实习这个概念，不也找到工作了？你现在的任务是把研究做好。",["现在秋招会看实习经历，我想提前准备","项目已经做完了，我可以安排好交接","您之前说项目做完就可以再谈"],["导师：企业列什么条件你就跟着跑？先把学位拿到，比那些重要。","导师：项目做完还有论文。你人去了公司，组里的事情谁接？","导师：再谈不等于答应。情况在变，你不能只记着那一句。"]],
	["导师：公司让你去几个月，回来论文还做不做？别人的节奏不能打乱我们组的安排。",["我每周回来汇报，论文计划不变","我只去暑期，秋招前回来","那秋招没有经历怎么办"],["导师：两边跑，哪边都做不好。我不同意。","导师：暑期正是集中出成果的时候，也不行。","导师：把研究做好，找工作自然会有办法。你不要现在就想着外面的事情。"]],
	["导师：这件事就这么定了，不许去。把下周汇报的材料准备好。",["我不同意，但知道您的决定了","我会继续准备秋招","结束谈话，先离开"],["导师：你以后就知道我为什么这么要求了。","导师：先顾眼前，找工作的事到时候再说。","导师：出去记得把门带上。"]]
]
var game: Node3D
var data := blank()
var room: Node3D
var points: Array[AutumnStoryPoint] = []

static func blank(mode: String="legacy") -> Dictionary:
	return {"mode":mode,"phase":"mentor" if mode=="current" else "legacy","beat":0,"reply":-1,"answers":[],"mentor_interrupted":false}

func active() -> bool:
	return data.mode=="current"

func campus() -> bool:
	return active() and data.phase in ["mentor","campus_exit"]

func build() -> void:
	room=Node3D.new()
	room.name="GraduatePrologue"
	game.add_child(room)
	room.position=Vector3(0,40,0)
	Shapes.solid(room,Vector3(12,.2,14),Vector3(0,-.1,2),Color("a6a19a"))
	for wall in [[Vector3(12,3.5,.2),Vector3(0,1.75,-5)],[Vector3(.2,3.5,14),Vector3(-6,1.75,2)],[Vector3(.2,3.5,14),Vector3(6,1.75,2)],[Vector3(12,3.5,.2),Vector3(0,1.75,9)]]:
		Shapes.solid(room,wall[0],wall[1],Color("d3d0c3"))
	Shapes.solid(room,Vector3(12,.15,14),Vector3(0,3.5,2),Color("d9d6cb"))
	# Doorway divides the office and corridor; walking remains under player control.
	for x in [-3.65,3.65]: Shapes.solid(room,Vector3(4.7,3.5,.15),Vector3(x,1.75,5),Color("a6b7b3"))
	Shapes.solid(room,Vector3(2.5,.12,1),Vector3(0,.8,-1),Color("9a795d"))
	for x in [-1.05,1.05]: Shapes.solid(room,Vector3(.12,.8,.8),Vector3(x,.4,-1),Color("52585b"))
	Shapes.box(room,Vector3(.7,.035,.45),Vector3(.5,.88,-.8),Color("f0ead9"))
	Shapes.box(room,Vector3(.8,.5,.06),Vector3(-.6,1.1,-1.15),Color("34454a"))
	for i in range(3):
		Shapes.solid(room,Vector3(1.3,.8,.5),Vector3(-4.8,.4+i*.8,-3),Color("8e7a62"))
		Shapes.box(room,Vector3(1.1,.5,.35),Vector3(-4.8,.65+i*.8,-2.9),Color("617c86"))
	var sign := Shapes.label(room,"研究生导师办公室",Vector3(0,2.8,-4.85),34)
	sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	var light := OmniLight3D.new()
	light.position=Vector3(0,2.8,0); light.omni_range=12; light.light_energy=2.0
	room.add_child(light)
	add_point("story_mentor","导师 · 讨论暑期实习",Vector3(0,40,-2.2),true)
	add_point("story_exit","走廊 · 离校与秋招",Vector3(0,40,7.2))
	sync_scene()

func add_point(id: String,title: String,at: Vector3,person: bool=false) -> void:
	var point := AutumnStoryPoint.new()
	point.story=self; point.stable_id=id; point.title=title; point.person=person
	game.add_child(point); point.position=at
	points.append(point)

func start_new() -> void:
	data=blank("current")
	game.career.facts["autumn_story"]=true
	game.player.position=CAMPUS_SPAWN
	game.player.yaw=0; game.player.pitch=-.08
	sync_scene()

func sync_scene() -> void:
	if room: room.visible=campus()
	for point in points: point.visible=campus()

func objective() -> Dictionary:
	if not active(): return {}
	if data.phase=="mentor": return {"title":"秋招前 · 与导师讨论暑期实习（可走开或结束谈话）","id":"story_mentor"}
	if data.phase=="campus_exit": return {"title":"实习未获允许 · 走到办公室外的走廊","id":"story_exit"}
	return {}

func open(point: AutumnStoryPoint) -> void:
	if not campus(): return
	game.speaker=point
	if point.stable_id=="story_exit":
		game.conversation={"text":"暑期实习的确认期限已经过去。你留在学校做项目。\n毕业学年，秋招开始。简历的实习经历一栏仍是空白。","choices":[["带上简历，进入秋招","story_autumn"],["回办公室再谈谈","story_pause"]]} if data.phase=="campus_exit" else {"text":"实习还没有得到允许。可以回去继续争辩，也可以结束这次谈话。","choices":[["不再争辩，离开办公室","story_leave"],["回去继续谈","story_pause"]]}
	elif data.phase=="campus_exit":
		game.conversation={"text":"导师：实习的事已经说过了，不许去。下周照常汇报。","choices":[["结束谈话","story_pause"]]}
	elif data.reply>=0:
		game.conversation={"text":MENTOR_LINES[data.beat][2][data.reply],"choices":[["继续听","story_next"],["结束争辩，离开","story_leave"]]}
	else:
		var beat: Array=MENTOR_LINES[data.beat]
		var choices: Array=[]
		for i in range(beat[1].size()): choices.append([beat[1][i],"story_answer_"+str(i)])
		choices.append(["结束争辩，离开","story_leave"])
		game.conversation={"text":beat[0],"choices":choices}

func refuse(interrupted: bool=false) -> void:
	data.phase="campus_exit"
	data.mentor_interrupted=interrupted
	game.career.record("mentor_refused","秋招前争取暑期实习，导师拒绝批准。实习机会错过，留校完成研究。")
	game.close_interaction(); game.queue_save()
	sync_scene()

func handle(action: String) -> bool:
	if not action.begins_with("story_"): return false
	if not campus(): return true
	var point: AutumnStoryPoint=game.speaker as AutumnStoryPoint
	if not point: return true
	if action=="story_pause": game.close_interaction(); return true
	if action=="story_leave": refuse(); return true
	if action=="story_autumn" and data.phase=="campus_exit" and point.stable_id=="story_exit":
		data.phase="early_autumn"
		game.career.record("autumn_started","毕业学年参加秋招。没有企业实习经历，保留研究项目与成果。")
		game.close_interaction()
		game.player.position=STREET_SPAWN; game.player.velocity=Vector3.ZERO
		game.player.yaw=0; game.player.pitch=-.08
		game.say("秋招前段 · 应届研究生。两家公司都可以先去了解，J查看安排。")
		sync_scene(); game.queue_save(); return true
	if data.phase!="mentor" or point.stable_id!="story_mentor": return true
	if action.begins_with("story_answer_") and data.reply==-1:
		var answer := int(action.trim_prefix("story_answer_"))
		if answer<0 or answer>=3: return true
		data.reply=answer; data.answers.append(answer)
	elif action=="story_next" and data.reply>=0:
		data.beat+=1; data.reply=-1
		if data.beat==MENTOR_LINES.size(): refuse(); return true
	open(point); game.queue_save()
	return true

func restore(saved: Dictionary) -> void:
	data=saved.duplicate(true) if not saved.is_empty() else blank()
	sync_scene()

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("mode") in ["legacy","current"]: return false
	if not value.get("phase") in ["legacy","mentor","campus_exit","early_autumn"]: return false
	if (value.mode=="legacy")!=(value.phase=="legacy"): return false
	for key in ["beat","reply"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(value[key]) or value[key]!=int(value[key]): return false
	if value.beat<0 or value.beat>3 or value.reply< -1 or value.reply>2: return false
	if value.phase=="mentor" and value.beat>=3: return false
	if not value.get("answers") is Array or value.answers.size()!=int(value.beat)+(1 if value.reply>=0 else 0): return false
	for answer in value.answers:
		if not (answer is int or answer is float) or answer!=int(answer) or answer<0 or answer>2: return false
	return value.get("mentor_interrupted") is bool

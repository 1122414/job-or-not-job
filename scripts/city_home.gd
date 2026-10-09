class_name CityHome
extends Node3D

const CENTER := Vector3(56,0,32)
const SEAT := CENTER+Vector3(3.6,0,3.75)
const POINTS := {
	"home_sofa":["沙发 · 坐下歇歇",Vector3(3.6,0,3.75)],
	"home_bed":["床边 · 休息",Vector3(-4.05,0,-4.5)],
	"home_light":["室内灯",Vector3(1.81,0,6.72)],
	"home_curtain":["客厅窗帘",Vector3(4.55,0,6.6)],
	"home_picture":["城市明信片",Vector3(6.5,0,1.0)],
	"home_memory":["生活留痕",Vector3(.76,0,-6.5)]
}
var game: Node3D
var room: CityHomeRoom
var points: Array[CityHomePoint]=[]
var entrance: CityHomePoint
var lights_on := true
var curtains_closed := false
var picture := 0
var visited := false
var last_rest := -1
var guiding := false
var seat_owned := false
var memory_clock := 0.0

func _ready() -> void:
	name="CityHome"
	room=game.get_node("ConnectedDistrict/HomeRoom")
	entrance=CityHomePoint.new()
	entrance.stable_id="home_entry";entrance.title="东里 101 · 我的住处"
	entrance.position=CENTER+Vector3(0,0,8.5)
	add_child(entrance)
	for id in POINTS:
		var point := CityHomePoint.new()
		point.stable_id=id;point.title=POINTS[id][0];point.position=CENTER+POINTS[id][1]
		add_child(point);points.append(point)
	sync_scene()

func inside(point: Vector3) -> bool:
	var p := point-CENTER
	return absf(p.x)<6.84 and absf(p.z)<6.84 and p.y>-.3 and p.y<2.8

func point_for(id: String) -> CityHomePoint:
	for point in points:
		if point.stable_id==id: return point
	return null

func sitting() -> bool:
	return seat_owned and game.player.seated and game.player.seat_body==room.sofa and game.player.position.distance_to(SEAT)<.12

func _physics_process(delta: float) -> void:
	memory_clock+=delta
	if memory_clock>=1:
		memory_clock=0;room.memory.text=memory_text()
	if seat_owned and not sitting():
		if game.player.seat_body==room.sofa:
			game.player.remove_collision_exception_with(room.sofa)
			game.player.seat_body=null;game.player.seated=false
		seat_owned=false;game.queue_save()
	if inside(game.player.position) and not game.in_vehicle() and not visited:
		visited=true;game.queue_save()
	if guiding and inside(game.player.position):
		guiding=false;game.queue_save()

func can_use(point: CityHomePoint) -> bool:
	return point in points and inside(game.player.position) and game.player.hp>0 and not game.in_vehicle() and game.player.position.distance_to(point.position)<3.0 and game.can_see(game.player,point)

func open_point(point: CityHomePoint) -> void:
	if not can_use(point): return
	if point.stable_id=="home_sofa":
		use_sofa();return
	game.speaker=point
	match point.stable_id:
		"home_bed":
			game.conversation={"text":"把这段时间留给自己。休息后仍在住处，可以再决定去哪儿。","choices":[["休息到上午 · "+game.recruitment.stamp(game.rest_time("rest_morning")),"home_morning"],["休息到傍晚 · "+game.recruitment.stamp(game.rest_time("rest_evening")),"home_evening"],["先不休息","home_leave"]]}
		"home_light":
			lights_on=not lights_on;changed();game.say("室内灯已打开。" if lights_on else "室内灯已关闭。")
		"home_curtain":
			curtains_closed=not curtains_closed;changed();game.say("窗帘已拉上。" if curtains_closed else "窗帘已打开，能看见外面的街道。")
		"home_picture":
			game.conversation={"text":"给自己的住处换一张城市明信片。","choices":[["旧货运站","home_picture_0"],["街巷日常","home_picture_1"],["社区书屋","home_picture_2"],["保持现在这样","home_leave"]]}
		"home_memory":
			game.conversation={"text":"生活留痕\n"+memory_text(),"choices":[["收好，继续自己的安排","home_leave"]]}

func changed() -> void:
	game.close_interaction();sync_scene();game.queue_save()

func answer(point: CityHomePoint,action: String) -> void:
	if action=="home_leave": game.close_interaction();return
	if not can_use(point): game.close_interaction();return
	if point.stable_id=="home_bed" and action in ["home_morning","home_evening"]:
		var target: int=game.rest_time("rest_morning" if action=="home_morning" else "rest_evening")
		game.close_interaction()
		game.advance_time(target-game.payroll.minute)
		last_rest=game.payroll.minute
		visited=true;sync_scene();game.queue_save()
		game.say(game.payroll.time_text()+" · 休息过了，接下来由你安排。")
	elif point.stable_id=="home_picture" and action in ["home_picture_0","home_picture_1","home_picture_2"]:
		picture=int(action.right(1));changed()

func use_sofa() -> void:
	if sitting(): game.player.stand_up();return
	if not game.player.stand_up(): return
	var local: Vector3=room.sofa.to_local(game.player.position)
	if local.z>-.45 or game.player.position.distance_to(SEAT)>2.4:
		game.say("从沙发前面靠近，就可以坐下。");return
	var shape := CapsuleShape3D.new()
	shape.radius=.28;shape.height=1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape;query.collision_mask=3;query.margin=.005
	query.exclude=[game.player.get_rid(),room.sofa.get_rid()]
	query.transform.origin=SEAT+Vector3.UP*.9
	if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		game.say("沙发上放着东西，先挪开再坐吧。");return
	game.close_interaction()
	game.player.sit_at(SEAT,room.sofa,0)
	seat_owned=true;visited=true;game.queue_save()
	game.say("回到自己的住处 · 可以自由看四周，移动即可起身。")

func memory_text() -> String:
	var lines: Array[String]=[]
	var career: Career=game.career
	lines.append("正在"+("规程科技" if career.employer=="a" else "自己人网络")+"工作。" if career.employer!="" else "下一份工作，仍由自己选择。")
	if career.facts.has("output_two"): lines.append("两份工作成果已留下记录。")
	elif career.facts.has("output_one"): lines.append("第一份演示已经交付。")
	elif career.b_event in ["helped","negotiated","refused"]:
		lines.append({"helped":"和阿乐一起完成了交接。","negotiated":"与阿乐谈好了明早交接。","refused":"那次加班，你选择了自己的晚上。"}[career.b_event])
	if not game.friend_handover.data.is_empty(): lines.append(game.friend_handover.status())
	var company := ""
	if game.handover.data.get("phase")=="delivered": lines.append(game.handover.receipt())
	for npc in game.npcs:
		var city: Dictionary=game.social.people.get(npc.stable_id,{}).get("city",{})
		if not city.is_empty(): company=npc.title.split(" · ")[0];break
	if company!="": lines.append("和"+company+"在公司之外也有了共同经历。")
	if game.city_life.walk.stage==5: lines.append("街区的走访记录，已留在社区书屋。")
	elif game.city_life.walk.stage==4: lines.append("走访笔记整理好了，等回书屋亲手布置。")
	elif game.city_life.result!="": lines.append("参加过书屋的街区记忆分享。")
	if lines.size()==1: lines.append("把时间留给工作，也留给生活。")
	return "\n".join(lines)

func sync_scene() -> void:
	room.apply(lights_on,curtains_closed,picture)
	room.memory.text=memory_text()

func snapshot() -> Dictionary:
	return {"schema":1,"lights_on":lights_on,"curtains_closed":curtains_closed,"picture":picture,"visited":visited,"last_rest":last_rest,"guiding":guiding,"seated":sitting()}

func valid(data: Variant,world: Dictionary) -> bool:
	if not data is Dictionary or data.get("schema")!=1: return false
	for key in ["lights_on","curtains_closed","visited","guiding","seated"]:
		if not data.get(key) is bool: return false
	if not CityPopulation.number(data.get("picture"),0,2,true) or not CityPopulation.number(data.get("last_rest"),-1,world.payroll.minute,true): return false
	if data.last_rest>=0 and not data.visited: return false
	if data.seated:
		if not data.visited or world.player.hp<=0 or world.city_transit.riding or world.city_driving.active!="" or world.city_commons.player_slot!="": return false
		if SaveGame.unvector(world.player.position).distance_to(SEAT)>.12: return false
	return true

func restore(data: Dictionary) -> void:
	lights_on=data.get("lights_on",true);curtains_closed=data.get("curtains_closed",false)
	picture=int(data.get("picture",0));visited=data.get("visited",false)
	last_rest=int(data.get("last_rest",-1));guiding=data.get("guiding",false)
	seat_owned=data.get("seated",false)
	if seat_owned:
		# Rebind the physical seat without stowing a restored object or turning
		# the player's saved camera, unlike a fresh sit_at interaction.
		game.player.seated=true;game.player.seat_body=room.sofa
		game.player.add_collision_exception_with(room.sofa)
		game.player.visual.rotation.y=0
	sync_scene()

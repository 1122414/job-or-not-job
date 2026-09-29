extends "res://tools/render_city_evening.gd"
const Driver=preload("res://tests/scene_driver.gd")

var player_previous := Vector3.ZERO
var friend_previous := Vector3.ZERO
var metres := 0.0
var friend_metres := 0.0
var max_step := 0.0
var friend_max_step := 0.0
var desktop_safe := true
var visits := []

func record_step(game: Node3D) -> void:
	var step: float=game.player.position.distance_to(player_previous)
	metres+=step;max_step=maxf(max_step,step);player_previous=game.player.position
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	step=npc.position.distance_to(friend_previous)
	friend_metres+=step;friend_max_step=maxf(friend_max_step,step);friend_previous=npc.position
	desktop_safe=desktop_safe and guard()

func walk_to(game: Node3D,point: Vector3) -> bool:
	for i in range(3600):
		var offset: Vector3=point-game.player.position
		offset.y=0
		if offset.length()<.22:
			Input.action_release("forward")
			return true
		var direction := Driver.steer_around_people(game,offset)
		game.player.yaw=atan2(-direction.x,-direction.z)
		Input.action_press("forward")
		await physics_frame
	Input.action_release("forward")
	push_error("Day route blocked at "+str(game.player.position)+" toward "+str(point))
	return false

func interact_with(viewport: SubViewport,game: Node3D,target: Node3D) -> bool:
	var offset: Vector3=target.position-game.player.position
	game.player.yaw=atan2(-offset.x,-offset.z)
	for i in range(5): await physics_frame
	key(viewport,KEY_E)
	if game.speaker!=target:
		push_error("Day route interaction missed "+target.stable_id+" actual="+str(game.speaker));return false
	return true

func shot(viewport: SubViewport,game: Node3D,label: String) -> bool:
	if not guard() or not await capture(viewport,label): return false
	visits.append({"image":label,"minute":game.payroll.minute,"player":SaveGame.vector(game.player.position),"outing":game.social.outing.duplicate(true)})
	return true

func wait_at_foyer(game: Node3D,npc: OfficeNPC) -> bool:
	for i in range(6000):
		if npc.position.distance_to(CityEvening.FOYERS[npc.role_id])<.65: return true
		await physics_frame
	push_error("Colleague did not reach actual foyer: "+str(npc.position));return false

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	# Only the initial time/player location are fixtures. From here every move
	# uses normal input; the colleague follows its own physical route throughout.
	game.payroll.minute=1120;game.player.position=Vector3(0,0,18);game.player.pitch=-.05
	game.update_daylight()
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	player_previous=game.player.position;friend_previous=npc.position
	var monitor: Callable=record_step.bind(game)
	physics_frame.connect(monitor)
	var rest: WorkStation
	for station in game.stations:
		if station.stable_id=="rest":rest=station
	if not await wait_at_foyer(game,npc):quit(1);return
	if not await walk_to(game,npc.position+Vector3(0,0,1.5)):quit(1);return
	if not await interact_with(viewport,game,npc) or not choose(viewport,game,"people_menu") or not choose(viewport,game,"people_invite_walk") or not choose(viewport,game,"people_city_go_garden"):quit(1);return
	if not await shot(viewport,game,"evening-agreement"):quit(1);return
	if not await walk_to(game,rest.position+Vector3(0,0,1.3)):quit(1);return
	if not await interact_with(viewport,game,rest) or not await shot(viewport,game,"rest-options"):quit(1);return
	if not choose(viewport,game,"rest_morning") or game.payroll.minute!=1980 or game.social.outing.get("stage")!="paused":push_error("Morning transition failed");quit(1);return
	if not await shot(viewport,game,"next-morning"):quit(1);return
	game.person_index=game.social.roster().find(npc)
	key(viewport,KEY_P)
	if not await shot(viewport,game,"retained-agreement"):quit(1);return
	key(viewport,KEY_ESCAPE)
	var path := output.path_join("paused-route.json")
	if SaveGame.write(game,path)!=OK or not SaveGame.restore(game,SaveGame.read(path,game)):push_error("Actual route save failed");quit(1);return
	for point in [Vector3(0,0,23),Vector3(0,0,58),Vector3(-64,0,58),Vector3(-56,0,52),Vector3(-52,0,43),Vector3(-52,0,35),Vector3(-55.7,0,30.5)]:
		if not await walk_to(game,point):quit(1);return
	if not await interact_with(viewport,game,game.city_life.point_for("paper")) or not choose(viewport,game,"city_read"):quit(1);return
	if not await shot(viewport,game,"morning-bookshop"):quit(1);return
	if not choose(viewport,game,"city_leave"):quit(1);return
	if npc.position.distance_to(npc.home)>1.0 or game.social.outing.get("stage")!="paused":push_error("Paused agreement still occupies colleague's workday");quit(1);return
	for point in [Vector3(-52,0,35),Vector3(-52,0,43),Vector3(-56,0,52),Vector3(-64,0,58),Vector3(0,0,58),Vector3(0,0,23),rest.position+Vector3(0,0,1.3)]:
		if not await walk_to(game,point):quit(1);return
	if not await interact_with(viewport,game,rest) or not choose(viewport,game,"rest_evening"):quit(1);return
	if not await wait_at_foyer(game,npc):quit(1);return
	if not await walk_to(game,npc.position+Vector3(0,0,1.5)):quit(1);return
	if not await interact_with(viewport,game,npc) or not await shot(viewport,game,"resume-next-evening"):quit(1);return
	if not choose(viewport,game,"people_city_resume"):quit(1);return
	if not await Driver.follow(self,game,npc,CityOuting.place_position(npc,"garden"),9000):quit(1);return
	if not await interact_with(viewport,game,npc) or not choose(viewport,game,"people_share"):quit(1);return
	if not await shot(viewport,game,"garden-conversation"):quit(1);return
	if not choose(viewport,game,"people_boundary") or game.social.state(npc).get("city",{}).get("garden",{}).get("reply")!="boundary":push_error("Actual resumed outing did not record response");quit(1);return
	if not await shot(viewport,game,"next-day-memory"):quit(1);return
	if SaveGame.write(game,output.path_join("completed-route.json"))!=OK:quit(1);return
	physics_frame.disconnect(monitor)
	var data := {"images":captures,"visits":visits,"metres":metres,"friend_metres":friend_metres,"max_player_step":max_step,"max_friend_step":friend_max_step,"background_guard":desktop_safe and guard(),"persistence":game.persistence_enabled,"initial_time_player_fixture":true,"npc_teleports":false,"actual_inputs_and_clock":true,"normal_game_fps":false,"independent_player_acceptance":false}
	if not desktop_safe or not guard() or game.persistence_enabled or max_step>.2 or friend_max_step>.1 or metres<250:push_error("Day route incomplete or guard failed: "+JSON.stringify(data));quit(1);return
	FileAccess.open(output.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("CITY_DAY_ROUTE_OK ",JSON.stringify(data))
	viewport.queue_free();await process_frame;quit()

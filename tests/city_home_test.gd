extends "res://tests/city_bookshop_test.gd"

var metres := 0.0
var maximum_step := 0.0
var previous := Vector3.ZERO
func measure() -> void:
	var distance: float=game.player.position.distance_to(previous)
	metres+=distance;maximum_step=maxf(maximum_step,distance);previous=game.player.position

func home_use(id: String) -> bool:
	var point: CityHomePoint=game.home.point_for(id)
	var offset: Vector3=point.position-game.player.position
	game.player.yaw=atan2(-offset.x,-offset.z)
	await frames(5)
	check(game.nearest()==point,"正确选择家中设施 "+id+" actual="+str(game.nearest()))
	if game.nearest()!=point: return false
	key(KEY_E)
	return true

func choose_action(action: String) -> bool:
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]==action:
			key(KEY_1+i)
			if game.rest_transition.active: key(KEY_ESCAPE)
			return true
	check(false,"缺少真实选项 "+action+" "+str(game.conversation));return false

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3i")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(10)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	check(game.player.position.distance_to(Vector3(-14,0,5))<.3 and game.career.employer=="","保留自由求职出生入口")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"新世界完整快照合法")
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"住宅不挡既有公共路段 "+str(link))
	game.player.position=Vector3(56,0,43)
	await frames(4)
	previous=game.player.position;physics_frame.connect(measure)
	for point in [Vector3(56,0,37),Vector3(56,0,34.5),Vector3(59.6,0,34.3)]:
		if not await walk_to(point):finish();return
	check(game.home.visited and game.home.inside(game.player.position) and game.player.is_on_floor(),"原受阻入口连续实走进入并站稳")
	physics_frame.disconnect(measure)
	if not await home_use("home_sofa"): finish();return
	check(game.home.sitting(),"真实E坐到沙发")
	game.player.yaw=1.4
	await frames(45)
	check(absf(game.player.visual.rotation.y)<.03 and game.home.sitting(),"自由转镜头不旋转沙发坐姿")
	press("forward",true);await frames(1);press("forward",false);await frames(8)
	check(not game.player.seated and not game.home.seat_owned and game.player.is_on_floor(),"真实移动起身，释放座位后站稳")
	for point in [Vector3(56,0,34.5),Vector3(56,0,33.3),Vector3(53.6,0,33.3),Vector3(53.6,0,29.1),Vector3(51.95,0,29.1)]:
		if not await walk_to(point):finish();return
	game.payroll.minute=1140
	var old_position: Vector3=game.player.position
	if not await home_use("home_bed"):finish();return
	check(choose_action("home_leave") and game.payroll.minute==1140,"取消休息不跳时")
	var blocker := StaticBody3D.new()
	game.add_child(blocker)
	blocker.position=(game.player.position+game.home.point_for("home_bed").position)*.5+Vector3.UP*1.4
	Shapes.collider(blocker,Vector3(1.0,2.8,.16))
	await frames(3)
	game.home.open_point(game.home.point_for("home_bed"))
	game.home.answer(game.home.point_for("home_bed"),"home_morning")
	check(game.player.position.distance_to(game.home.point_for("home_bed").position)<3 and game.payroll.minute==1140 and game.conversation.is_empty(),"近距离也不能隔实体障碍打开或执行休息")
	blocker.queue_free();await frames(3)
	if not await home_use("home_bed"):finish();return
	check(choose_action("home_morning") and game.payroll.minute==1980,"床边休息到次日上午09点")
	check(game.home.last_rest==1980 and game.player.position==old_position and game.career.employer=="" and game.payroll.balance==0,"休息在原地，未就业不发工资也不收费")
	for point in [Vector3(53.6,0,29.1),Vector3(53.6,0,33.3),Vector3(56,0,33.3),Vector3(56,0,37),Vector3(57.9,0,37.1)]:
		if not await walk_to(point):finish();return
	if not await home_use("home_light"):finish();return
	check(not game.home.lights_on and game.home.room.lamps[0].light_energy==0,"实际E关灯改变场景照明")
	if not await home_use("home_light"):finish();return
	check(game.home.lights_on and game.home.room.lamps[0].light_energy>0,"实际E开灯")
	if not await walk_to(Vector3(60.5,0,37.8)):finish();return
	if not await home_use("home_curtain"):finish();return
	check(game.home.curtains_closed and game.home.room.curtains[0].scale.x==1,"实际E拉上窗帘")
	if not await home_use("home_curtain"):finish();return
	check(not game.home.curtains_closed and game.home.room.curtains[0].scale.x<.2,"实际E打开窗帘")
	for point in [Vector3(61.6,0,36.0),Vector3(61.6,0,33.0)]:
		if not await walk_to(point):finish();return
	if not await home_use("home_picture"):finish();return
	check(choose_action("home_picture_2") and game.home.picture==2 and game.home.room.postcard.texture==CityBookshop.IMAGES[2],"选择明信片实际改变画面")
	for point in [Vector3(61.6,0,31),Vector3(57,0,31),Vector3(57,0,28),Vector3(56.76,0,27)]:
		if not await walk_to(point):finish();return
	game.career.b_event="refused"
	await frames(65)
	if not await home_use("home_memory"):finish();return
	check(game.conversation.text.contains("自己的晚上") and game.home.room.memory.text.contains("自己的晚上"),"既有拒绝后果在实体生活记录中可见")
	check(choose_action("home_leave"),"生活记录可自由离开")
	game.city_life.walk.stage=4
	check(game.home.memory_text().contains("等回书屋亲手布置") and not game.home.memory_text().contains("已留在社区书屋"),"整理完笔记不等于已经布展")
	game.city_life.walk.stage=5
	check(game.home.memory_text().contains("已留在社区书屋"),"亲手布置后才陈列完成经历")
	game.city_life.walk.stage=0
	for point in [Vector3(56,0,30),Vector3(56,0,37),Vector3(56,0,43)]:
		if not await walk_to(point):finish();return
	check(not game.home.inside(game.player.position) and game.player.is_on_floor(),"次日实际出门无门槛阻挡")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(60.55,1.85,40),Vector3(60.55,1.85,38),1)
	check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"透明窗仍有身体碰撞")
	var bed: CityHomePoint=game.home.point_for("home_bed")
	var before: int=game.payroll.minute
	game.home.open_point(bed);game.home.answer(bed,"home_morning")
	check(game.payroll.minute==before and game.conversation.is_empty(),"离家后无法远程休息")
	check(game.soundscape.room_at(Vector3(56,0,35))=="home" and game.soundscape.surface_at(Vector3(56,0,35))=="wood","室内木地板和声音区域")
	check(game.soundscape.indoor_weight(Vector3(56,0,38.7))<.1 and game.soundscape.indoor_weight(Vector3(56,0,35))==1 and game.soundscape.room_at(Vector3(56,0,40))=="","声音在真实入口渐变，出门回户外")
	for destination in ["city-bookshop","city-clear","guide-car_office"]:
		game.panels.show_page("city");await frames(3)
		game.panels.view.buttons["city-home"].pressed.emit()
		check(game.home.guiding and game.navigation_target()==game.home.entrance,"城市页面回家导航")
		game.panels.show_page("city");await frames(3)
		game.panels.view.buttons[destination].pressed.emit()
		check(not game.home.guiding and game.navigation_target()!=game.home.entrance,"新目的地替换回家导航 "+destination)
	game.home.guiding=true;key(KEY_J);key(KEY_1)
	check(not game.home.guiding and game.career.facts.get("guide_company")=="a","求职页面真实按键切换公司目标")
	game.panels.show_page("")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.persistence_enabled,"不抓取鼠标或写玩家存档")
	check(maximum_step<.2 and metres>10,"入口路线物理移动无传送")
	FileAccess.open("res://build/c3i/home-test.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"entry_metres":metres,"entry_max_step":maximum_step,"bed_rest_minute":game.home.last_rest,"actual_interactions":true,"new_game_company_choice":true},"\t")+"\n")
	finish()

func finish() -> void:
	if physics_frame.is_connected(measure):physics_frame.disconnect(measure)
	press("forward",false);game.queue_free();await process_frame
	print("CITY_HOME_TEST failures=",failures);quit(failures)

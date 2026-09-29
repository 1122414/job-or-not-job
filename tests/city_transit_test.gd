extends SceneTree

var failures := 0
var game: Node3D
var transit: CityTransit

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1

func walk(point: Vector3) -> void:
	for i in range(1500):
		var diff: Vector3=point-game.player.position
		diff.y=0
		if diff.length()<0.5: break
		game.player.yaw=atan2(-diff.x,-diff.z)
		Input.action_press("forward")
		Input.action_press("run")
		await physics_frame
	Input.action_release("forward")
	Input.action_release("run")
	check(game.player.position.distance_to(point)<1.0,"实走公共路径抵达 "+str(point)+" actual="+str(game.player.position))

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(5): await physics_frame
	transit=game.transit
	game.set_process(false)
	transit.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var original := SaveGame.snapshot(game)
	check(SaveGame.valid(original,game),"新世界存档合法")
	# The player crosses the old x=-36 / z=23 walls with actual CharacterBody movement.
	for point in [Vector3(-28,0,18),Vector3(-69,0,18),Vector3(-71.5,0,58),Vector3(0,0,58),Vector3(0,0,98),Vector3(-6,0,99.5),Vector3(66,0,96),Vector3(66,0,58),Vector3(71.5,0,58)]:
		await walk(point)
		transit._physics_process(0)
	check(transit.visited.size()==4,"实走四区记录到访")
	check(game.location_name().begins_with("东里社区") and game.alert_level()==0,"远处住宅不被判断成公司")
	game.player.position=Vector3(-6,0,12.5)
	await physics_frame
	game.player.yaw=0
	game.player.pick(game.props[0])
	game.interact()
	check(game.panels.page=="transit" and game.panels.view.buttons.has("bus-board"),"E 打开真实站点上车页面")
	game.panels.view.buttons["bus-board"].pressed.emit()
	check(transit.riding and game.player.seated and game.player.inventory.has(game.props[0]),"站台上车并坐在实际车辆中，手持物只收纳一次")
	var held_count: int= game.player.inventory.size()
	game.player.pick(game.props[0])
	game.player.attack()
	check(game.player.held==null and game.player.inventory.size()==held_count and game.player.swing==0,"乘客不能穿车捡物或攻击")
	transit.dwell=0
	for i in range(120):
		transit.tick(0.1)
		await physics_frame
	check(transit.current_stop<0 and transit.distance>20,"车辆自然离站沿道路行驶")
	check(game.player.position.distance_to(transit.bus.to_global(Vector3(.65,.4,-.4)))<0.01,"乘客持续跟随移动载具")
	check(not transit.leave(),"行驶中拒绝下车")
	var saved := SaveGame.snapshot(game)
	var path := "user://city-transit-"+str(Time.get_ticks_usec())+".json"
	check(SaveGame.write(game,path)==OK,"行驶中的乘车档真实写入")
	transit.detach()
	transit.distance=0
	transit.sync_vehicle()
	check(SaveGame.restore(game,SaveGame.read(path,game)),"乘车档 JSON 恢复")
	for i in range(4): await physics_frame
	check(transit.riding and absf(transit.distance-saved.city_transit.distance)<0.001 and transit.visited.size()==4,"恢复车辆距离、乘客和四区到访")
	check(game.player.position.distance_to(transit.bus.to_global(Vector3(.65,.4,-.4)))<0.01,"旧位置修正不会把乘客移出车辆")
	game.panels.show_page("city")
	var paused_distance := transit.distance
	transit.set_physics_process(true)
	for i in range(5): await physics_frame
	check(transit.distance==paused_distance,"地图暂停时公交不移动")
	check(game.panels.view.buttons.has("city-waterfront"),"地图提供实际区域导航")
	game.panels.view.buttons["city-waterfront"].pressed.emit()
	check(transit.waypoint=="waterfront" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"地图选择生效且不捕获鼠标")
	transit.set_physics_process(false)
	transit.request_stop()
	for i in range(900):
		transit.tick(0.1)
		await physics_frame
		if transit.current_stop==1: break
	check(transit.current_stop==1,"公交自然驶达老城")
	var before := transit.distance
	transit.tick(30)
	check(transit.distance==before,"请求下车后停站等待乘客")
	var exit_block := Shapes.solid(game,Vector3(1.5,2,1.5),CityLayout.STOPS[1].platform+Vector3.UP,Color.RED)
	for i in range(3): await physics_frame
	check(not transit.leave() and transit.riding,"站台被挡时禁止穿进障碍下车")
	exit_block.queue_free()
	for i in range(3): await physics_frame
	check(transit.leave(),"可在老城站下车")
	check(game.player.position.distance_to(CityLayout.STOPS[1].platform)<0.01 and not game.player.seated,"落脚位在站台")
	# Swept obstacle collision, then resume and naturally complete all remaining stops.
	transit.dwell=0
	var obstacle_position := transit.curve.sample_baked(transit.distance+9)
	var obstacle := Shapes.solid(game,Vector3(3,3,1),obstacle_position+Vector3.UP*1.5,Color.RED)
	for i in range(5): await physics_frame
	for i in range(100):
		transit.tick(0.1)
		await physics_frame
		if transit.blocked: break
	check(transit.blocked,"道路实体障碍让公交停车")
	check(transit.bus.position.distance_to(obstacle_position)>3,"公交没有穿过路障")
	obstacle.queue_free()
	for i in range(3): await physics_frame
	var reached: Array[int]=[]
	for i in range(1600):
		transit.tick(0.1)
		await physics_frame
		if transit.current_stop>=0 and not transit.current_stop in reached: reached.append(transit.current_stop)
		if reached.has(2) and reached.has(3) and reached.has(0): break
	check(reached==[2,3,0],"按滨水/住宅/双公司顺序完成环线 actual="+str(reached))
	var time_before: int=game.payroll.minute
	game.player.position=CityLayout.STOPS[2].platform
	for i in range(3): await physics_frame
	check(transit.wait_for_bus(2),"允许主动跳过等车")
	check(game.payroll.minute>time_before and transit.current_stop==2 and not transit.riding,"等待推进共享时间但不强制上车")
	check(not transit.board(0),"不能远程上车")
	for entry in [["distance",NAN],["distance",-1],["route","unknown"],["current_stop",4],["next_stop",1.5],["visited",["unknown"]],["waypoint","missing"],["riding","true"]]:
		var invalid := saved.duplicate(true)
		invalid.city_transit[entry[0]]=entry[1]
		var before_state := transit.snapshot()
		check(not SaveGame.restore(game,invalid) and transit.snapshot()==before_state,"非法交通档拒绝且世界不变 "+entry[0])
	for version in range(1,12):
		var legacy := original.duplicate(true)
		legacy.version=version
		legacy.erase("city_transit")
		var json_legacy: Variant=JSON.parse_string(JSON.stringify(legacy))
		check(SaveGame.restore(game,json_legacy) and not transit.riding and transit.current_stop==0,"v%d 兼容夹具 JSON 恢复为初始公交" % version)
		check(game.payroll.balance==original.payroll.balance and game.career.employer==original.career.employer,"旧版职业/工资保留 v%d" % version)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("CITY_TRANSIT_TEST failures=",failures," route_m=",transit.curve.get_baked_length()," stops=",reached)
	game.queue_free()
	await process_frame
	quit(failures)

extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	for outfit in ["casual","office","office_female","protagonist","lin_lan","a_cheng"]:
		var v := HumanVisual.new()
		if outfit in ["protagonist","lin_lan","a_cheng"]: v.cast_id=outfit
		else: v.outfit=outfit
		game.add_child(v)
		v.animation.play("work")
		v.animation.advance(0.4)
		var s := v.skeleton
		var hip: Vector3=s.get_bone_global_pose(s.find_bone("upperleg01.L")).origin+v.seated_offset
		var foot: Vector3=s.get_bone_global_pose(s.find_bone("foot.L")).origin+v.seated_offset
		var head: Vector3=s.get_bone_global_pose(s.find_bone("head")).origin+v.seated_offset
		check(absf(hip.y-0.53)<0.03,"臀部对齐座面 "+outfit)
		check(foot.y>0.02 and foot.y<0.14,"脚踝接近地面 "+outfit)
		check(head.y>1.1,"头部高于桌面 "+outfit)
		if not v.cast_id.is_empty():
			var rest_y := s.get_bone_global_rest(s.find_bone("foot.L")).origin.y
			check(absf(foot.y-rest_y)<0.012,"新体型坐姿脚底保持原站立高度 "+outfit)
			print("CAST_SEAT ",outfit," ankle_error_m=",absf(foot.y-rest_y))
		v.queue_free()
	var desk: WorkStation
	for station in game.stations:
		if station.stable_id=="desk_a": desk=station
	game.player.position=desk.position+Vector3(0,0,1.2)
	game.player.yaw=0
	await physics_frame
	check(game.nearest()==desk,"从椅后可使用工位，座椅不抢占工作目标")
	game.player.sit_at(desk.position)
	for i in range(40): await physics_frame
	check(game.player.seated,"坐姿稳定")
	check(game.player.spring.spring_length<2.25 and game.player.pivot.position.y<1.36,"坐姿镜头平滑接近工位")
	check(game.player.stand_up(),"有空间可以起身")
	check(game.player.position.distance_to(desk.position)>0.7,"起身落在椅子外")
	check(game.player.seat_body==null,"起身清除本人座椅碰撞例外")
	var legacy: Dictionary=SaveGame.snapshot(game)
	legacy.version=2
	legacy.props["a_desk_6_-2"].position[1]=0.85
	check(SaveGame.restore(game,legacy),"v2布局存档可迁移")
	for prop in game.props:
		if prop.stable_id=="a_desk_6_-2": check(absf(prop.position.y-0.72)<0.01,"旧桌子迁移到新高度")
	game.queue_free()
	await process_frame
	print("SEATING_TEST failures=",failures)
	quit(failures)

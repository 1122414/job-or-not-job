extends SceneTree
var failures := 0
var capture_view: Viewport
var captured := {}
func _initialize() -> void:
	if DisplayServer.get_name()!="headless": root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	capture_view=root
	if DisplayServer.get_name()!="headless":
		var view:=SubViewport.new();view.size=Vector2i(1280,800);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.set_disable_input(true);root.add_child(view);capture_view=view
	capture_view.add_child(game);root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(10)
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false);game.response.set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var base: Dictionary=SaveGame.snapshot(game)
	var car: CityCar=game.driving.cars[0]
	var person: CityResident=game.population.residents[0]
	game.player.position=Vector3(10,0,64)
	car.position=Vector3(0,0,64);car.rotation.y=0;car.speed=0
	person.position=Vector3(0,0,63.8);person.hp=0;person.state="dead";person.update_body()
	await frames(3)
	for i in range(60): car.drive(1.0/60,1,0,false)
	check(car.position.z<63 and car.speed>2,"F01 倒地身体不再把车辆永久锁住")
	var heights := []
	for speed in [3.0,12.0]:
		check(SaveGame.restore(game,base),"恢复碰撞夹具")
		game.player.position=Vector3(10,0,64)
		car.position=Vector3(0,0,70);car.rotation.y=0;car.speed=0;car.steering=0
		person.position=Vector3(0,0,66.5);person.hp=100;person.down=0;person.state="activity";person.update_body()
		await frames(3)
		game.player.position=car.to_global(Vector3(-1.65,0,0))
		check(game.driving.enter(car),"实际驾驶关联建立")
		car.speed=speed
		var highest := 0.0
		var impacted := false
		for i in range(90):
			car.drive(1.0/60,1,0,false)
			if person.vehicle_velocity.length_squared()>.001: person.move_vehicle_impact(1.0/60)
			highest=maxf(highest,person.position.y)
			if speed>6 and person.position.y>.4: await shot(game,"high-speed-impact",person.position+Vector3(6,3,6),person.position)
			impacted=impacted or not person.available()
			if person.vehicle_velocity.length_squared()>.001:
				check(SaveGame.valid(SaveGame.snapshot(game),game),"F01 抛离途中全档有效："+SaveGame.invalid_section(game))
			await physics_frame
		check(impacted,"F01 真实车体扫掠撞到居民")
		heights.append(highest)
	check(heights[0]<.1 and heights[1]>.2,"F01 低速留在地面，高速产生抛物线："+str(heights))
	check(SaveGame.restore(game,base),"恢复存档夹具")
	var folder := "/private/tmp/feedback-save-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	game.save_path=folder+"/world.json";game.archive_directory=folder+"/restarts";game.persistence_enabled=true
	check(game.save_game(false),"F02 先保存有效旧档")
	var old := FileAccess.get_file_as_string(game.save_path)
	game.response.elapsed=99
	game.hud.toast="正在播放的剧情字幕"
	check(not game.save_game(false) and game.hud.toast=="正在播放的剧情字幕","F02 自动失败不覆盖字幕")
	check(game.save_problem.contains("现场救助"),"F02 数据校验显示实际模块，不误报空间不足")
	for i in range(5):game.save_game(false)
	check(game.hud.toast=="正在播放的剧情字幕" and FileAccess.get_file_as_string(game.save_path)==old,"F02 连续失败保持旧档与字幕")
	await shot(game,"save-status",Vector3(8,3,67),Vector3(0,1,64))
	game.new_game()
	check(game.save_problem=="" and not SaveGame.read(game.save_path,game).is_empty(),"F02 当前状态异常仍可保全后新游戏")
	var backups:=SaveGame.archives(game.archive_directory)
	check(backups.size()==1 and FileAccess.get_file_as_string(backups[0])==old,"F02 最近有效旧档可恢复且逐字节保留")
	var recovery_count:=0
	for filename in DirAccess.get_files_at(game.archive_directory):
		if filename.ends_with(".recovery"):
			var raw=JSON.parse_string(FileAccess.get_file_as_string(game.archive_directory.path_join(filename)))
			check(raw.payload.sha256_text()==raw.checksum and JSON.parse_string(raw.payload).city_response.elapsed==99,"F02 异常原始现场另存并校验，不伪装有效档")
			recovery_count+=1
	check(recovery_count==1,"F02 只生成一份原始现场备份")
	var blocker := folder+"/not-a-directory"
	var file := FileAccess.open(blocker,FileAccess.WRITE);file.store_string("keep");file.close()
	game.archive_directory=blocker+"/restarts"
	var before: Dictionary=SaveGame.snapshot(game)
	game.new_game()
	check(SaveGame.snapshot(game)==before,"F02 真实备份写入失败不清世界")
	game.persistence_enabled=false
	game.queue_free();await process_frame
	print("FEEDBACK_BLOCKERS_TEST failures=",failures," impact_peak_y=",heights);quit(failures)

func shot(game: Node3D,name: String,at: Vector3,focus: Vector3) -> void:
	if DisplayServer.get_name()=="headless" or captured.has(name):return
	captured[name]=true
	var camera:=Camera3D.new();game.add_child(camera);camera.position=at;camera.look_at(focus);camera.current=true
	for i in range(3):await process_frame
	RenderingServer.force_draw()
	var folder:="res://docs/evidence/2026-10-09-playtest-feedback/runtime"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_view.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"图形保存")
	camera.queue_free()

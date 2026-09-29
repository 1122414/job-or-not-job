extends "res://tests/city_bookshop_test.gd"

func total_steps() -> int:
	var total := 0
	for count in game.soundscape.step_counts.values(): total+=count
	return total

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	game.transit.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var sound: CitySoundscape=game.soundscape
	check(not sound.enabled and not sound.persistence,"测试隔离且不向音频设备输出")
	check(sound.step_players.size()==12 and sound.engines.size()==6,"固定12脚步声道及6真实载具声源")
	for key in sound.clips:
		check(sound.clips[key].get_length()>.1,"实际导入音频有效 "+key)
	for bus in CitySoundscape.DEFAULTS:
		check(AudioServer.get_bus_index(bus)>=0,"分类总线存在 "+bus)
	for item in [[Vector3(-14,0,-7),"a","carpet"],[Vector3(14,0,-7),"b","wood"],[game.city_life.room.global_position,"bookshop","wood"],[Vector3(0,0,58),"","stone"],[Vector3(6.5,0,35),"","grass"]]:
		check(sound.room_at(item[0])==item[1] and sound.surface_at(item[0])==item[2],"真实场所/地表 "+str(item))
	var previous := -1.0
	for i in range(61):
		var weight := sound.indoor_weight(Vector3(-14,0,2-float(i)*.05))
		check(weight>=previous and weight-previous<.05 if previous>=0 else true,"办公室门口连续渐变")
		previous=weight
	check(sound.indoor_weight(Vector3(-14,5,-7))==0,"屋顶不当作室内")
	var measured := {}
	for item in [["stone",Vector3(0,0,18),Vector3(0,0,23)],["carpet",Vector3(-14,0,1),Vector3(-14,0,-3)],["wood",Vector3(14,0,1),Vector3(14,0,-3)],["grass",Vector3(6.5,0,33),Vector3(6.5,0,38)]]:
		game.player.position=item[1]; game.player.velocity=Vector3.ZERO
		await frames(5)
		var before: int=sound.step_counts.get(item[0],0)
		check(await walk_to(item[2]),"实际键盘走过 "+item[0])
		measured[item[0]]=sound.step_counts.get(item[0],0)-before
		check(measured[item[0]]>=2,"实际动作周期触发脚步 "+item[0]+str(measured))
	var before := total_steps()
	await frames(120)
	check(total_steps()==before,"静止不响")
	game.player.position=Vector3(0,0,52); game.player.velocity=Vector3.ZERO
	await frames(10)
	before=total_steps()
	game.player.position=Vector3(0,0,58)
	await frames(4)
	check(total_steps()==before,"位置跳变不补播脚步")
	# A resident follows its actual route while the player remains still nearby.
	var resident: CityResident=game.population.residents[0]
	resident.position=Vector3(0,0,58); resident.velocity=Vector3.ZERO
	resident.plan("commons_south"); resident.set_physics_process(true)
	game.player.position=Vector3(3,0,56)
	await frames(150)
	check(total_steps()>before,"附近居民实际步行参与声景")
	before=total_steps()
	resident.position=Vector3(0,0,58); resident.velocity=Vector3.ZERO
	resident.plan("commons_south")
	game.player.position=Vector3(-94,0,18); game.player.velocity=Vector3.ZERO
	await frames(150)
	check(resident.position.z<57 and total_steps()==before,"远处实际步行不占用脚步声道")
	resident.set_physics_process(false)
	game.player.position=Vector3(0,0,58); game.player.velocity=Vector3.ZERO
	await frames(6); before=total_steps()
	press("jump",true); await frames(1); press("jump",false)
	press("forward",true)
	await frames(14)
	check(game.player.position.y>.2 and total_steps()==before,"真实腾空移动不响脚步")
	press("forward",false); await frames(70)
	before=total_steps()
	game.player.seated=true
	await frames(30)
	check(total_steps()==before,"坐下不响脚步")
	game.player.seated=false
	game.player.position=CityLayout.STOPS[0].platform
	game.transit.board(0); game.transit.dwell=0
	game.transit.set_physics_process(true)
	before=total_steps(); await frames(180)
	check(game.transit.riding and total_steps()==before,"实际乘车移动不被当成步行")
	var snapshot := SaveGame.snapshot(game)
	check(SaveGame.restore(game,snapshot),"乘车音频不改变存档恢复")
	await frames(6)
	check(total_steps()==before,"恢复乘车没有脚步爆发")
	var path := "res://build/c4e-audio-settings.json"
	var defaults := sound.levels.duplicate()
	sound.set_level("Ambience",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")),"0音量明确静音")
	check(sound.write_settings(path)==OK,"独立设置实际写盘")
	sound.set_level("Ambience",.5)
	check(sound.write_settings(path)==OK,"原子替换已存在的设置文件")
	sound.set_level("Ambience",0)
	check(sound.write_settings(path)==OK,"已有设置再次保存静音")
	sound.set_level("Ambience",.5)
	check(sound.read_settings(path) and sound.levels.Ambience==0,"实际磁盘恢复静音设置")
	for bad in [{"Master":true,"Ambience":.5,"Actions":.5,"Interaction":.5},{"Master":.5,"Ambience":2,"Actions":.5,"Interaction":.5},{"Master":.5},[]]:
		var baseline := sound.levels.duplicate()
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(bad))
		check(not sound.read_settings(path) and sound.levels==baseline,"坏设置原子拒绝 "+str(bad))
	sound.levels=defaults; sound.apply_levels()
	AudioServer.set_bus_mute(0,true); sound.capture_only=true
	sound._process(1)
	check(sound.enabled and sound.engines.bus.playing,"静音捕获模式可混音，公交实际发声")
	check(not sound.engines.car_office.playing and not sound.engines.car_homes.playing,"空置共享车不发声")
	game.panels.show_page("pause"); sound._process(.1)
	check(not sound.enabled and sound.beds.values().all(func(p): return not p.playing),"暂停立即停止环境和车辆")
	game.panels.show_page("")
	sound.capture_only=false; sound._process(.1)
	check(not sound.enabled and sound.engines.values().all(func(p): return not p.playing),"后台非捕获模式静音")
	sound.apply_levels()
	DirAccess.remove_absolute(path)
	print("CITY_SOUND_SCENE steps=",measured," failures=",failures)
	game.queue_free(); await frames(2)
	# Fixed-fps headless frames can finish before the audio thread consumes stop.
	var stopped_at := Time.get_ticks_msec()
	while Time.get_ticks_msec()-stopped_at<120: await process_frame
	quit(1 if failures else 0)

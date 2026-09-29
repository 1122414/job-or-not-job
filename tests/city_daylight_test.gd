extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func light_state(game: Node3D) -> Array:
	var sky: ProceduralSkyMaterial=game.environment.sky.sky_material
	return [game.sun.light_energy,game.sun.rotation_degrees,game.sun.shadow_enabled,
		game.environment.ambient_light_energy,game.environment.ambient_light_color,
		sky.sky_top_color,sky.sky_horizon_color,
		game.get_node("ConnectedDistrict/Streetscape").lamps[0].light_energy]

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6): await physics_frame
	game.set_process(false)
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	game.payroll.minute=0; game.update_daylight()
	var previous := light_state(game)
	var midnight := previous.duplicate()
	var maximum_energy_step := 0.0
	var maximum_sky_step := 0.0
	for minute in range(1,1441):
		game.payroll.minute=minute; game.update_daylight()
		var current := light_state(game)
		maximum_energy_step=maxf(maximum_energy_step,absf(current[0]-previous[0]))
		var sky_step := Vector3(current[6].r-previous[6].r,current[6].g-previous[6].g,current[6].b-previous[6].b).length()
		maximum_sky_step=maxf(maximum_sky_step,sky_step)
		check(is_finite(current[0]) and current[0]>=0,"太阳能量有限且非负")
		if minute<360 or minute>=1080:
			check(is_zero_approx(current[0]) and not current[2],"太阳落到地平线后不再从地下照明或绘制阴影")
		previous=current
	check(maximum_energy_step<.025 and maximum_sky_step<.025,"全天逐分钟光照连续，无晨昏跳变")
	check(previous==midnight,"跨午夜与前一日同一时刻一致")
	game.payroll.minute=1080; game.update_daylight()
	var dusk := light_state(game)
	game.payroll.minute=1230; game.update_daylight()
	var night := light_state(game)
	check(dusk[6]!=night[6] and dusk[3]>night[3],"18点余晖和深夜分别表达，不再完全相同")
	for place in [Vector3(40.8,1.6,54),Vector3(42,1.6,54),Vector3(-50.5,1.6,42),Vector3(28,1.6,116),Vector3(0,1.6,22),Vector3(0,1.6,35),Vector3(0,1.6,58),Vector3(0,1.6,82)]:
		var covered := false
		for lamp in streets.lamps:
			if lamp.light_energy>.5 and lamp.global_position.distance_to(place)<lamp.omni_range*.85: covered=true
		check(covered,"公共活动和主步道处于实际灯光范围内："+str(place))
	game.payroll.minute=720; game.update_daylight()
	for lamp in streets.lamps: check(is_zero_approx(lamp.light_energy),"正午公共灯具关闭")
	paused=true
	for minute in [0,330,360,540,720,1080,1110,1170,2880]:
		game.payroll.minute=minute; game.update_daylight()
		var expected := light_state(game)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
		game.payroll.minute=840; game.update_daylight()
		check(SaveGame.restore(game,saved),"暂停中真实JSON恢复")
		check(light_state(game)==expected,"无需解除暂停或等下一帧，读档立即恢复光照")
		for i in range(3): await process_frame
		check(game.payroll.minute==minute and light_state(game)==expected,"暂停期间时刻与光照保持")
	paused=false
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"昼夜检查不接管鼠标")
	game.queue_free(); await process_frame
	print("CITY_DAYLIGHT_TEST failures=",failures," minute_samples=1440 pause_restore_cases=9 max_sun_step=",maximum_energy_step," max_sky_step=",maximum_sky_step," visual_acceptance=separate")
	quit(failures)

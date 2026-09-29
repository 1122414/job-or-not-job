extends "res://tests/city_home_test.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/c3i")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(10);game.set_process(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from-route="):
			var file := argument.trim_prefix("--from-route=")
			var actual := SaveGame.read(file,game)
			check(not actual.is_empty() and SaveGame.restore(game,actual),"独立进程读取真实路线档")
			await frames(30)
			var restored_home: Dictionary=JSON.parse_string(JSON.stringify(game.home.snapshot()))
			check(restored_home==actual.city_home,"实际路线全部住处字段恢复 expected="+JSON.stringify(actual.city_home)+" actual="+JSON.stringify(restored_home))
			check(game.player.position.distance_to(SaveGame.unvector(actual.player.position))<.1,"实际路线人物位置保留")
			check(SaveGame.valid(SaveGame.snapshot(game),game),"实际路线恢复后完整快照合法")
			finish();return
	var original := JSON.parse_string(JSON.stringify(SaveGame.snapshot(game))) as Dictionary
	game.player.position=CityHome.SEAT+Vector3(0,0,-1.45)
	await frames(5)
	check(await home_use("home_sofa") and game.home.sitting(),"沙发真实交互作为存档前置")
	game.home.lights_on=false;game.home.curtains_closed=true;game.home.picture=2;game.home.sync_scene()
	game.player.yaw=1.3;game.player.pitch=.18
	game.player.pick(game.props[0])
	var held: OfficeProp=game.player.held
	var path := "res://build/c3i/seated.json"
	check(SaveGame.write(game,path)==OK,"布置与坐姿实际磁盘JSON")
	var saved := SaveGame.read(path,game)
	check(not saved.is_empty(),"读取校验封装")
	if saved.is_empty():finish();return
	check(SaveGame.restore(game,saved),"恢复真实磁盘档")
	await frames(40)
	check(game.home.sitting() and game.player.is_on_floor() and game.player.position.distance_to(CityHome.SEAT)<.03,"迁移检查后仍坐稳沙发")
	check(game.player.held==held and is_equal_approx(game.player.yaw,1.3) and is_equal_approx(game.player.pitch,.18),"恢复不收包、不重置自由镜头")
	check(not game.home.lights_on and game.home.room.lamps[0].light_energy==0 and game.home.curtains_closed and game.home.room.curtains[0].scale.x==1 and game.home.room.postcard.texture==CityBookshop.IMAGES[2],"布置实际恢复到场景")
	var corruptions := ["missing","schema","lamp_type","curtain_type","picture_range","picture_fraction","rest_future","rest_fraction","unvisited_rest","unvisited_seat","position","hp","vehicle","public_seat"]
	for corrupt in corruptions:
		var bad: Dictionary=saved.duplicate(true)
		match corrupt:
			"missing": bad.erase("city_home")
			"schema": bad.city_home.schema=2
			"lamp_type": bad.city_home.lights_on=1
			"curtain_type": bad.city_home.curtains_closed="yes"
			"picture_range": bad.city_home.picture=3
			"picture_fraction": bad.city_home.picture=.5
			"rest_future": bad.city_home.last_rest=bad.payroll.minute+1
			"rest_fraction": bad.city_home.last_rest=1.5
			"unvisited_rest": bad.city_home.last_rest=10;bad.city_home.visited=false
			"unvisited_seat": bad.city_home.visited=false
			"position": bad.player.position=[0,0,18]
			"hp": bad.player.hp=0
			"vehicle": bad.city_driving.active="shared_0"
			"public_seat": bad.city_commons.player_slot="commons_west_0/0"
		var before := SaveGame.snapshot(game)
		check(not SaveGame.restore(game,bad) and SaveGame.snapshot(game)==before,"坏档原子拒绝 "+corrupt)
	game.player.position+=Vector3(.5,0,0)
	await frames(4)
	check(not game.player.seated and not game.home.seat_owned and game.player.seat_body==null,"外力位移释放居家坐姿")
	check(SaveGame.restore(game,saved),"恢复危险前置")
	game.player.protection=0;game.player.hurt(100)
	await frames(1)
	check(not game.home.sitting() and not game.home.snapshot().seated and game.player.hp==0,"死亡不残留居家坐姿")
	for version in range(1,22):
		var old := original.duplicate(true);old.version=version;old.erase("city_home")
		if version<20:old.city_population.crossings.erase("office")
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(old))),"旧v%d实际JSON夹具合法"%version)
		check(game.home.lights_on and not game.home.curtains_closed and game.home.picture==0 and not game.home.visited and game.home.last_rest==-1 and not game.home.sitting(),"旧v%d仅初始化新的住处字段"%version)
	# The player can carry existing objects home; identity and damage remain in
	# the existing world-object store, without adding a second storage inventory.
	check(SaveGame.restore(game,original),"恢复物品测试初态")
	await frames(8)
	game.player.position=CityHome.CENTER+Vector3(0,0,3)
	game.player.pick(game.props[0]);game.player.release(false)
	await frames(120)
	var object_position: Vector3=game.props[0].position
	var object_world := SaveGame.snapshot(game)
	check(game.home.inside(object_position) and SaveGame.restore(game,JSON.parse_string(JSON.stringify(object_world))),"携入并放下的原物件完整JSON恢复")
	await frames(30)
	check(game.props.size()==114 and game.props[0].position.distance_to(object_position)<.2,"回家存物不复制或重置已有物品")
	for at in [CityHome.CENTER+Vector3(-4.05,0,-4.8),CityHome.CENTER+Vector3(3.6,0,3.9),CityHome.CENTER+Vector3(4.5,0,-6.45)]:
		var old := original.duplicate(true);old.player.position=SaveGame.vector(at);old.version=21;old.erase("city_home")
		check(SaveGame.restore(game,old),"原家具占地中的旧有效玩家位置可读")
		await frames(70)
		check(game.player.is_on_floor() and game.position_clear(game.player,game.player.position) and game.player.position.distance_to(at)<3.5,"旧家具落点局部恢复并实际站稳")
	check(SaveGame.restore(game,original),"恢复跨日前置")
	await frames(8)
	game.player.position=CityHome.CENTER+Vector3(-4.05,0,-2.8)
	game.payroll.minute=1140;game.career.employer="a"
	game.social.outing={"person":"a_friend","kind":"walk","stage":"walking","elapsed":0.0,"venue":"garden"}
	if not await home_use("home_bed"):finish();return
	check(choose_action("home_morning") and game.payroll.minute==1980 and game.social.outing.stage=="paused","居家休息沿用跨日约定暂缓")
	var day := SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(day))) and game.home.last_rest==1980 and game.social.outing.stage=="paused","居家跨日与原约定一起恢复")
	var money: Dictionary=SaveGame.fields(game.payroll,SaveGame.PAYROLL_FIELDS)
	check(SaveGame.restore(game,day),"再次恢复同一跨日档")
	var reloaded := SaveGame.fields(game.payroll,SaveGame.PAYROLL_FIELDS)
	check(JSON.stringify(reloaded)==JSON.stringify(money),"重复读档不重复结算工资 before="+JSON.stringify(money)+" after="+JSON.stringify(reloaded))
	check(not game.persistence_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"隔离存档与鼠标保护")
	print("CITY_HOME_SAVE_CASES corruptions=",corruptions.size()," legacy=21 furniture_positions=3")
	finish()

func finish() -> void:
	press("forward",false);game.queue_free();await process_frame
	print("CITY_HOME_SAVE_TEST failures=",failures);quit(failures)

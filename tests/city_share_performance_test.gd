extends "res://tests/city_bookshop_test.gd"

var metrics := {}

func penetration(human: HumanVisual,book: CityStoryAlbum) -> float:
	var body: MeshInstance3D=human.find_children("body","MeshInstance3D",true,false)[0]
	var arrays := body.mesh.surface_get_arrays(0)
	var transforms := []
	for bind in body.skin.get_bind_count():
		var bone := human.skeleton.find_bone(body.skin.get_bind_name(bind))
		transforms.append(book.global_transform.affine_inverse()*human.skeleton.global_transform*human.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
	var worst := 0.0
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var point := Vector3.ZERO
		for slot in range(4): point+=(transforms[arrays[Mesh.ARRAY_BONES][i*4+slot]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
		# Both rigid covers and stationary page blocks, in unscaled book space.
		for x in [-.25,.25]:
			for box in [[Vector3(.5,.018,.57),Vector3(x,-.012,0)],[Vector3(.48,.018,.55),Vector3(x,0,0)]]:
				var depths: Vector3=box[0]*.5-(point-box[1]).abs()
				var depth: float=minf(depths.x,minf(depths.y,depths.z))*.36
				if depth>worst:
					worst=depth
					book.set_meta("skin_worst",{"point":str(point),"bone":body.skin.get_bind_name(arrays[Mesh.ARRAY_BONES][i*4]),"depth":depth})
	return worst

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var original := SaveGame.snapshot(game)
	var life: CityLife=game.city_life
	var performance: CitySharePerformance=life.performance
	for method in CityLife.METHODS:
		check(SaveGame.restore(game,original.duplicate(true)),"独立方案恢复原世界 "+method)
		life.set_physics_process(true)
		# Input fixture begins by the notice. Residents always use physical routes.
		game.player.position=Vector3(-50,0,42)
		await frames(4)
		await use_point("notice",CityLife.METHODS.keys().find(method))
		game.player.position={"screen":Vector3(-49.2,0,29.7),"paper":Vector3(-55.7,0,30.5),"garden":Vector3(38,0,55.2)}[method]
		await frames(4)
		await use_point(method,0)
		if method=="screen": key(KEY_1)
		check(life.prepared,"真实输入准备完成 "+method)
		game.player.position=Vector3(0,0,18)
		for frame in range(20000):
			await physics_frame
			if performance.attending().size()==3: break
		check(performance.attending().size()==3,"三人自然走到各自方案现场 "+method)
		check(life.elapsed==0 and not performance.running(),"玩家未参与时不空演 "+method)
		game.player.position=life.center()+Vector3(0,0,3)
		await frames(60)
		check(performance.running() and life.elapsed>0,"真实在场开始表演 "+method)
		life.set_physics_process(false)
		var palm_error := 0.0
		var skin_depth := 0.0
		var turns := []
		for moment in [1.4,5.6,7.4,11.6,13.4]:
			life._physics_process(moment-life.elapsed)
			await frames(80)
			await process_frame
			var narrator := performance.narrator()
			check(narrator.index==CityLife.AUDIENCE[mini(2,int(moment/6))],"实际讲述者随段落切换 "+method)
			check(life.caption().begins_with(narrator.title.split(" · ")[0]),"字幕指出实际讲述者 "+method)
			for person in performance.attending():
				var expected := "story_read" if method=="paper" else "story_present" if person==narrator else "story_listen"
				check(person.visual.current==expected,"站立表演选择 "+method+"/"+person.stable_id)
				var book: CityStoryAlbum=performance.books[person.stable_id]
				check(book.visible==(method=="paper"),"只在纸本共读持有副本")
				if method=="paper":
					check(book.page==mini(2,int(moment/6)),"持本内容跟随当前记录")
					for side in ["L","R"]:
						var target := book.to_global(Vector3(-.13/.36 if side=="L" else .13/.36,-.032,.23))
						if side=="R" and book.turn>0: target=book.turning_page.to_global(Vector3(.36,-.009,.23))
						palm_error=maxf(palm_error,person.visual.contacts.palm(side).origin.distance_to(target))
					skin_depth=maxf(skin_depth,penetration(person.visual,book))
				check(not game.commons.sitting(person) and person.visual.position.y==0,"阅读保持站姿与原物理位置")
				if person==narrator and method!="paper" and performance.pointing_weight()>.9:
					var direction: Vector3=(life.focus_position()+Vector3((mini(2,int(moment/6))-1)*.95,1.45,.09) if method=="garden" else life.focus_position())-person.visual.contacts.palm("R").origin
					check(person.visual.contacts.palm("R").basis.y.dot(direction.normalized())>.95,"伸指方向实际指向当前展示物")
			turns.append({"time":moment,"narrator":narrator.stable_id,"page":life.room.album.page,"turn":life.room.album.turn})
		var max_hand_step := 0.0
		if method=="paper":
			life.elapsed=4.6 # A labelled animation boundary fixture, not a played completion.
			await frames(50)
			var previous := {}
			for frame in range(190):
				life._physics_process(1.0/60)
				await physics_frame
				await process_frame
				for person in performance.attending():
					var palm: Vector3=person.visual.contacts.palm("R").origin
					if previous.has(person.stable_id): max_hand_step=maxf(max_hand_step,palm.distance_to(previous[person.stable_id]))
					previous[person.stable_id]=palm
					if frame%13==0: skin_depth=maxf(skin_depth,penetration(person.visual,performance.books[person.stable_id]))
					for name in ["upperarm01.L","lowerarm01.L","wrist.L","upperarm01.R","lowerarm01.R","wrist.R"]:
						var bone: int=person.visual.skeleton.find_bone(name)
						check(person.visual.skeleton.get_bone_pose_position(bone).is_equal_approx(person.visual.skeleton.get_bone_rest(bone).origin),"翻页未拉长手臂骨骼")
			check(max_hand_step<.035,"连续翻页/交接无手腕瞬移 step="+str(max_hand_step))
			life.elapsed=13.4
			await frames(70)
		check(palm_error<.01,"全部阅读相位双掌实际接触 error="+str(palm_error))
		check(skin_depth<.002,"导入皮肤不穿过书本基体超过2mm depth="+str(skin_depth))
		var before := SaveGame.snapshot(game)
		check(SaveGame.valid(before,game),"表演中完整v19快照有效")
		var path := "user://c3f-share-%d-%s.json"%[OS.get_process_id(),method]
		check(SaveGame.write(game,path)==OK,"表演中实际JSON写盘")
		check(SaveGame.restore(game,SaveGame.read(path,game)),"表演中磁盘JSON恢复")
		DirAccess.remove_absolute(path)
		await frames(70)
		check(life.elapsed==before.city_life.elapsed and performance.running(),"表演由保存的实际进度重建")
		game.panels.show_page("city")
		var frozen: float=performance.books[game.population.residents[0].stable_id].turn
		await frames(30)
		check(performance.books[game.population.residents[0].stable_id].turn==frozen,"菜单暂停冻结翻页")
		game.panels.show_page("")
		var speaker := performance.narrator()
		game.population.talk(speaker)
		await frames(50)
		check(not life.present(speaker) and performance.narrator()!=speaker,"玩家交谈优先，其他在场者转述")
		check(speaker.visual.current=="talk" and not performance.books[speaker.stable_id].visible,"交谈退出现场姿势和持本")
		check(life.caption().contains(CityLife.STORIES[2]),"换人不篡改原作者的记录")
		game.close_interaction()
		await frames(60)
		var participant: CityResident=game.population.residents[0]
		participant.hit(Vector3.FORWARD,200,991,true)
		await frames(10)
		check(not performance.books[participant.stable_id].visible and participant.visual.current=="fallen","重伤受击释放表演，保留倒地")
		check(not performance.running(),"目击避险让分享中断")
		check(SaveGame.restore(game,before.duplicate(true)),"中断后恢复合法存档")
		await frames(50)
		game.player.position=Vector3(0,0,18)
		await frames(30)
		check(not performance.running() and performance.books.values().all(func(book): return not book.visible),"离场后书本和表演无残留")
		game.payroll.minute=1200
		await frames(30)
		check(not life.active() and performance.books.values().all(func(book): return not book.visible),"闭馆停止场景表演")
		metrics[method]={"turns":turns,"palm_error_m":palm_error,"skin_depth_m":skin_depth,"max_hand_step_m":max_hand_step}
	check(SaveGame.restore(game,original.duplicate(true)),"玩家独立阅读新世界")
	life.set_physics_process(true)
	game.player.position=Vector3(-55.7,0,30.5)
	await frames(4)
	await use_point("paper",0)
	var player_yaw: float=game.player.yaw
	check(life.reading_page==0,"真实输入打开第1页")
	for page in [1,2,0]:
		key(KEY_2)
		await frames(25)
		check(life.room.album.turning_page.visible and life.room.album.turn>.2 and life.room.album.turn<.8,"实体页面经过连续转动")
		await frames(30)
		check(life.reading_page==page and life.room.album.page==page and game.conversation.text.contains(CityLife.STORIES[page]),"真实翻页使实物和文字一致")
	key(KEY_1)
	await frames(5)
	check(game.speaker==null and life.reading_page==-1,"真实合上不保留阅读控制")
	check(game.player.yaw==player_yaw,"翻阅不接管玩家镜头")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"不自动捕获鼠标")
	DirAccess.make_dir_recursive_absolute("res://build/c3f-share")
	FileAccess.open("res://build/c3f-share/test.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t")+"\n")
	print("CITY_SHARE_PERFORMANCE_TEST failures=",failures," metrics=",JSON.stringify(metrics))
	game.queue_free(); await process_frame; quit(failures)

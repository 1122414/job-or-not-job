extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	for action in ["interview_hr","interview_lead","interview_boss","join_a","data","prepare","shortcut","submit"]: game.career.apply(action)
	game.payroll.advance(Payroll.PERIOD,"a")
	game.player.pick(game.props[0])
	game.player.pick(game.props[1])
	game.npcs[0].hit(Vector3.FORWARD,1,game.next_action())
	var saved := SaveGame.snapshot(game)
	var money: int = game.payroll.balance
	game.player.release(true)
	game.career.apply("resign")
	check(SaveGame.restore(game,saved),"完整恢复成功")
	check(game.player.held==game.props[1] and game.player.inventory==[game.props[0]],"背包与手持唯一位置恢复")
	check(game.career.employer=="a" and game.career.facts.has("output_one") and game.career.conflict.a==1,"职业成果与警告恢复")
	check(game.payroll.balance==money and game.npcs[0].down>0,"工资与NPC倒地状态恢复")
	game.player.release(true)
	game.player.protection=0
	game.player.hurt(100)
	var dead := SaveGame.snapshot(game)
	SaveGame.restore(game,dead)
	check(game.player.hp==100 and game.player.held==null and game.player.inventory==[game.props[0]],"死亡读档复活不复制投出物")
	var path := "user://test-"+str(Time.get_ticks_usec())+".json"
	check(SaveGame.write(game,path)==OK,"安全写入")
	check(SaveGame.write(game,path)==OK,"第二次写入产生有效备份")
	check(not SaveGame.read(path+".bak",game).is_empty(),"备份有效")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{ damaged")
	file.close()
	check(SaveGame.read(path,game).is_empty(),"损坏档被拒绝")
	check(SaveGame.restore(game,SaveGame.read(path+".bak",game)),"备份可恢复")
	var invalid := saved.duplicate(true)
	invalid.props.a_keyboard.location="held"
	check(not SaveGame.restore(game,invalid),"双手持非法存档整体拒绝")
	game.payroll.advance(0,game.career.employer)
	check(game.payroll.balance==money,"读档不重复支付")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var migration := SaveGame.snapshot(game)
	migration.version=5
	migration.player.position=[-24,0,-12.3]
	check(SaveGame.restore(game,migration),"旧版布局存档可读")
	for i in range(8): await physics_frame
	check(game.position_clear(game.player,game.player.position),"旧档玩家卡在新玻璃墙时只就近修正")
	check(game.player.position.distance_to(Vector3(-24,0,-12.3))<3.1,"布局迁移不把室内角色送到远处")
	var valid_position := Vector3(0,0,10)
	migration.player.position=SaveGame.vector(valid_position)
	check(SaveGame.restore(game,migration),"旧档无障碍位置恢复")
	for i in range(8): await physics_frame
	check(Vector2(game.player.position.x,game.player.position.z)==Vector2(0,10),"有效旧位置不被搬动")
	game.audio.stop()
	OS.delay_msec(150)
	await process_frame
	print("SAVE_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.panels.toggle("bag")
	check(paused and game.player.bag_open,"背包暂停世界")
	game.panels.toggle("journal")
	game.panels.toggle("help")
	check(game.help_open and not game.journal_open and not game.player.bag_open,"主页面互斥")
	game.panels.back()
	check(not paused,"关闭面板恢复")
	game.panels.toggle("pause")
	game.panels.toggle("help")
	check(paused and game.help_open and not game.menu.visible,"暂停帮助互斥")
	game.panels.back()
	check(paused and game.menu.visible,"帮助返回暂停")
	game.panels.back()
	check(not paused,"暂停返回世界")
	var directory := "user://test-restart-"+str(Time.get_ticks_usec())
	game.career.apply("interview_hr")
	var path := SaveGame.archive(game,directory)
	check(not path.is_empty(),"重开归档写入并校验")
	SaveGame.restore(game,game.initial_state.duplicate(true))
	check(game.career.recruit.a==0,"新档恢复未求职状态")
	check(SaveGame.restore(game,SaveGame.read(path,game)),"重开备份可恢复")
	check(game.career.recruit.a==1,"原面试进度保留")
	game.save_path=directory.path_join("active.save")
	game.archive_directory=directory
	game.persistence_enabled=true
	game.new_game()
	check(game.career.recruit.a==0 and not paused,"真实新游戏入口重置并恢复游戏")
	game.restore_previous()
	check(game.career.recruit.a==1,"真实恢复入口还原原进度")
	game.save_path=directory.path_join("missing/active.save")
	game.new_game()
	check(game.hud.toast.contains("保存失败"),"失败提示不能被新游戏成功提示覆盖")
	game.persistence_enabled=false
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	game.queue_free()
	await process_frame
	print("PANELS_TEST failures=",failures)
	quit(failures)

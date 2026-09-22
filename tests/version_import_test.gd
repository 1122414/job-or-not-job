extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	for i in range(10): await physics_frame
	var directory := "user://test-version-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var old := directory.path_join("old.json")
	game.career.apply("interview_hr")
	check(SaveGame.write(game,old)==OK,"创建独立旧进度夹具")
	var original := FileAccess.get_file_as_string(old)
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"切回空世界")
	game.persistence_enabled=true
	game.save_path=directory.path_join("new.json")
	check(game.import_previous(old) and game.career.recruit.a==1,"首次启动可复制旧进度")
	game.career.apply("interview_lead"); game.save_game(false)
	check(FileAccess.get_file_as_string(old)==original,"新版本保存不改变旧文件")
	check(not game.import_previous(old) and game.career.recruit.a==2,"已有新版进度时不重复导入覆盖")
	game.persistence_enabled=false
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	game.queue_free()
	await process_frame
	print("VERSION_IMPORT_TEST failures=",failures)
	quit(failures)

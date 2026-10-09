extends "res://tests/autumn_career_test.gd"
const SearchDriver=preload("res://tests/autumn_search_driver.gd")
func finish(game: Node3D) -> void:
	if failures>0:
		super.finish(game)
		return
	call_deferred("run_search",game)
func run_search(game: Node3D) -> void:
	game.close_interaction()
	if not await perform(game,"rest","story_jobs"):
		failures+=1; super.finish(game); return
	await SearchDriver.run(self,game,check,capture_search)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--story-save="):
			var save_file: String=argument.trim_prefix("--story-save=")
			check(SaveGame.write(game,save_file)==OK and not SaveGame.read(save_file,game).is_empty(),"实际结尾存档落盘校验")
	game.queue_free();await process_frame
	print("AUTUMN_FULL_STORY_TEST failures=",failures);quit(failures)
func capture_search(game: Node3D,name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	RenderingServer.force_draw()
	var folder := "res://docs/evidence/2026-10-09-internship-arc/search"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_viewport.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"后段图形证据保存")

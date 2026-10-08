extends SceneTree
const SearchDriver=preload("res://tests/autumn_search_driver.gd")
var failures := 0
var capture_viewport: Viewport
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	capture_viewport=root
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1280,800);viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.set_disable_input(true);root.add_child(viewport);capture_viewport=viewport
	capture_viewport.add_child(game);root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for frame in range(10): await physics_frame
	# Explicit late-autumn fixture; full_story_test reaches this through career interactions.
	game.story.start_new();game.story.refuse();game.story.data.phase="late_autumn";game.story.sync_scene()
	game.player.position=AutumnStory.STREET_SPAWN
	game.career.stage=6;game.career.grade="未转正 · 应届求职者"
	for key in ["conversion_failed","internship_certificate","output_one","output_two"]: game.career.facts[key]=true
	await SearchDriver.run(self,game,check,capture)
	game.queue_free();await process_frame
	print("AUTUMN_SEARCH_TEST failures=",failures);quit(failures)

func capture(game: Node3D,name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	RenderingServer.force_draw()
	var folder := "res://docs/evidence/2026-10-08-autumn-search"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_viewport.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"最终投递页字体图形证据")

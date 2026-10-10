extends SceneTree
var game: Node3D
var view: SubViewport
const FOLDER := "res://docs/evidence/2026-10-10-six-feedback"
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func shot(title: String) -> void:
	for i in range(8): await process_frame
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png(FOLDER.path_join(title+".png"))
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	view=SubViewport.new();view.size=Vector2i(1280,800);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.set_disable_input(true);root.add_child(view)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(FOLDER)
	game.player.position=CityHome.CENTER+Vector3(0,0,12)
	game.player.yaw=0
	for i in range(15): await physics_frame
	await shot("home-minimap")
	game.panels.show_page("city");await shot("home-map")
	game.panels.show_page("")
	var mentor: AutumnStoryPoint=game.story.points[0]
	game.story.start_new();mentor.position=Vector3(0,40,3);mentor.down=12;mentor.hp=1
	mentor.visual.rotation.y=PI;mentor._physics_process(.4);mentor.set_physics_process(false)
	game.player.position=Vector3(3,40,5);game.player.set_physics_process(false)
	var camera := Camera3D.new();game.add_child(camera)
	camera.position=Vector3(2,42,4);camera.look_at(Vector3(.5,40.3,3));camera.current=true
	await shot("mentor-body")
	print("FEEDBACK_RENDER_DONE")
	game.queue_free();await process_frame;quit()

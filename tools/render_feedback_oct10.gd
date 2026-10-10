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
	game.story.start_new();game.story.data.phase="early_autumn";game.story.sync_scene();game.rental.begin()
	camera.queue_free();game.player.camera.current=true;game.player.set_physics_process(true)
	game.player.position=CityHome.CENTER+Vector3(0,0,12)
	for point in game.rental.points: game.rental.open(point)
	game.panels.show_page("rental");await shot("rental-comparison")
	game.panels.view.scroll.scroll_vertical=10000;await shot("rental-contracts")
	game.rental.sign_lease(false);game.panels.show_page("")
	game.interviews.schedule("interview_hr")
	game.interview_ai.resume_text="本地协议测试简历（非真实求职材料）：我负责离线演示项目的版本对照、实验数据处理和可复现验证，定位过环境差异。"
	game.interview_ai.prepare("a");await shot("resume-preview")
	game.panels.show_page("")
	var host: OfficeNPC=game.npc_for_role("a_hr")
	host.position=OfficeRooms.point(game,"a","interview_host");game.interviews.sessions.a.call_stage="room"
	game.interviews.sessions.a.ai={"questions":["你在离线演示项目里独立负责什么？请说明一种可验证的证据。","三个版本怎么验证差异？","环境差异如何定位？","如何处理临时需求？","你会反问哪些岗位条件？"],"answers":[],"result":"","reason":"","feedback":[]}
	game.interviews.handle("interview_seat_a")
	for i in range(60): await physics_frame
	await shot("resume-question")
	game.interview_ai.input.grab_focus();game.interview_ai.input.text="我建立了三个版本的输入输出对照，保留原始数据，先复现再缩小环境差异。"
	await shot("resume-answer")
	print("FEEDBACK_RENDER_DONE")
	game.queue_free();await process_frame;quit()

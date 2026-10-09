extends SceneTree
var failures := 0
var capture_view: Viewport
var captured := {}
func _initialize():
	if DisplayServer.get_name()!="headless": root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func check(ok: bool,message: String):
	if not ok:push_error(message);failures+=1
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	capture_view=root
	if DisplayServer.get_name()!="headless":
		var view:=SubViewport.new();view.size=Vector2i(1280,800);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.set_disable_input(true);root.add_child(view);capture_view=view
	capture_view.add_child(game);root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10):await physics_frame
	game.set_process(false)
	for npc in game.npcs:npc.set_physics_process(false)
	for person in game.population.residents:
		person.set_physics_process(false);person.position=Vector3(30+person.index*2,0,24)
	var victim: CityResident=game.population.residents[4]
	victim.position=Vector3(-7.47,0,16.62)
	victim.hit(Vector3.FORWARD,10,game.next_action());victim.set_physics_process(true)
	game.response.report(victim,"player");game.player.position=Vector3(20,0,20)
	var phases := []
	var maximum_y := 0.0
	var moved := false
	for i in range(14000):
		await physics_frame
		var phase: String=game.response.cases[victim.stable_id].phase
		if not phase in phases:
			phases.append(phase)
			if phase in ["assessing","transporting"]: await shot(game,"rescue-"+phase,game.response.crew.position+Vector3(5,3,5),game.response.crew.position+Vector3.UP)
		maximum_y=maxf(maximum_y,absf(game.response.crew.position.y))
		if not moved and phase=="approaching" and game.response.crew.position.z<30:
			victim.position.x-=2;moved=true
		if i%120==0:check(SaveGame.valid(SaveGame.snapshot(game),game),"F03 救助全程存档有效："+SaveGame.invalid_section(game))
		if phase=="received":break
	check(game.response.resting(victim) and "assessing" in phases and "transporting" in phases,"F03 站棚旁移动伤者最终连续转运："+str(game.response.snapshot()))
	check(maximum_y<.01,"F03 平地救助不被身体顶起后悬空")
	print("FEEDBACK_RESCUE_TEST failures=",failures," phases=",phases," max_y=",maximum_y)
	game.queue_free();await process_frame;quit(failures)

func shot(game: Node3D,name: String,at: Vector3,focus: Vector3) -> void:
	if DisplayServer.get_name()=="headless" or captured.has(name):return
	captured[name]=true
	var camera:=Camera3D.new();game.add_child(camera);camera.position=at;camera.look_at(focus);camera.current=true
	for i in range(3):await process_frame
	RenderingServer.force_draw()
	var folder:="res://docs/evidence/2026-10-09-playtest-feedback/runtime"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_view.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"图形保存")
	camera.queue_free()

extends "res://tests/attack_window_test.gd"
var view: Viewport
func _initialize() -> void:
	if DisplayServer.get_name()!="headless": root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func run() -> void:
	view=root
	if DisplayServer.get_name()!="headless":
		var capture:=SubViewport.new();capture.size=Vector2i(1280,800);capture.own_world_3d=true;capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(capture);view=capture
	root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	await frames(10);game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false);npc.position=Vector3(40+game.npcs.find(npc)*2,0,80)
	for person in game.population.residents: person.set_physics_process(false);person.position=Vector3(-40-person.index*2,0,80)
	victim=game.npc_for_role("a_hr")
	await reset(2);attack_input();await frames(34)
	check(get_nodes_in_group("comic_impacts").is_empty(),"F06 空挥不出命中或 KO")
	for mode in ["punch","ko","slam"]:
		await reset(.8)
		if mode=="ko":victim.hp=10
		if mode=="slam":
			for prop in game.props:
				if prop.kind=="monitor":game.player.pick(prop);break
			await frames(3);Input.action_press("dangerous")
		attack_input();Input.action_release("dangerous")
		var effects_before := 0
		var pause_seen := false
		var captured := false
		for i in range(42):
			await physics_frame
			var effects := get_nodes_in_group("comic_impacts")
			effects_before=maxi(effects_before,effects.size())
			pause_seen=pause_seen or game.player.hit_pause>0
			if not effects.is_empty() and not captured:
				check(effects[0].knockout==(mode=="ko"),"F06 KO 只在真正击倒时出现")
				check(effects[0].heavy==(mode=="slam"),"F06 摔砸与拳击反馈不同")
				await shot(mode);captured=true
		check(effects_before==1 and pause_seen,"F06 一次命中只有一次特效和局部停顿 "+mode)
		check(victim.hp==(1 if mode=="ko" else 66 if mode=="slam" else 88),"F06 命中伤害只计算一次 "+mode)
		await frames(60)
		check(get_nodes_in_group("comic_impacts").is_empty(),"F06 短时特效及时释放")
		if game.player.held:game.player.store_held()
	game.queue_free();await process_frame
	print("FEEDBACK_COMBAT_TEST failures=",failures);quit(failures)
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var camera:=Camera3D.new();game.add_child(camera);camera.position=Vector3(3.2,2.2,63);camera.look_at(Vector3(0,1,60.5));camera.current=true
	for i in range(3): await process_frame
	RenderingServer.force_draw(false)
	var folder:="res://docs/evidence/2026-10-09-playtest-feedback/runtime"
	DirAccess.make_dir_recursive_absolute(folder)
	check(view.get_texture().get_image().save_png(folder.path_join("comic-"+name+".png"))==OK,"保存实际打击画面")
	camera.queue_free()

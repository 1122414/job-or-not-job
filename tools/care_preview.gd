extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(30): await physics_frame
	game.player.position=Vector3(-9,0,2)
	var npc: OfficeNPC=game.npc_for_role("a_hr")
	npc.position=Vector3(-14,0,-2)
	for i in range(9): npc.hit(Vector3.FORWARD,0.5,game.next_action(),false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current=true
	var captured := {}
	var output := "res://docs/evidence/2026-09-22-care"
	DirAccess.make_dir_recursive_absolute(output)
	for frame in range(2400):
		await physics_frame
		var point: Vector3=npc.rescue_position if npc.care_state=="carried" else npc.position
		camera.position=point+Vector3(3.4,2.5,3.4)
		camera.look_at(point+Vector3.UP*0.6)
		if frame>40 and not captured.has(npc.care_state):
			var state: String=npc.care_state
			paused=true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(state+".png"))
			captured[state]=true
			paused=false
		if npc.care_state=="away": break
	print("CARE_PREVIEW ",captured.keys())
	game.care.clear()
	game.queue_free()
	await process_frame
	quit(0 if captured.has("away") else 1)

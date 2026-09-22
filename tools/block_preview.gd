extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	var npc: OfficeNPC=game.npc_for_role("a_lead")
	npc.position=Vector3(-14,0,0)
	npc.home=npc.position
	game.player.position=npc.position+Vector3(0,0,2)
	game.player.yaw=0
	npc.hit(Vector3.FORWARD,0.5,game.next_action(),false)
	for i in range(40): await physics_frame
	paused=true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/evidence/2026-09-22-care")
	root.get_texture().get_image().save_png("res://docs/evidence/2026-09-22-care/block.png")
	print("BLOCK_PREVIEW ",npc.visual.current)
	quit()

extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	npc.position=Vector3(-14,0,-1)
	npc.home=npc.position
	game.player.position=npc.position+Vector3(0,0,1.5)
	game.player.yaw=0
	game.social.meet(npc)
	game.social.remember(npc,"shared_demo","你们一起核对了演示资料，小夏认可你保留原始依据。",10,10)
	game.person_index=1
	game.panels.show_page("people")

	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://docs/evidence/2026-09-22-people")
		root.get_texture().get_image().save_png("res://docs/evidence/2026-09-22-people/details.png")
		quit()

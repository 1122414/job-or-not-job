extends SceneTree
# Isolated, actual movement input with a side inspection camera; never loads a save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.size=Vector2i(1280,800)
	game.player.position=Vector3(0,0,16)
	game.player.yaw=0
	game.hud.hide()
	var inspection := Camera3D.new()
	game.add_child(inspection)
	inspection.current=true
	var output := "res://docs/evidence/2026-09-22-motion"
	DirAccess.make_dir_recursive_absolute(output)
	Input.action_press("forward")
	for frame in range(90):
		if frame==45: Input.action_press("run")
		await physics_frame
		inspection.global_position=game.player.position+Vector3(2.7,1.1,-1.2)
		inspection.look_at(game.player.position+Vector3.UP*0.85)
		if frame in [25,35,55,65]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("step-%02d.png"%frame))
	Input.action_release("forward")
	Input.action_release("run")
	var npc: OfficeNPC=game.npcs[0]
	npc.position=Vector3(-2,0,10)
	npc.home=npc.position
	game.player.position=Vector3(0,0,20)
	for strength in [0.65,1.4,5.0]:
		npc.visual.rotation.y=0
		npc.hit(Vector3.RIGHT,strength,game.next_action())
		for frame in range(20 if strength>=1 else 6):
			await physics_frame
			inspection.global_position=npc.position+Vector3(2.7,1.1,2.0)
			inspection.look_at(npc.position+Vector3(0.4,0.65,0))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("hit-%.2f.png"%strength))
	print("MOTION_CAPTURED ",output)
	game.queue_free()
	await process_frame
	quit()

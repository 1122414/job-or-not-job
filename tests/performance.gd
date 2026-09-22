extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	root.size=Vector2i(1280,800)
	game.player.position=Vector3(-14,0,0)
	game.player.yaw=0
	for i in range(60): await process_frame
	var result := {"device":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"viewport":str(root.size),"renderer":"gl_compatibility","samples":{}}
	for mode in ["normal","chaos"]:
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for i in range(600):
			if mode=="chaos" and i%45==0:
				for prop in game.props: prop.strike(Vector3(1,0,-1),game.next_action(),4.0)
				for npc in game.npcs:
					if npc.company=="a": npc.hit(Vector3(1,0,-1),0.65,game.next_action())
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now-previous)/1000.0)
			previous=now
		times.sort()
		var total := 0.0
		for value in times: total+=value
		result.samples[mode]={"frames":600,"mean_ms":total/600,"p95_ms":times[569],"p99_ms":times[593],"average_fps":600000/total}
	var file := FileAccess.open("res://build/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("PERFORMANCE ",JSON.stringify(result))
	game.audio.stop()
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	quit()

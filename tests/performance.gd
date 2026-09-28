extends SceneTree

var frames := 600
var runs := 1
var warmup := 60
var output := "res://build/performance.json"
var identity_path := ""
var viewport_size := Vector2i(1280,800)
var company := "a"
var allow_headless := false

func _initialize() -> void:
	call_deferred("run")

func parse_options() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument=="--allow-headless":
			allow_headless=true
			continue
		var pair := argument.split("=",true,1)
		if pair.size()!=2: return false
		match pair[0]:
			"--frames": frames=int(pair[1])
			"--runs": runs=int(pair[1])
			"--warmup": warmup=int(pair[1])
			"--width": viewport_size.x=int(pair[1])
			"--height": viewport_size.y=int(pair[1])
			"--output": output=pair[1]
			"--identity": identity_path=pair[1]
			"--company": company=pair[1]
			_: return false
	return frames>=10 and frames<=360000 and runs>=1 and runs<=10 and warmup>=2 and warmup<=3600 and viewport_size.x>=320 and viewport_size.x<=7680 and viewport_size.y>=240 and viewport_size.y<=4320 and company in ["a","b"]

func distribution(values: Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered: total+=float(value)
	var count := ordered.size()
	return {"count":count,"mean":total/count,"p50":ordered[ceili(count*0.50)-1],"p95":ordered[ceili(count*0.95)-1],"p99":ordered[ceili(count*0.99)-1],"max":ordered[-1]}

func run() -> void:
	if not parse_options():
		push_error("Invalid performance options")
		quit(2)
		return
	var headless := DisplayServer.get_name()=="headless"
	if headless and not allow_headless:
		push_error("Graphical performance requires a display; --allow-headless is only for harness validation")
		quit(2)
		return
	var identity: Dictionary = {"available":false}
	if not identity_path.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(identity_path))
		if not parsed is Dictionary or not parsed.has("source_sha256"):
			push_error("Invalid source identity")
			quit(2)
			return
		identity={"available":true,"source_commit":parsed.source_commit,"source_sha256":parsed.source_sha256,"runtime_dirty":parsed.runtime_dirty}
	seed(20260929)
	root.size=viewport_size
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled:
		push_error("Performance fixture must not enable player persistence")
		quit(2)
		return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var result := {"schema_version":2,"source":identity,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"viewport":[root.size.x,root.size.y],"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"headless_validation_only":headless,"company":company,"seed":20260929,"frames_per_sample":frames,"warmup_frames":warmup,"samples":[]}
	result["cpu"]=OS.get_processor_name()
	result["logical_processors"]=OS.get_processor_count()
	result["os_version"]=OS.get_version()
	result["memory_info"]=OS.get_memory_info()
	for iteration in range(runs):
		for mode in ["normal","chaos"]:
			if not SaveGame.restore(game,game.initial_state.duplicate(true)):
				push_error("Cannot reset performance fixture")
				quit(2)
				return
			game.player.position=Vector3(-14 if company=="a" else 14,0,0)
			game.player.yaw=0
			for i in range(warmup): await process_frame
			var times: Array = []
			var metrics := {"render_cpu_ms":[],"render_setup_cpu_ms":[],"render_gpu_ms":[],"physics_monitor_ms":[],"static_memory_bytes":[],"render_memory_bytes":[],"draw_calls":[],"primitives":[],"active_physics_objects":[],"nodes":[]}
			var previous := Time.get_ticks_usec()
			for i in range(frames):
				if mode=="chaos" and i%45==0:
					for prop in game.props: prop.strike(Vector3(1,0,-1),game.next_action(),4.0)
					for npc in game.npcs:
						if npc.company==company: npc.hit(Vector3(1,0,-1),0.65,game.next_action())
				await process_frame
				var now := Time.get_ticks_usec()
				times.append((now-previous)/1000.0)
				previous=now
				metrics.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				metrics.render_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
				metrics.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				metrics.physics_monitor_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
				metrics.static_memory_bytes.append(Performance.get_monitor(Performance.MEMORY_STATIC))
				metrics.render_memory_bytes.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
				metrics.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				metrics.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				metrics.active_physics_objects.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
				metrics.nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var measured := {}
			for key in metrics:
				var stats := distribution(metrics[key])
				measured[key]={"available":false,"reason":"monitor returned only zero; unsupported or inactive"} if stats.max<=0 else {"available":true,"distribution":stats}
			var frame_stats := distribution(times)
			var entry := {"run":iteration+1,"mode":mode,"frame_ms":frame_stats,"average_fps":1000.0/frame_stats.mean,"metrics":measured,"raw_frame_ms":times}
			result.samples.append(entry)
			print("PROFILE_SAMPLE run=",iteration+1," mode=",mode," fps=",entry.average_fps," p95_ms=",frame_stats.p95)
	var directory := ProjectSettings.globalize_path(output).get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK:
		push_error("Cannot create performance output directory")
		quit(2)
		return
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write performance output")
		quit(2)
		return
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	game.audio.stop()
	game.queue_free()
	await process_frame
	print("PROFILE_COMPLETE output=",output," persistence=false headless=",headless)
	quit()

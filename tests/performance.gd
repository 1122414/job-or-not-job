extends SceneTree

var frames := 600
var runs := 1
var warmup := 60
var output := "res://build/performance.json"
var identity_path := ""
var viewport_size := Vector2i(1280,800)
var company := "a"
var allow_headless := false
var background := false
var view: Viewport
var completed_draws := 0

func _initialize() -> void:
	if "--background" in OS.get_cmdline_user_args():
		background=true
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	call_deferred("run")

func parse_options() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument=="--background": background=true;continue
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

func background_guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func run() -> void:
	if not parse_options():
		push_error("Invalid performance options")
		quit(2)
		return
	var headless := DisplayServer.get_name()=="headless"
	if background and (headless or RenderingServer.is_render_loop_enabled()):
		push_error("Background measurement requires graphics and --disable-render-loop; it is not normal-game FPS")
		quit(2);return
	if headless and not allow_headless:
		push_error("Graphical performance requires a display; --allow-headless is only for harness validation")
		quit(2)
		return
	var identity: Dictionary = {"available":false}
	if background and identity_path.is_empty():
		push_error("Background measurement requires a build identity")
		quit(2);return
	if not identity_path.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(identity_path))
		if not parsed is Dictionary or not parsed.has_all(["source_commit","source_sha256","runtime_dirty"]):
			push_error("Invalid source identity")
			quit(2)
			return
		identity={"available":true,"source_commit":parsed.source_commit,"source_sha256":parsed.source_sha256,"runtime_dirty":parsed.runtime_dirty}
	var packaged_identity := BuildInfo.read()
	if background and (packaged_identity.is_empty() or packaged_identity.source_sha256!=identity.source_sha256 or packaged_identity.source_commit!=identity.source_commit):
		push_error("Background measurement identity must match the running package")
		quit(2);return
	identity["build_id"]=packaged_identity.get("build_id", "source-run")
	seed(20260929)
	root.size=viewport_size
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	view=root
	if background:
		root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
		var viewport := SubViewport.new()
		viewport.size=viewport_size;viewport.own_world_3d=true
		viewport.msaa_3d=root.msaa_3d;viewport.screen_space_aa=root.screen_space_aa
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport);view=viewport
		RenderingServer.frame_post_draw.connect(func(): completed_draws+=1)
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled:
		push_error("Performance fixture must not enable player persistence")
		quit(2)
		return
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	var result := {"schema_version":4,"source":identity,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"viewport":[viewport_size.x,viewport_size.y],"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"headless_validation_only":headless,"company":company,"seed":20260929,"frames_per_sample":frames,"warmup_frames":warmup,"samples":[]}
	result["kind"]="running_scene_offscreen_step_cost_not_game_fps" if background else "normal_render_loop" if not headless else "headless_harness_validation"
	result["normal_game_fps"]=not background and not headless
	result["debug_build"]=OS.is_debug_build()
	result["driver"]=RenderingServer.get_current_rendering_driver_name()
	result["msaa_3d"]=view.msaa_3d
	result["physics_ticks_per_second"]=Engine.physics_ticks_per_second
	result["render_loop_enabled"]=RenderingServer.is_render_loop_enabled()
	result["render_samples_valid"]=not headless
	result["monitor_note"]="Performance monitors are periodically refreshed snapshots, not independent per-frame timings"
	result["background_window_guard_required"]=background
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
			var warmup_started := Time.get_ticks_usec()
			var warmed := 0
			while warmed<warmup or (background and Time.get_ticks_usec()-warmup_started<2000000):
				await process_frame
				if background: RenderingServer.force_draw(false)
				warmed+=1
			var warmup_elapsed_ms := (Time.get_ticks_usec()-warmup_started)/1000.0
			var times: Array = []
			var metrics := {"render_cpu_ms":[],"render_setup_cpu_ms":[],"render_gpu_ms":[],"physics_monitor_ms":[],"static_memory_bytes":[],"render_memory_bytes":[],"draw_calls":[],"primitives":[],"active_physics_objects":[],"nodes":[]}
			var previous := Time.get_ticks_usec()
			var previous_drawn := Engine.get_frames_drawn()
			var drawn_deltas: Array=[]
			for i in range(frames):
				if mode=="chaos" and i%45==0:
					for prop in game.props: prop.strike(Vector3(1,0,-1),game.next_action(),4.0)
					for npc in game.npcs:
						if npc.company==company: npc.hit(Vector3(1,0,-1),0.65,game.next_action())
				await process_frame
				var drawn := Engine.get_frames_drawn()
				var draw_delta := drawn-previous_drawn
				if background:
					var before := completed_draws
					RenderingServer.force_draw(false)
					for pending in range(2):
						if completed_draws>before: break
						await process_frame
					if completed_draws-before!=1 or not background_guard():
						push_error("Invalid background draw completion/window guard")
						quit(3);return
					draw_delta=completed_draws-before
				drawn_deltas.append(draw_delta)
				previous_drawn=drawn
				var now := Time.get_ticks_usec()
				times.append((now-previous)/1000.0)
				previous=now
				metrics.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()))
				metrics.render_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
				metrics.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
				metrics.physics_monitor_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
				metrics.static_memory_bytes.append(Performance.get_monitor(Performance.MEMORY_STATIC))
				metrics.render_memory_bytes.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
				metrics.draw_calls.append(view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
				metrics.primitives.append(view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
				metrics.active_physics_objects.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
				metrics.nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var measured := {}
			for key in metrics:
				var stats := distribution(metrics[key])
				measured[key]={"available":false,"reason":"monitor returned only zero; unsupported or inactive"} if stats.max<=0 else {"available":true,"distribution":stats}
			var frame_stats := distribution(times)
			var entry := {"run":iteration+1,"mode":mode,"actual_warmup_steps":warmed,"warmup_elapsed_ms":warmup_elapsed_ms,"frame_ms":frame_stats,"average_fps":1000.0/frame_stats.mean,"metrics":measured,"raw_frame_ms":times}
			if background or headless:
				entry.erase("frame_ms");entry.erase("average_fps");entry.erase("raw_frame_ms")
				entry["step_wall_ms"]=frame_stats;entry["raw_step_wall_ms"]=times
			if background:
				var picture := view.get_texture().get_image()
				if picture.is_empty() or picture.get_size()!=viewport_size or not measured.primitives.available:
					push_error("Background measurement did not render the scene")
					quit(3);return
				var image_path: String = output.get_basename()+"-"+str(iteration+1)+"-"+mode+".png"
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(image_path).get_base_dir())
				if picture.save_png(image_path)!=OK: push_error("Cannot save background evidence");quit(2);return
				entry["image"]=image_path.get_file()
			entry["raw_draw_completions" if background else "raw_drawn_frames"]=drawn_deltas
			entry["draw_counter"]="RenderingServer.frame_post_draw" if background else "Engine.get_frames_drawn"
			entry["undrawn_samples"]=drawn_deltas.count(0)
			entry["render_sample_valid"]=not headless and drawn_deltas.count(0)==0
			if not entry.render_sample_valid: result.render_samples_valid=false
			result.samples.append(entry)
			if background: print("PROFILE_SAMPLE run=",iteration+1," mode=",mode," offscreen_step_p95_ms=",frame_stats.p95," not_game_fps=true")
			elif headless: print("PROFILE_SAMPLE run=",iteration+1," mode=",mode," headless_validation=true")
			else: print("PROFILE_SAMPLE run=",iteration+1," mode=",mode," fps=",entry.average_fps," p95_ms=",frame_stats.p95)
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
	if background: view.queue_free()
	await process_frame
	print("PROFILE_COMPLETE output=",output," persistence=false headless=",headless)
	if not headless and not result.render_samples_valid:
		push_error("Performance samples included undrawn frames; do not use as rendering FPS")
		quit(3)
	else: quit()

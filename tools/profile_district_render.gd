extends "res://tools/render_character_candidates.gd"

# Controlled rendering attribution, not a normal-game FPS benchmark.
const VIEWS := [
	["old-street",Vector3(-64,1.75,54),Vector3(-47,2.8,36),540],
	["company-a",Vector3(-14,1.7,-1.8),Vector3(-8.5,1.35,-8),540],
	["company-b",Vector3(14,1.7,-1.8),Vector3(19.5,1.35,-8),540],
	["waterfront-night",Vector3(-30,1.7,115),Vector3(16,1.6,121),1230]
]
var completed_draws := 0

func views() -> Array:
	return VIEWS

func prepare_scene(_game: Node3D) -> void:
	pass

func warmup_frames() -> int:
	return 10

func draw_completed() -> void:
	completed_draws+=1

func summary(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values: total+=value
	return {"mean":total/values.size(),"p50":sorted[int((sorted.size()-1)*0.5)],"p95":sorted[int((sorted.size()-1)*0.95)],"max":sorted.back()}

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Rendering attribution requires a real graphics backend"); quit(1); return
	var samples := 45
	var runs := 1
	var attribute := false
	var nature_attribute := false
	var identity := ""
	for argument in OS.get_cmdline_user_args():
		if argument=="--attribute": attribute=true
		if argument=="--nature-attribute": nature_attribute=true
		if argument.begins_with("--samples="): samples=int(argument.trim_prefix("--samples="))
		if argument.begins_with("--runs="): runs=int(argument.trim_prefix("--runs="))
		if argument.begins_with("--identity="): identity=argument.trim_prefix("--identity=")
	if samples<10 or samples>600 or runs<1 or runs>5 or identity.is_empty():
		push_error("Require identity file, 10..600 samples and 1..5 runs"); quit(1); return
	var provenance=JSON.parse_string(FileAccess.get_file_as_string(identity))
	if not provenance is Dictionary or not provenance.has("source_sha256"):
		push_error("Missing runtime source identity"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	if not guard(): push_error("Background window protection failed"); quit(1); return
	game.process_mode=Node.PROCESS_MODE_DISABLED
	await prepare_scene(game)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.fov=65
	camera.make_current()
	var buckets := {"company_geometry":[],"props":[],"people":[],"company_lights":[]}
	for company in [game.get_node("CompanyA"),game.get_node("CompanyB")]:
		buckets.company_geometry.append_array(company.find_children("*","GeometryInstance3D",true,false))
		buckets.company_lights.append_array(company.find_children("*","Light3D",true,false))
	for prop in game.props: buckets.props.append(prop)
	buckets.people=game.find_children("*","HumanVisual",true,false)
	buckets.trees=game.get_node("ConnectedDistrict/Streetscape").trees
	var phases := ["full"]
	if attribute: phases.append_array(["company_geometry","props","people","company_lights","sun_shadows"])
	if nature_attribute: phases.append_array(["trees","ssao"])
	var rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	RenderingServer.frame_post_draw.connect(draw_completed)
	var data := {"schema":1,"source_commit":provenance.source_commit,"source_sha256":provenance.source_sha256,"runtime_dirty":provenance.runtime_dirty,
		"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info(),"debug_build":OS.is_debug_build(),
		"environment":{"sdfgi":game.environment.sdfgi_enabled,"ssil":game.environment.ssil_enabled,"static_gi_instances":game.get_meta("static_gi_instances",0)},"warmup_frames":warmup_frames(),
		"candidate_indirect_multiplier":game.get_meta("candidate_indirect_multiplier",1.0),
		"candidate_mode":game.get_meta("candidate_mode","runtime"),
		"candidate_voxel_bias":game.get_meta("candidate_voxel_bias",[]),
		"resolution":[1440,900],"fov":65,"kind":"frozen_scene_offscreen_render_submission","normal_game_fps":false,"final_performance_accepted":false,"samples_per_entry":samples,"runs":runs,"entries":[]}
	for iteration in range(runs):
		for shot in views():
			game.payroll.minute=shot[3]
			game.update_daylight()
			camera.position=shot[1]
			camera.look_at(shot[2])
			for phase in phases:
				var previous := {}
				for node in buckets.get(phase,[]):
					previous[node]=node.visible
					node.visible=false
				var shadow_before: bool=game.sun.shadow_enabled
				var ssao_before: bool=game.environment.ssao_enabled
				if phase=="sun_shadows": game.sun.shadow_enabled=false
				if phase=="ssao": game.environment.ssao_enabled=false
				for warmup in range(warmup_frames()):
					await process_frame
					RenderingServer.force_draw(false)
				var metrics := {"force_draw_wall_ms":[],"render_cpu_ms":[],"render_setup_cpu_ms":[],"render_gpu_ms":[],"draw_calls":[],"primitives":[]}
				var rendered := 0
				for index in range(samples):
					await process_frame
					var before := completed_draws
					var start := Time.get_ticks_usec()
					RenderingServer.force_draw(false)
					metrics.force_draw_wall_ms.append((Time.get_ticks_usec()-start)/1000.0)
					# Engine.get_frames_drawn() stays zero with --disable-render-loop,
					# even when force_draw renders. Require the server's actual completion.
					for pending in range(2):
						if completed_draws>before: break
						await process_frame
					var delta := completed_draws-before
					if delta!=1 or not guard():
						push_error("Invalid draw sample: delta="+str(delta)+" minimized="+str(root.mode==Window.MODE_MINIMIZED)+" no_focus="+str(root.get_flag(Window.FLAG_NO_FOCUS))+" focused="+str(root.has_focus())+" mouse="+str(Input.mouse_mode))
						quit(1); return
					rendered+=delta
					metrics.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
					metrics.render_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
					metrics.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
					metrics.draw_calls.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
					metrics.primitives.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
				var measured := {}
				for key in metrics:
					var stats := summary(metrics[key])
					measured[key]={"available":stats.max>0,"distribution":stats,"raw":metrics[key]}
				var entry := {"run":iteration+1,"view":shot[0],"excluded":phase if phase!="full" else "none","minute":shot[3],"camera":SaveGame.vector(shot[1]),"target":SaveGame.vector(shot[2]),"rendered_samples":rendered,"metrics":measured}
				data.entries.append(entry)
				if phase in ["full","ssao"] and iteration==0:
					var picture := viewport.get_texture().get_image()
					var suffix := "-without-ssao" if phase=="ssao" else ""
					if picture==null or picture.is_empty() or picture.save_png(output.path_join(shot[0]+suffix+".png"))!=OK:
						push_error("Cannot save full-scene comparison image"); quit(1); return
				for node in previous: node.visible=previous[node]
				game.sun.shadow_enabled=shadow_before
				game.environment.ssao_enabled=ssao_before
				print("RENDER_SAMPLE ",shot[0]," excluded=",entry.excluded," calls=",measured.draw_calls.distribution.mean," submit_ms=",measured.force_draw_wall_ms.distribution.mean)
	data.background_guard_passed=guard()
	data.draw_completion_signal_count=completed_draws
	data.engine_frames_drawn=Engine.get_frames_drawn()
	FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("DISTRICT_RENDER_PROFILE_OK entries=",data.entries.size()," normal_game_fps=false pointer_visible=",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	quit()

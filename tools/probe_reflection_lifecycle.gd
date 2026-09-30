extends "res://tools/probe_indirect_lighting.gd"

# Repeated independent worlds distinguish a fixed shutdown warning from growth.
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Lifecycle probe requires graphics"); quit(1); return
	root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.frame_post_draw.connect(on_draw)
	var entries := []
	var cycles := 4
	var refreshes := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cycles="): cycles=int(argument.trim_prefix("--cycles="))
		if argument.begins_with("--refreshes="): refreshes=int(argument.trim_prefix("--refreshes="))
	for cycle in range(cycles):
		var viewport := SubViewport.new()
		viewport.size=Vector2i(320,240)
		viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		make_box(stage,Vector3(8,.2,8),Vector3.ZERO,Color.WHITE)
		var light := OmniLight3D.new()
		light.position=Vector3(0,3,0); light.omni_range=10
		stage.add_child(light)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position=Vector3(0,3,4);camera.look_at(Vector3.ZERO);camera.current=true
		var probe := ReflectionProbe.new()
		probe.size=Vector3(8,6,8);probe.position=Vector3(0,2,0)
		stage.add_child(probe)
		for frame in range(32):
			await process_frame
			RenderingServer.force_draw(false)
		for refresh in range(refreshes):
			probe.update_mode=ReflectionProbe.UPDATE_ONCE
			for frame in range(16):
				await process_frame
				RenderingServer.force_draw(false)
		if not background_guard() or completed<32*(cycle+1):
			push_error("Lifecycle background/draw guard failed");quit(1);return
		var active := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		viewport.queue_free()
		for frame in range(12):
			await process_frame
			RenderingServer.force_draw(false)
		entries.append({"cycle":cycle,"active_texture_bytes":active,"released_texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)})
	FileAccess.open(output.path_join("lifecycle.json"),FileAccess.WRITE).store_string(JSON.stringify({"entries":entries,"refreshes_per_world":refreshes,"completed_draws":completed,"guard":background_guard(),"driver":RenderingServer.get_current_rendering_driver_name(),"texture_counter_valid":false},"\t")+"\n")
	print("REFLECTION_LIFECYCLE_OK ",JSON.stringify(entries))
	quit()

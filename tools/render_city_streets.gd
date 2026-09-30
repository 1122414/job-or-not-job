extends "res://tools/render_character_candidates.gd"

const VIEWS := [
	["old-street",Vector3(-64,1.75,54),Vector3(-47,2.8,36),540],
	["bookshop",Vector3(-47,1.7,48),Vector3(-53,2.1,32),540],
	["homes",Vector3(64,1.7,63),Vector3(43,5,82),540],
	["waterfront",Vector3(-30,1.7,115),Vector3(16,1.6,121),540],
	["company-exit",Vector3(-20,1.7,17),Vector3(-46,3,34),540],
	["district-overview",Vector3(-59,18,95),Vector3(2,1,50),540],
	["old-street-night",Vector3(-64,1.75,54),Vector3(-47,2.8,36),1230],
	["waterfront-night",Vector3(-30,1.7,115),Vector3(16,1.6,121),1230]
]

func views() -> Array:
	return VIEWS

func prepare_scene(_game: Node3D) -> void:
	pass

func fingerprint(game: Node3D) -> Dictionary:
	var result := {}
	for node in game.get_node("ConnectedDistrict/Streetscape").find_children("*","MultiMeshInstance3D",true,false):
		var buffer: PackedFloat32Array=node.multimesh.buffer
		var stride := 12+(4 if node.multimesh.use_colors else 0)+(4 if node.multimesh.use_custom_data else 0)
		if buffer.size()!=node.multimesh.instance_count*stride:
			push_error("Street fingerprint requires actual nonempty GPU transforms: "+String(node.name))
			return {}
		result[String(node.name)]=hash(buffer)
	return result

func tree_fingerprint(game: Node3D) -> Array:
	var result := []
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	for tree in streets.trees:
		result.append(var_to_str(tree.transform))
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var initial_actions := InputMap.get_actions()
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	if root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Street capture must remain minimized, unfocusable, without focus or mouse capture"); quit(1); return
	game.set_process(false)
	prepare_scene(game)
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	camera.fov=65
	var data := {"views":[],"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"root_minimized":root.mode==Window.MODE_MINIMIZED,"root_focused":root.has_focus(),"root_unfocusable":root.get_flag(Window.FLAG_NO_FOCUS),"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"resolution":[1440,900],"fov":65,"normal_game_performance":false,"final_visual_acceptance":false}
	for shot in views():
		game.payroll.minute=shot[3]
		game.update_daylight()
		camera.position=shot[1]
		camera.look_at(shot[2])
		if not await capture(viewport,shot[0]): quit(1); return
		data.views.append({"name":shot[0],"camera":SaveGame.vector(shot[1]),"target":SaveGame.vector(shot[2]),"minute":shot[3],"draw_calls":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
	var signature := fingerprint(game)
	var tree_signature := tree_fingerprint(game)
	if signature.is_empty(): quit(1); return
	game.queue_free()
	await process_frame
	# Match a fresh process: game-specific input actions otherwise survive the
	# destroyed fixture and are registered twice by the next scene.
	for action in InputMap.get_actions():
		if not initial_actions.has(action): InputMap.erase_action(action)
	var rebuilt=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(rebuilt)
	for i in range(6): await physics_frame
	for i in range(3):
		await process_frame
		RenderingServer.force_draw(false)
	data.deterministic_gpu_buffers=fingerprint(rebuilt)==signature
	data.nonempty_gpu_batches=signature.size()
	data.deterministic_tree_transforms=tree_fingerprint(rebuilt)==tree_signature
	data.tree_instances=tree_signature.size()
	if not data.deterministic_gpu_buffers: push_error("Street transforms changed on fresh scene construction"); quit(1); return
	if not data.deterministic_tree_transforms or data.tree_instances!=23: push_error("Tree placements changed on fresh scene construction"); quit(1); return
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("CITY_STREET_RENDER ",JSON.stringify(data))
	viewport.queue_free()
	await process_frame
	quit()

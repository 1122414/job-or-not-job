extends SceneTree

# Run from outside the project with --main-pack and this external script.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var build := BuildInfo.read()
	if build.is_empty() or build.save_schema!=SaveGame.VERSION:
		push_error("Package identity or save schema missing")
		quit(1)
		return
	for excluded in ["res://tests/world_test.gd", "res://tools/package_macos.py", "res://docs/progress.md", "res://build/p0-source-identity.json", "res://production/quaternius/standard-2025-06-10/glTF/AnimationLibrary_Godot_Standard.gltf"]:
		if FileAccess.file_exists(excluded) or ResourceLoader.exists(excluded):
			push_error("Development files leaked into package: "+excluded)
			quit(1)
			return
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	if game.persistence_enabled or game.npcs.size()!=10 or game.props.size()!=114:
		push_error("Package scene or persistence isolation changed")
		quit(1)
		return
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE or game.player.capture_permitted():
		push_error("Automated package probe must not capture the desktop pointer")
		quit(1)
		return
	var sources_path := OS.get_executable_path().get_base_dir().path_join("../Resources/ASSET-SOURCES.json")
	var sources: Variant=JSON.parse_string(FileAccess.get_file_as_string(sources_path))
	if not sources is Dictionary or sources.get("assets",[]).size()!=5:
		push_error("Packaged asset provenance missing")
		quit(1)
		return
	var motion_path := OS.get_executable_path().get_base_dir().path_join("../Resources/ANIMATION-SOURCES.json")
	var motion: Variant=JSON.parse_string(FileAccess.get_file_as_string(motion_path))
	var authored: AnimationLibrary=load("res://assets/animations/quaternius_upper_body.res")
	if not motion is Dictionary or motion.get("clips",[]).size()!=2 or not authored.has_animation("talk") or not authored.has_animation("idle"):
		push_error("Packaged authored motion or provenance missing")
		quit(1)
		return
	var humans: Array=game.find_children("*","Node3D",true,false).filter(func(node): return node is HumanVisual)
	if humans.size()!=11:
		push_error("Packaged character visuals missing")
		quit(1)
		return
	for human in humans:
		if human.animation.get_animation("talk")!=authored.get_animation("talk") or human.animation.get_animation("idle")!=authored.get_animation("idle"):
			push_error("Packaged character does not use authored motion")
			quit(1)
			return
	for firm in ["A","B"]:
		var space := OfficeRooms.space(game,firm.to_lower())
		if space==null or space.get_node_or_null("Anchors/interview_seat")==null or space.get_node_or_null("Architecture")==null:
			push_error("Packaged authored company space missing")
			quit(1)
			return
		for name in ["ReceptionLamp"+firm,"WaitingChair"+firm+"-1","WaitingChair"+firm+"1"]:
			var prop: Node=OfficeRooms.space(game,firm.to_lower()).get_node_or_null(name)
			if prop==null:
				push_error("Packaged environment prop missing: "+name)
				quit(1)
				return
			for mesh in prop.find_children("*","MeshInstance3D",true,false):
				for surface in range(mesh.mesh.get_surface_count()):
					var material: StandardMaterial3D=mesh.mesh.surface_get_material(surface)
					for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
						if texture==null or not texture.get_image().has_mipmaps() or not texture.get_image().is_compressed():
							push_error("Packaged model texture import contract failed: "+name)
							quit(1)
							return
	game.panels.show_page("journal")
	var company_sources: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/company_materials/provenance.json"))
	if not company_sources is Dictionary or company_sources.get("assets",[]).size()!=2:
		push_error("Packaged company material provenance missing")
		quit(1)
		return
	for path in ["res://assets/materials/office_wood.tres","res://assets/materials/office_brick.tres"]:
		var material: StandardMaterial3D=load(path)
		for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
			if texture==null or not texture.get_image().has_mipmaps() or not texture.get_image().is_compressed():
				push_error("Packaged company material import contract failed: "+path)
				quit(1)
				return
	for i in range(5): await process_frame
	var page: Control=game.panels.view
	if not page.visible or not page.buttons.has("company-b"):
		push_error("Packaged interactive page missing")
		quit(1)
		return
	root.set_disable_input(false)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position=page.buttons["company-b"].get_global_rect().get_center()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=pressed
		root.push_input(click,true)
	for i in range(5): await process_frame
	if game.career.facts.get("guide_company")!="b":
		push_error("Packaged company button did not handle mouse input")
		quit(1)
		return
	root.set_disable_input(true)
	game.panels.show_page("")
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Closing a page recaptured the pointer")
		quit(1)
		return
	game.toggle_menu()
	if DisplayServer.get_name()!="headless":
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--screenshot="):
				var error := root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
				if error!=OK: quit(1); return
	print("PACKAGED_SMOKE_OK build=",build.build_id," label=",BuildInfo.label()," npcs=",game.npcs.size()," props=",game.props.size()," company_spaces=2 company_sources=2 environment_props=6 asset_sources=5 authored_clips=2 authored_characters=11 texture_imports=verified ui_mouse=verified persistence=",game.persistence_enabled)
	paused=false
	game.queue_free()
	await process_frame
	quit()

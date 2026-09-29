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
	if humans.size()!=14:
		push_error("Packaged character visuals missing")
		quit(1)
		return
	for human in humans:
		var expected: AnimationLibrary=authored if human.cast_id.is_empty() else load("res://assets/animations/cast/"+human.cast_id+".res")
		if human.animation.get_animation("talk")!=expected.get_animation("talk") or human.animation.get_animation("idle")!=expected.get_animation("idle"):
			push_error("Packaged character does not use authored motion")
			quit(1)
			return
		if not human.cast_id.is_empty():
			if human.face_meshes.is_empty() or human.skeleton.find_bone("eye.L")<0 or human.skeleton.find_bone("eye.R")<0:
				push_error("Packaged cast facial resources missing")
				quit(1)
				return
			for mesh in human.find_children("*","MeshInstance3D",true,false):
				if mesh.skin==null: continue
				for surface in range(mesh.mesh.get_surface_count()):
					var material: StandardMaterial3D=mesh.mesh.surface_get_material(surface)
					if material==null or material.albedo_texture==null or not material.albedo_texture.get_image().is_compressed():
						push_error("Packaged cast texture compression missing")
						quit(1)
						return
	if game.player.visual.cast_id!="protagonist" or game.npc_for_role("a_hr").visual.cast_id!="lin_lan" or game.npc_for_role("b_hr").visual.cast_id!="a_cheng":
		push_error("Packaged cast identities missing")
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
	if game.transit==null or CityLayout.STOPS.size()!=4 or game.get_node_or_null("ConnectedDistrict")==null:
		push_error("Packaged connected district or bus missing")
		quit(1)
		return
	game.player.position=CityLayout.STOPS[0].platform
	for i in range(3): await physics_frame
	if not game.transit.board(0):
		push_error("Packaged bus cannot be boarded")
		quit(1)
		return
	game.transit.set_physics_process(false)
	game.transit.dwell=0
	for i in range(90):
		game.transit.tick(0.1)
		await physics_frame
	var riding_save := SaveGame.snapshot(game)
	if game.transit.distance<20 or not SaveGame.restore(game,riding_save):
		push_error("Packaged moving bus or rider save failed")
		quit(1)
		return
	for i in range(4): await physics_frame
	if not game.transit.riding or game.player.position.distance_to(game.transit.bus.to_global(Vector3(.65,.4,-.4)))>0.01:
		push_error("Packaged rider detached during restore")
		quit(1)
		return
	game.panels.show_page("city")
	if not game.panels.view.buttons.has("city-waterfront"):
		push_error("Packaged city navigation missing")
		quit(1)
		return
	game.panels.show_page("")
	game.transit.detach()
	if game.driving.cars.size()!=5 or not game.driving.valid(game.driving.snapshot()):
		push_error("Packaged drivable cars or traffic state missing")
		quit(1)
		return
	var car: CityCar=game.driving.car_for("car_office")
	game.player.position=car.to_global(Vector3(-1.6,0,0))
	for i in range(3): await physics_frame
	if not game.driving.enter(car):
		push_error("Packaged vehicle entry failed")
		quit(1)
		return
	root.set_disable_input(false)
	var throttle := InputEventKey.new()
	throttle.keycode=KEY_W
	throttle.physical_keycode=KEY_W
	throttle.pressed=true
	root.push_input(throttle,true)
	for i in range(100): await physics_frame
	root.set_disable_input(true)
	var driving_save := SaveGame.snapshot(game)
	if car.speed<5 or not SaveGame.restore(game,driving_save):
		push_error("Packaged real driving input or save restore failed")
		quit(1)
		return
	for i in range(4): await physics_frame
	if game.driving.active!=car or game.player.position.distance_to(car.to_global(CityCar.SEAT))>.01 or not game.driving.suspended:
		push_error("Packaged driver restore or input suspension failed")
		quit(1)
		return
	game.driving.detach()
	game.toggle_menu()
	if DisplayServer.get_name()!="headless":
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--screenshot="):
				var error := root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
				if error!=OK: quit(1); return
	print("PACKAGED_SMOKE_OK build=",build.build_id," label=",BuildInfo.label()," npcs=",game.npcs.size()," props=",game.props.size()," company_spaces=2 company_sources=2 environment_props=6 asset_sources=5 authored_clips=2 authored_characters=14 texture_imports=verified ui_mouse=verified city_stops=4 bus_ride_save=verified driving_save=verified traffic=3 persistence=",game.persistence_enabled)
	paused=false
	game.queue_free()
	await process_frame
	quit()

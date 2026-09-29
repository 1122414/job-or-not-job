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
	for excluded in ["res://tests/world_test.gd", "res://tools/package_macos.py", "res://tools/company_sources/company_a.tscn", "res://tools/company_sources/company_b.tscn", "res://docs/progress.md", "res://build/p0-source-identity.json", "res://production/quaternius/standard-2025-06-10/glTF/AnimationLibrary_Godot_Standard.gltf", "res://production/environment/polyhaven_nature/tree_small_02/tree_small_02_2k.gltf", "res://production/environment/polyhaven_nature/tree_small_02/tree_small_02.bin"]:
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
	var streets: CityStreetscape=game.get_node_or_null("ConnectedDistrict/Streetscape")
	if streets==null or streets.find_children("*","MultiMeshInstance3D",true,false).is_empty() or not streets.materials.paving is ShaderMaterial or not streets.materials.grass is StandardMaterial3D:
		push_error("Packaged streetscape or ground materials missing")
		quit(1)
		return
	if streets.trees.size()!=23 or streets.materials.grass.uv1_scale!=Vector3(.5,.5,.5):
		push_error("Packaged tree placement or metre-scaled grass missing"); quit(1); return
	var nature_path := OS.get_executable_path().get_base_dir().path_join("../Resources/NATURE-SOURCES.json")
	if FileAccess.get_file_as_string(nature_path)!=FileAccess.get_file_as_string(CityTree.ROOT+"provenance.json"):
		push_error("Packaged nature provenance differs from runtime record"); quit(1); return
	for tree in streets.trees:
		if tree.lods.size()!=3 or tree.position.y!=0:
			push_error("Packaged tree detail levels or ground anchor missing"); quit(1); return
	var nature_materials: Array=[streets.materials.grass]
	for surface in range(3): nature_materials.append(streets.trees[0].lods[0].mesh.surface_get_material(surface))
	for material in nature_materials:
		for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
			if texture==null or not texture.get_image().is_compressed() or not texture.get_image().has_mipmaps():
				push_error("Packaged nature texture compression or mipmaps missing"); quit(1); return
	if nature_materials[2].transparency!=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		push_error("Packaged foliage depth cutout missing"); quit(1); return
	print("PACKAGED_NATURE trees=23 levels=3 source_excluded=true texture_imports=verified provenance=matched")
	streets.daylight(0)
	for lamp in streets.lamps:
		if lamp.light_energy<=0:
			push_error("Packaged street lighting does not illuminate at night")
			quit(1)
			return
	game.update_daylight()
	print("PACKAGED_STREETSCAPE pieces=",streets.get_meta("pieces")," batches=",streets.get_meta("batches")," lights=",streets.lamps.size())
	var sea := game.get_node_or_null("ConnectedDistrict/CoastalWater") as MeshInstance3D
	if streets.get_meta("arcade_lots",0)!=3 or streets.get_meta("background_lots",0)!=29 or sea==null or sea.material_override!=streets.water or streets.water.shader==null:
		push_error("Packaged urban galleries or coastal water missing")
		quit(1)
		return
	for ends in [[Vector3(-8,0,42),Vector3(-28,0,42)],[Vector3(8,0,42),Vector3(28,0,42)],[Vector3(-6,0,85),Vector3(-26,0,85)]]:
		if not game.walking.clear_segment(ends[0],ends[1]):
			push_error("Packaged public gallery is obstructed")
			quit(1)
			return
	if game.commons.benches.size()!=6 or SaveGame.VERSION!=18:
		push_error("Packaged public commons missing"); quit(1); return
	var commons_original := SaveGame.snapshot(game)
	game.set_process(false)
	var neighbour: CityResident=game.population.residents[0]
	neighbour.plan(game.commons.reserve(neighbour,"commons_west_0"))
	for i in range(12000):
		await physics_frame
		if game.commons.sitting(neighbour): break
	if not game.commons.sitting(neighbour) or not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))):
		push_error("Packaged resident cannot naturally use and restore a bench"); quit(1); return
	print("PACKAGED_COMMONS benches=6 schema=18 natural_seating=true json_restore=true")
	if not SaveGame.restore(game,commons_original): quit(1); return
	game.set_process(true)
	var urban_original := SaveGame.snapshot(game)
	var urban_old := JSON.parse_string(JSON.stringify(urban_original)) as Dictionary
	urban_old.player.position=[-18,0,32]
	if not SaveGame.restore(game,urban_old):
		push_error("Packaged urban old-position fixture rejected"); quit(1); return
	for i in range(10): await physics_frame
	if game.player.position.y<-.05 or game.player.position.distance_to(Vector3(-18,0,32))>3.5 or not game.player.is_on_floor():
		push_error("Packaged urban local ground recovery failed"); quit(1); return
	if not SaveGame.restore(game,urban_original):
		push_error("Packaged urban fixture cleanup failed"); quit(1); return
	for i in range(8): await physics_frame
	print("PACKAGED_URBAN galleries=3 scenery_only=29 coastal_shader=true local_ground_restore=true")
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
	if humans.size()!=28:
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
		var batch_report: Dictionary=space.get_meta("static_batch_report",{})
		var actual_batches := 0
		var actual_triangles := 0
		for mesh in space.find_children("*","MeshInstance3D",true,false):
			if mesh.has_meta("source_paths"):
				actual_batches+=1
				actual_triangles+=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
		if actual_batches<=0 or actual_batches!=batch_report.get("batches",-1) or actual_triangles!=batch_report.get("source_triangles",-1):
			push_error("Packaged company static batches are missing or incomplete")
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
	if game.population.residents.size()!=12 or not game.population.valid(JSON.parse_string(JSON.stringify(game.population.snapshot()))):
		push_error("Packaged public residents or crossing state missing")
		quit(1)
		return
	var resident: CityResident=game.population.residents[0]
	var resident_position := resident.position
	for i in range(180): await physics_frame
	var population_save: Variant=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
	if resident.position.distance_to(resident_position)<.5 or not SaveGame.restore(game,population_save):
		push_error("Packaged resident movement or JSON restore failed")
		quit(1)
		return
	var life: CityLife=game.city_life
	if life.points.size()!=5 or CityBookshop.IMAGES.size()!=3 or CityBookshop.IMAGES[0].get_width()!=800 or not life.valid(life.snapshot()) or not life.walk.valid(life.walk.snapshot(),life.snapshot(),game.payroll.minute):
		push_error("Packaged bookshop activity or original illustrations missing")
		quit(1)
		return
	var walk: CityStoryWalk=life.walk
	var before_walk := SaveGame.snapshot(game)
	life.method="paper"; life.prepared=true; life.joined=true; life.elapsed=18; life.result="paper"
	life.participants.assign(["resident_zhou_ning","resident_lin_qiao"])
	if not walk.start(CityStoryWalk.GUIDES[1]): push_error("Packaged story invitation failed"); quit(1); return
	walk.stage=5; walk.meeting=false; walk.ready_day=1
	walk.notes.assign(["daily","named","album"])
	walk.authors.assign([walk.partner,walk.partner,walk.partner])
	game.payroll.advance(1980-game.payroll.minute,game.career.employer)
	if not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) or not walk.album.visible or walk.board.visible:
		push_error("Packaged story outcome or v17 JSON restore failed"); quit(1); return
	print("PACKAGED_STORY_WALK schema=17 physical_album=true notes=",walk.notes)
	if not SaveGame.restore(game,before_walk): push_error("Packaged story probe cleanup failed"); quit(1); return
	game.player.position=Vector3(-52,0,35)
	game.player.yaw=0
	game.set_process(false)
	for i in range(3): await physics_frame
	Input.action_press("forward")
	for i in range(35): await physics_frame
	Input.action_release("forward")
	if game.player.position.z>33.5:
		push_error("Packaged bookshop interior is not walkable")
		quit(1)
		return
	game.player.position=Vector3(-49.2,0,29.7)
	life.open_point(life.point_for("notice"))
	life.answer(life.point_for("notice"),"city_plan_screen")
	life.open_point(life.point_for("screen"))
	life.answer(life.point_for("screen"),"city_check")
	life.answer(life.point_for("screen"),"city_prepare")
	if not life.prepared or not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))) or not life.room.projection.visible:
		push_error("Packaged activity scene preparation or JSON restore failed")
		quit(1)
		return
	var patient: CityResident=game.population.residents[0]
	patient.position=Vector3(16,0,68)
	patient.hp=0; patient.state="dead"; patient.route.clear(); patient.crossing=""
	game.player.position=Vector3(-18,0,18)
	if not game.response.report(patient,"player"):
		push_error("Packaged public response report failed"); quit(1); return
	for i in range(1200):
		await physics_frame
		if game.response.resting(patient): break
	if not game.response.resting(patient) or patient.hp!=0 or not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))):
		var failed := SaveGame.snapshot(game)
		print("PACKAGED_RESPONSE_DIAG resting=",game.response.resting(patient)," hp=",patient.hp," commons_valid=",game.commons.valid(failed.city_commons,failed)," case=",game.response.cases.get(patient.stable_id)," visit=",game.commons.visits.get(patient.stable_id))
		push_error("Packaged actual crew transfer or persistence failed"); quit(1); return
	game.toggle_menu()
	if DisplayServer.get_name()!="headless":
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--screenshot="):
				var error := root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
				if error!=OK: quit(1); return
	print("PACKAGED_SMOKE_OK build=",build.build_id," label=",BuildInfo.label()," npcs=",game.npcs.size()," props=",game.props.size()," company_spaces=2 company_sources=2 environment_props=6 asset_sources=5 authored_clips=2 authored_characters=28 texture_imports=verified ui_mouse=verified city_stops=4 bus_ride_save=verified driving_save=verified traffic=3 public_residents=12 population_save=verified bookshop_walk_save=verified original_illustrations=3 public_response_transfer_save=verified persistence=",game.persistence_enabled)
	paused=false
	game.queue_free()
	await process_frame
	quit()

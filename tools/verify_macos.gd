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
	var audio_sources := OS.get_executable_path().get_base_dir().path_join("../Resources/AUDIO-SOURCES.json")
	if FileAccess.get_file_as_string(audio_sources)!=FileAccess.get_file_as_string("res://assets/audio/city/provenance.json") or ResourceLoader.exists("res://production/audio/cc0-2026-09-30/engine.wav") or FileAccess.file_exists("res://production/audio/cc0-2026-09-30/shop.zip"):
		push_error("Packaged audio provenance mismatch or originals leaked"); quit(1); return
	if game.soundscape.clips.size()!=12 or game.soundscape.step_players.size()!=12 or game.soundscape.engines.size()!=6 or game.soundscape.persistence or game.soundscape.enabled:
		push_error("Packaged spatial audio or background isolation missing"); quit(1); return
	for bus in CitySoundscape.DEFAULTS:
		if AudioServer.get_bus_index(bus)<0:
			push_error("Packaged audio bus missing "+bus); quit(1); return
	for clip in game.soundscape.clips.values():
		if clip.get_length()<.1:
			push_error("Packaged audio stream invalid"); quit(1); return
	print("PACKAGED_AUDIO clips=12 buses=4 pool=12 vehicles=6 sources=true originals_excluded=true silent_background=true")
	if game.persistence_enabled or game.npcs.size()!=10 or game.props.size()!=114:
		push_error("Package scene or persistence isolation changed")
		quit(1)
		return
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE or game.player.capture_permitted():
		push_error("Automated package probe must not capture the desktop pointer")
		quit(1)
		return
	var streets: CityStreetscape=game.get_node_or_null("ConnectedDistrict/Streetscape")
	if streets==null:
		push_error("Packaged streetscape missing");quit(1);return
	var architecture_sources := OS.get_executable_path().get_base_dir().path_join("../Resources/ARCHITECTURE-SOURCES.json")
	if FileAccess.get_file_as_string(architecture_sources)!=FileAccess.get_file_as_string(CityArchitecture.ROOT+"provenance.json"):
		push_error("Packaged architecture provenance mismatch");quit(1);return
	for extension in ["_2k.gltf",".bin"]:
		var original: String="res://production/environment/polyhaven_architecture/modular_urban_apartments_facade/modular_urban_apartments_facade"+extension
		if FileAccess.file_exists(original) or ResourceLoader.exists(original):push_error("Original architecture library leaked into package");quit(1);return
	var architecture_bays := 0
	for lot in CityUrbanFabric.LOTS:
		var facade := streets.get_node_or_null("Architecture_"+lot.id)
		if facade==null:push_error("Packaged architecture missing");quit(1);return
		architecture_bays+=int(facade.get_meta("window_bays"))
		if not game.walking.clear_segment(lot.at+Vector3(-10,0,7),lot.at+Vector3(10,0,7)):push_error("Architecture blocks gallery");quit(1);return
	for variant in CityArchitecture.MODULES:
		var module: ArrayMesh=load(CityArchitecture.ROOT+variant+".res")
		for surface in range(module.get_surface_count()):
			var material: StandardMaterial3D=module.surface_get_material(surface)
			for texture in [material.albedo_texture,material.normal_texture,material.ao_texture]:
				if not texture.get_image().is_compressed() or not texture.get_image().has_mipmaps():push_error("Architecture texture import missing");quit(1);return
	print("PACKAGED_ARCHITECTURE lots=3 window_bays=",architecture_bays," source_excluded=true compressed_mipmaps=true routes=true")
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
	game.payroll.minute=1080; game.update_daylight()
	var dusk_color: Color=game.environment.sky.sky_material.sky_horizon_color
	game.payroll.minute=1230; game.update_daylight()
	var garden_lit := false
	for lamp in streets.lamps:
		if lamp.light_energy>.5 and lamp.global_position.distance_to(Vector3(40.8,1.6,54))<lamp.omni_range*.85: garden_lit=true
	if not garden_lit or game.environment.sky.sky_material.sky_horizon_color==dusk_color or game.environment.tonemap_mode!=Environment.TONE_MAPPER_ACES or build.renderer!="forward_plus":
		push_error("Packaged district lighting or target renderer missing"); quit(1); return
	game.payroll.minute=540; game.update_daylight()
	print("PACKAGED_DAYLIGHT garden_lit=true twilight_distinct=true tonemap=ACES configured_renderer=",build.renderer," actual_renderer=",RenderingServer.get_current_rendering_method())
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
	if game.commons.benches.size()!=6 or SaveGame.VERSION!=21:
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
	print("PACKAGED_COMMONS benches=6 schema=",SaveGame.VERSION," natural_seating=true json_restore=true")
	if not SaveGame.restore(game,commons_original): quit(1); return
	game.payroll.minute=780
	game.social.outing={"person":"a_friend","kind":"lunch","stage":"walking","elapsed":0.0}
	game.advance_time(game.rest_time("rest_morning")-game.payroll.minute)
	if game.payroll.minute!=1980 or game.social.outing.get("stage")!="paused" or not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))):
		push_error("Packaged next morning or paused private plan failed"); quit(1); return
	print("PACKAGED_DAY_CYCLE morning=1980 private_plan=paused json_restore=true")
	if not SaveGame.restore(game,commons_original): quit(1); return
	if not await verify_city_evening(game): quit(1); return
	if not await verify_city_outing(game): quit(1); return
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
	if life.room.furnishings==null or life.room.announcement.double_sided or life.room.lamps.size()!=4:
		push_error("Packaged authored bookshop or single-sided window signage missing"); quit(1); return
	for x in [-55.9,-46.9]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x,1.9,40),Vector3(x,1.9,37),1)
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or absf(hit.position.z-38.5)>.2:
			push_error("Packaged window collision missing"); quit(1); return
		var panes: Array=hit.collider.find_children("*","MeshInstance3D",true,false)
		if panes.is_empty() or panes[0].material_override.transparency!=BaseMaterial3D.TRANSPARENCY_ALPHA:
			push_error("Packaged storefront is not transparent"); quit(1); return
	for link in CityPopulation.LINKS:
		if not game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]):
			push_error("Packaged furnishings obstruct public activity route "+str(link)); quit(1); return
	var place_original := SaveGame.snapshot(game)
	var place_saved := JSON.parse_string(JSON.stringify(place_original)) as Dictionary
	var place_person: CityResident=game.population.residents[5]
	var person_data: Dictionary=place_saved.city_population.people[place_person.stable_id]
	var old_point: Vector3=life.room.to_global(Vector3(5.94,0,-2.5))
	person_data.position=SaveGame.vector(old_point)
	person_data.state="activity"; person_data.destination="reading_east"; person_data.from_node="reading_east"
	person_data.route=[]; person_data.crossing=""; person_data.activity_left=40; person_data.phase=game.population.time_phase()
	game.set_process(false)
	if not SaveGame.restore(game,place_saved):
		push_error("Packaged old resident position rejected"); quit(1); return
	for i in range(70): await physics_frame
	if not game.position_clear(place_person,place_person.position) or not place_person.is_on_floor() or place_person.position.y<-.05 or place_person.position.distance_to(old_point)>3.5 or place_person.hp!=person_data.hp or place_person.destination!=person_data.destination:
		push_error("Packaged resident is trapped by new furniture or lost state"); quit(1); return
	if not SaveGame.restore(game,place_original):
		push_error("Packaged place fixture cleanup failed"); quit(1); return
	game.set_process(true)
	print("PACKAGED_PLACES actual_glazing=2 public_routes=clear fixtures=batched lamps=4 signage=single_sided resident_old_position=restored")
	if life.points.size()!=5 or CityBookshop.IMAGES.size()!=3 or CityBookshop.IMAGES[0].get_width()!=800 or not life.valid(life.snapshot()) or not life.walk.valid(life.walk.snapshot(),life.snapshot(),game.payroll.minute):
		push_error("Packaged bookshop activity or original illustrations missing")
		quit(1)
		return
	var walk: CityStoryWalk=life.walk
	var before_walk := SaveGame.snapshot(game)
	if not await verify_city_share(game): quit(1); return
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

func verify_city_share(game: Node3D) -> bool:
	var original: Dictionary=SaveGame.snapshot(game)
	var life: CityLife=game.city_life
	life.method="paper"; life.prepared=true
	game.player.position=life.center()+Vector3(0,0,3)
	for i in range(3):
		var person: CityResident=game.population.residents[CityLife.AUDIENCE[i]]
		game.commons.release(person)
		person.position=CityPopulation.POINTS[CityLife.PAPER[i]]
		person.route.clear(); person.destination=CityLife.PAPER[i]; person.state="activity"; person.fear=0
	for i in range(85): await physics_frame
	if not life.performance.running() or life.performance.books.size()!=3:
		push_error("Packaged live bookshop performance missing"); return false
	for person in life.performance.attending():
		var book: CityStoryAlbum=life.performance.books[person.stable_id]
		if not book.visible or person.visual.current!="story_read" or book.right_page.texture.get_width()!=800:
			push_error("Packaged standing reading or original page texture missing"); return false
	var point: CityActivityPoint=life.point_for("paper")
	life.open_point(point); life.answer(point,"city_read"); life.answer(point,"city_page")
	for i in range(24): await physics_frame
	if not life.room.album.turning_page.visible:
		push_error("Packaged physical page turn missing"); return false
	for i in range(32): await physics_frame
	if life.room.album.page!=1 or life.reading_page!=1:
		push_error("Packaged reading text/page mismatch"); return false
	game.close_interaction()
	if not SaveGame.restore(game,original):
		push_error("Packaged performance fixture cleanup failed"); return false
	print("PACKAGED_SHARE real_books=3 standing_reading=true page_turn=true restored=true")
	return true

func verify_city_outing(game: Node3D) -> bool:
	var original := SaveGame.snapshot(game)
	game.set_process(false)
	game.payroll.minute=1110
	var npc: OfficeNPC=game.npc_for_role("b_friend")
	npc.position=Vector3(0,0,18); npc.route_clock=0
	game.player.position=Vector3(0,0,16)
	await physics_frame
	game.social.meet(npc)
	game.social.handle("people_city_go_garden",npc)
	if game.social.outing.get("venue")!="garden": push_error("Packaged public outing missing"); return false
	var path := PackedVector3Array()
	var start := npc.position
	for frame in range(9000):
		if npc.position.distance_to(CityOuting.VENUES.garden[1])<.7 and game.player.position.distance_to(npc.position)<2.8: break
		if frame%30==0: path=game.walking.route(game.player.position,npc.position,null,game.player)
		while not path.is_empty() and game.player.position.distance_to(path[0])<.15: path.remove_at(0)
		if game.player.position.distance_to(npc.position)>1.65 and not path.is_empty():
			var offset: Vector3=path[0]-game.player.position
			game.player.yaw=atan2(-offset.x,-offset.z); Input.action_press("forward")
		else: Input.action_release("forward")
		await physics_frame
	Input.action_release("forward")
	game.speaker=npc
	game.social.handle("people_share",npc)
	game.social.handle("people_boundary",npc)
	if not game.social.outing.is_empty() or not game.social.state(npc).get("city",{}).has("garden") or npc.position.distance_to(start)<40:
		push_error("Packaged outing failed: npc=%s player=%s route=%s outing=%s" % [npc.position,game.player.position,npc.route,game.social.outing]); return false
	if not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))):
		push_error("Packaged public outing JSON failed"); return false
	print("PACKAGED_OUTING actual_garden_walk=true distinct_memory=true schema=19 json_restore=true")
	return SaveGame.restore(game,original)

func verify_city_evening(game: Node3D) -> bool:
	var original := SaveGame.snapshot(game)
	game.set_process(false)
	game.payroll.minute=1140
	var crossed := false
	for frame in range(14000):
		await physics_frame
		var ready := true
		for id in CityEvening.PLANS:
			var npc: OfficeNPC=game.npc_for_role(id)
			crossed=crossed or CityFootRoutes.crossing_at(npc.position)=="office"
			if CityEvening.at_place(npc)=="": ready=false
		if ready: break
	for id in CityEvening.PLANS:
		if CityEvening.at_place(game.npc_for_role(id))=="":
			push_error("Packaged autonomous evening arrival failed: "+id); return false
	if not crossed or not SaveGame.restore(game,JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))):
		push_error("Packaged evening crossing or JSON restore failed"); return false
	var npc: OfficeNPC=game.npc_for_role("a_friend")
	game.player.position=npc.position+Vector3(0,0,1.7)
	game.player.yaw=0
	for i in range(8): await physics_frame
	game.interact()
	game.social.handle("people_evening_join",npc)
	game.social.handle("people_share",npc)
	game.social.handle("people_listen",npc)
	if not game.social.outing.is_empty() or not game.social.state(npc).get("city",{}).has("bookshop"):
		push_error("Packaged public encounter failed"); return false
	var legacy := original.duplicate(true)
	legacy.version=19; legacy.city_population.crossings.erase("office")
	if not SaveGame.restore(game,JSON.parse_string(JSON.stringify(legacy))):
		push_error("Packaged v19 crossing migration failed"); return false
	for kind in ["lunch","walk"]:
		var place: Vector3=game.social.destination(npc,kind)
		if place.z<17 or not game.walking.clear_segment(place,place+Vector3(0,0,.5)):
			push_error("Packaged legacy meeting point is not on the sidewalk"); return false
	print("PACKAGED_EVENING autonomous_arrivals=3 office_crossing=true actual_encounter=true json_restore=true legacy_v19=true legacy_meeting_spots=true schema=",SaveGame.VERSION)
	return SaveGame.restore(game,original)

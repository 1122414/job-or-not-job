extends "res://tools/profile_city_reflections.gd"

const Baker = preload("res://tools/city_lighting_bake.gd")

func prepare_scene(game: Node3D) -> void:
	# Parent attaches reflection probes. Use --mode=baseline so it does not bake
	# the whole live scene before this audited static-only candidate.
	await super.prepare_scene(game)
	if not str(game.get_meta("candidate_mode")).begins_with("baseline"):
		push_error("Static bake candidate requires --mode=baseline"); quit(1); return
	var subdivision := VoxelGI.SUBDIV_256
	var baked_source := ""
	var identity := ""
	for argument in OS.get_cmdline_user_args():
		if argument=="--subdiv=128": subdivision=VoxelGI.SUBDIV_128
		if argument.begins_with("--load-baked="): baked_source=argument.trim_prefix("--load-baked=")
		if argument.begins_with("--identity="): identity=argument.trim_prefix("--identity=")
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(identity))
	var recorded := {}
	if not baked_source.is_empty():
		var record_path := baked_source.path_join("bake-provenance.json")
		if not FileAccess.file_exists(record_path):
			push_error("Missing baked resource provenance"); quit(1); return
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if not parsed is Dictionary or parsed.get("source_sha256")!=provenance.source_sha256 or parsed.get("engine_hash")!=Engine.get_version_info().hash or parsed.get("baker_sha256")!=FileAccess.get_sha256("res://tools/city_lighting_bake.gd"):
			push_error("Baked resources do not match source/engine"); quit(1); return
		recorded=parsed
		subdivision=int(recorded.subdivision)
	var baker := Baker.new()
	var source := baker.make_source(game)
	if baker.failed:
		push_error("Static source extraction failed; refusing to bake"); quit(1); return
	for geometry in game.find_children("*","GeometryInstance3D",true,false): geometry.layers&=~CAPTURE_LAYER
	for path in baker.audit.sources: game.get_node(path).layers|=CAPTURE_LAYER
	var directory := output.path_join("baked")
	DirAccess.make_dir_recursive_absolute(directory)
	var resources := {}
	for room in Baker.ROOMS:
		var probe := VoxelGI.new()
		probe.name="Baked-"+room[0]
		probe.position=room[2]
		probe.size=room[3]
		probe.subdiv=subdivision
		game.add_child(probe)
		await process_frame
		var path := directory.path_join(room[0]+".res")
		if baked_source.is_empty():
			probe.bake(source)
		else:
			path=baked_source.path_join("baked").path_join(room[0]+".res")
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=recorded.get("resources",{}).get(room[0],""):
				push_error("Baked resource checksum mismatch: "+room[0]); quit(1); return
			probe.data=ResourceLoader.load(path,"VoxelGIData",ResourceLoader.CACHE_MODE_IGNORE)
		if probe.data==null:
			push_error("Static room bake failed"); quit(1); return
		if baked_source.is_empty() and ResourceSaver.save(probe.data,path,ResourceSaver.FLAG_COMPRESS)!=OK:
			push_error("Cannot save baked light: "+path); quit(1); return
		resources[room[0]]=FileAccess.get_sha256(path)
		print("STATIC_ROOM_", "BAKED " if baked_source.is_empty() else "LOADED ",room[0])
	source.free()
	FileAccess.open(output.path_join("bake-inputs.json"),FileAccess.WRITE).store_string(JSON.stringify(baker.audit,"\t")+"\n")
	var record := {"source_sha256":provenance.source_sha256,"engine_hash":Engine.get_version_info().hash,"subdivision":subdivision,"resources":resources,"baker_sha256":FileAccess.get_sha256("res://tools/city_lighting_bake.gd"),"loaded_from":baked_source}
	FileAccess.open(output.path_join("bake-provenance.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	game.set_meta("candidate_mode","static-baked-"+("reflections-" if not reflection_probes.is_empty() else "")+("memory" if baked_source.is_empty() else "loaded"))
	game.set_meta("static_gi_instances",baker.audit.mesh_instances)

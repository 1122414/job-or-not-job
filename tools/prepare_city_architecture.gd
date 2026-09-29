extends SceneTree

const SOURCE := "res://production/environment/polyhaven_architecture"
const OUTPUT := "res://assets/city_architecture"
const ASSET := "modular_urban_apartments_facade"
const WINDOWS := ["centered_large_02","centered_double_02","centered_small_03"]

func _initialize() -> void: call_deferred("run")

func material_for(name: String) -> StandardMaterial3D:
	var kind := name.trim_prefix(ASSET+"_")
	var atlas := "objects" if kind=="glass" else kind
	var prefix := OUTPUT.path_join("textures").path_join(ASSET+"_"+atlas)
	var material := StandardMaterial3D.new()
	material.resource_name=kind
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.albedo_texture=load(prefix+("_rgba_2k.png" if kind=="glass" else "_diff_2k.jpg"))
	material.normal_enabled=true
	material.normal_texture=load(prefix+"_nor_gl_2k.jpg")
	material.ao_enabled=true
	material.ao_texture=load(prefix+"_arm_2k.jpg")
	material.roughness_texture=material.ao_texture
	material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.metallic_texture=material.ao_texture
	material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	material.metallic=1 if kind in ["objects","glass"] else 0
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.vertex_color_use_as_albedo=kind=="plaster"
	if kind=="glass":
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.disable_receive_shadows=true
	return material

func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE.path_join("provenance.json")))
	for asset in provenance.assets:
		for relative in asset.files:
			if FileAccess.get_sha256(SOURCE.path_join(asset.id).path_join(relative))!=asset.files[relative].sha256:
				push_error("Architecture source differs: "+relative);quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("textures"))
	if "--textures" in OS.get_cmdline_user_args():
		for file in DirAccess.get_files_at(SOURCE.path_join(ASSET+"/textures")):
			if not file.ends_with(".jpg") or "_trim_02_" in file:continue
			if DirAccess.copy_absolute(SOURCE.path_join(ASSET+"/textures").path_join(file),OUTPUT.path_join("textures").path_join(file))!=OK:quit(1);return
		# Preserve the source opacity: glTF BLEND alone cannot add alpha to JPEG.
		var original := SOURCE.path_join(ASSET+"/textures/"+ASSET+"_objects_")
		var rgb := Image.load_from_file(original+"diff_2k.jpg")
		var alpha := Image.load_from_file(original+"alpha_2k.png")
		rgb.convert(Image.FORMAT_RGBA8);alpha.convert(Image.FORMAT_L8)
		if rgb.get_size()!=alpha.get_size():push_error("Architecture opacity size mismatch");quit(1);return
		var pixels := rgb.get_data()
		var opacity := alpha.get_data()
		for i in range(opacity.size()):pixels[i*4+3]=opacity[i]
		rgb=Image.create_from_data(rgb.get_width(),rgb.get_height(),false,Image.FORMAT_RGBA8,pixels)
		if rgb.save_png(OUTPUT.path_join("textures/"+ASSET+"_objects_rgba_2k.png"))!=OK:quit(1);return
		for file in DirAccess.get_files_at(OUTPUT.path_join("textures")):
			if not file.ends_with(".jpg") and not file.ends_with(".png"):continue
			var path := OUTPUT.path_join("textures").path_join(file)
			var config := ConfigFile.new()
			if FileAccess.file_exists(path+".import") and config.load(path+".import")!=OK:quit(1);return
			config.set_value("remap","importer","texture");config.set_value("remap","type","CompressedTexture2D")
			config.set_value("deps","source_file",path)
			config.set_value("params","compress/mode",2);config.set_value("params","mipmaps/generate",true)
			if config.save(path+".import")!=OK:quit(1);return
		print("ARCHITECTURE_TEXTURES_PREPARED source_alpha=true");quit();return
	var materials := {}
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE.path_join(ASSET+"/"+ASSET+"_2k.gltf")))
	for source in raw.materials:
		if not source.name.ends_with("_trim_02"):materials[source.name]=material_for(source.name)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(SOURCE.path_join(ASSET+"/"+ASSET+"_2k.gltf"),state)!=OK:quit(1);return
	var records := {}
	var files := {}
	for variant in WINDOWS:
		var module := ImporterMesh.new()
		for prefix in ["wall_window_","window_"]:
			var index := -1
			for node in raw.nodes:
				if node.get("name")==prefix+variant:index=int(node.mesh)
			if index<0:push_error("Missing architecture part: "+variant);quit(1);return
			var mesh: ImporterMesh=state.get_meshes()[index].mesh
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.get_surface_arrays(surface)
				var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				# All reviewed straight parts share a 3m bay, local x=-3..0 and
				# y=0 floor datum. Ignore the library's exploded display offsets.
				for i in range(positions.size()):positions[i].x+=1.5
				arrays[Mesh.ARRAY_VERTEX]=positions
				var material_index: int=raw.meshes[index].primitives[surface].material
				module.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},materials[raw.materials[material_index].name])
		module.generate_lods(60,25,[])
		var runtime := module.get_mesh()
		var relative: String=variant+".res"
		if ResourceSaver.save(runtime,OUTPUT.path_join(relative),ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
		files[relative]=FileAccess.get_sha256(OUTPUT.path_join(relative))
		var surfaces := []
		for surface in range(module.get_surface_count()):
			var levels := []
			for level in range(module.get_surface_lod_count(surface)):
				levels.append({"error":module.get_surface_lod_size(surface,level),"triangles":module.get_surface_lod_indices(surface,level).size()/3})
			surfaces.append({"material":module.get_surface_material(surface).resource_name,"triangles":module.get_surface_arrays(surface)[Mesh.ARRAY_INDEX].size()/3,"lods":levels})
		records[variant]={"source_parts":["wall_window_"+variant,"window_"+variant],"surfaces":surfaces,"aabb":var_to_str(runtime.get_aabb())}
	for file in DirAccess.get_files_at(OUTPUT.path_join("textures")):
		if file.ends_with(".jpg") or file.ends_with(".png"):files["textures/"+file]=FileAccess.get_sha256(OUTPUT.path_join("textures").path_join(file))
	var report := {"source_provenance":provenance,"processing":"prepare_city_architecture.gd --textures; Godot import; prepare_city_architecture.gd. Three straight 3m bays, x+1.5, source UV/normals/tangents retained, generated mesh LODs, original glass opacity.","metres_per_unit":1,"modules":records,"derived_files":files}
	FileAccess.open(OUTPUT.path_join("provenance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("ARCHITECTURE_MODULES_PREPARED ",JSON.stringify(records))
	quit()

extends SceneTree

const SOURCE := "res://production/environment/polyhaven_street"
const OUTPUT := "res://assets/city_street"
const IDS := ["rollershutter_door","plastic_crate_01","potted_plant_02","industrial_wall_lamp"]

func _initialize() -> void:call_deferred("run")

func source_texture(raw: Dictionary,index: int) -> String:
	return raw.images[int(raw.textures[index].source)].uri

func output_texture(id: String,uri: String) -> String:
	var name := uri.get_file().get_basename()
	var suffix := "2k" if id=="rollershutter_door" else "1k"
	if name=="potted_plant_02_leaves_diff_2k" or name=="industrial_wall_lamp_glass_diff_2k":
		name=name.replace("_diff_2k","_rgba_"+suffix)
	else:name=name.replace("_2k","_"+suffix)
	return OUTPUT.path_join("textures").path_join(name+".png")

func selected_nodes(id: String,raw: Dictionary) -> Array:
	return raw.nodes.filter(func(node):return id!="rollershutter_door" or node.name==id)

func prepare_textures(id: String,raw: Dictionary) -> bool:
	var needed := {}
	for node in selected_nodes(id,raw):
		for primitive in raw.meshes[int(node.mesh)].primitives:
			var material: Dictionary=raw.materials[int(primitive.material)]
			for part in [material,material.get("pbrMetallicRoughness",{})]:
				for key in part:
					if part[key] is Dictionary and part[key].has("index") and key.ends_with("Texture"):
						needed[source_texture(raw,int(part[key].index))]=true
	for uri in needed:
		var picture := Image.load_from_file(SOURCE.path_join(id).path_join(uri))
		if picture==null or picture.is_empty():return false
		var alpha_name := ""
		if uri.ends_with("potted_plant_02_leaves_diff_2k.jpg"):alpha_name="potted_plant_02_leaves_alpha_2k.png"
		if uri.ends_with("industrial_wall_lamp_glass_diff_2k.jpg"):alpha_name="industrial_wall_lamp_glass_alpha_2k.png"
		if alpha_name!="":
			var alpha := Image.load_from_file(SOURCE.path_join(id).path_join("textures").path_join(alpha_name))
			if alpha.get_size()!=picture.get_size():return false
			picture.convert(Image.FORMAT_RGBA8);alpha.convert(Image.FORMAT_L8)
			var pixels := picture.get_data()
			var opacity := alpha.get_data()
			for i in range(opacity.size()):pixels[i*4+3]=opacity[i]
			picture=Image.create_from_data(picture.get_width(),picture.get_height(),false,Image.FORMAT_RGBA8,pixels)
		if id!="rollershutter_door":picture.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
		var path := output_texture(id,uri)
		if picture.save_png(path)!=OK:return false
		var config := ConfigFile.new()
		if FileAccess.file_exists(path+".import") and config.load(path+".import")!=OK:return false
		config.set_value("remap","importer","texture");config.set_value("remap","type","CompressedTexture2D")
		config.set_value("deps","source_file",path)
		config.set_value("params","compress/mode",2);config.set_value("params","mipmaps/generate",true)
		if config.save(path+".import")!=OK:return false
	return true

func material_for(id: String,raw: Dictionary,data: Dictionary) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name=data.name
	result.cull_mode=BaseMaterial3D.CULL_DISABLED if data.get("doubleSided",false) else BaseMaterial3D.CULL_BACK
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var pbr: Dictionary=data.pbrMetallicRoughness
	result.albedo_texture=load(output_texture(id,source_texture(raw,int(pbr.baseColorTexture.index))))
	result.normal_enabled=true
	result.normal_texture=load(output_texture(id,source_texture(raw,int(data.normalTexture.index))))
	result.roughness_texture=load(output_texture(id,source_texture(raw,int(pbr.metallicRoughnessTexture.index))))
	result.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	result.metallic=float(pbr.get("metallicFactor",1.0))
	result.metallic_texture=result.roughness_texture
	result.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	if "_arm_" in source_texture(raw,int(pbr.metallicRoughnessTexture.index)):
		result.ao_enabled=true;result.ao_texture=result.roughness_texture
	if data.get("alphaMode","")=="MASK":
		result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.alpha_scissor_threshold=float(data.get("alphaCutoff",.5))
	elif data.get("alphaMode","")=="BLEND":result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	if data.has("emissiveTexture"):
		result.emission_enabled=true;result.emission=Color("ffdeb2")
		result.emission_texture=load(output_texture(id,source_texture(raw,int(data.emissiveTexture.index))))
		# The source uses 100x emission for an isolated render. The district's
		# daylight owner controls this surface together with its other fixtures.
		result.emission_energy_multiplier=0
	return result

func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE.path_join("provenance.json")))
	for asset in provenance.assets:
		for relative in asset.files:
			if FileAccess.get_sha256(SOURCE.path_join(asset.id).path_join(relative))!=asset.files[relative].sha256:
				push_error("Street source changed: "+relative);quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("textures"))
	var records := {}
	var derived := {}
	for id in IDS:
		var path := SOURCE.path_join(id).path_join(id+"_2k.gltf")
		var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		if "--textures" in OS.get_cmdline_user_args():
			if not prepare_textures(id,raw):push_error("Street texture preparation failed: "+id);quit(1);return
			continue
		var state := GLTFState.new()
		if GLTFDocument.new().append_from_file(path,state)!=OK:quit(1);return
		var materials := {}
		var result := ImporterMesh.new()
		var parts := []
		for node in selected_nodes(id,raw):
			# This reviewed source set contains independent, untranslated axes.
			# Preserve the plant's three authored part translations; library door
			# variants are selected by node name, not their display offset.
			if node.has("rotation") or node.has("scale") or node.has("children"):
				push_error("Unreviewed street node transform: "+node.name);quit(1);return
			var offset := Vector3.ZERO
			if node.has("translation"):offset=Vector3(node.translation[0],node.translation[1],node.translation[2])
			var source: ImporterMesh=state.get_meshes()[int(node.mesh)].mesh
			source.generate_lods(60,25,[])
			for surface in range(source.get_surface_count()):
				var arrays := source.get_surface_arrays(surface)
				var original_triangles: int=arrays[Mesh.ARRAY_INDEX].size()/3
				# The perforated crate stops simplifying around 10K triangles with
				# its authored UV seams intact. Keep those holes; record the actual
				# result rather than pretending an unreachable 8K target was met.
				var budget := 12000 if id=="plastic_crate_01" else 800 if node.name.ends_with("_dirt") else 1800 if node.name.ends_with("_pot") else original_triangles
				if original_triangles>budget:
					for level in range(source.get_surface_lod_count(surface)):
						var indices := source.get_surface_lod_indices(surface,level)
						if indices.size()/3<=budget:
							arrays[Mesh.ARRAY_INDEX]=indices;break
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for i in range(vertices.size()):vertices[i]+=offset
				arrays[Mesh.ARRAY_VERTEX]=vertices
				var material_index: int=raw.meshes[int(node.mesh)].primitives[surface].material
				if not materials.has(material_index):materials[material_index]=material_for(id,raw,raw.materials[material_index])
				result.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},materials[material_index])
				parts.append({"node":node.name,"surface":surface,"source_triangles":original_triangles,"runtime_triangles":arrays[Mesh.ARRAY_INDEX].size()/3,"translation":SaveGame.vector(offset)})
		result.generate_lods(60,25,[])
		var mesh := result.get_mesh()
		var relative: String=id+".res"
		if ResourceSaver.save(mesh,OUTPUT.path_join(relative),ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
		derived[relative]=FileAccess.get_sha256(OUTPUT.path_join(relative))
		records[id]={"parts":parts,"aabb":var_to_str(mesh.get_aabb()),"surfaces":mesh.get_surface_count()}
	if "--textures" in OS.get_cmdline_user_args():print("STREET_TEXTURES_PREPARED");quit();return
	for file in DirAccess.get_files_at(OUTPUT.path_join("textures")):
		if file.ends_with(".png"):derived["textures/"+file]=FileAccess.get_sha256(OUTPUT.path_join("textures").path_join(file))
	var report := {"source_provenance":provenance,"metres_per_unit":1,"processing":"prepare_city_street.gd --textures; Godot import; prepare_city_street.gd. Selected plain shutter; authored plant offsets retained; source alpha merged; prop textures 1K, doorway 2K; crate/pot/soil reduced with source LODs; runtime LODs generated.","models":records,"derived_files":derived}
	FileAccess.open(OUTPUT.path_join("provenance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("STREET_MODELS_PREPARED ",JSON.stringify(records));quit()

extends SceneTree

var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/cast/provenance.json"))
	for person in manifest.characters:
		var path := "res://assets/characters/cast/"+str(person.id)+".glb"
		check(FileAccess.get_sha256(path)==person.sha256,"Cast checksum: "+person.id)
		var model: Node=load(path).instantiate()
		var textures := {}
		var memory := 0
		for node in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(node.mesh.get_surface_count()):
				var data := RenderingServer.mesh_get_surface(node.mesh.get_rid(),surface)
				check(not data.get("lods",[]).is_empty(),"Real LOD indices: "+person.id+"/"+str(node.name))
				var previous: int=data.index_count*(2 if data.vertex_count<65536 else 4)
				for lod in data.get("lods",[]):
					check(lod.index_data.size()>0 and lod.index_data.size()<previous,"LOD reduces indices")
					previous=lod.index_data.size()
				var material: StandardMaterial3D=node.mesh.surface_get_material(surface)
				if material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					check(material.alpha_antialiasing_mode==BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE,"Cutout edge coverage")
					check(material.alpha_antialiasing_edge<material.alpha_scissor_threshold,"Coverage edge precedes cutoff")
				for property in material.get_property_list():
					if not property.name.ends_with("_texture"): continue
					var texture: Variant=material.get(property.name)
					if not texture is Texture2D or textures.has(texture.resource_path): continue
					textures[texture.resource_path]=true
					var picture: Image=texture.get_image()
					check(picture.is_compressed() and picture.has_mipmaps(),"Real compressed mip chain: "+texture.resource_path)
					memory+=picture.get_data_size()
		check(memory<36*1024*1024,"Per-person texture budget 36 MiB: "+person.id)
		model.free()
	print("CAST_RESOURCES_TEST failures=",failures)
	quit(failures)

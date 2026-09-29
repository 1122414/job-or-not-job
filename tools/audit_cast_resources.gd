extends SceneTree

# Inspect the resources used by the imported scene, not only its importer settings.
func _initialize() -> void:
	var output := "res://build/cast-resources.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var report := {}
	for person in ["protagonist","lin_lan","a_cheng"]:
		var model: Node=load("res://assets/characters/cast/"+person+".glb").instantiate()
		var entry := {"meshes":[],"textures":{},"texture_bytes":0}
		for node in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(node.mesh.get_surface_count()):
				var data := RenderingServer.mesh_get_surface(node.mesh.get_rid(),surface)
				var lods := []
				for lod in data.get("lods",[]):
					# Godot uses 16-bit indices below 65536 vertices, otherwise 32-bit.
					lods.append({"error":lod.edge_length,"triangles":lod.index_data.size()/(6 if data.vertex_count<65536 else 12)})
				entry.meshes.append({"name":node.name,"triangles":data.index_count/3,"blend_shapes":node.mesh.get_blend_shape_count(),"lods":lods})
				var material: Material=node.mesh.surface_get_material(surface)
				for property in material.get_property_list():
					if not property.name.ends_with("_texture"): continue
					var texture: Variant=material.get(property.name)
					if not texture is Texture2D or entry.textures.has(texture.resource_path): continue
					var picture: Image=texture.get_image()
					entry.textures[texture.resource_path]={"width":picture.get_width(),"height":picture.get_height(),"format":picture.get_format(),"compressed":picture.is_compressed(),"mipmaps":picture.has_mipmaps(),"bytes":picture.get_data_size()}
					entry.texture_bytes+=picture.get_data_size()
		report[person]=entry
		print("CAST_RESOURCES ",person," texture_bytes=",entry.texture_bytes," surfaces=",entry.meshes.size())
		model.free()
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	quit()

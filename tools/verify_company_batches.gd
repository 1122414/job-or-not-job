extends SceneTree

var resource_cache := {}
var failures := 0

func _initialize() -> void: call_deferred("run")

func normalized(value: Variant) -> Variant:
	if value is Resource:
		if resource_cache.has(value.get_instance_id()): return resource_cache[value.get_instance_id()]
		var data := {"class":value.get_class()}
		if not value.resource_path.is_empty() and not "::" in value.resource_path:
			data.path=value.resource_path
		elif value is ImageTexture:
			data.image=hash(value.get_image().get_data())
		else:
			for property in value.get_property_list():
				if property.usage&PROPERTY_USAGE_STORAGE and not property.name in ["resource_name","resource_local_to_scene","script"]:
					data[property.name]=normalized(value.get(property.name))
		var signature := hash(data)
		resource_cache[value.get_instance_id()]=signature
		return signature
	return value

func point(value: Vector3) -> String:
	return str(Vector3i(roundi(value.x*100000),roundi(value.y*100000),roundi(value.z*100000)))

func inspect(company: Node3D) -> Dictionary:
	var result := {"triangles":{},"collision":{},"lights":{},"anchors":{},"interactive":{}}
	for node in company.find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		var local: Transform3D=company.global_transform.affine_inverse()*node.global_transform
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var material := str(normalized(node.get_active_material(surface)))+":"+str(node.cast_shadow)+":"+str(node.layers)
			for offset in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
				var positions: Array[String]=[]
				var attributes: Array=[]
				for corner in range(3):
					var id: int=indices[offset+corner] if not indices.is_empty() else offset+corner
					positions.append(point(local*vertices[id]))
					var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
					var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
					var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
					attributes.append([local.basis.inverse().transposed()*normals[id] if not normals.is_empty() else Vector3.ZERO,uv[id] if not uv.is_empty() else Vector2.ZERO,
						local.basis*Vector3(tangents[id*4],tangents[id*4+1],tangents[id*4+2]) if not tangents.is_empty() else Vector3.ZERO,tangents[id*4+3] if not tangents.is_empty() else 0.0])
				var first := positions.find(positions.min())
				var key := material+":"+positions[first]+positions[(first+1)%3]+positions[(first+2)%3]
				var ordered := [attributes[first],attributes[(first+1)%3],attributes[(first+2)%3]]
				if not result.triangles.has(key): result.triangles[key]=[]
				result.triangles[key].append(ordered)
	for node in company.find_children("*","CollisionShape3D",true,false):
		var key := str(company.get_path_to(node))
		result.collision[key]=[node.global_transform,normalized(node.shape),node.disabled,node.get_parent().collision_layer,node.get_parent().collision_mask]
	for node in company.find_children("*","Light3D",true,false):
		var props := {"transform":node.global_transform}
		for property in node.get_property_list():
			if property.usage&PROPERTY_USAGE_STORAGE and (String(property.name).begins_with("light_") or String(property.name).begins_with("shadow_") or String(property.name).begins_with("omni_") or String(property.name).begins_with("spot_")):
				props[property.name]=node.get(property.name)
		result.lights[String(company.get_path_to(node))]=props
	for name in ["Anchors","PropSpawns","PeopleSpawns"]:
		for node in company.get_node(name).get_children():
			var metadata := {}
			for key in node.get_meta_list(): metadata[key]=node.get_meta(key)
			result.anchors[name+"/"+String(node.name)]=[node.transform,metadata]
	for node in company.get_children():
		if String(node.name).begins_with("Interview"):
			result.interactive[String(node.name)]=[node.transform,node.visible,node.find_children("*","",true,false).size()]
	return result

func attributes_match(a: Array,b: Array) -> bool:
	for corner in range(3):
		for index in range(3):
			if a[corner][index].distance_to(b[corner][index])>0.001: return false
		if absf(a[corner][3]-b[corner][3])>0.001: return false
	return true

func run() -> void:
	var before := "res://tools/company_sources"
	var after := "res://scenes/companies"
	var output := "res://build/company-batch-equivalence.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--before="): before=argument.trim_prefix("--before=")
		if argument.begins_with("--after="): after=argument.trim_prefix("--after=")
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var report := {}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	for firm in ["a","b"]:
		var original: Node3D=load(before.path_join("company_"+firm+".tscn")).instantiate()
		var candidate: Node3D=load(after.path_join("company_"+firm+".tscn")).instantiate()
		root.add_child(original)
		root.add_child(candidate)
		var source := inspect(original)
		var baked := inspect(candidate)
		var missing := 0
		var mismatched := 0
		var total := 0
		for key in source.triangles:
			for triangle in source.triangles[key]:
				total+=1
				if not baked.triangles.has(key) or baked.triangles[key].is_empty(): missing+=1; continue
				var found := -1
				for i in range(baked.triangles[key].size()):
					if attributes_match(triangle,baked.triangles[key][i]): found=i; break
				if found<0: mismatched+=1
				else: baked.triangles[key].remove_at(found)
		var extra := 0
		for triangles in baked.triangles.values(): extra+=triangles.size()
		var entry := {"triangles":total,"missing_triangles_or_materials":missing,"extra_triangles":extra,"attribute_mismatches":mismatched,"batch_report":candidate.get_meta("static_batch_report",{})}
		for domain in ["collision","lights","anchors","interactive"]:
			entry[domain+"_equal"]=source[domain]==baked[domain]
			if not entry[domain+"_equal"]: failures+=1
		if missing+extra+mismatched>0: failures+=1
		report[firm]=entry
		print("COMPANY_EQUIVALENCE ",firm," ",entry)
		original.free()
		candidate.free()
	report.failures=failures
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("COMPANY_EQUIVALENCE_TEST failures=",failures)
	quit(failures)

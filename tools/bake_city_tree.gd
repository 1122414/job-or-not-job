extends SceneTree

const SOURCE := "res://production/environment/polyhaven_nature/tree_small_02/tree_small_02_2k.gltf"
var destination := "res://build/c4d-tree-production"
var comparison := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
		if arg.begins_with("--compare="): comparison=arg.trim_prefix("--compare=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	var mapping_path := "res://build/c4d-asset-review/leaf-components.bin"
	var mapping: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://build/c4d-asset-review/leaf-components.manifest.json"))
	if not mapping is Dictionary or not mapping.get("source_files") is Dictionary or mapping.get("mapping_sha256","")!=FileAccess.get_sha256(mapping_path):
		push_error("Source component map is missing or changed"); quit(1); return
	for relative in mapping.source_files:
		if FileAccess.get_sha256(SOURCE.get_base_dir().path_join(relative))!=mapping.source_files[relative]:
			push_error("Tree source no longer matches component map"); quit(1); return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(SOURCE,state)!=OK: quit(1); return
	var source: ImporterMesh=state.get_meshes()[0].mesh
	var arrays := source.get_surface_arrays(1)
	var file := FileAccess.open(mapping_path,FileAccess.READ)
	if file==null or file.get_buffer(8).get_string_from_ascii()!="TREEISL1": push_error("Missing leaf component mapping"); quit(1); return
	var vertex_count := file.get_32()
	var count := file.get_32()
	if vertex_count!=arrays[Mesh.ARRAY_VERTEX].size(): push_error("Source foliage vertex order changed"); quit(1); return
	var groups := []
	var group_for := PackedInt32Array()
	var local_for := PackedInt32Array()
	group_for.resize(vertex_count)
	local_for.resize(vertex_count)
	for i in range(count):
		var indices := file.get_buffer(file.get_32()*4).to_int32_array()
		groups.append({"vertices":indices,"indices":PackedInt32Array()})
		for j in range(indices.size()):
			group_for[indices[j]]=i
			local_for[indices[j]]=j
	var source_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in range(0,source_indices.size(),3):
		var group: Dictionary=groups[group_for[source_indices[i]]]
		for j in range(3): group.indices.append(local_for[source_indices[i+j]])
	var combined := [empty_arrays(),empty_arrays(),empty_arrays()]
	var counts := [0,0,0]
	var disconnected := []
	var topology_cost := {}
	var rejected_lods := 0
	for id in range(groups.size()):
		var group: Dictionary=groups[id]
		var local := select_vertices(arrays,group.vertices)
		local[Mesh.ARRAY_INDEX]=group.indices
		var leaf_sheet: bool=group.vertices.size() in [14,17,71,117,119,132,137,146]
		var island := ImporterMesh.new()
		if not leaf_sheet:
			island.add_surface(Mesh.PRIMITIVE_TRIANGLES,local)
			island.generate_lods(60,25,[])
		for level in range(3):
			var previous_count: int=counts[level]
			if leaf_sheet:
				var sheet := leaf_outline(local,[10,7,5][level],level==0)
				append_compact(combined[level],sheet,sheet[Mesh.ARRAY_INDEX])
				counts[level]+=sheet[Mesh.ARRAY_INDEX].size()/3
			else:
				var selected: PackedInt32Array=group.indices
				for lod in range(island.get_surface_lod_count(0)):
					var candidate := island.get_surface_lod_indices(0,lod)
					if candidate.size()>=6:
						if index_components(candidate)!=1:
							rejected_lods+=1
							continue
						selected=candidate
						if selected.size()/3<=[12,6,4][level]: break
				append_compact(combined[level],local,selected)
				counts[level]+=selected.size()/3
				var components := index_components(selected)
				if components!=1:
					disconnected.append({"id":id,"vertices":group.vertices.size(),"level":level,"components":components,"triangles":selected.size()/3})
			var topology: int=group.vertices.size()
			if not topology_cost.has(topology): topology_cost[topology]=[0,0,0]
			topology_cost[topology][level]+=counts[level]-previous_count
		if id%5000==0: print("FOLIAGE_BAKE islands=",id,"/",groups.size())
	print("FOLIAGE_TOPOLOGY_COST ",JSON.stringify(topology_cost))
	if not disconnected.is_empty():
		FileAccess.open(destination.path_join("disconnected.json"),FileAccess.WRITE).store_string(JSON.stringify(disconnected,"\t"))
		push_error("Simplification split %d foliage islands; see disconnected.json"%disconnected.size())
		quit(1)
		return
	# Branch and trunk are connected surfaces; normal automatic LOD works here.
	source.generate_lods(60,25,[])
	var report := {"source":SOURCE,"source_triangles":2062487,"preserved_islands":count,"topology_triangles":topology_cost,"rejected_disconnected_lods":rejected_lods,"levels":[]}
	for level in range(3):
		var mesh := ArrayMesh.new()
		var total := 0
		for surface in range(3):
			var reduced: Array
			if surface==1:
				reduced=combined[level]
			else:
				var full := source.get_surface_arrays(surface)
				var lod := level+2
				reduced=empty_arrays()
				append_compact(reduced,full,source.get_surface_lod_indices(surface,lod))
			for channel in range(Mesh.ARRAY_MAX):
				if reduced[channel]!=null and reduced[channel].size()==0: reduced[channel]=null
			reduced[Mesh.ARRAY_TANGENT]=null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,reduced)
			if mesh.get_surface_count()!=surface+1: push_error("Tree surface assembly failed"); quit(1); return
			total+=reduced[Mesh.ARRAY_INDEX].size()/3
		mesh.regen_normal_maps()
		var geometry_sha := mesh_digest(mesh)
		if not comparison.is_empty():
			var previous: ArrayMesh=load(comparison.path_join("tree_lod%d.res"%level))
			if previous==null or mesh_digest(previous)!=geometry_sha:
				push_error("Rebuilt mesh geometry differs at level "+str(level)); quit(1); return
		var path := destination.path_join("tree_lod%d.res"%level)
		if ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)!=OK: quit(1); return
		report.levels.append({"level":level,"triangles":total,"leaves":counts[level],"geometry_sha256":geometry_sha,"path":path})
	report.compared_geometry_with=comparison
	FileAccess.open(destination.path_join("bake.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("TREE_BAKED ",JSON.stringify(report))
	quit()

func mesh_digest(mesh: ArrayMesh) -> String:
	# Resource containers may differ while the complete geometry is identical.
	# Compare all actual vertex channels and indices separately from metadata.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):
		digest.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return digest.finish().hex_encode()

func index_components(indices: PackedInt32Array) -> int:
	var parents := {}
	for index in indices: parents[index]=index
	for i in range(0,indices.size(),3):
		var a := index_root(parents,indices[i])
		parents[index_root(parents,indices[i+1])]=a
		parents[index_root(parents,indices[i+2])]=a
	var roots := {}
	for index in parents: roots[index_root(parents,index)]=true
	return roots.size()

func index_root(parents: Dictionary,index: int) -> int:
	while parents[index]!=index:
		parents[index]=parents[parents[index]]
		index=parents[index]
	return index

func empty_arrays() -> Array:
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX]=PackedVector3Array()
	result[Mesh.ARRAY_NORMAL]=PackedVector3Array()
	result[Mesh.ARRAY_TEX_UV]=PackedVector2Array()
	result[Mesh.ARRAY_TEX_UV2]=PackedVector2Array()
	result[Mesh.ARRAY_TANGENT]=null
	result[Mesh.ARRAY_INDEX]=PackedInt32Array()
	return result

func select_vertices(source: Array,vertices: PackedInt32Array) -> Array:
	var output := empty_arrays()
	for vertex in vertices:
		for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if source[channel]!=null: output[channel].append(source[channel][vertex])
	return output

func append_compact(target: Array,source: Array,indices: PackedInt32Array) -> void:
	var mapping := {}
	for old in indices:
		if not mapping.has(old):
			mapping[old]=target[Mesh.ARRAY_VERTEX].size()
			for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
				if source[channel]!=null and source[channel].size()>0: target[channel].append(source[channel][old])
		target[Mesh.ARRAY_INDEX].append(mapping[old])

func leaf_outline(source: Array,budget: int,centered: bool) -> Array:
	# The reviewed source has eight curved cutout-sheet topologies and three
	# tubular petiole topologies. The 71-vertex sheet depicts a bare twig.
	# Keep every sheet in place and simplify its
	# UV outline; global LOD deletes the small disconnected sheets instead.
	var uv: PackedVector2Array=source[Mesh.ARRAY_TEX_UV]
	var order := range(uv.size())
	order.sort_custom(func(a: int,b: int) -> bool: return uv[a].x<uv[b].x or uv[a].x==uv[b].x and uv[a].y<uv[b].y)
	var lower: Array[int]=[]
	var upper: Array[int]=[]
	for id in order:
		while lower.size()>1 and (uv[lower[-1]]-uv[lower[-2]]).cross(uv[id]-uv[lower[-1]])<=0: lower.pop_back()
		lower.append(id)
	order.reverse()
	for id in order:
		while upper.size()>1 and (uv[upper[-1]]-uv[upper[-2]]).cross(uv[id]-uv[upper[-1]])<=0: upper.pop_back()
		upper.append(id)
	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	assert(lower.size()>=3,"Leaf UV outline is degenerate")
	while lower.size()>budget:
		var remove := 0
		var error := INF
		for i in range(lower.size()):
			var a: Vector3=source[Mesh.ARRAY_VERTEX][lower[posmod(i-1,lower.size())]]
			var b: Vector3=source[Mesh.ARRAY_VERTEX][lower[i]]
			var c: Vector3=source[Mesh.ARRAY_VERTEX][lower[(i+1)%lower.size()]]
			var loss := b.distance_squared_to(Geometry3D.get_closest_point_to_segment(b,a,c))
			if loss<error: error=loss; remove=i
		lower.remove_at(remove)
	var result := select_vertices(source,PackedInt32Array(lower))
	if not centered:
		# Distant leaves retain their outline; the near mesh also preserves the
		# curved center. UV-space convexity makes this fan non-overlapping.
		for i in range(1,lower.size()-1):
			result[Mesh.ARRAY_INDEX].append_array(PackedInt32Array([0,i,i+1]))
		return result
	var center := Vector3.ZERO
	var normal := Vector3.ZERO
	var center_uv := Vector2.ZERO
	var center_uv2 := Vector2.ZERO
	for i in range(lower.size()):
		center+=result[Mesh.ARRAY_VERTEX][i]
		normal+=result[Mesh.ARRAY_NORMAL][i]
		center_uv+=result[Mesh.ARRAY_TEX_UV][i]
		if result[Mesh.ARRAY_TEX_UV2].size()>0: center_uv2+=result[Mesh.ARRAY_TEX_UV2][i]
	result[Mesh.ARRAY_VERTEX].append(center/lower.size())
	result[Mesh.ARRAY_NORMAL].append(normal.normalized())
	result[Mesh.ARRAY_TEX_UV].append(center_uv/lower.size())
	if result[Mesh.ARRAY_TEX_UV2].size()>0: result[Mesh.ARRAY_TEX_UV2].append(center_uv2/lower.size())
	# Regenerated after assembly because the fan adds a new center vertex.
	result[Mesh.ARRAY_TANGENT]=null
	for i in range(lower.size()):
		result[Mesh.ARRAY_INDEX].append_array(PackedInt32Array([lower.size(),i,(i+1)%lower.size()]))
	return result

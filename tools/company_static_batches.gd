extends RefCounted

# Bake only the builder's static opaque decorations. Interactive interview props,
# imported scenes, transparency and object-space triplanar materials stay separate.
const GROUPS := ["Architecture","CeilingServices","StreetFacade","Lighting","WorkplaceDetails"]
const CELL_SIZE := 4.0

static func eligible(node: MeshInstance3D) -> bool:
	if not node.mesh is PrimitiveMesh or node.get_child_count()!=0 or not node.visible or node.get_script()!=null: return false
	if node.material_overlay!=null or node.mesh.get_surface_count()!=1: return false
	var material := node.get_active_material(0) as StandardMaterial3D
	if material==null or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass!=null: return false
	if material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED: return false
	if material.uv1_triplanar and not material.uv1_world_triplanar: return false
	return not (material.uv2_triplanar and not material.uv2_world_triplanar)

static func bake(company: Node3D) -> Dictionary:
	var report: Dictionary=company.get_meta("static_batch_report",{"source_meshes":0,"batches":0,"source_triangles":0,"batch_triangles":0,"cell_size":CELL_SIZE}).duplicate(true)
	for title in GROUPS:
		var group: Node3D=company.get_node(title)
		var buckets := {}
		for node in group.find_children("*","MeshInstance3D",true,false):
			if not eligible(node): continue
			var local: Transform3D=group.global_transform.affine_inverse()*node.global_transform
			var center: Vector3=local*node.mesh.get_aabb().get_center()
			var cell := Vector3i(floori(center.x/CELL_SIZE),floori(center.y/CELL_SIZE),floori(center.z/CELL_SIZE))
			var key := str(cell)+":"+str(node.get_active_material(0).get_instance_id())+":"+str(node.cast_shadow)+":"+str(node.layers)
			if not buckets.has(key): buckets[key]=[]
			buckets[key].append(node)
		for sources in buckets.values():
			if sources.size()<2: continue
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var triangles := 0
			var paths: PackedStringArray=[]
			for node in sources:
				var local: Transform3D=group.global_transform.affine_inverse()*node.global_transform
				surface.append_from(node.mesh,0,local)
				var arrays: Array=node.mesh.surface_get_arrays(0)
				triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
				paths.append(String(group.get_path_to(node)))
			var batch := MeshInstance3D.new()
			batch.name="StaticBatch"+str(report.batches)
			batch.mesh=surface.commit()
			batch.material_override=sources[0].get_active_material(0)
			batch.cast_shadow=sources[0].cast_shadow
			batch.layers=sources[0].layers
			batch.set_meta("source_paths",paths)
			batch.set_meta("source_triangles",triangles)
			group.add_child(batch)
			report.source_meshes+=sources.size()
			report.batches+=1
			report.source_triangles+=triangles
			report.batch_triangles+=batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
			for node in sources: node.free()
	company.set_meta("static_batch_report",report)
	return report

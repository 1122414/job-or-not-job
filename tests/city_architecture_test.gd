extends SceneTree

var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func intersections(mesh: ArrayMesh,surface: int,point: Vector3) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var hits := 0
	for i in range(0,indices.size(),3):
		if Geometry3D.segment_intersects_triangle(point+Vector3(0,0,1),point-Vector3(0,0,1),points[indices[i]],points[indices[i+1]],points[indices[i+2]])!=null:hits+=1
	return hits

func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CityArchitecture.ROOT+"provenance.json"))
	check(provenance.source_provenance.assets.size()==1,"选定建筑套件的独立来源")
	var source: Dictionary=provenance.source_provenance.assets[0]
	check(source.license=="CC0-1.0" and not source.authors.is_empty(),"建筑许可和作者可追溯")
	for path in provenance.derived_files:check(FileAccess.get_sha256(CityArchitecture.ROOT+path)==provenance.derived_files[path],"运行资源与派生记录一致："+path)
	var textures := {}
	var texture_bytes := 0
	for variant in CityArchitecture.MODULES:
		var mesh: ArrayMesh=load(CityArchitecture.ROOT+variant+".res")
		check(mesh.get_aabb().position.distance_to(Vector3(-1.5,0,mesh.get_aabb().position.z))<.001,"模块底部和水平中心规范化")
		check(absf(mesh.get_aabb().size.x-3)<.001 and absf(mesh.get_aabb().size.y-3)<.001,"源模型3米开间和层高")
		var glass_hits := 0
		var opening := Vector3.ZERO
		var largest := 0.0
		# Double windows have a central masonry pier. Probe a real glass triangle
		# interior instead of assuming every module's centre is an aperture.
		for surface in range(mesh.get_surface_count()):
			if mesh.surface_get_material(surface).resource_name!="glass":continue
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a: Vector3=vertices[indices[i]]
				var b: Vector3=vertices[indices[i+1]]
				var c: Vector3=vertices[indices[i+2]]
				var area := absf((b-a).cross(c-a).z)
				if area>largest:largest=area;opening=(a+b+c)/3
		check(largest>.01,"存在实际玻璃三角面用于窗洞射线")
		for surface in range(mesh.get_surface_count()):
			var data := RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
			var previous: int=data.index_count*(2 if data.vertex_count<65536 else 4)
			check(not data.get("lods",[]).is_empty(),"实际网格具有LOD索引")
			for lod in data.get("lods",[]):
				check(lod.index_data.size()>0 and lod.index_data.size()<previous,"LOD索引逐级减少")
				previous=lod.index_data.size()
			var arrays := mesh.surface_get_arrays(surface)
			check(arrays[Mesh.ARRAY_NORMAL].size()==arrays[Mesh.ARRAY_VERTEX].size() and arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"源法线与UV完整")
			var material: StandardMaterial3D=mesh.surface_get_material(surface)
			if material.resource_name=="plaster":check(intersections(mesh,surface,opening)==0,"窗洞不是被实心墙填住的贴片")
			if material.resource_name=="glass":
				glass_hits+=intersections(mesh,surface,opening)
				check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"实际玻璃使用源alpha")
			for texture in [material.albedo_texture,material.normal_texture,material.ao_texture,material.roughness_texture,material.metallic_texture]:
				if textures.has(texture.resource_path):continue
				textures[texture.resource_path]=true
				var picture: Image=texture.get_image()
				check(picture.is_compressed() and picture.has_mipmaps(),"真实压缩和mipmap："+texture.resource_path)
				texture_bytes+=picture.get_data_size()
		check(glass_hits>0,"真实窗洞中保留玻璃几何")
	check(textures.size()==10,"仅十张实际使用贴图进入运行资源")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):await physics_frame
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	var bays := 0
	for lot in CityUrbanFabric.LOTS:
		var architecture: Node3D=streets.get_node("Architecture_"+lot.id)
		bays+=architecture.get_meta("window_bays")
		for batch in architecture.find_children("*","MultiMeshInstance3D",true,false):
			check(batch.multimesh.use_colors,"建筑色调由实例设置且网格共享")
			# Dummy rendering cannot return real instance transforms. The same
			# clearance gate runs against GPU buffers in render_city_architecture.gd.
			check(batch.multimesh.instance_count>0,"实际建筑批次非空")
		var ray := PhysicsRayQueryParameters3D.create(lot.at+Vector3(0,5,lot.size.z/2+2),lot.at+Vector3(0,5,0),1)
		check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"换真实外墙后仍保留上层碰撞体")
		check(game.walking.clear_segment(lot.at+Vector3(-10,0,7),lot.at+Vector3(10,0,7)),"各连廊实际胶囊通行")
	check(game.commons.benches.size()==6 and game.props.size()==114,"原座位和物品身份保持")
	check(not game.persistence_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"不写玩家档或接管鼠标")
	game.queue_free();await process_frame
	print("CITY_ARCHITECTURE_TEST failures=",failures," window_bays=",bays," textures=",textures.size()," texture_bytes=",texture_bytes)
	quit(failures)

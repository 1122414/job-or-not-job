extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func component_root(parents: Array,value: int) -> int:
	while parents[value]!=value:
		parents[value]=parents[parents[value]]
		value=parents[value]
	return value

func islands(arrays: Array) -> int:
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var parents := []
	parents.resize(arrays[Mesh.ARRAY_VERTEX].size())
	for i in range(parents.size()): parents[i]=i
	var used := {}
	for i in range(0,indices.size(),3):
		for j in range(3): used[indices[i+j]]=true
		var a := component_root(parents,indices[i])
		parents[component_root(parents,indices[i+1])]=a
		parents[component_root(parents,indices[i+2])]=a
	var unique := {}
	for i in range(parents.size()): unique[component_root(parents,i)]=true
	check(used.size()==parents.size(),"减面网格不保留未引用顶点")
	return unique.size()

func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CityTree.ROOT+"provenance.json"))
	check(provenance.source_provenance.assets.size()==2,"树木与草地都有独立来源")
	for item in provenance.source_provenance.assets:
		check(item.license=="CC0-1.0" and not item.authors.is_empty(),"记录开放许可和作者")
	for relative in provenance.derived_files:
		check(FileAccess.get_sha256(CityTree.ROOT+relative)==provenance.derived_files[relative],"派生资源与制作记录一致："+relative)
	var count := 0
	var texture_bytes := 0
	for file in DirAccess.get_files_at(CityTree.ROOT+"textures"):
		if not file.ends_with(".jpg") and not file.ends_with(".png"): continue
		var texture: Texture2D=load(CityTree.ROOT+"textures/"+file)
		var image := texture.get_image()
		check(image.is_compressed() and image.has_mipmaps(),"实际使用VRAM压缩及mipmap："+file)
		check(texture.get_width()==2048 and texture.get_height()==2048,"来源2K尺度保留")
		texture_bytes+=image.get_data_size()
		count+=1
	check(count==12,"只打包十二张实际使用纹理，叶色和透明度已合并")
	var counts := []
	var baseline := AABB()
	for level in range(3):
		var mesh: ArrayMesh=load(CityTree.ROOT+"tree_lod%d.res"%level)
		check(mesh.get_surface_count()==3,"枝、叶、干材质面完整")
		var triangles := 0
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			check(arrays[Mesh.ARRAY_NORMAL].size()==positions.size() and arrays[Mesh.ARRAY_TEX_UV].size()==positions.size(),"法线和UV数量与顶点一致")
			check(arrays[Mesh.ARRAY_TANGENT].size()==positions.size()*4,"改拓扑后切线重新生成")
			var finite := true
			for vertex in positions:
				if not vertex.is_finite(): finite=false; break
			check(finite,"所有网格位置有限")
			var valid := indices.size()%3==0
			for index in indices:
				if index<0 or index>=positions.size(): valid=false; break
			check(valid,"索引完整并在实际顶点范围内")
			triangles+=indices.size()/3
			if surface==1:
				var island_count := islands(arrays)
				print("FOLIAGE_ISLANDS level=",level," count=",island_count)
				check(island_count==30250,"LOD%d保留原始30250个独立叶片及细枝组，实际%d"%[level,island_count])
		counts.append(triangles)
		if level>0: check(triangles<counts[level-1],"LOD几何严格递减")
		var bounds := mesh.get_aabb()
		if level==0: baseline=bounds
		check(absf(bounds.position.y)<.01,"根部落地误差小于1cm")
		check(bounds.get_center().distance_to(baseline.get_center())<.03 and bounds.size.distance_to(baseline.size)<.06,"LOD切换保持整棵树位置和轮廓范围")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6): await physics_frame
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	check(streets.trees.size()==23,"全部原树位接入且不额外阻路")
	for tree in streets.trees:
		check(tree.lods.size()==3 and tree.position.y==0,"每棵树保留三级模型与地面锚点")
		check(tree.lods[0].mesh==streets.trees[0].lods[0].mesh,"树位共享运行网格，避免重复常驻副本")
	var leaves: StandardMaterial3D=streets.trees[0].lods[0].mesh.surface_get_material(1)
	check(leaves.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"叶片裁切写入深度，避免混合透明排序")
	check(streets.materials.grass.uv1_scale==Vector3(.5,.5,.5),"草地按来源2米尺寸铺设")
	check(not game.persistence_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"验证不写玩家存档、不捕获鼠标")
	game.queue_free()
	await process_frame
	print("CITY_NATURE_TEST failures=",failures," triangles=",counts," texture_bytes=",texture_bytes," textures=",count)
	quit(failures)

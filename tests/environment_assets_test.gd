extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1

func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var local_bounds: AABB=(node.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		result=local_bounds if first else result.merge(local_bounds)
		first=false
	return result

func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/polyhaven/provenance.json"))
	check(provenance.assets.size()==5,"五项开放资产均有来源")
	for asset in provenance.assets:
		check(asset.license=="CC0-1.0" and not asset.authors.is_empty(),"记录许可及作者")
		for relative in asset.files:
			var path: String="res://assets/polyhaven/"+asset.id+"/"+relative
			check(FileAccess.get_sha256(path)==asset.files[relative].sha256,"原始文件校验："+path)
	for name in ["painted_wall","pavement","asphalt"]:
		var material: StandardMaterial3D=load("res://assets/materials/"+name+".tres")
		check(material.normal_enabled and material.ao_enabled,"法线与AO接入："+name)
		check(material.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN and material.ao_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_RED,"ARM通道对应："+name)
		check(material.uv1_triplanar and material.uv1_world_triplanar,"大面材质使用世界尺度："+name)
		for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
			check(texture!=null and texture.get_width()==2048 and texture.get_height()==2048,"样板贴图2K")
			check(texture.get_image().has_mipmaps(),"3D贴图生成mipmap")
	for name in ["waiting_chair","reception_lamp"]:
		var prop: StaticBody3D=load("res://scenes/props/"+name+".tscn").instantiate()
		root.add_child(prop)
		var box := bounds(prop)
		if name=="waiting_chair":
			check(absf(box.position.y)<0.002,"椅脚与地面误差不超过2mm")
		else:
			check(box.position.y>-0.065 and box.position.y<-0.055,"夹桌灯的夹具在安装点下方，不能悬在桌面上")
		check(box.size.y>0.5 and box.size.y<1.1,"家具采用米制尺度："+name)
		check(not prop.find_children("*","CollisionShape3D",true,false).is_empty(),"家具碰撞体存在")
		var triangles := 0
		for mesh in prop.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
				var material: StandardMaterial3D=mesh.mesh.surface_get_material(surface)
				for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
					check(texture!=null and texture.get_image().has_mipmaps(),"模型实际材质贴图也必须有mipmap")
					check(texture!=null and texture.get_image().is_compressed(),"模型实际材质贴图必须使用VRAM压缩")
		check(triangles<=25000,"单件样板不超过25k三角形："+name)
		print("ASSET_BOUNDS name=",name," bounds=",box," triangles=",triangles)
		prop.queue_free()
		await process_frame
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	check(not game.persistence_enabled,"测试不写玩家存档")
	for firm in ["A","B"]:
		check(game.get_node_or_null("ReceptionLamp"+firm)!=null,"两家公司均接入台灯")
		var lamp: Node3D=game.get_node("ReceptionLamp"+firm)
		check(is_equal_approx(lamp.position.z,OfficeRooms.RECEPTIONS[firm.to_lower()].z-0.37),"台灯夹在桌沿")
		for side in [-1,1]:
			var chair: Node3D=game.get_node_or_null("WaitingChair"+firm+str(side))
			check(chair!=null,"两家公司均接入候场椅")
			check(chair.basis.z.dot(Vector3.FORWARD)>0.99,"候场椅正面朝向室内")
		var arrival := Vector3(-10 if firm=="A" else 18,0,0.2)
		check(game.walking.clear_segment(arrival+Vector3(0,0,-1),arrival),"候场家具不得封堵入职带领终点："+firm)
	game.queue_free()
	await process_frame
	print("ENVIRONMENT_ASSETS_TEST failures=",failures)
	quit(failures)

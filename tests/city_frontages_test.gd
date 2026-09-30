extends SceneTree

var failures := 0
var textures := {}
var texture_bytes := 0
var model_costs := {}
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func run() -> void:
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CityStreetFront.ROOT+"provenance.json"))
	check(record.source_provenance.assets.size()==4,"四项独立街道资源来源")
	for source in record.source_provenance.assets:
		check(source.license=="CC0-1.0" and not source.authors.is_empty(),"许可与作者可追溯")
	for file in record.derived_files:
		check(FileAccess.get_sha256(CityStreetFront.ROOT+file)==record.derived_files[file],"实际派生文件未偏离制作记录："+file)
	for id in CityStreetFront.MODELS:
		var mesh: ArrayMesh=load(CityStreetFront.ROOT+id+".res")
		var triangles := 0
		var lods := 0
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			triangles+=indices.size()/3
			check(arrays[Mesh.ARRAY_NORMAL].size()==vertices.size() and arrays[Mesh.ARRAY_TEX_UV].size()==vertices.size(),"实际网格保留法线和UV")
			var data := RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
			var previous: int=data.index_count*(2 if data.vertex_count<65536 else 4)
			for lod in data.get("lods",[]):
				check(lod.index_data.size()>0 and lod.index_data.size()<previous,"实际LOD索引逐级减少")
				previous=lod.index_data.size();lods+=1
			var material: StandardMaterial3D=mesh.surface_get_material(surface)
			check(material.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN and material.metallic_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_BLUE,"源ARM通道未交换")
			if "leaves" in material.resource_name or "glass" in material.resource_name:
				check(material.transparency==(BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if "leaves" in material.resource_name else BaseMaterial3D.TRANSPARENCY_ALPHA),"实际叶片/灯罩透明模式")
				# get_image can return a cached Image. Decompress a copy so this
				# observation cannot change the resource being audited below.
				var rgba: Image=material.albedo_texture.get_image().duplicate()
				check(rgba.decompress()==OK,"实际alpha贴图可读取")
				var channel := "leaves" if "leaves" in material.resource_name else "glass"
				var original_alpha := Image.load_from_file("res://production/environment/polyhaven_street/"+id+"/textures/"+id+"_"+channel+"_alpha_2k.png")
				original_alpha.convert(Image.FORMAT_L8)
				original_alpha.resize(rgba.get_width(),rgba.get_height(),Image.INTERPOLATE_LANCZOS)
				var minimum := 1.0
				var maximum := 0.0
				var difference := 0.0
				var samples := 0
				for y in range(0,rgba.get_height(),8):
					for x in range(0,rgba.get_width(),8):
						var alpha: float=rgba.get_pixel(x,y).a
						minimum=minf(minimum,alpha);maximum=maxf(maximum,alpha)
						difference+=absf(alpha-original_alpha.get_pixel(x,y).r);samples+=1
				check(difference/samples<.03 and minimum<.99,"实际运行alpha与同源透明度一致，未退回不透明JPEG")
				print("STREET_ALPHA ",id," range=",minimum,":",maximum," source_mean_error=",difference/samples)
			for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture,material.emission_texture]:
				if texture==null or textures.has(texture.resource_path):continue
				textures[texture.resource_path]=true
				var picture: Image=texture.get_image()
				check(picture.is_compressed() and picture.has_mipmaps(),"真实显存压缩与mipmap："+texture.resource_path)
				check(picture.get_width()==(2048 if id=="rollershutter_door" else 1024),"按实际用途控制纹理分辨率")
				texture_bytes+=picture.get_data_size()
		model_costs[id]={"triangles":triangles,"lod_surfaces":lods}
		if id=="plastic_crate_01":check(triangles<12000 and triangles>0,"周转箱确实减面且保留几何")
		if id=="potted_plant_02":
			check(mesh.get_aabb().position.y>=-.001 and mesh.get_aabb().end.y>.83 and mesh.get_aabb().end.y<.86,"叶片保留源偏移并从真实盆口生长")
			check(triangles<14000,"高密土壤未整件进入运行资源")
		if id=="rollershutter_door":check(mesh.get_aabb().size.x<1.1 and triangles==552,"只有完整原版素色门，无带展示偏移的涂鸦变体")
		if id=="industrial_wall_lamp":check(triangles==4446 and absf(mesh.get_aabb().position.z)<.001,"灯具源轮廓与壁面基准保留")
	check(textures.size()==19,"仅实际使用的十九张运行纹理")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(8):await physics_frame
	game.set_process(false)
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	check(streets.get_meta("street_frontages")==10,"现有十处首层接入且未覆盖书屋和住处")
	for x in [-96,-52,-34,36,56,96]:
		for z in [32,82]:
			if z==32 and x in [-52,56]:continue
			var at := Vector3(x,0,z)
			var rot := Basis(Vector3.UP,CityStreetFront.face_for(at)*PI/2)
			var front: Vector3=at+rot*Vector3(0,0,6.5 if x<0 else 7)
			check(game.walking.clear_segment(front+rot*Vector3(0,0,1.2),front-rot*Vector3(0,0,.2)),"实际门廊可接近："+str(at))
			var ray := PhysicsRayQueryParameters3D.create(front+Vector3(0,1.3,0)+rot*Vector3(0,0,1),front+Vector3(0,1.3,0)-rot*Vector3(0,0,1.2),1)
			check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"关闭入口保留实体，不是虚假通道")
	check(game.walking.clear_segment(CityHome.CENTER+Vector3(0,0,10),CityHome.CENTER+Vector3(0,0,3)),"实际住处入口保持")
	check(game.walking.clear_segment(Vector3(-52,0,41),Vector3(-52,0,36)),"实际书屋入口保持")
	check(game.commons.benches.size()==6 and game.props.size()==114,"既有公共座位和物品身份保持")
	var front_lights := 0
	for lamp in streets.lamps:
		if is_equal_approx(lamp.omni_range,4.2):
			front_lights+=1
			check(lamp.shadow_enabled and lamp.distance_fade_enabled,"入口灯有真实遮挡和距离成本控制")
	check(front_lights==10,"十处入口使用实际灯光")
	for minute in [720,1230]:
		game.payroll.minute=minute;game.update_daylight()
		for lamp in streets.lamps:check(is_zero_approx(lamp.light_energy) if minute==720 else lamp.light_energy>.5,"日夜实际光能切换")
	var original := SaveGame.snapshot(game)
	var resident: CityResident=game.population.residents[5]
	# These positions were open ground before the crate and planters arrived.
	for at in [Vector3(-38.55,0,38.75),Vector3(42.3,0,39.45),Vector3(-21.25,0,29.495)]:
		check(not game.position_clear(game.player,at),"旧落点确实被新增实物占据")
		var saved := original.duplicate(true)
		saved.player.position=SaveGame.vector(at)
		var person: Dictionary=saved.city_population.people[resident.stable_id]
		person.position=SaveGame.vector(at+Vector3(.1,0,0));person.state="activity"
		person.route=[];person.crossing="";person.activity_left=40
		person.hp=47;person.hits=2;person.met=true
		check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(saved))),"新增实物附近的真实JSON可恢复")
		for i in range(70):await physics_frame
		for actor in [game.player,resident]:
			check(game.position_clear(actor,actor.position) and actor.is_on_floor() and actor.position.distance_to(at)<3.5,"玩家和居民在附近恢复并持续站稳")
		check(resident.hp==47 and resident.hits==2 and resident.met,"恢复不清除居民身份和健康")
	check(game.career.employer==original.career.employer and not game.persistence_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"自由职业选择和测试隔离保持")
	game.queue_free();await process_frame
	print("CITY_FRONTAGES_TEST failures=",failures," textures=",textures.size()," texture_bytes=",texture_bytes," models=",JSON.stringify(model_costs)," old_positions=3 actors=2")
	quit(failures)

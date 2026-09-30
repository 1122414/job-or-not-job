extends SceneTree

const Baker = preload("res://tools/city_lighting_bake.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func snapshot(source: Node3D) -> Array:
	var result := []
	for mesh in source.get_children():
		var surfaces := []
		for index in range(mesh.mesh.get_surface_count()):
			var material: StandardMaterial3D=mesh.get_surface_override_material(index)
			surfaces.append([material.albedo_color,material.albedo_texture,material.emission,material.emission_energy_multiplier])
		result.append([mesh.transform,mesh.mesh,surfaces])
	return result

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(10): await physics_frame
	game.process_mode=Node.PROCESS_MODE_DISABLED
	check(not game.persistence_enabled,"烘焙测试不能读写玩家存档")
	var live_static := 0
	for actor in [game.player]+game.npcs+game.population.residents+game.props:
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			if mesh.gi_mode==GeometryInstance3D.GI_MODE_STATIC and mesh.is_visible_in_tree(): live_static+=1
	var baker := Baker.new()
	var source := baker.make_source(game)
	check(not baker.failed,"实际城区静态材料可提取")
	check(source.get_child_count()>2000,"实际批量结构展开为独立烘焙网格")
	check(baker.audit.excluded.size()==7,"面试物件、翻页图册与两片窗帘明确排除")
	var before := snapshot(source)
	source.free()
	# Moving actors and interactive objects must not become permanent geometry.
	for actor in [game.player]+game.npcs+game.population.residents+game.props:
		actor.position+=Vector3(1,0,1)
	for path in ["CompanyA/InterviewPhoneA","CompanyA/InterviewPapersA","CompanyB/InterviewPhoneB","CompanyB/InterviewBoxB"]:
		game.get_node(path).position+=Vector3(2,1,0)
	game.home.room.apply(false,true,2)
	game.get_node("ConnectedDistrict/CommunityBookshop").album.show_story(1,.5,2)
	var next := Baker.new()
	var changed := next.make_source(game)
	check(not next.failed and before==snapshot(changed),"人物、物件、翻页、窗帘、灯开关不改变静态烘焙源")
	changed.free()
	game.home.room.sofa.position.x+=.25
	var structural := Baker.new()
	var modified := structural.make_source(game)
	check(before!=snapshot(modified),"固定家具结构改变必须改变烘焙输入")
	modified.free()
	# Verify actual material resolution rather than just checking node flags.
	var fixture := Node3D.new()
	root.add_child(fixture)
	var converter := Baker.new()
	var red := StandardMaterial3D.new(); red.albedo_color=Color.RED
	var blue := StandardMaterial3D.new(); blue.albedo_color=Color.BLUE
	var cube := BoxMesh.new(); cube.material=blue
	converter.add_mesh(fixture,cube,Transform3D.IDENTITY,[],red)
	check(fixture.get_child(0).get_surface_override_material(0).albedo_color==Color.RED,"批量网格实例材质优先于底层网格材质")
	var texture := Image.create(64,64,false,Image.FORMAT_RGB8)
	texture.fill(Color.BLACK)
	texture.fill_rect(Rect2i(32,0,32,64),Color.WHITE)
	red.albedo_texture=ImageTexture.create_from_image(texture)
	red.uv1_triplanar=true
	var average := Baker.new()
	var proxy := average.bake_material(red)
	check(absf(proxy.albedo_color.r-.735357)<.001,"GI材质在线性空间计算纹理平均色")
	check(proxy.albedo_texture==null and red.albedo_texture!=null and red.uv1_triplanar,"仅转换离线代理，不改可见材质")
	fixture.free()
	game.queue_free()
	await process_frame
	print("CITY_LIGHTING_BAKE_TEST failures=",failures," proxies=",before.size()," exclusions=",baker.audit.excluded.size()," live_static_dynamic_meshes=",live_static)
	quit(failures)

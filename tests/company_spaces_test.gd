extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1

func run() -> void:
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/company_materials/provenance.json"))
	check(provenance.assets.size()==2,"两项制作材质具有来源")
	for asset in provenance.assets:
		check(asset.license=="CC0-1.0" and not asset.authors.is_empty(),"材质许可和作者")
		for file in asset.files:
			check(FileAccess.get_sha256("res://assets/company_materials/"+asset.id+"/"+file)==asset.files[file].sha256,"原件摘要："+file)
	for name in ["office_wood","office_brick"]:
		var mat: StandardMaterial3D=load("res://assets/materials/"+name+".tres")
		for texture in [mat.albedo_texture,mat.normal_texture,mat.roughness_texture]:
			check(texture.get_image().is_compressed() and texture.get_image().has_mipmaps(),"实际贴图有VRAM压缩和mipmap："+name)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	check(not game.persistence_enabled,"隔离正式存档")
	check(game.props.size()==114 and game.npcs.size()==10,"重制空间保留全部稳定物件和人物")
	var saved: Dictionary=SaveGame.snapshot(game)
	for firm in ["a","b"]:
		var space := OfficeRooms.space(game,firm)
		check(space.scene_file_path.ends_with("company_"+firm+".tscn"),"运行时实例化可编辑独立场景")
		check(OfficeRooms.point(game,firm,"interview_seat").is_equal_approx(OfficeRooms.INTERVIEW_SEATS[firm]),"v11面试座位保持")
		check(OfficeRooms.point(game,firm,"interview_host").is_equal_approx(OfficeRooms.INTERVIEW_HOSTS[firm]),"v11主持位置保持")
		check(OfficeRooms.point(game,firm,"reception").is_equal_approx(OfficeRooms.RECEPTIONS[firm]),"v11接待位置保持")
		for marker in space.get_node("PropSpawns").get_children():
			var matches: Array=game.props.filter(func(prop): return prop.stable_id==String(marker.name))
			check(matches.size()==1 and matches[0].home.is_equal_approx(marker.global_position),"物件由场景标记生成且ID唯一："+String(marker.name))
		for key in ["interview_seat","interview_call","tour_greet","tour_desk"]:
			check(not game.walking.route(OfficeRooms.point(game,firm,"entry"),OfficeRooms.point(game,firm,key)).is_empty(),"入口可达："+firm+"/"+key)
		# Move one marker: actor targeting must read the live scene, not old constants.
		var host: OfficeNPC=game.npc_for_role(firm+"_hr")
		game.interviews.schedule("interview_hr" if firm=="a" else "interview_b")
		var call_marker: Marker3D=space.get_node("Anchors/interview_call")
		var old_position := call_marker.position
		call_marker.position+=Vector3(0.3,0,0.2)
		check(game.interviews.host_target(host).is_equal_approx(call_marker.global_position),"叫号使用编辑后的场景锚点")
		call_marker.position=old_position
		game.onboarding.tour={"firm":firm,"phase":"leading","paused":false}
		check(game.onboarding.destination().is_equal_approx(OfficeRooms.point(game,firm,"tour_greet")),"带领使用场景锚点")
		game.onboarding.tour={}
	check(SaveGame.restore(game,saved),"v11快照仍可恢复")
	var next: Dictionary=SaveGame.snapshot(game)
	check(saved.props.keys()==next.props.keys() and saved.npcs.keys()==next.npcs.keys(),"读档不丢稳定ID")
	var a_back: OfficeProp=game.props.filter(func(prop): return prop.stable_id=="a_desk_-7_-2_back")[0]
	var b_back: OfficeProp=game.props.filter(func(prop): return prop.stable_id=="b_desk_-7_-2_back")[0]
	check(b_back.mesh.get_aabb().size.y<a_back.mesh.get_aabb().size.y,"B共享工位采用低隔板")
	check(absf((b_back.mesh.position.y-b_back.mesh.get_aabb().size.y/2)-(a_back.mesh.position.y-a_back.mesh.get_aabb().size.y/2))<0.001,"降低隔板保留地面支撑和旧档坐标")
	game.queue_free()
	await process_frame
	print("COMPANY_SPACES_TEST failures=",failures)
	quit(failures)

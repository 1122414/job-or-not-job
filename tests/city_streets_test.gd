extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(6): await physics_frame
	game.set_process(false)
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	for link in CityPopulation.LINKS:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]]),"新街具不封堵公共/室内/服务路线 "+str(link))
	# The response crew starts at service_entry: exclude the moving actor itself,
	# as actual CharacterBody motion does. All scenery stays in the collision query.
	for link in [["center","service_entry"],["service_entry","service_hall"]]:
		check(game.walking.clear_segment(CityPopulation.POINTS[link[0]],CityPopulation.POINTS[link[1]],game.response.crew),"救助自身之外的服务路段可通 "+str(link))
	for stop in CityLayout.STOPS:
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius=.32; shape.height=1.7
		query.shape=shape
		query.transform.origin=stop.platform+Vector3(0,.9,0)
		query.collision_mask=1
		query.exclude=game.walking.excluded
		check(game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"新布景保留上下车落脚位 "+stop.id)
	# A bench's slats must block the actual collision query, not just look solid.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-43,1.2,63),Vector3(-43,.2,63),1)
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.position.y>.49,"公共长凳中部有实际座面支撑")
	game.payroll.minute=720
	game.update_daylight()
	for light in streets.lamps: check(is_zero_approx(light.light_energy),"正午街灯关闭")
	game.payroll.minute=1230
	game.update_daylight()
	for light in streets.lamps: check(light.light_energy>.5,"夜间公共道路得到实际照明")
	var before := SaveGame.snapshot(game)
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(before))),"环境升级后的真实 JSON 仍可恢复")
	check(game.career.employer==before.career.employer and game.props.size()==114,"环境升级不改变职业选择或物品身份")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"检查不接管鼠标")
	var instances := 0
	var render_nodes := streets.find_children("*","MultiMeshInstance3D",true,false)
	for node in render_nodes: instances+=node.multimesh.instance_count
	var batch_count := render_nodes.size()
	var light_count := streets.lamps.size()
	game.queue_free()
	await process_frame
	print("CITY_STREETS_TEST failures=",failures," instances=",instances," batches=",batch_count," lights=",light_count," public_links=",CityPopulation.LINKS.size()+2," deterministic_buffers=GPU_tool_required")
	quit(failures)

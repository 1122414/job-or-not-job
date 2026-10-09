extends SceneTree
var failures := 0
var view: Viewport
var game: Node3D
var output := ""
var report := {}
var capture_height := 800
var physics_rate := 60
func _initialize() -> void:
	if DisplayServer.get_name()!="headless": root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	for arg in OS.get_cmdline_user_args():
		if arg=="--720": capture_height=720
		if arg.begins_with("--physics="): physics_rate=int(arg.trim_prefix("--physics="))
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second=physics_rate
	call_deferred("run")
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message);failures+=1
func ray_mesh(node: MeshInstance3D,to: Vector3) -> bool:
	var start: Vector3=node.to_local(game.player.camera.global_position)
	var end: Vector3=node.to_local(to)
	if node.get_aabb().intersects_segment(start,end)==null: return false
	var faces := node.mesh.get_faces()
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(start,end,faces[i],faces[i+1],faces[i+2])!=null: return true
	return false
func blocked_window_rays(to: Vector3) -> int:
	var count := 0
	var nodes: Array=[]
	var hits := {}
	for path in ["Architecture/@Node3D@94/Glass","Architecture/StaticBatch9"]:
		nodes.append(game.get_node("CompanyA/"+path))
	for x in [-.2,0,.2]:
		for y in [-.2,0,.2]:
			for node in nodes:
				if ray_mesh(node,to+Vector3(x,y,0)):
					hits[str(node.get_path())]=int(hits.get(str(node.get_path()),0))+1
					count+=1
	report.window_mesh_hits=hits
	return count
func shot(name: String) -> void:
	if output=="" or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(output)
	paused=true
	for i in range(3): await process_frame
	RenderingServer.force_draw()
	view.get_texture().get_image().save_png(output.path_join(name+".png"))
	paused=false
func run() -> void:
	view=root
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new();viewport.size=Vector2i(1280,capture_height);viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);view=viewport
	root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game);await frames(10)
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for npc in game.population.residents: npc.set_physics_process(false)
	var witness: OfficeNPC=game.npc_for_role("a_group")
	var boss: OfficeNPC=game.npc_for_role("a_boss")
	witness.position=Vector3(-5.081455,0,-9.912681);boss.position=Vector3(-3.1,0,-9.8)
	# Camera geometry fixture: position actors explicitly, with idle poses; real approach is covered by departure_response_test.
	for actor in [witness,boss]:
		actor.seated=false;actor.visual.position.y=0
		actor.visual.pose(0,false,false,false,false,false,false)
	game.player.position=Vector3(-4.013989,0,-8.144639)
	var toward: Vector3=witness.position-game.player.position
	game.player.yaw=atan2(-toward.x,-toward.z);game.player.pitch=-.08
	await frames(120)
	var rays := blocked_window_rays(witness.position+Vector3.UP*1.5)
	report.witness={"window_triangle_hits":rays,"camera":SaveGame.vector(game.player.camera.global_position),"hit_length":game.player.spring.get_hit_length()}
	print("WINDOW_RAYS ",report.witness)
	check(rays==0,"原见证视角不被突出窗饰挡住")
	await shot("witness")
	report.physics_rate=Engine.physics_ticks_per_second
	var shortest := 10.0
	for point in [Vector3(-4,0,-8.15),Vector3(-3,0,-15.5),Vector3(-25,0,-15.5),Vector3(0,0,28)]:
		game.player.position=point
		for step in range(72):
			game.player.yaw=step*TAU/72
			await frames(3)
			var length: float=game.player.spring.get_hit_length()
			shortest=minf(shortest,length)
			check(game.player.camera.global_position.is_finite() and length>=0 and length<=3.101,"绕墙角/街道旋转时镜头位置有效")
		await shot("corner-"+str(point.x)+"-"+str(point.z))
	report.rotation={"samples":288,"min_length":shortest}
	game.player.position=Vector3(0,0,28);game.player.yaw=0;await frames(10)
	var walk_start: Vector3=game.player.position
	Input.action_press("forward");await frames(60);Input.action_release("forward")
	check(game.player.position.distance_to(walk_start)>1,"按真实移动输入时镜头继续跟随")
	report.walk={"distance":game.player.position.distance_to(walk_start),"camera_offset":SaveGame.vector(game.player.camera.global_position-game.player.position)}
	var car: CityCar=game.driving.car_for("car_office")
	game.player.position=car.to_global(Vector3(-1.65,0,0));await frames(3)
	check(game.driving.enter(car),"相机检查夹具进入共享车")
	await frames(120)
	report.driving={"hit_length":game.player.spring.get_hit_length(),"distance":game.player.camera.global_position.distance_to(car.position)}
	check(game.player.spring.get_hit_length()>3,"驾驶镜头不会被本车碰撞体卡在座椅")
	await shot("driving")
	car.speed=0;check(game.driving.leave(),"可以下车")
	game.player.position=CityLayout.STOPS[0].platform
	check(game.transit.board(0),"相机检查夹具乘公交")
	await frames(120)
	report.bus={"hit_length":game.player.spring.get_hit_length()}
	check(game.player.spring.get_hit_length()>.5,"乘公交的镜头不被本车碰撞体压到零")
	await shot("bus")
	check(game.transit.leave(),"可以下公交")
	if output!="": FileAccess.open(output.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free()
	if view!=root: view.queue_free()
	await process_frame
	print("CAMERA_CLEARANCE_TEST failures=",failures," results=",report);quit(failures)

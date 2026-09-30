extends "res://tools/render_city_bus.gd"

func joints(human: HumanVisual) -> Dictionary:
	var result := {}
	for id in ["upperleg01.L","lowerleg01.L","foot.L","head"]:
		result[id]=SaveGame.vector(human.skeleton.get_bone_global_pose(human.skeleton.find_bone(id)).origin)
	return result

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED;root.set_disable_input(true)
	DirAccess.make_dir_recursive_absolute(output)
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for i in range(10):await physics_frame
	paused=true
	var camera := Camera3D.new();game.add_child(camera);camera.make_current();camera.fov=58
	var car: CityCar=game.driving.car_for("car_office")
	for shot in [
		["front",Vector3(-4,2.2,-5),Vector3(0,.9,0)],
		["rear",Vector3(4,2.2,5),Vector3(0,.9,0)],
		["side",Vector3(-4.8,1.5,0),Vector3(0,.9,0)],
		["cabin",Vector3(.7,1.45,1.0),Vector3(-.25,1.05,-.4)],
		["front-wheel",Vector3(-2.0,.75,-2.05),Vector3(-.88,.4,-1.38)]]:
		camera.position=car.to_global(shot[1]);camera.look_at(car.to_global(shot[2]))
		if not await capture(shot[0]):quit(1);return
	var traffic: CityCar=game.driving.car_for("traffic_0")
	var human: HumanVisual=traffic.driver
	var before := joints(human)
	camera.position=traffic.to_global(Vector3(-2.2,1.35,-.6));camera.look_at(traffic.to_global(Vector3(-.43,.95,.1)))
	if not await capture("traffic-driver-current"):quit(1);return
	human.animation.play("work",0);human.animation.advance(.4);human.animation.pause();traffic.pose_driver(human)
	var settled := joints(human)
	if not await capture("traffic-driver-settled-diagnostic"):quit(1);return
	var max_joint_delta := 0.0
	for id in before:max_joint_delta=maxf(max_joint_delta,SaveGame.unvector(before[id]).distance_to(SaveGame.unvector(settled[id])))
	game.payroll.minute=20*60;game.update_daylight()
	camera.position=car.to_global(Vector3(-4,2.0,-5));camera.look_at(car.to_global(Vector3(0,.9,0)))
	if not await capture("night-front"):quit(1);return
	car.animate_wheels(0,true)
	camera.position=car.to_global(Vector3(4,1.7,5));camera.look_at(car.to_global(Vector3(0,.9,0)))
	if not await capture("night-brake"):quit(1);return
	for braking in [false,true]:
		traffic.animate_wheels(0,braking)
		camera.position=traffic.to_global(Vector3(4,1.7,5));camera.look_at(traffic.to_global(Vector3(0,.9,0)))
		if not await capture("traffic-night-brake" if braking else "traffic-night-position"):quit(1);return
	camera.position=traffic.to_global(Vector3(-4,2,-5));camera.look_at(traffic.to_global(Vector3(0,.9,0)))
	if not await capture("traffic-night-headlights"):quit(1);return
	var result := {"images":pictures,"current_driver_joints":before,"settled_driver_joints":settled,"driver_max_joint_difference":max_joint_delta,"background_guard":guard(),"persistence":game.persistence_enabled,"fixture_cameras":true,"normal_game_fps":false,"renderer":RenderingServer.get_current_rendering_method()}
	if not guard() or game.persistence_enabled:quit(1);return
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	paused=false;game.queue_free();await process_frame
	print("CITY_CAR_RENDER_OK ",JSON.stringify(result));quit()

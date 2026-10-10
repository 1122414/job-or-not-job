extends "res://tools/render_character_candidates.gd"

var observations := []
func shot(viewport: SubViewport,id: String) -> void:
	RenderingServer.force_draw(false)
	var picture := viewport.get_texture().get_image()
	if picture==null or picture.is_empty() or picture.save_png(output.path_join(id+".png"))!=OK: push_error("Capture failed "+id);quit(1)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new();viewport.size=Vector2i(960,600);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.set_disable_input(true);root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
	for i in range(8): await physics_frame
	game.set_process(false);game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	game.player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for npc in game.population.residents: npc.set_physics_process(false)
	game.hud.visible=false
	var camera := Camera3D.new();game.add_child(camera);camera.make_current();camera.fov=54
	var car: CityCar=game.driving.car_for("traffic_0")
	car.position=Vector3(0,0,65);car.rotation.y=0;car.speed=0
	game.player.position=Vector3(-1.65,0,65)
	for i in range(3): await physics_frame
	if not game.driving.enter(car):push_error("Takeover fixture rejected");quit(1);return
	camera.position=Vector3(-5,2.8,60);camera.look_at(Vector3(-.5,1,65));camera.make_current()
	for i in range(210):
		if car.boarding: game.driving.step_entry(1.0/60)
		await physics_frame
		if i%10==0:
			await process_frame;await shot(viewport,"entry-%03d" % (i/10))
			observations.append({"frame":i,"driver":SaveGame.vector(car.displaced.visual.global_position),"player":SaveGame.vector(game.player.visual.global_position),"door":car.visual.doors[0].rotation.y})
	game.driving.detach()
	car.set_taken(false)
	game.player.position=Vector3(-1.65,0,65);game.player.yaw=-PI/2
	game.player.set_physics_process(true);game.player.camera.make_current()
	for i in range(4): await physics_frame
	if not game.driving.enter(car): push_error("Normal-camera takeover rejected");quit(1);return
	game.driving.set_physics_process(true)
	for i in range(210):
		await physics_frame
		if i%30==0: await process_frame;await shot(viewport,"normal-entry-%03d" % (i/30))
	game.driving.set_physics_process(false);game.player.set_physics_process(false)
	game.driving.detach()
	game.player.position=Vector3(15,0,75)
	var a: CityCar=game.driving.cars[0];var b: CityCar=game.driving.cars[1]
	a.position=Vector3(0,0,80);a.rotation.y=0;a.speed=12
	b.position=Vector3(.35,0,72);b.rotation.y=0
	camera.position=Vector3(6,4.5,81);camera.look_at(Vector3(0,.5,73));camera.make_current()
	for i in range(180):
		a.drive(1.0/60,0,0,false);b.step_impact(1.0/60);car.step_impact(1.0/60)
		await physics_frame
		if i%10==0: await process_frame;await shot(viewport,"impact-%03d" % (i/10))
	game.player.position=Vector3(52,0,29);game.payroll.minute=540
	game.rest_until(1980);game.rest_transition.set_process(false)
	for i in range(49):
		game.rest_transition._process(.095)
		await process_frame;await shot(viewport,"rest-%03d" % i)
	game.rest_transition.finish()
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify({"entry":observations,"impact_displacement":72-b.position.z,"root_minimized":root.mode==Window.MODE_MINIMIZED,"root_no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"mouse_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"display":DisplayServer.get_name()},"\t"))
	viewport.queue_free();await process_frame
	print("MOTION_FEEDBACK_RENDER success");quit()

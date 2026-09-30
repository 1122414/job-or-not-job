extends "res://tools/render_character_candidates.gd"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output);root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1600,900);viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new();viewport.add_child(stage)
	var world := WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("899daa")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("d2dce4");world.environment.ambient_light_energy=.5
	world.environment.tonemap_mode=Environment.TONE_MAPPER_ACES;stage.add_child(world)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0)
	sun.shadow_enabled=true;sun.light_energy=1.4;stage.add_child(sun)
	Shapes.box(stage,Vector3(10,.04,6),Vector3(0,-.03,0),Color("9e9b88"))
	var camera := Camera3D.new();camera.current=true;camera.fov=42
	stage.add_child(camera);camera.position=Vector3(0,2.3,8);camera.look_at(Vector3(0,.85,0))
	for outfit in ["casual","office_female","protagonist","lin_lan","a_cheng"]:
		for clip in ["walk","run"]:
			var humans: Array[HumanVisual]=[]
			for index in range(4):
				var human := HumanVisual.new()
				if outfit in ["protagonist","lin_lan","a_cheng"]:human.cast_id=outfit
				else:human.outfit=outfit
				stage.add_child(human);humans.append(human)
				human.position.x=-2.4+index*1.6;human.rotation.y=PI*.7
				human.set_process(false)
				human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				human.animation.stop();human.skeleton.reset_bone_poses()
				human.animation.play(clip);human.animation.seek(index*.25,true);human.animation.advance(0)
			if not await capture(viewport,outfit+"-"+clip):quit(1);return
			for human in humans:human.queue_free()
			await process_frame
	if root.mode!=Window.MODE_MINIMIZED or root.has_focus() or not root.get_flag(Window.FLAG_NO_FOCUS) or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Locomotion capture lost desktop protection");quit(1);return
	viewport.queue_free();await process_frame
	print("LOCOMOTION_VIEWS_OK images=",captures," background_guard=true");quit()

extends SceneTree

const OUTPUT := "res://build/authored-motion-preview/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Graphical capture required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size=Vector2i(960,720)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(1.3,1.15,3.0)
	camera.look_at(Vector3(0,0.98,0))
	camera.fov=38
	camera.current=true
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees=Vector3(-40,-25,0)
	light.light_energy=1.5
	var world := WorldEnvironment.new()
	stage.add_child(world)
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("242e38")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=0.65
	Shapes.box(stage,Vector3(5,0.04,5),Vector3(0,-0.02,0),Color("525e67"))
	for outfit in ["casual","office","office_female"]:
		var human := HumanVisual.new()
		human.outfit=outfit
		stage.add_child(human)
		human.get_node("Model").rotation.y=0
		human.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in ["idle","talk"]:
			if outfit=="casual":
				var before: String="before_"+clip
				human.animation.get_animation_library("").add_animation(before,human.make_clip(clip))
				await capture(human,before,0.25,outfit+"_"+clip+"_before")
			for phase in [0.0,0.33,0.66]:
				await capture(human,clip,phase,outfit+"_"+clip+"_"+str(roundi(phase*100)))
		human.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	print("AUTHORED_MOTION_CAPTURE images=20")
	quit()

func capture(human: HumanVisual,clip: String,phase: float,file_name: String) -> void:
	human.animation.stop()
	human.skeleton.reset_bone_poses()
	human.animation.play(clip)
	human.animation.seek(human.animation.get_animation(clip).length*phase,true)
	human.animation.advance(0)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+file_name+".png")

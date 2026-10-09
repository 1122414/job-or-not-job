extends SceneTree

var game: Node3D
var view: SubViewport
var output := ""
var saved_path := ""
var audio_capture := AudioEffectCapture.new()
var records: Array=[]
var failures := 0
var post_draws := 0

func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--from-save="): saved_path=arg.trim_prefix("--from-save=")
	if not "--background" in OS.get_cmdline_user_args() or output.is_empty() or saved_path.is_empty():
		push_error("Require --background, --output and --from-save");quit(2);return
	call_deferred("run")

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and root.is_input_disabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and AudioServer.is_bus_mute(0)

func require_guard() -> bool:
	if guard(): return true
	Input.action_release("back")
	Input.action_release("forward")
	push_error("Capture guard failed: "+str({"mode":root.mode,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"focused":root.has_focus(),"root_input_disabled":root.is_input_disabled(),"mouse":Input.mouse_mode,"muted":AudioServer.is_bus_mute(0)}))
	quit(2)
	return false

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)

func input_action(action: String,pressed: bool) -> void:
	var event := InputEventAction.new();event.action=action;event.pressed=pressed
	view.push_input(event,true)

func choose(action: String) -> bool:
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]==action: game.choose(i);return true
	return false

func write_audio(samples: PackedVector2Array,path: String) -> Dictionary:
	var bytes := PackedByteArray();bytes.resize(samples.size()*4)
	var peak := 0.0
	var energy := 0.0
	for i in range(samples.size()):
		peak=maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
		energy+=samples[i].length_squared()
		bytes.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var wav := AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true
	wav.mix_rate=int(AudioServer.get_mix_rate());wav.data=bytes
	check(wav.save_to_wav(path)==OK,"save actual PCM")
	return {"samples":samples.size(),"sample_rate":wav.mix_rate,"peak":peak,"rms":sqrt(energy/maxi(1,samples.size()*2)),"dropped":audio_capture.get_discarded_frames()}

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	if DisplayServer.get_name()=="headless" or RenderingServer.is_render_loop_enabled() or AudioServer.get_driver_name()!="Dummy":
		push_error("Require graphics, --disable-render-loop and --audio-driver Dummy");quit(2);return
	Engine.max_fps=30
	AudioServer.set_bus_mute(0,true)
	view=SubViewport.new();view.size=Vector2i(1280,800);view.own_world_3d=true
	view.set_disable_input(false)
	view.audio_listener_enable_3d=true;view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	RenderingServer.frame_post_draw.connect(func():post_draws+=1)
	game=load("res://scenes/main.tscn").instantiate();view.add_child(game)
	for frame in range(10): await physics_frame
	check(not game.persistence_enabled and not game.soundscape.persistence,"isolated settings and player save")
	var baseline := SaveGame.read(saved_path,game)
	check(not baseline.is_empty(),"real completed-story save must be valid")
	if failures: quit(2);return
	audio_capture.buffer_length=10;AudioServer.add_bus_effect(0,audio_capture)
	DirAccess.make_dir_recursive_absolute(output)
	game.soundscape.capture_only=true
	AudioServer.set_bus_mute(0,true)
	if not require_guard(): return
	check(SaveGame.restore(game,baseline),"restore for actual meeting")
	game.panels.show_page("")
	var original_boss: OfficeNPC=game.npc_for_role("a_boss")
	game.player.position=original_boss.position+Vector3(.85,0,0)
	game.interact(original_boss)
	check(choose("story_response_menu") and choose("story_response_request"),"request actual witness")
	var witness: OfficeNPC=game.story.response.witness()
	game.player.position=witness.position+Vector3(.85,0,0)
	game.interact(witness)
	check(choose("story_response_invite"),"invite actual witness")
	game.player.position=game.story.response.station().position+Vector3(1,0,3.8)
	var deadline := Time.get_ticks_msec()+60000
	while not game.story.response.present() and Time.get_ticks_msec()<deadline:
		await process_frame
		if not require_guard(): return
	check(game.story.response.present(),"both participants physically reach clear meeting aisle")
	if failures: quit(2);return
	baseline=SaveGame.snapshot(game)
	for branch in ["written","leave","conflict"]:
		var branch_failures := failures
		check(SaveGame.restore(game,baseline),"restore actual story "+branch)
		game.panels.show_page("")
		check(game.career.employer=="" and game.career.facts.has("conversion_failed") and game.career.facts.has("output_two"),"same no-HC result")
		var person: OfficeNPC=game.npc_for_role("a_boss")
		game.player.position=person.position+Vector3(0,0,.85);game.player.yaw=0;game.player.pitch=-.1
		game.player.velocity=Vector3.ZERO
		for frame in range(20): await physics_frame
		for frame in range(90):
			var direction: Vector3=person.position-game.player.position
			game.player.yaw=atan2(-direction.x,-direction.z)
			if direction.length()<.78: break
			if not require_guard(): return
			Input.action_press("forward");await physics_frame
		Input.action_release("forward")
		game.interact(person)
		check(game.speaker==person,"real local conversation")
		check(choose("story_response_menu"),"response menu present")
		if failures>branch_failures: quit(2);return
		for frame in range(12): await physics_frame
		game.soundscape.capture_only=true
		var folder := output.path_join(branch);DirAccess.make_dir_recursive_absolute(folder)
		var samples := PackedVector2Array();var frames: Array=[]
		var began := Time.get_ticks_usec();audio_capture.clear_buffer()
		var acted := false;var retreat := false
		var hp_before: int=person.hp;var balance: int=game.payroll.balance
		while Time.get_ticks_usec()-began<4000000:
			await process_frame
			if not require_guard(): return
			var now := (Time.get_ticks_usec()-began)/1000000.0
			if now>=.8 and not acted:
				acted=true
				if branch=="written": check(choose("story_response_written"),"written option present")
				elif branch=="leave": check(choose("story_response_leave"),"leave option present")
				else:
					game.close_interaction();input_action("attack",true);input_action("attack",false)
			if now>=2 and not retreat:
				game.close_interaction();Input.action_press("back");retreat=true
			var draws := post_draws;RenderingServer.force_draw(false)
			check(post_draws==draws+1 and guard(),"actual frame and background/audio guard")
			var picture := view.get_texture().get_image()
			check(not picture.is_empty() and picture.save_jpg(folder.path_join("%04d.jpg"%frames.size()),.9)==OK,"write actual sequence frame")
			samples.append_array(audio_capture.get_buffer(audio_capture.get_frames_available()))
			frames.append({"t":now,"hp":person.hp,"player":SaveGame.vector(game.player.position),"npc":SaveGame.vector(person.position),"effects":get_nodes_in_group("comic_impacts").size(),"hit_pause":game.player.hit_pause,"camera_offset":game.player.camera.h_offset,"conversation":not game.conversation.is_empty(),"strike_phase":game.player.visual.animation.current_animation_position,"swing":game.player.swing,"strike_action":game.player.strike_action})
		Input.action_release("back")
		samples.append_array(audio_capture.get_buffer(audio_capture.get_frames_available()))
		var audio := write_audio(samples,output.path_join(branch+".wav"))
		check(audio.samples>audio.sample_rate*3 and audio.dropped==0 and audio.peak>.00001 and audio.peak<.95,"PCM duration/nonzero/no drop/no clipping "+branch)
		check(game.career.employer=="" and not game.career.facts.has("regular") and game.payroll.balance==balance,"result and money unchanged")
		check(person.hp==hp_before-12 if branch=="conflict" else person.hp==hp_before,"expected one ordinary hit "+branch)
		var damage_changes := 0
		var peak_effects := 0
		var peak_offset := 0.0
		for i in range(frames.size()):
			if i>0 and frames[i].hp<frames[i-1].hp: damage_changes+=1
			peak_effects=maxi(peak_effects,frames[i].effects)
			peak_offset=maxf(peak_offset,absf(frames[i].camera_offset))
		check(damage_changes==(1 if branch=="conflict" else 0),"single damage transition")
		check(peak_effects==(1 if branch=="conflict" else 0),"single transient impact")
		check(peak_offset>.1 if branch=="conflict" else is_zero_approx(peak_offset),"impact camera feedback only on conflict")
		check(frames[-1].effects==0 and absf(frames[-1].camera_offset)<.001 and frames[-1].swing==0,"feedback returns to rest")
		check(game.player.position.distance_to(SaveGame.unvector(frames[0].player))>1,"can leave after choice")
		records.append({"branch":branch,"frames":frames,"audio":audio,"hp_before":hp_before,"hp_after":person.hp,"written":not game.story.response.state().written.is_empty(),"employer":game.career.employer,"company_conflict":game.career.conflict.a,"guard":guard()})
		print("BRANCH ",branch," hp=",person.hp," move=",game.player.position.distance_to(SaveGame.unvector(frames[0].player))," audio=",audio.peak)
	game.soundscape.stop_all();game.audio.stop()
	game.soundscape.capture_only=false
	await create_timer(.15,true,false,true).timeout
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"records":records,"placement_fixture":true,"natural_player_acceptance":false,"normal_game_fps":false,"audio_driver":AudioServer.get_driver_name(),"source_save_sha256":FileAccess.get_sha256(saved_path)},"  "))
	print("RESPONSE_MOTION_CAPTURE failures=",failures," records=",records.size())
	view.queue_free();await process_frame;quit(failures)

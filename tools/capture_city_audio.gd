extends SceneTree

var output := "res://build/c4e-audio"
var game: Node3D
var viewport: SubViewport
var capture := AudioEffectCapture.new()
var results := {}
var failures := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true); root.mode=Window.MODE_MINIMIZED
	root.set_disable_input(true); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

func check(value: bool,label: String) -> void:
	if not value: push_error(label); failures+=1

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and root.is_input_disabled() and AudioServer.is_bus_mute(0)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout

func record(label: String,seconds: float) -> Dictionary:
	capture.clear_buffer()
	var samples := PackedVector2Array()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<int(seconds*1000):
		await process_frame
		samples.append_array(capture.get_buffer(capture.get_frames_available()))
	var data := PackedByteArray(); data.resize(samples.size()*4)
	var peak := 0.0; var left := 0.0; var right := 0.0
	for i in range(samples.size()):
		var frame := samples[i]
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		left+=frame.x*frame.x; right+=frame.y*frame.y
		data.encode_s16(i*4,roundi(clampf(frame.x,-1,1)*32767))
		data.encode_s16(i*4+2,roundi(clampf(frame.y,-1,1)*32767))
	var wav := AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.stereo=true
	wav.mix_rate=int(AudioServer.get_mix_rate()); wav.data=data
	check(wav.save_to_wav(output.path_join(label+".wav"))==OK,"写出真实混音 "+label)
	var result := {"frames":samples.size(),"rate":wav.mix_rate,"peak":peak,"left_rms":sqrt(left/maxi(1,samples.size())),"right_rms":sqrt(right/maxi(1,samples.size())),"dropped_frames":capture.get_discarded_frames(),"guard":guard()}
	results[label]=result
	check(samples.size()>wav.mix_rate*seconds*.6 and result.dropped_frames==0 and peak<.95 and guard(),"混音捕获完整、无削波、不输出设备 "+label+str(result))
	return result

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true); root.mode=Window.MODE_MINIMIZED
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,800)
	viewport.own_world_3d=true; viewport.audio_listener_enable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=load("res://scenes/main.tscn").instantiate(); viewport.add_child(game)
	for i in range(8): await physics_frame
	game.set_process(false)
	capture.buffer_length=5
	AudioServer.add_bus_effect(0,capture)
	AudioServer.set_bus_mute(0,true); game.soundscape.capture_only=true
	check(AudioServer.get_driver_name()=="Dummy","取证必须使用Dummy驱动，不向扬声器输出")
	for item in [["street-day",Vector3(0,0,58),600],["office-a",Vector3(-14,0,-4),600],["office-b",Vector3(14,0,-4),600],["bookshop",Vector3(-52,0,35),600],["garden-day",Vector3(42,0,60),600],["garden-night",Vector3(42,0,60),1320],["waterfront",Vector3(28,0,119),1080]]:
		game.player.position=item[1]; game.player.velocity=Vector3.ZERO
		game.player.yaw=0; game.payroll.minute=item[2]; game.update_daylight()
		await wait_seconds(2)
		var result := await record(item[0],2)
		check(result.left_rms+result.right_rms>.00005,"实际输出非静音 "+item[0])
		result["interior"]=game.soundscape.interior
		result["beds_db"]={}
		for key in game.soundscape.beds: result.beds_db[key]=game.soundscape.beds[key].volume_db
	game.player.position=Vector3(0,0,58); game.player.yaw=0; game.player.velocity=Vector3.ZERO
	await wait_seconds(.4)
	var before: Dictionary=game.soundscape.step_counts.duplicate()
	Input.action_press("forward")
	await record("actual-walking",1.1)
	Input.action_release("forward")
	check(game.player.position.z<54 and game.soundscape.step_counts!=before,"捕获期间真实键盘行走产生脚步")
	game.panels.show_page("pause")
	await wait_seconds(.4)
	var silent := await record("paused",.6)
	check(silent.peak<.00001,"暂停无残余声音")
	# Actual Control input inside the isolated viewport, no OS focus or pointer capture.
	var slider: HSlider=game.menu.audio_sliders.Ambience
	var scroll: ScrollContainer=game.menu.get_child(0)
	scroll.ensure_control_visible(slider)
	for i in range(5): await process_frame
	var point := slider.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=pressed
		viewport.push_input(event,true)
	check(absf(game.soundscape.levels.Ambience-.5)<.04,"实际鼠标点击调整环境音量")
	for bus in game.menu.audio_sliders:
		var control: HSlider=game.menu.audio_sliders[bus]
		scroll.ensure_control_visible(control)
		for i in range(3): await process_frame
		control.grab_focus()
		for code in [KEY_HOME,KEY_END]:
			for pressed in [true,false]:
				var event := InputEventKey.new()
				event.keycode=code; event.physical_keycode=code; event.pressed=pressed
				viewport.push_input(event,true)
			check(game.soundscape.levels[bus]==(0.0 if code==KEY_HOME else 1.0),"实际键盘操作分类音量端点 "+bus)
		game.soundscape.set_level(bus,CitySoundscape.DEFAULTS[bus])
		control.value=game.soundscape.levels[bus]*100
	for i in range(4): await process_frame
	var image := viewport.get_texture().get_image()
	check(image.save_png(output.path_join("audio-settings.png"))==OK,"音量设置界面取证")
	game.panels.show_page("")
	game.soundscape.set_process(false); game.soundscape.stop_all()
	var source := AudioStreamPlayer3D.new()
	source.stream=game.soundscape.clips.engine; source.bus="Actions"; source.unit_size=5; source.volume_db=-8
	game.add_child(source)
	game.player.set_physics_process(false)
	for side in [-1,1]:
		source.global_position=game.player.camera.global_position+game.player.camera.global_basis.x*float(side)*4-game.player.camera.global_basis.z*3
		source.play(); await wait_seconds(.25)
		var result := await record("source-left" if side<0 else "source-right",.7)
		check(result.left_rms>result.right_rms*1.2 if side<0 else result.right_rms>result.left_rms*1.2,"真实3D声源方向 "+str(side)+str(result))
	game.soundscape.set_level("Actions",0)
	await wait_seconds(.3)
	silent=await record("actions-muted",.6)
	check(silent.peak<.00001,"分类静音实际PCM为零")
	source.stop(); source.queue_free()
	game.soundscape.capture_only=false
	game.soundscape.set_process(true)
	await wait_seconds(.4)
	silent=await record("background",.6)
	check(silent.peak<.00001,"失焦后台无声音")
	results["summary"]={"failures":failures,"guard":guard(),"audio_driver":AudioServer.get_driver_name(),"player_save_written":game.persistence_enabled,"settings_written":game.soundscape.persistence,"listening_acceptance":false,"independent_playtest":false}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t")+"\n")
	print("CITY_AUDIO_CAPTURE failures=",failures," guard=",guard())
	viewport.queue_free(); await process_frame
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	quit(1 if failures else 0)

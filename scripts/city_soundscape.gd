class_name CitySoundscape
extends Node3D

const SETTINGS_PATH := "user://audio-settings.json"
const DEFAULTS := {"Master":0.8,"Ambience":0.7,"Actions":0.8,"Interaction":0.9}
const LABELS := {"Master":"总音量","Ambience":"环境与车流","Actions":"脚步与动作","Interaction":"现场交互提示"}
const STEPS := {"stone":["stone"],"carpet":["carpet"],"wood":["wood1","wood2","wood3"],"grass":["grass1","grass2"]}
const POOL_SIZE := 12
var game: Node3D
var levels := DEFAULTS.duplicate()
var clips := {}
var beds := {}
var engines := {}
var step_players: Array[AudioStreamPlayer3D]=[]
var tracked := {}
var step_counts := {}
var last_sample := {}
var rng := RandomNumberGenerator.new()
var enabled := false
var capture_only := false
var interior := 0.0
var revision := -1
var last_error := OK
var persistence := false

func _ready() -> void:
	name="CitySoundscape"
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	for key in ["traffic","birds","engine","waves","room","stone","carpet","wood1","wood2","wood3","grass1","grass2"]:
		var stream: AudioStreamWAV=load("res://assets/audio/city/"+key+".wav").duplicate()
		if key in ["traffic","birds","engine","waves","room"]:
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
		clips[key]=stream
	for key in ["traffic","birds","waves","room"]:
		var source := AudioStreamPlayer.new()
		source.bus="Ambience"; source.stream=clips[key]; source.volume_db=-80
		add_child(source); beds[key]=source
	for car in game.driving.cars:
		var source := positional("engine","Ambience",38.0)
		engines[car.stable_id]=source
	engines.bus=positional("engine","Ambience",46.0)
	for i in range(POOL_SIZE): step_players.append(positional("stone","Actions",18.0))
	apply_levels()

func positional(clip: String,bus_name: String,reach: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.stream=clips[clip]; source.bus=bus_name; source.max_distance=reach
	source.unit_size=2.0; source.max_db=0; source.volume_db=-80
	source.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(source)
	return source

func start_settings() -> void:
	persistence=game==get_tree().current_scene
	if persistence and FileAccess.file_exists(SETTINGS_PATH): read_settings(SETTINGS_PATH)
	apply_levels()

func apply_levels() -> void:
	for bus in levels:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(levels[bus],0.0001)))
		AudioServer.set_bus_mute(index,levels[bus]<=0)
	if capture_only: AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)

func set_level(bus: String,value: float) -> void:
	if not levels.has(bus) or not is_finite(value): return
	levels[bus]=clampf(value,0,1)
	apply_levels()
	if persistence:
		last_error=write_settings(SETTINGS_PATH)
		if last_error!=OK: game.say("音量已生效，但设置保存失败；请检查磁盘空间。")

func read_settings(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return false
	var data=JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.size()!=DEFAULTS.size(): return false
	for key in DEFAULTS:
		var value=data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>1: return false
	levels=data.duplicate(); apply_levels()
	return true

func write_settings(path: String) -> Error:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(levels)+"\n"); file.flush()
	var result := file.get_error()
	file.close()
	if result!=OK: return result
	return DirAccess.rename_absolute(path+".tmp",path)

func output_allowed() -> bool:
	# Capture fixtures may mix only into a muted Master, never the output device.
	if capture_only: return AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	return game==get_tree().current_scene and DisplayServer.get_name()!="headless" and get_window().has_focus() and not "--no-audio" in OS.get_cmdline_user_args()

func room_at(point: Vector3) -> String:
	if point.y<-.5 or point.y>3.8: return ""
	if game.home and game.home.inside(point): return "home"
	for firm in ["a","b"]:
		var p := OfficeRooms.space(game,firm).to_local(point)
		if absf(p.x)<11.86 and p.z>-15.86 and p.z<1.86: return firm
	var p: Vector3=game.city_life.room.to_local(point)
	if absf(p.x)<6.35 and absf(p.z)<6.35: return "bookshop"
	return ""

func indoor_weight(point: Vector3) -> float:
	var room := room_at(point)
	if room=="home":
		var local := point-CityHome.CENTER
		return smoothstep(6.84,4.5,local.z) if absf(local.x)<1.4 else 1.0
	if room in ["a","b"]:
		var local := OfficeRooms.space(game,room).to_local(point)
		return smoothstep(1.86,.0,local.z) if absf(local.x)<3.1 else 1.0
	if room=="bookshop":
		var local: Vector3=game.city_life.room.to_local(point)
		return smoothstep(6.35,4.5,local.z) if absf(local.x)<2.5 else 1.0
	return 0.0

func surface_at(point: Vector3) -> String:
	var room := room_at(point)
	if room=="a": return "carpet"
	if room in ["b","bookshop","home"]: return "wood"
	for patch in CityStreetscape.GRASS_PATCHES:
		var offset: Vector3=(point-patch[0]).abs()
		if offset.x<patch[1].x/2 and offset.z<patch[1].z/2: return "grass"
	return "stone"

func _process(delta: float) -> void:
	var allowed := output_allowed() and not get_tree().paused
	if allowed!=enabled:
		enabled=allowed
		if not enabled: stop_all()
	if not enabled: return
	var point: Vector3=game.player.global_position
	interior=lerpf(interior,indoor_weight(point),1-exp(-delta*5))
	var minute: int=game.payroll.minute%1440
	var day := smoothstep(300,420,minute)*(1-smoothstep(1080,1200,minute))
	var green := maxf(1-clampf(Vector2(point.x-44,point.z-66).length()/36,0,1),1-clampf(Vector2(point.x,point.z-38).length()/26,0,1))
	var coast := smoothstep(78,122,point.z)
	var in_car: bool=game.in_vehicle()
	var outdoor := (1-interior*.97)*(.45 if in_car else 1.0)
	# These are diffuse beds; nearby vehicles remain separate positional sources.
	bed("traffic",(.42+.58*day)*outdoor*(1-coast*.55),-28,delta)
	bed("waves",coast*outdoor,-19,delta)
	bed("birds",green*day*outdoor,-25,delta)
	bed("room",interior,-33,delta)
	for car in game.driving.cars:
		engine(engines[car.stable_id],car.global_position,absf(car.speed),car.traffic or game.driving.active==car,delta)
	engine(engines.bus,game.transit.bus.global_position,absf(game.transit.speed),true,delta)

func bed(key: String,weight: float,base: float,delta: float) -> void:
	var source: AudioStreamPlayer=beds[key]
	var target := base+linear_to_db(maxf(weight,.0001))
	source.volume_db=lerpf(source.volume_db,target,1-exp(-delta*3))
	if weight>.001 and not source.playing: source.play(rng.randf_range(0,source.stream.get_length()*.7))
	elif weight<=.001 and source.volume_db<-65: source.stop()

func engine(source: AudioStreamPlayer3D,point: Vector3,speed: float,running: bool,delta: float) -> void:
	source.global_position=point+Vector3(0,.6,0)
	if not running or point.distance_to(game.player.global_position)>source.max_distance+3:
		source.stop(); return
	source.pitch_scale=lerpf(source.pitch_scale,.72+clampf(speed/17,0,1)*.68,1-exp(-delta*4))
	source.volume_db=-22+clampf(speed/17,0,1)*7-interior*18
	if not source.playing: source.play(rng.randf_range(0,source.stream.get_length()*.7))

func _physics_process(delta: float) -> void:
	if get_tree().paused: tracked.clear(); return
	if revision!=game.restore_revision: tracked.clear(); revision=game.restore_revision
	var actors: Array=[game.player]
	actors.append_array(game.npcs); actors.append_array(game.population.residents)
	var alive := {}
	for actor in actors:
		var id: int=actor.get_instance_id(); alive[id]=true
		var point: Vector3=actor.global_position
		var anim: AnimationPlayer=actor.visual.animation
		var phase := int(floor(anim.current_animation_position/maxf(anim.current_animation_length,.001)*2))
		var old: Dictionary=tracked.get(id,{})
		tracked[id]={"point":point,"phase":phase,"clip":actor.visual.current}
		if old.is_empty() or actor.visual.current not in ["walk","run","carry"] or old.clip!=actor.visual.current: continue
		var moved: float=Vector2(point.x-old.point.x,point.z-old.point.z).length()
		if moved<.001 or moved>maxf(.5,delta*18) or not actor.is_on_floor() or absf(actor.velocity.y)>.3: continue
		if actor==game.player and (game.player.seated or game.in_vehicle() or game.player.dead>0): continue
		if actor is OfficeNPC and (actor.dead or actor.down>0 or actor.seated): continue
		if actor is CityResident and not actor.available(): continue
		if point.distance_to(game.player.global_position)>16 or phase==old.phase: continue
		step(actor,point,phase)
	for id in tracked.keys():
		if not alive.has(id): tracked.erase(id)

func step(actor: Node3D,point: Vector3,phase: int) -> void:
	var surface := surface_at(point)
	var pool: Array=STEPS[surface]
	var index := int(last_sample.get(surface,-1)+1)%pool.size()
	last_sample[surface]=index
	step_counts[surface]=int(step_counts.get(surface,0))+1
	if not enabled: return
	for source in step_players:
		if source.playing: continue
		source.stream=clips[pool[index]]
		source.global_position=point+actor.visual.global_basis.x*(.14 if phase==0 else -.14)+Vector3(0,.06,0)
		source.pitch_scale=rng.randf_range(.96,1.04)
		source.volume_db=(-12.0 if actor==game.player else -19.0)+rng.randf_range(-1,1)
		if room_at(point)!=room_at(game.player.global_position): source.volume_db-=16
		source.play(); return

func stop_all() -> void:
	for source in beds.values()+engines.values()+step_players:
		source.stop()
		if source is AudioStreamPlayer: source.volume_db=-80
	if is_instance_valid(game.audio): game.audio.stop()
	if is_instance_valid(game.interview_audio):
		for source in game.interview_audio.players.values(): source.stop()

func _exit_tree() -> void:
	stop_all()
	for source in beds.values()+engines.values()+step_players: source.stream=null

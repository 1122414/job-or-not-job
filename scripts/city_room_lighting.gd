class_name CityRoomLighting
extends Node3D

# Geometry is baked offline. No actors, scripts or bake proxies are loaded here.
const CAPTURE_LAYER := 1 << 19
const SETTINGS_PATH := "user://graphics-settings.cfg"
const ROOMS := [
	["office-a","CompanyA",Vector3(-14,2,-7),Vector3(29,8,28),Vector3(-14,1.8,-7),Vector3(24,3.6,18)],
	["office-b","CompanyB",Vector3(14,2,-7),Vector3(29,8,28),Vector3(14,2.15,-7),Vector3(24,4.3,18)],
	["bookshop","ConnectedDistrict/CommunityBookshop",Vector3(-52,2,32),Vector3(16,6,17),Vector3(-52,2,32),Vector3(13,4,13)],
	["home","ConnectedDistrict/HomeRoom",Vector3(56,2,32),Vector3(17,6,17),Vector3(56,1.7,32),Vector3(14,3.4,14)]
]
var game: Node3D
var available := false
var enabled := true
var indirect: Array[VoxelGI]=[]
var reflections: Array[ReflectionProbe]=[]
var captured_geometry: Array[GeometryInstance3D]=[]
var pending: Array[int]=[]
var last_minute := -1
var last_home := ""
var cooldown := 0.0
var refresh_count := 0

func _ready() -> void:
	name="CityRoomLighting"
	process_mode=Node.PROCESS_MODE_ALWAYS
	available=DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="forward_plus"
	if not available: return
	for item in ROOMS:
		mark_structure(game.get_node(item[1]))
		var volume := VoxelGI.new()
		volume.name=item[0]+"-indirect"
		volume.position=item[2];volume.size=item[3];volume.subdiv=VoxelGI.SUBDIV_256
		volume.data=load("res://assets/lighting/rooms/"+item[0]+".res")
		add_child(volume);indirect.append(volume)
		var reflection := ReflectionProbe.new()
		reflection.name=item[0]+"-reflection"
		reflection.position=item[4];reflection.size=item[5]
		reflection.box_projection=true
		reflection.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
		reflection.cull_mask=CAPTURE_LAYER
		reflection.enable_shadows=true
		reflection.max_distance=40
		reflection.blend_distance=.2
		add_child(reflection);reflections.append(reflection)
	mark_structure(game.get_node("DistrictGround"))
	sync_lights()

func mark_structure(node: Node) -> void:
	if str(node.name) in ["InterviewPhoneA","InterviewPhoneB","InterviewBoxB","InterviewPapersA"] or node is CityStoryAlbum: return
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		if node.get_parent() is CityHomeRoom and node in node.get_parent().curtains: return
		if node.is_visible_in_tree():
			node.layers|=CAPTURE_LAYER
			captured_geometry.append(node)
	for child in node.get_children(): mark_structure(child)

func set_enabled(value: bool) -> void:
	enabled=value
	for volume in indirect: volume.visible=value
	for reflection in reflections: reflection.visible=value
	if value:
		last_minute=-1
		sync_lights()
	else: pending.clear()
	if game.persistence_enabled and write_settings(SETTINGS_PATH)!=OK:
		game.say("画面设置未保存，下次启动会使用原设置。")

func read_settings(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path)!=OK: return false
	var value=config.get_value("lighting","rooms",null)
	if not value is bool: return false
	enabled=value
	for volume in indirect: volume.visible=value
	for reflection in reflections: reflection.visible=value
	if not value: pending.clear()
	return true

func write_settings(path: String) -> Error:
	var config := ConfigFile.new()
	config.set_value("lighting","rooms",enabled)
	var error := config.save(path+".tmp")
	if error!=OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)

func request_refresh(index: int) -> void:
	if index not in pending: pending.append(index)

func sync_lights() -> void:
	if not available or not enabled: return
	# The game advances half a minute per second. Ten minutes limits recaptures
	# while retaining continuous direct/indirect light updates between them.
	var minute: int=game.payroll.minute/10
	if minute!=last_minute:
		last_minute=minute
		for index in range(reflections.size()): request_refresh(index)
	var home_state := str(game.home.lights_on)+":"+str(game.home.curtains_closed)
	if home_state!=last_home:
		last_home=home_state
		pending.erase(3);pending.push_front(3)

func _process(delta: float) -> void:
	if not available or not enabled: return
	sync_lights()
	cooldown=maxf(0,cooldown-delta)
	if cooldown>0 or pending.is_empty(): return
	var index: int=pending.pop_front()
	# Reapply UPDATE_ONCE to invalidate the capture: no transform jitter or switch
	# to UPDATE_ALWAYS (which captures and filters all faces in one frame).
	reflections[index].update_mode=ReflectionProbe.UPDATE_ONCE
	refresh_count+=1
	cooldown=.25

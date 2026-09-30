extends SceneTree

const Baker=preload("res://tools/city_lighting_bake.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message);failures+=1

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(10): await physics_frame
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var lighting: CityRoomLighting=game.room_lighting
	check(not game.persistence_enabled,"光照测试不读取或修改玩家设置/存档")
	check(not lighting.available and lighting.indirect.is_empty(),"无窗口后端不创建GPU光照资源")
	var baker := Baker.new()
	var source := baker.make_source(game)
	check(not baker.failed,"当前固定结构仍满足烘焙约束")
	for room in CityRoomLighting.ROOMS: lighting.mark_structure(game.get_node(room[1]))
	lighting.mark_structure(game.get_node("DistrictGround"))
	var paths := []
	for geometry in lighting.captured_geometry: paths.append(str(game.get_path_to(geometry)))
	check(paths==baker.audit.sources,"运行反射仅包含同一静态白名单，不捕获人物或可动物件")
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lighting/rooms/provenance.json"))
	for index in range(CityRoomLighting.ROOMS.size()):
		var room=CityRoomLighting.ROOMS[index]
		check(room.slice(0,4)==Baker.ROOMS[index],"运行GI体积与烘焙体积相同")
		var path: String="res://assets/lighting/rooms/"+room[0]+".res"
		check(FileAccess.get_sha256(path)==provenance.resources[room[0]],"四份资源与已验收制作数据同字节")
		check(load(path) is VoxelGIData,"交付资源可作为VoxelGIData加载")
		var reflection := ReflectionProbe.new()
		lighting.add_child(reflection);lighting.reflections.append(reflection)
	lighting.available=true
	lighting.last_minute=-1;lighting.last_home=""
	lighting.sync_lights()
	check(lighting.pending.size()==4 and lighting.pending[0]==3,"首次刷新去重并优先住处灯状态")
	lighting.pending.clear();lighting.sync_lights()
	check(lighting.pending.is_empty(),"同一时间段与相同灯状态不反复请求捕获")
	game.home.lights_on=not game.home.lights_on
	lighting.sync_lights()
	check(lighting.pending==[3],"灯开关仅使住处反射失效")
	lighting.pending.clear();game.payroll.minute+=1440
	lighting.sync_lights()
	check(lighting.pending.size()==4,"跨日跳时使四处反射失效")
	lighting.set_enabled(false)
	check(lighting.pending.is_empty(),"关闭时取消排队刷新")
	var directory := "res://build/c4l2b/settings-test"
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("graphics.cfg")
	check(lighting.write_settings(path)==OK,"设置原子写入测试目录")
	lighting.set_enabled(true)
	check(lighting.read_settings(path) and not lighting.enabled,"独立画面设置可恢复关闭状态")
	FileAccess.open(path,FileAccess.WRITE).store_string("[lighting]\nrooms=\"false\"\n")
	check(not lighting.read_settings(path) and not lighting.enabled,"错误类型设置不改变现状")
	lighting.set_enabled(true)
	check(lighting.pending.size()==4,"再次启用刷新当前时间和灯光")
	source.free();game.queue_free();await process_frame
	print("CITY_ROOM_LIGHTING_TEST failures=",failures," static_geometry=",paths.size())
	quit(failures)

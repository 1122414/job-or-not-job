extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	check(game.props.size()>=100,"办公家具应成为真实交互对象")
	var legacy=SaveGame.snapshot(game)
	legacy.version=1
	for id in legacy.props.keys():
		if not id in SaveGame.LEGACY_PROPS: legacy.props.erase(id)
	for entry in legacy.npcs.values(): entry.erase("hp"); entry.erase("dead")
	check(SaveGame.valid(JSON.parse_string(JSON.stringify(legacy)),game),"旧版 JSON 数值类型兼容")
	check(SaveGame.restore(game,legacy),"旧版十件道具存档能迁移，新增家具默认生成")
	var kinds := {}
	for prop in game.props:
		if not kinds.has(prop.kind):
			prop.strike(Vector3.FORWARD,game.next_action())
			check(prop.damaged and prop.damage_parts[0].visible,"损坏必须可见："+prop.kind)
			if prop.kind=="desk": check(prop.mesh.global_position.y<0.3,"破坏后的桌面应落低，不能整体悬空")
			kinds[prop.kind]=true
	var keyboard=game.props[0]
	game.player.position=Vector3(0,0,18)
	game.player.yaw=0
	keyboard.position=Vector3(0,0.2,16.5)
	keyboard.linear_velocity=Vector3.ZERO
	for i in range(2): await physics_frame
	game.interact()
	check(game.player.inventory.has(keyboard) and game.player.held==null and not keyboard.visible,"E 应直接收进背包")
	game.player.collect(keyboard)
	check(game.player.inventory.count(keyboard)==1,"重复收纳不复制")
	game.player.cycle_item()
	check(game.player.held==keyboard and not game.player.inventory.has(keyboard),"背包可取出")
	game.player.release(false)
	check(keyboard.visible and not keyboard.freeze and game.player.held==null,"可放回物理世界")
	var data=SaveGame.snapshot(game)
	check(SaveGame.restore(game,data),"新版道具存档可恢复")
	for prop in game.props:
		if data.props[prop.stable_id].damaged: check(prop.damaged and prop.damage_parts[0].visible,"损坏读档可见")
	var invalid=data.duplicate(true)
	invalid.props.erase("a_desk_-7_-2")
	check(not SaveGame.valid(invalid,game),"新版缺失家具不能被静默忽略")
	print("PROPS_EXPANSION_TEST failures=",failures," props=",game.props.size())
	game.queue_free()
	await process_frame
	quit(failures)

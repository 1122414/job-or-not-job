extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var npc: OfficeNPC=game.npcs[0]
	game.player.position=Vector3(0,0,15)
	npc.hit(Vector3.RIGHT,0.65,game.next_action())
	check(npc.hp==84 and npc.down==0 and npc.hit_stun>0,"首次徒手轻击造成轻伤和踉跄，不直接放倒")
	for i in range(2): await physics_frame
	check(npc.visual.current=="recoil","轻击有独立受击动作")
	for i in range(24): await physics_frame
	check(npc.hit_stun==0 and not npc.dead,"轻击后恢复可行动")
	npc.visual.rotation.y=0
	npc.hit(Vector3.RIGHT,1.4,game.next_action())
	for i in range(20): await physics_frame
	check(npc.down>0 and npc.visual.rotation.z<0,"向右重击向右倾倒")
	check(npc.body_shape.position.x>0,"倒地碰撞位于身体倾倒侧")
	var saved := SaveGame.snapshot(game)
	check(SaveGame.restore(game,saved),"倒地状态可恢复")
	check(npc.fall_side==-1 and npc.visual.rotation.z<0,"读档保留倒地方向")
	saved.version=6
	for entry in saved.npcs.values():
		entry.erase("fall_side")
		entry.erase("facing")
	check(SaveGame.restore(game,saved),"v6旧档迁移缺失姿态字段")
	check(npc.fall_side==1,"旧档采用原先左侧倒地默认值")
	npc.visual.rotation.y=0
	npc.hit(Vector3.LEFT,5.0,game.next_action())
	check(npc.dead and npc.hp==0 and npc.fall_side==1,"反向致命重击保持死亡事实")
	await physics_frame
	check(npc.body_shape.position.x<0,"再次反向打击后倒地碰撞同步换侧")
	var malformed := SaveGame.snapshot(game)
	malformed.npcs[npc.stable_id].fall_side="left"
	check(not SaveGame.valid(malformed,game),"拒绝无效倒地方向类型")
	game.queue_free()
	await process_frame
	print("HIT_REACTION_TEST failures=",failures)
	quit(failures)

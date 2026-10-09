extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await physics_frame
	var npc: OfficeNPC=game.npc_for_role("a_hr")
	npc.position=Vector3(-14,0,0)
	game.player.position=npc.position+Vector3(0,0,.75)
	game.player.yaw=0
	for other in game.npcs: other.set_physics_process(false)
	game.player.attack()
	for i in range(34): await physics_frame
	check(npc.hp==88 and npc.down==0 and npc.velocity.y<=0,"徒手首击不倒地、不腾空")
	check(npc.hostile==0 and npc.reaction>0,"谨慎人物退避求助，不追打")
	for i in range(20):
		game.player.cooldown=0
		game.player.attack()
		for frame in range(34): await physics_frame
		if npc.care_state=="unconscious": break
	check(npc.hp==1 and not npc.dead and npc.care_state=="unconscious","连续徒手最多昏迷")
	for other in game.npcs: other.set_physics_process(true)
	var original: String=npc.stable_id
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,saved),"昏迷状态可存取")
	game.player.position=Vector3(0,0,10)
	for other in game.npcs: other.hostile=0; other.reaction=0
	var resumed_carry := false
	for i in range(2400):
		await physics_frame
		if npc.care_state=="carried" and not resumed_carry:
			resumed_carry=true
			check(SaveGame.restore(game,SaveGame.snapshot(game)),"搬运中读档仍可继续离场")
		if npc.care_state=="away": break
	check(resumed_carry,"实际经过搬运存取检查")
	check(npc.care_state=="away" and not npc.visible,"救助从入口抵达、搬运离场："+npc.care_state+str(npc.position)+str(npc.rescue_position))
	check(SaveGame.restore(game,SaveGame.snapshot(game)),"离场休养状态可存取")
	game.payroll.advance(maxi(0,npc.return_minute-game.payroll.minute),game.career.employer)
	game.care.tick(0)
	check(npc.available() and npc.visible and npc.stable_id==original and npc.affinity<0,"次日原人返岗、关系损伤保留")
	npc.hit(Vector3.FORWARD,5,game.next_action(),true)
	check(npc.hp==1 and not npc.dead and npc.care_state=="unconscious","危险伤害现在也最多暂时昏迷")
	preload("res://tests/legacy_damage_fixture.gd").npc(game,npc)
	var old: Dictionary=SaveGame.snapshot(game)
	old.version=7
	for entry in old.npcs.values():
		for key in ["care_state","care_elapsed","return_minute","rescue_position"]: entry.erase(key)
	check(SaveGame.restore(game,old) and npc.dead,"v7迁移保留原死亡事实")
	game.care.clear()
	game.queue_free()
	await process_frame
	print("NONLETHAL_CARE_TEST failures=",failures)
	quit(failures)

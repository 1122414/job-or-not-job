extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(3): await physics_frame
	game.player.position=Vector3(0,0,18)
	game.payroll.minute=9*60
	for i in range(game.npcs.size()):
		var npc=game.npcs[i]
		npc.position=Vector3((-14 if npc.company=="a" else 14)+3,0.05,-2.5*(i%6))
	for i in range(2000): await physics_frame
	for npc in game.npcs:
		check(Vector2(npc.position.x-npc.home.x,npc.position.z-npc.home.z).length()<0.6,"返岗不应卡住："+npc.stable_id+str(npc.position))
	var victim=game.npcs[0]
	for i in range(5): victim.hit(Vector3.FORWARD,1,game.next_action())
	preload("res://tests/legacy_damage_fixture.gd").npc(game,victim)
	check(victim.dead and victim.hp==0,"旧版死亡夹具保留死亡事实")
	for i in range(300): await physics_frame
	check(victim.dead and not victim.seated and victim.visual.current=="fallen","死亡不恢复坐班，使用独立倒地姿势")
	var data=SaveGame.snapshot(game)
	check(SaveGame.restore(game,data) and victim.dead,"死亡持久化")
	check(not game.career.facts.has("fatal_a") and game.career.conflict.b==0,"死亡不额外强制关闭岗位，也不污染另一公司")
	var invalid=data.duplicate(true)
	invalid.npcs.a_hr.hp=10
	check(not SaveGame.valid(invalid,game),"死亡与生命值矛盾的存档应拒绝")
	print("NPC_LIFECYCLE_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

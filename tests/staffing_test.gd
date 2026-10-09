extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	var original: OfficeNPC=game.npc_for_role("a_hr")
	original.hit(Vector3.FORWARD,5.0,game.next_action())
	preload("res://tests/legacy_damage_fixture.gd").npc(game,original)
	check(original.dead and game.career.conflict.a==1,"旧版死亡事件保留警告，不额外直接关职业线")
	for npc in game.npcs: npc.hostile=0; npc.reaction=0
	game.staffing.tick(29)
	check(game.npc_for_role("a_hr")==null,"平静不足30秒不生成替代人员")
	game.staffing.tick(1)
	var replacement: OfficeNPC=game.npc_for_role("a_hr")
	check(replacement!=null and replacement!=original and original.dead,"原人保持死亡，岗位由新人接手")
	check(replacement.affinity==0 and replacement.position.z>2,"新人从入口出现且不继承私人关系")
	check(OfficeDialogue.options(replacement,game.career).choices[0][1]=="interview_hr","岗位面试选项仍可继续")
	check(OfficeDialogue.options(replacement,game.career).text.begins_with(replacement.title.split(" · ")[0]),"接替者使用自己的名字，不冒充死者")
	var saved: Dictionary=SaveGame.snapshot(game)
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"新档可移除旧替代者")
	check(SaveGame.restore(game,saved),"读档可重建替代者与原死者")
	check(game.npc_for_role("a_hr").stable_id==replacement.stable_id,"接替岗位标识读档稳定")
	var duplicate := saved.duplicate(true)
	duplicate.npcs.a_hr.hp=100
	duplicate.npcs.a_hr.dead=false
	check(not SaveGame.valid(duplicate,game),"同岗位两个活人存档拒绝")
	game.queue_free()
	await process_frame
	print("STAFFING_TEST failures=",failures)
	quit(failures)

extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var people := {}
	for npc in game.npcs: people[npc.stable_id]=npc
	# Move this fixture to a clear public space to isolate stance from occlusion.
	var positions := {"a_boss":Vector3(0,0,16),"a_friend":Vector3(2,0,16),"a_hr":Vector3(-2,0,16),"a_guard":Vector3(0,0,18)}
	for id in positions:
		people[id].position=positions[id]
		people[id].home=positions[id]
	game.player.position=Vector3(0,0,20)
	await physics_frame
	game.on_aggression(people.a_boss,game.next_action())
	check(people.a_friend.mood.contains("解气"),"同事对老板受击有不同立场")
	check(people.a_guard.hostile>0,"保安介入")
	check(people.a_hr.mood.contains("紧张"),"普通目击者退避")
	check(people.b_friend.mood=="平静","远处另一家公司不全知")
	people.a_friend.affinity=100
	game.player.position=people.a_friend.position+Vector3(0,0,1.5)
	game.speaker=people.a_friend
	game.conversation=OfficeDialogue.options(people.a_friend,game.career)
	game.choose(0)
	check(not game.career.facts.has("output_one") and game.hud.toast.contains("不能造假"),"满好感仍不能伪造成果")
	game.career.former.append("a")
	game.payroll.minute=18*60
	people.a_friend.hostile=0
	game.speaker=people.a_friend
	game.conversation={"text":"下班交谈","choices":[["聊一聊","social"]]}
	game.choose(0)
	check(game.career.facts.has("a_friend_social"),"离职后仍可记录公共区人际互动")
	print("SOCIAL_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)

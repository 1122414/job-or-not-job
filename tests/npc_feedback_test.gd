extends "res://tests/attack_window_test.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(10);game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false);npc.position=Vector3(45,0,80)
	for person in game.population.residents: person.set_physics_process(false);person.position=Vector3(-45,0,80)
	victim=game.npc_for_role("a_hr")
	for style in ["strike","strike_left","push","kick"]:
		await reset(.75)
		game.player.next_left=style=="strike_left"
		game.player.attack(style if style in ["push","kick"] else "")
		check(game.player.strike_style==style,"动作选择 "+style)
		check(victim.hp==100,"抬手阶段不提前伤害 "+style)
		await frames(40)
		var damage := 6 if style=="push" else 19 if style=="kick" else 12
		check(victim.hp==100-damage,"真实接触且只命中一次 "+style+" hp="+str(victim.hp))
		await reset(2.5);game.player.attack(style if style in ["push","kick"] else "");await frames(40)
		check(victim.hp==100,"远处空挥不命中 "+style)
	await reset();victim.hit(Vector3.FORWARD,100,game.next_action(),true)
	check(victim.hp==1 and not victim.dead and victim.care_state=="unconscious","重物也不会永久杀死同事")
	var resident: CityResident=game.population.residents[0]
	resident.position=Vector3(5,0,60);resident.hit(Vector3.FORWARD,100,game.next_action(),true)
	check(resident.hp==1 and resident.down>0,"居民危险伤害暂时昏迷")
	game.story.start_new();await frames(3)
	var mentor: AutumnStoryPoint=game.story.points[0]
	mentor.position=Vector3(3,40,0);game.player.position=Vector3(3,40,.75);game.player.yaw=0;game.player.visual.rotation=Vector3.ZERO
	game.player.cooldown=0;game.player.next_left=false;await frames(4)
	var before := mentor.position
	game.player.attack();await frames(40)
	check(mentor.hp<100 and mentor.position.distance_to(before)>.05 and mentor.fear>0,"导师真实命中掉血、后退且留下戒心")
	check(game.story.data.phase=="campus_exit" and not game.story.data.call_done,"打击不批准实习")
	mentor.hit(Vector3.RIGHT,100,game.next_action(),true);await frames(12)
	check(mentor.hp==1 and mentor.down>0 and mentor.visual.current=="fallen","导师倒地有身体姿势且不会死亡")
	var saved := SaveGame.snapshot(game)
	check(SaveGame.valid(saved,game) and SaveGame.restore(game,saved),"导师受伤及关系可保存恢复")
	var relationship: int=mentor.affinity
	await frames(750)
	check(mentor.hp==35 and mentor.available() and mentor.affinity==relationship,"导师恢复清醒，不清除关系损伤")
	var bad := SaveGame.snapshot(game);bad.mentor.hp=0
	check(not SaveGame.restore(game,bad),"拒绝导师新档永久死亡")
	game.free_chat.api_key="test-not-a-real-key"
	check(not JSON.stringify(SaveGame.snapshot(game)).contains("test-not-a-real-key"),"密钥不进入存档")
	game.queue_free();await process_frame
	print("NPC_FEEDBACK_TEST failures=",failures);quit(failures)

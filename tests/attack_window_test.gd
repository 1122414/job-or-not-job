extends SceneTree

var failures := 0
var game: Node3D
var victim: OfficeNPC
var samples := []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message);failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func reset(distance: float=.75) -> void:
	game.player.cancel_strike();game.player.cooldown=0;game.player.protection=0
	game.player.hp=100;game.player.dead=0
	game.player.position=Vector3(0,0,61);game.player.yaw=0;game.player.visual.rotation=Vector3.ZERO;game.player.velocity=Vector3.ZERO;game.player.seated=false;game.player.visual.position=Vector3.ZERO
	victim.position=Vector3(0,0,61-distance)
	victim.hp=100;victim.dead=false;victim.care_state="awake";victim.down=0;victim.last_hit=-1;victim.block_time=0
	victim.sync_care()
	await frames(4)
func attack_input() -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new();event.action="attack";event.pressed=pressed
		game.player._unhandled_input(event)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(5)
	game.set_process(false)
	game.driving.set_physics_process(false);game.transit.set_physics_process(false)
	for npc in game.npcs:
		npc.set_physics_process(false);npc.position=Vector3(40+game.npcs.find(npc)*2,0,80)
	for person in game.population.residents:
		person.set_physics_process(false);person.position=Vector3(-40-person.index*2,0,80)
	victim=game.npc_for_role("a_hr")
	await reset()
	var bone_positions := []
	for i in game.player.visual.skeleton.get_bone_count():bone_positions.append(game.player.visual.skeleton.get_bone_pose_position(i))
	attack_input()
	check(victim.hp==100 and game.player.swing>0,"R30-A: input starts animation without immediate damage")
	var action_id: int=game.action_counter
	attack_input()
	check(game.action_counter==action_id,"R30-A: cooldown prevents restarting an active swing")
	var first_hit := -1.0
	for i in range(34):
		await frames(1)
		var phase: float=game.player.visual.animation.current_animation_position
		if victim.hp<100 and first_hit<0:first_hit=phase
		samples.append({"frame":i,"phase":phase,"hp":victim.hp,"pending":game.player.strike_action,"palm":SaveGame.vector(game.player.visual.contacts.palm("R").origin-game.player.position)})
		if i<3:check(victim.hp==100,"R30-A: wind-up remains harmless")
		if phase>=.15 and phase<=.25:
			var palm: Transform3D=game.player.visual.contacts.palm("R")
			for finger in range(2,6):
				var tip: int=game.player.visual.skeleton.find_bone("finger%d-3.R"%finger)
				var point: Vector3=palm.affine_inverse()*(game.player.visual.skeleton.global_transform*game.player.visual.skeleton.get_bone_global_pose(tip).origin)
				check(point.y<.075,"R30-B: punching fingers fold back towards the palm")
		for bone in bone_positions.size():check(game.player.visual.skeleton.get_bone_pose_position(bone).distance_to(bone_positions[bone])<.00001,"R30-B: solver preserves imported bone length")
	check(victim.hp==88 and first_hit>=.08 and first_hit<=.30,"R30-A: exactly one nonlethal contact in active phase: "+str(first_hit))
	var second: OfficeNPC=game.npc_for_role("a_group")
	await reset()
	victim.position.x=-.15;second.position=victim.position+Vector3(.55,0,0);second.hp=100;second.down=0;second.care_state="awake";second.block_time=0
	await frames(3);attack_input();await frames(34)
	check(int(victim.hp<100)+int(second.hp<100)==1,"R30-A: one primary target per swing")
	second.position=Vector3(42,0,80)
	for distance in [2.0,1.5]:
		await reset(distance);attack_input();await frames(34)
		check(victim.hp==100,"R30-B: former remote range now misses: "+str(distance))
	await reset();attack_input();victim.position.x=2;await frames(34)
	check(victim.hp==100,"R30-B: target can leave the stroke after input")
	await reset(2);attack_input();victim.position=Vector3(0,0,60.25);await frames(34)
	check(victim.hp==88,"R30-B: target entering the actual stroke can be hit")
	await reset();victim.position=Vector3(0,0,61.85);attack_input();await frames(34)
	check(victim.hp==100,"R30-B: a person behind the player is not selected")
	await reset();var wall=Shapes.solid(game,Vector3(1.5,2,.03),Vector3(0,1,60.58),Color.GRAY)
	await frames(3);attack_input();await frames(34)
	check(victim.hp==100,"R30-B: thin solid wall blocks the fist")
	wall.queue_free();await frames(3)
	await reset()
	var cup: OfficeProp
	for prop in game.props:
		if prop.kind=="cup":cup=prop;break
	cup.freeze=true;cup.position=Vector3(.20,1.14,60.48);cup.collision_layer=1;cup.durability=cup.max_durability()
	await frames(3);attack_input();check(cup.durability==cup.max_durability(),"R30-A: property durability unchanged at input")
	await frames(34)
	check(is_equal_approx(cup.durability,.6) and victim.hp==100,"R30-B: actual fist contacts the cup once and cannot hit through it")
	cup.position=cup.home;cup.thrown=false
	var keyboard: OfficeProp
	var monitor: OfficeProp
	for prop in game.props:
		if prop.kind=="keyboard":keyboard=prop
		if prop.kind=="monitor":monitor=prop
	for weapon in [keyboard,monitor]:
		await reset(.80);game.player.pick(weapon);await frames(4);attack_input()
		check(victim.hp==100,"R30-A: held weapon also waits for contact")
		await frames(34);check(victim.hp==88,"R30-B: held weapon can contact with nonlethal damage: "+weapon.kind)
		game.player.store_held()
	await reset(.80);game.player.pick(monitor);await frames(4)
	Input.action_press("dangerous");attack_input();Input.action_release("dangerous");await frames(34)
	check(victim.hp==66,"R30-A: explicit heavy dangerous swing keeps its input intent")
	game.player.store_held()
	for interruption in ["hurt","pick","sit","restore","turn","teleport","death","vehicle"]:
		await reset();attack_input()
		match interruption:
			"hurt":game.player.hurt(1)
			"pick":game.player.pick(keyboard)
			"sit":game.player.sit_at(Vector3(0,0,61))
			"restore":check(SaveGame.restore(game,SaveGame.snapshot(game)),"R30-C: mid-wind-up snapshot restores")
			"turn":game.player.yaw=PI
			"teleport":game.player.position+=Vector3(3,0,0)
			"death":game.player.hurt(100)
			"vehicle":game.driving.active=game.driving.car_for("car_office");game.player.seated=true
		await frames(34)
		check(victim.hp==100 and game.player.strike_action<0,"R30-C: interrupted swing never produces later damage: "+interruption)
		if game.player.held:game.player.store_held()
		if game.in_vehicle():game.driving.detach()
		if game.player.seated:game.player.stand_up()
	for interruption in ["release","store","replace"]:
		await reset();game.player.pick(keyboard);await frames(4);attack_input()
		match interruption:
			"release":game.player.release(false)
			"store":game.player.store_held()
			"replace":game.player.pick(monitor)
		await frames(34)
		check(victim.hp==100 and game.player.strike_action<0,"R30-C: equipment change cancels pending swing: "+interruption)
		if game.player.held:game.player.store_held()
	await reset();attack_input();paused=true
	var phase_before: float=game.player.visual.animation.current_animation_position
	await create_timer(.12,true,false,true).timeout
	check(victim.hp==100 and game.player.visual.animation.current_animation_position==phase_before,"R30-C: pause freezes pending swing")
	paused=false;await frames(34)
	check(victim.hp==88,"R30-C: resume produces one contact, not a repeated hit")
	check(not game.persistence_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"R30-C: fixture never writes player save or captures pointer")
	if "--evidence" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://build/attack-window-2026-10-01")
		FileAccess.open("res://build/attack-window-2026-10-01/attack-window.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"first_hit_phase":first_hit,"samples":samples},"  ")+"\n")
	game.audio.stop();game.queue_free();await process_frame
	print("ATTACK_WINDOW_TEST failures=",failures," first_hit_phase=",first_hit)
	quit(failures)

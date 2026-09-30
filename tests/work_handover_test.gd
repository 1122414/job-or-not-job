extends SceneTree
var failures := 0
var game: Node3D
var metres := 0.0
var max_step := 0.0
var contact_error := 0.0
var contact_samples := 0
var working_frames := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool,line: String) -> void:
	if not value: push_error(line);failures+=1

func decide(kind: String) -> void:
	check(SaveGame.restore(game,game.initial_state.duplicate(true)),"fresh branch")
	game.set_process(false)
	for action in ["interview_b","join_b"]: game.career.apply(action)
	game.career.facts["welcome_b"]=true
	game.recruitment.work["account_b"]=true
	game.payroll.minute=1080;game.player.position=Vector3(0,0,23)
	if kind=="negotiated":
		game.career.apply("negotiate")
		for key in [1,2,3,4,5,5,6,7]: game.projects.key(key)
		game.career.apply("settle");game.handover.decided("settle")
	else:
		game.career.apply("refuse");game.handover.decided("refuse")

func frames(count: int) -> void:
	var npc: OfficeNPC=game.npc_for_role("b_friend")
	var previous: Vector3=npc.position
	for i in range(count):
		await physics_frame
		var step: float=npc.position.distance_to(previous)
		metres+=step;max_step=maxf(max_step,step);previous=npc.position
		game.handover.tick(1.0/60)
		working_frames=working_frames+1 if game.handover.working(npc) and npc.visual.current=="terminal_work" else 0
		if working_frames>30:
			for side in ["L","R"]:
				contact_error=maxf(contact_error,npc.visual.contacts.palm(side).origin.distance_to(game.handover.station().position+Vector3(-.17 if side=="L" else .17,.965,.24)))
			contact_samples+=1

func boundary_cases() -> void:
	decide("refused")
	var npc: OfficeNPC=game.npc_for_role("b_friend")
	var obstacle := Shapes.solid(game,Vector3(1.4,2,1.4),game.handover.point()+Vector3(0,1,0),Color.GRAY)
	await physics_frame;game.walking.build(game)
	await frames(600)
	check(game.handover.data.elapsed==0 and not game.projects.state("b").sent,"blocked workstation cannot fabricate work")
	obstacle.queue_free();await physics_frame;game.walking.build(game)
	game.social.meet(npc)
	game.social.outing={"person":npc.stable_id,"kind":"walk","stage":"offered","elapsed":4.0}
	await frames(1)
	check(game.social.outing.is_empty(),"unaccepted invitation is not converted into a commitment")
	game.social.outing={"person":npc.stable_id,"kind":"walk","stage":"walking","elapsed":4.0,"venue":"garden"}
	var trust: int=game.social.state(npc).trust
	await frames(3000)
	check(game.handover.data.phase=="delivered" and game.social.outing.stage=="paused" and game.social.outing.venue=="garden" and game.social.state(npc).trust==trust,"work keeps private plan and trust")
	game.speaker=npc;game.social.handle("people_city_resume",npc)
	check(game.social.outing.stage=="walking","private plan resumes after delivery")
	decide("negotiated")
	game.career.apply("resign")
	game.advance_time(960)
	await frames(3000)
	check(game.career.employer=="" and game.handover.data.phase=="delivered","colleague fulfills agreement even after player resigns")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"resigned world with delivery remains valid")
	decide("negotiated")
	npc=game.npc_for_role("b_friend")
	game.advance_time(960)
	npc.hit(Vector3.RIGHT,10,game.next_action(),true)
	for i in range(180):await physics_frame;game.handover.tick(1.0/60)
	check(npc.dead and game.handover.data.elapsed==0 and not game.projects.state("b").sent,"dead colleague never completes work")
	for i in range(3600):
		await physics_frame;game.staffing.tick(1.0/60)
		if game.npc_for_role("b_friend")!=null:break
	var replacement: OfficeNPC=game.npc_for_role("b_friend")
	check(replacement!=null and replacement!=npc,"existing staffing supplies actual replacement")
	if replacement:
		await frames(3000)
		check(game.handover.data.phase=="delivered" and game.handover.data.sender==replacement.stable_id and npc.dead,"receipt names actual replacement, original stays dead")
		check(SaveGame.valid(SaveGame.snapshot(game),game),"replacement receipt and death facts remain saveable")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);root.set_disable_input(true)
	for i in range(10):await physics_frame
	decide("negotiated")
	check(game.handover.data.due_at==2040,"next day 10:00 is fixed at agreement")
	await frames(180)
	check(game.handover.data.elapsed==0 and not game.projects.state("b").sent,"tonight is free, no early delivery")
	game.advance_time(960)
	check(game.handover.data.elapsed==0,"calendar jump does not fabricate physical work")
	var npc: OfficeNPC=game.npc_for_role("b_friend")
	for i in range(2400):
		await frames(1)
		if game.handover.data.elapsed>2:break
	check(game.handover.data.elapsed>2,"colleague physically reaches terminal and works")
	check(npc.position.distance_to(game.handover.point())<.18,"working at actual terminal")
	for side in ["L","R"]:
		var palm: Vector3=npc.visual.contacts.palm(side).origin
		contact_error=maxf(contact_error,palm.distance_to(game.handover.station().position+Vector3(-.17 if side=="L" else .17,.965,.24)))
	check(contact_error<.02,"typing palms reach keyboard: "+str(contact_error)+" actor="+str(npc.position)+" pose="+npc.visual.current+" palms="+str([npc.visual.contacts.palm("L").origin,npc.visual.contacts.palm("R").origin]))
	var before: float=game.handover.data.elapsed
	game.speaker=npc;game.conversation={"text":"interruption","choices":[]}
	await frames(120)
	check(game.handover.data.elapsed==before,"conversation pauses actual work")
	check(game.handover.screen_text().contains("暂缓"),"terminal does not claim active work during conversation")
	game.close_interaction();npc.reaction=3
	await frames(60)
	check(game.handover.data.elapsed==before,"danger interrupts work")
	npc.reaction=0
	paused=true
	for i in range(10):await process_frame;game.handover.tick(1)
	check(game.handover.data.elapsed==before,"pause does not advance work")
	paused=false
	var path := "res://build/c3j/in-progress.json"
	DirAccess.make_dir_recursive_absolute("res://build/c3j")
	check(SaveGame.write(game,path)==OK,"in-progress disk save valid")
	check(SaveGame.restore(game,SaveGame.read(path,game)),"in-progress disk restore")
	check(is_equal_approx(game.handover.data.elapsed,before),"work progress restored")
	await frames(2400)
	check(game.handover.data.phase=="delivered" and game.projects.state("b").sent,"actual autonomous send completes: "+str(game.handover.data)+" position="+str(npc.position)+" point="+str(game.handover.point())+" facing="+str(npc.visual.rotation.y)+" owns="+str(game.handover.owns(npc))+" pose="+npc.visual.current+" velocity="+str(npc.velocity))
	check(game.career.b_event=="negotiated" and not game.career.facts.has("b_help"),"negotiation remains distinct from doing colleague's work")
	check(game.handover.data.sender==npc.stable_id and game.handover.data.completed_at==2040,"actual sender and date recorded")
	var sent: Dictionary=game.handover.data.duplicate(true)
	var messages: int=game.recruitment.messages.size()
	await frames(120)
	check(game.handover.data==sent and game.recruitment.messages.size()==messages,"receipt delivered once")
	check(game.home.memory_text().contains("已将完整交接包"),"home reflects real result")
	check(SaveGame.write(game,"res://build/c3j/completed.json")==OK,"completed disk save")
	check(not OfficeDialogue.options(npc,game.career).choices.any(func(c):return c[1] in ["help","negotiate"]),"completed work cannot be accepted again")
	decide("refused")
	npc=game.npc_for_role("b_friend")
	var affinity: int=npc.affinity
	await frames(3000)
	check(game.handover.data.phase=="delivered" and game.career.b_event=="refused","refusal permits colleague's own completed work")
	check(npc.affinity==affinity and not game.career.facts.has("b_help"),"no friendship penalty or false player credit")
	decide("refused")
	npc.hit(Vector3.RIGHT,.2,game.next_action(),false)
	check(game.handover.data.phase=="suspended" and game.career.b_event=="conflict","active conflict suspends original task")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"conflict remains saveable")
	await frames(200)
	check(not game.projects.state("b").sent,"conflict is not falsely marked delivered")
	await boundary_cases()
	check(max_step<.1,"routes do not teleport")
	check(contact_samples>1000 and contact_error<.02,"whole typing intervals maintain keyboard contact")
	print("WORK_HANDOVER_TEST failures=",failures," metres=",metres," max_step=",max_step," palm_error=",contact_error," contact_samples=",contact_samples)
	game.queue_free();await process_frame;quit(failures)

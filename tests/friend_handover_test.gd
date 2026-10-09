extends "res://tests/autumn_career_test.gd"

func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
		if not "--background" in OS.get_cmdline_user_args():
			push_error("Graphical friend test requires explicit --background mode");quit(2);return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

var world: Node3D
var baseline: Dictionary
var max_step := 0.0
var contacts := 0
var working_frames := 0
var palm_error := 0.0

func choose_action(action: String) -> bool:
	for i in range(world.conversation.get("choices",[]).size()):
		if world.conversation.choices[i][1]==action: world.choose(i);return true
	check(false,"missing real choice: "+action+" "+str(world.conversation));return false

func approach(person: OfficeNPC) -> void:
	# Boundary fixtures use an explicit nearby position; the entry and negotiation below use Driver.walk.
	world.close_interaction();world.player.position=person.position+Vector3(1.2,0,0)
	var direction: Vector3=person.position-world.player.position
	world.player.yaw=atan2(-direction.x,-direction.z)
	world.interact(person)

func frames(count: int) -> void:
	var npc: OfficeNPC=world.friend_handover.person()
	var previous: Vector3=npc.position
	for i in range(count):
		await physics_frame
		max_step=maxf(max_step,npc.position.distance_to(previous));previous=npc.position
		world.friend_handover.tick(1.0/60)
		if world.friend_handover.working(npc) and npc.visual.current=="terminal_work":
			working_frames+=1
			if working_frames>30:
				contacts+=1
				for side in ["L","R"]: palm_error=maxf(palm_error,npc.visual.contacts.palm(side).origin.distance_to(world.handover.station().position+Vector3(-.17 if side=="L" else .17,.965,.24)))

		else: working_frames=0

func restored() -> void:
	check(SaveGame.restore(world,baseline),"restore real-entry baseline")
	world.set_process(false)
	approach(world.friend_handover.person())

func no_job() -> void:
	check(world.career.employer=="" and world.career.grade=="求职者" and world.career.b_event=="none","friend event never grants employment/employee event")
	check(not world.recruitment.work.get("account_b",false) and world.office.assigned_desk()=="","no account or assigned workstation")
	check(world.payroll.pending.b==0 and world.payroll.balance==baseline.payroll.balance and world.handover.data.is_empty(),"no B wages or old handover result")
	check(not world.career.facts.has("b_help") and not world.recruitment.work.get("project_b",{}).get("sent",false),"no false player submission")
	check(SaveGame.valid(SaveGame.snapshot(world),world),"whole world remains valid")

func save_checks() -> void:
	var saved := SaveGame.snapshot(world)
	DirAccess.make_dir_recursive_absolute("res://build/friend-handover")
	check(SaveGame.write(world,"res://build/friend-handover/"+world.friend_handover.data.choice+".json")==OK,"actual friend event disk save")
	check(SaveGame.restore(world,JSON.parse_string(JSON.stringify(saved))),"actual friend state JSON restore")
	check(JSON.parse_string(JSON.stringify(world.friend_handover.data))==JSON.parse_string(JSON.stringify(saved.friend_handover)),"all friend fields survive JSON")
	for change in [["sender","player"],["elapsed",-1],["read",[0,0]],["read",[3]],["person","b_hr"],["phase","unknown"],["created_at",-1],["boss","a_boss"],["due_at",-20],["completed_at",world.payroll.minute+1]]:
		var bad: Dictionary=saved.duplicate(true);bad.friend_handover[change[0]]=change[1]
		check(not SaveGame.restore(world,bad),"reject bad friend field "+change[0])
		check(JSON.parse_string(JSON.stringify(world.friend_handover.data))==JSON.parse_string(JSON.stringify(saved.friend_handover)),"failed restore remains atomic")
	var old: Dictionary=baseline.duplicate(true);old.version=30;old.erase("friend_handover")
	check(SaveGame.restore(world,JSON.parse_string(JSON.stringify(old))) and world.friend_handover.data.is_empty(),"v30 does not invent a friend event")
	check(SaveGame.restore(world,saved),"restore completed current event")

func capture(game: Node3D,name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	if name=="03-ale-working":
		check(await Driver.walk(self,game,game.handover.point()+Vector3(1.8,0,1.2)),"walk to view Ale working")
		var direction: Vector3=game.friend_handover.person().position-game.player.position
		game.player.yaw=atan2(-direction.x,-direction.z)
	if name=="05-delivered": approach(game.friend_handover.person())
	for frame in range(5): await process_frame
	RenderingServer.force_draw(false)
	check(root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"background window guard")
	var folder := "res://docs/evidence/2026-10-09-friend-handover"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_viewport.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"save actual friend event image")

func run() -> void:
	capture_viewport=root
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
		var view := SubViewport.new();view.size=Vector2i(1280,800);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);capture_viewport=view
	world=load("res://scenes/main.tscn").instantiate();capture_viewport.add_child(world)
	root.set_disable_input(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	check(not world.persistence_enabled,"fixture cannot write player save")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from-route="):
			var saved := SaveGame.read(argument.trim_prefix("--from-route="),world)
			check(not saved.is_empty() and SaveGame.restore(world,saved),"independent process restores actual event save")
			check(world.friend_handover.data.get("phase")=="delivered" and world.friend_handover.data.sender=="b_friend" and world.career.employer=="","independent process preserves actual sender and unemployment")
			check(JSON.parse_string(JSON.stringify(world.friend_handover.data))==saved.get("friend_handover",{}),"all actual event fields preserved independently")
			print("FRIEND_HANDOVER_RESTORE failures=",failures)
			world.queue_free();await process_frame;quit(failures);return
	world.story.start_new();world.story.refuse()
	world.player.position=world.story.points[1].position+Vector3(0,0,-1.5)
	world.story.open(world.story.points[1]);world.choose(0)
	for step in [["b_hr","interview_b"],["rest","rest_next"],["b_friend","friend_open"]]:
		if not await perform(world,step[0],step[1]): check(false,"new story real entry "+str(step));finish(world);return
	check(world.recruitment.applications.b.phase=="rejected" and world.friend_handover.data.phase=="review","actual B rejection reaches optional friend event")
	await capture(world,"01-offer")
	world.friend_handover.handle("friend_check")
	check(world.friend_handover.data.phase=="review","cannot claim a checked package without reading")
	for i in range(3): choose_action("friend_read_"+str(i))
	await capture(world,"02-shared-deadline")
	world.close_interaction();baseline=SaveGame.snapshot(world);world.set_process(false)
	check(SaveGame.valid(baseline,world),"new entry baseline save valid")
	# Interrupted/blocked fixtures are separate from the continuous entry above.
	restored();choose_action("friend_negotiate");approach(world.friend_handover.person());choose_action("friend_pause")
	check(world.friend_handover.data.phase=="paused" and world.friend_handover.data.choice=="","pause is not a commitment")
	choose_action("friend_cancel");check(world.friend_handover.data.phase=="review" and world.friend_handover.data.boss=="","cancel releases meeting without accepting work")
	check(SaveGame.valid(SaveGame.snapshot(world),world),"cancelled accompaniment remains valid")
	restored();choose_action("friend_check");world.player.position=Vector3(0,0,23)
	var worker: OfficeNPC=world.friend_handover.person()
	var obstacle := Shapes.solid(world,Vector3(1.4,2,1.4),world.handover.point()+Vector3(0,1,0),Color.GRAY)
	await physics_frame;world.walking.build(world);await frames(600)
	check(world.friend_handover.data.elapsed==0,"blocked workstation cannot fabricate friend delivery")
	obstacle.queue_free();await physics_frame;world.walking.build(world)
	world.social.outing={"person":worker.stable_id,"kind":"walk","stage":"offered","elapsed":4.0}
	await frames(1);check(world.social.outing.is_empty(),"unaccepted invitation expires without becoming a commitment")
	world.social.outing={"person":worker.stable_id,"kind":"walk","stage":"walking","elapsed":4.0,"venue":"garden"}
	await frames(1);check(world.social.outing.stage=="paused" and world.social.outing.venue=="garden","accepted private plan is preserved")
	check(not world.friend_handover.owns(world.npc_for_role("b_hr")),"another employee cannot inherit personal request")
	worker.down=10;world.friend_handover.tick(100);check(world.friend_handover.data.elapsed==0,"incapacitated Ale cannot send")
	worker.down=0
	var pending_snapshot := SaveGame.snapshot(world)
	for key in ["friend_handover","mentor","free_chat"]:
		var bad: Dictionary=pending_snapshot.duplicate(true);bad.erase(key)
		check(not SaveGame.valid(bad,world),"v31 missing required field rejected: "+key)
	var future: Dictionary=pending_snapshot.duplicate(true);future.friend_handover.elapsed=1;future.friend_handover.due_at=world.payroll.minute+10
	check(not SaveGame.valid(future,world),"work before deadline rejected")
	# Help stops at material review; the employee performs the physical send.
	restored();choose_action("friend_check");no_job()
	world.player.position=Vector3(0,0,23)
	for i in range(2400):
		await frames(1)
		if world.friend_handover.data.elapsed>2: break
	check(world.friend_handover.data.elapsed>2,"Ale actually walks to terminal and works")
	await capture(world,"03-ale-working")
	var elapsed: float=world.friend_handover.data.elapsed
	world.speaker=world.friend_handover.person();await frames(60)
	check(world.friend_handover.data.elapsed==elapsed,"conversation interrupts sending")
	world.close_interaction();world.friend_handover.person().reaction=2;await frames(30)
	check(world.friend_handover.data.elapsed==elapsed,"danger interrupts sending")
	world.friend_handover.person().reaction=0
	paused=true
	world.friend_handover.tick(100)
	check(world.friend_handover.data.elapsed==elapsed,"pause cannot send")
	paused=false
	check(SaveGame.restore(world,JSON.parse_string(JSON.stringify(SaveGame.snapshot(world)))) ,"mid-work JSON resume")
	await frames(2000)
	check(world.friend_handover.data.phase=="delivered" and world.friend_handover.data.sender=="b_friend","actual sender is original Ale")
	var messages: int=world.recruitment.messages.size();await frames(60)
	check(world.recruitment.messages.size()==messages,"receipt once only")
	no_job();save_checks()
	# Refusing imposes no friendship loss and leaves the responsibility with Ale.
	restored();var affinity: int=world.friend_handover.person().affinity
	choose_action("friend_decline");world.player.position=Vector3(0,0,23)
	await frames(3000)
	check(world.friend_handover.data.phase=="delivered" and world.friend_handover.data.choice=="declined","refusal still leaves real independent work")
	check(world.friend_handover.person().affinity==affinity,"refusal does not deduct affinity")
	no_job();save_checks()
	# Negotiation waits for actual company-side presence and records a future arrangement.
	restored();choose_action("friend_negotiate")
	var npc: OfficeNPC=world.friend_handover.person()
	var b: OfficeNPC=world.friend_handover.boss()
	world.friend_handover.handle("friend_confirm")
	check(world.friend_handover.data.phase=="walking","remote confirmation rejected")
	world.advance_time(Payroll.DAY)
	check(world.friend_handover.data.phase=="paused","cross-day accompaniment pauses")
	approach(npc);choose_action("friend_resume")
	check(world.friend_handover.data.phase=="walking","explicit same-day resume")
	if not await perform(world,"b_boss","friend_confirm"): check(false,"walk to boss");finish(world);return
	for i in range(1200):
		if npc.position.distance_to(b.position)<3.5: break
		await frames(1)
	if world.friend_handover.data.phase=="walking":
		await capture(world,"04-confirmation")
		choose_action("friend_confirm")
	check(world.friend_handover.data.phase=="pending" and world.friend_handover.data.choice=="negotiated","both actually present before agreement")
	await capture(world,"04-negotiated")
	world.player.position=Vector3(0,0,23)
	await frames(60)
	check(world.friend_handover.data.elapsed==0,"no early work before due time")
	world.advance_time(world.friend_handover.data.due_at-world.payroll.minute)
	check(world.friend_handover.data.elapsed==0,"calendar jump cannot fake send")
	await frames(3000)
	check(world.friend_handover.data.phase=="delivered","next day actual autonomous delivery")
	no_job();save_checks()
	await capture(world,"05-delivered")
	world.advance_time(20*Payroll.DAY)
	check(not world.friend_handover.status().contains("明早") and not world.friend_handover.status().contains("昨晚"),"historical receipt never refers to a new tomorrow/yesterday")
	check(max_step<.1,"NPC movement never teleports")
	check(contacts>1000 and palm_error<.03,"actual typing palm contact "+str(palm_error))
	print("FRIEND_HANDOVER_TEST failures=",failures," max_step=",max_step," contacts=",contacts," palm_error=",palm_error)
	world.queue_free();await process_frame;quit(failures)

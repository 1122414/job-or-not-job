extends SceneTree
const Driver = preload("res://tests/scene_driver.gd")
var failures := 0
var evidence_dir := "res://docs/evidence/2026-09-22-route"
var capture_viewport: Viewport
func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.mode=Window.MODE_MINIMIZED
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("run")
func perform(game: Node3D,id: String,action: String) -> bool:
	if action=="no_hc" and game.story.active() and not game.story.review_ready():
		if not await perform(game,"rest","story_review_wait"): return false
	if action in ["join_a","join_b"]:
		var firm := action.trim_prefix("join_")
		if not await perform(game,"rest","rest_next"): return false
		game.panels.show_page("messages")
		game.recruitment.selected=firm
		game.recruitment.message_action(0)
		game.panels.back()
		if game.story.active() and game.story.data.phase=="mentor_call":
			if not await perform(game,"rest","story_call"): return false
			game.choose(1); game.choose(0)
		if not await perform(game,"rest","rest_next"): return false
		action="report_"+firm
	game.close_interaction()
	var target: Node3D=game.npc_for_role(id)
	if not target:
		for station in game.stations:
			if station.stable_id==id: target=station
	if not target: return false
	var reached := false
	# Try reachable approaches, preserving continuous player motion between them.
	for attempt in range(8):
		var offset := Vector3(sin(attempt*TAU/8),0,cos(attempt*TAU/8))*1.2
		if not await Driver.walk(self,game,target.position+offset): continue
		var toward: Vector3=target.position-game.player.position
		game.player.yaw=atan2(-toward.x,-toward.z)
		await physics_frame
		if game.nearest()==target:
			reached=true
			break
		# A slower walk lets a scheduled colleague arrive before the desk.
		# Answer the real interruption through its UI, then continue approaching.
		var nearby: Node3D=game.nearest()
		if nearby is OfficeNPC and not game.office.offer_for(nearby).is_empty():
			game.interact()
			for choice in range(game.conversation.get("choices",[]).size()):
				if game.conversation.choices[choice][1]=="visit_defer":
					game.choose(choice)
					break
			game.close_interaction()
	if not reached:
		push_error("完整路线无法接近 "+id+" player="+str(game.player.position)+" target="+str(target.position))
		return false
	game.interact()
	if not game.conversation.is_empty() and not game.conversation.choices.is_empty() and game.conversation.choices[0][1]=="visit_confirm":
		game.choose(0)
		if action in ["brief","no_hc"]:
			if action=="no_hc" and not game.conversation.is_empty(): game.choose(0)
			return true
		if game.conversation.is_empty(): game.interact()
	if game.conversation.is_empty():
		push_error("完整路线交谈中断："+id+" / "+action)
		return false
	for i in range(game.conversation.choices.size()):
		if game.conversation.choices[i][1]==action:
			if action=="settle":
				for frame in range(900):
					var companion: OfficeNPC=game.npc_for_role("b_friend")
					if companion and companion.position.distance_to(target.position)<3.8: break
					await physics_frame
			game.choose(i)
			if action in ["no_hc","transfer","defend"]: game.choose(0)
			if action.begins_with("report_"):
				game.choose(0)
				game.choose(0)
			if action in ["tour_begin","tour_greet"]:
				if not await Driver.follow(self,game,game.onboarding.guide(),game.onboarding.destination()): return false
				for frame in range(3): await physics_frame
			if action in InterviewFlow.ACTIONS: return await Driver.complete_interview(self,game,action)
			if action in ["prepare","handover","computer_open"]: return Driver.computer(game)
			return true
	push_error("完整路线选项缺失："+id+" / "+action+" "+str(game.conversation))
	return false
func run() -> void:
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.mode=Window.MODE_MINIMIZED
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): evidence_dir=argument.trim_prefix("--output=")
	var game=load("res://scenes/main.tscn").instantiate()
	capture_viewport=root
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1280,800)
		viewport.own_world_3d=true
		viewport.msaa_3d=Viewport.MSAA_2X
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.set_disable_input(true)
		root.add_child(viewport)
		capture_viewport=viewport
	capture_viewport.add_child(game)
	# Script drives input explicitly; desktop Escape/mouse events must not pause this fixture.
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10): await physics_frame
	if DisplayServer.get_name()!="headless":
		if root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
			push_error("Graphical route must remain minimized, unfocusable and pointer-free"); quit(1); return
		print("GRAPHICAL_BACKGROUND minimized=true unfocusable=true focused=false pointer_visible=true")
	var route := [["a_hr","interview_hr"],["a_lead","interview_lead"],["a_boss","interview_boss"],["a_hr","join_a"],["a_hr","tour_begin"],["a_hr","tour_greet"],["a_hr","tour_settle"],["desk_a","desk_open"],["a_hr","service_account"],["a_lead","brief"],["archive","data"],["desk_a","prepare"],["a_friend","shortcut"],["demo","submit"],["a_lead","no_hc"],["a_group","transfer"],["desk_a2","desk_open"],["backup","backup"],["a_boss","defend"],["a_hr","resign"],["b_hr","interview_b"],["b_hr","join_b"],["b_friend","tour_begin"],["b_friend","tour_greet"],["b_friend","tour_settle"],["desk_b","desk_open"],["b_hr","service_account"],["b_friend","help"],["handover","handover"]]
	var b_snapshot: Dictionary={}
	for step in route:
		print("ROUTE_STEP ",step)
		if not await perform(game,step[0],step[1]):
			failures+=1
			break
		if step[0]=="b_hr" and step[1]=="service_account": b_snapshot=SaveGame.snapshot(game)
		if DisplayServer.get_name()!="headless" and step[1] in ["interview_hr","join_a","prepare","submit","backup","defend","handover"]:
			DirAccess.make_dir_recursive_absolute(evidence_dir)
			paused=true
			for frame in range(3): await process_frame
			RenderingServer.force_draw()
			if capture_viewport.get_texture().get_image().save_png(evidence_dir.path_join(step[1]+".png"))!=OK: failures+=1
			paused=false
	if game.career.stage!=6 or game.career.b_event!="helped":
		push_error("最终职业状态不符 stage="+str(game.career.stage)+" B="+game.career.b_event)
		failures+=1
	if failures==0 and not SaveGame.restore(game,b_snapshot):
		push_error("B 分支存档恢复失败")
		failures+=1
	if failures==0:
		for step in [["b_friend","refuse"],["b_friend","negotiate"],["desk_b","computer_open"],["b_boss","settle"]]:
			print("ROUTE_BRANCH ",step)
			if not await perform(game,step[0],step[1]): failures+=1; break
		if game.career.b_event!="negotiated":
			push_error("协商未完成："+game.career.b_event+" proposal="+str(game.projects.state("b"))+" toast="+game.hud.toast)
			failures+=1
		SaveGame.restore(game,b_snapshot)
		game.npc_for_role("b_friend").hit(Vector3.FORWARD,0.65,game.next_action())
		if game.career.b_event!="conflict":
			push_error("冲突分支未触发："+game.career.b_event+" care="+game.npc_for_role("b_friend").care_state+" company="+str(game.career.conflict))
			failures+=1
	game.queue_free()
	if capture_viewport!=root: capture_viewport.queue_free()
	await process_frame
	print("FULL_ROUTE_TEST failures=",failures)
	quit(failures)

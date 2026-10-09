extends SceneTree
const Driver=preload("res://tests/scene_driver.gd")
var failures := 0
var capture_viewport: Viewport
var evidence_dir := ""
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message);failures+=1
func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): evidence_dir=argument.trim_prefix("--output=")
	call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless" or evidence_dir=="": return
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	paused=true
	for frame in range(3): await process_frame
	RenderingServer.force_draw()
	check(capture_viewport.get_texture().get_image().save_png(evidence_dir.path_join(name+".png"))==OK,"保存实际会面画面 "+name)
	paused=false
func json(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func choose(game: Node3D,action: String) -> bool:
	for i in range(game.conversation.get("choices",[]).size()):
		if game.conversation.choices[i][1]==action:
			game.choose(i);return true
	check(false,"真实对话缺少 "+action+" "+str(game.conversation));return false
func talk(game: Node3D,npc: OfficeNPC) -> bool:
	game.close_interaction()
	for attempt in range(8):
		var offset := Vector3(sin(attempt*TAU/8),0,cos(attempt*TAU/8))*1.2
		if not await Driver.walk(self,game,npc.position+offset): continue
		var d: Vector3=npc.position-game.player.position
		game.player.yaw=atan2(-d.x,-d.z)
		await physics_frame
		if game.nearest()!=npc: continue
		game.interact()
		return game.speaker==npc
	check(false,"连续行走无法接近 "+npc.stable_id+" player="+str(game.player.position)+" npc="+str(npc.position))
	return false
func click(game: Node3D,button: Button) -> void:
	game.panels.view.scroll.ensure_control_visible(button)
	for frame in range(5): await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		capture_viewport.push_input(event,true)
	for frame in range(3): await process_frame
func verify_life_buttons(game: Node3D) -> void:
	# The background fixture disables native input. Enable only this viewport for injected GUI events.
	capture_viewport.set_disable_input(false)
	for frame in range(5): await process_frame
	await click(game,game.panels.view.buttons["response-place-waterfront"])
	check(game.panels.page=="" and game.transit.waypoint=="waterfront","J实际鼠标选择海边后才开始导航")
	game.panels.show_page("city")
	for frame in range(5): await process_frame
	await click(game,game.panels.view.buttons["city-clear"])
	check(game.transit.waypoint=="" and game.story.response.state().guide=="","实际鼠标取消生活导航")
	game.advance_time(12*60);game.panels.show_page("journal")
	for frame in range(5): await process_frame
	check(game.panels.view.buttons.has("response-place-home") and not game.panels.view.buttons.has("response-place-bookshop"),"闭馆后呈现回家去处")
	await click(game,game.panels.view.buttons["response-place-home"])
	check(game.home.guiding and game.navigation_target()!=null,"实际鼠标选择回家导航")
	capture_viewport.set_disable_input(true)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	capture_viewport=root
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1280,800);viewport.own_world_3d=true
		viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.set_disable_input(true);root.add_child(viewport);capture_viewport=viewport
	capture_viewport.add_child(game);root.set_disable_input(true)
	for frame in range(10): await physics_frame
	var baseline: Dictionary=SaveGame.snapshot(game)
	# Domain fixture uses the supported pre-v29 current story; real 12-week route has its own integration test.
	game.story.start_new();game.story.data.placement=InternshipArc.blank();game.career.facts.erase("internship_extended")
	game.career.recruit.a=3;game.career.apply("join_a");game.story.joined();game.story.sync_scene()
	var boss: OfficeNPC=game.npc_for_role("a_boss")
	var witness: OfficeNPC=game.npc_for_role("a_group")
	var lead: OfficeNPC=game.npc_for_role("a_lead")
	for action in ["data","prepare","shortcut","submit"]: game.career.apply(action)
	game.advance_time(28*Payroll.DAY)
	game.promises.handle("no_hc",lead);game.promises.handle("transfer",witness);game.promises.handle("transfer_confirm",witness)
	game.career.apply("backup");game.promises.handle("defend",boss);game.promises.handle("defend_confirm",boss)
	check(game.conversation.text.contains("实习今天结束"),"初次答辩保持现场语境")
	var response: DepartureResponse=game.story.response
	check(SaveGame.valid(SaveGame.snapshot(game),game),"未转正夹具全档有效")
	var start: Dictionary=SaveGame.snapshot(game)
	game.advance_time(Payroll.DAY);game.story.show_verdict(boss)
	check(game.conversation.text.begins_with("回看结论") and not game.conversation.text.contains("实习今天"),"重看旧答辩明确历史，不改结局日期")
	check(SaveGame.restore(game,start),"恢复最终答辩前置")
	# Initial player placement is a fixture; all meeting travel below uses actual movement.
	game.player.position=boss.position+Vector3(0,0,2)
	game.close_interaction()
	for frame in range(5): await physics_frame
	if not await talk(game,boss):
		game.queue_free();await process_frame;quit(1);return
	choose(game,"story_response_menu");choose(game,"story_response_written")
	check(game.career.facts.has("review_written") and not response.state().written.is_empty(),"取得书面结论")
	await capture("01-written")
	var count: int=game.recruitment.promises.size()
	var balance: int=game.payroll.balance
	response.handle("story_response_written")
	check(game.recruitment.promises.size()==count and game.payroll.balance==balance and game.career.employer=="","重复索取不刷记录/工资/录用")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"书面结论全档有效")
	response.handle("story_response_request")
	check(response.state().meeting.get("phase")=="requested","提出请求不自动接受")
	game.speaker=boss;response.handle("story_response_invite")
	check(response.state().meeting.phase=="requested","错误人物不能代替见证者同意")
	game.social.meet(witness)
	if not await talk(game,witness):
		game.queue_free();await process_frame;quit(1);return
	var requested: Dictionary=SaveGame.snapshot(game)
	choose(game,"story_response_invite")
	var walking: Dictionary=SaveGame.snapshot(game)
	check(response.state().meeting.phase=="walking","见证者确认后两人才出发")
	var initial: Vector3=boss.position
	game.speaker=witness;response.handle("story_response_testify")
	check(not game.career.facts.has("review_testimony"),"未到场不能远程作证")
	game.close_interaction()
	check(await Driver.walk(self,game,response.station().position+Vector3(1,0,3.8)),"玩家实际走到成果旁")
	for frame in range(2400):
		if response.present(): break
		await physics_frame
	print("MEETING positions ",boss.position," / ",witness.position," player ",game.player.position," state ",response.state().meeting)
	check(boss.position.distance_to(initial)>3 and response.present(),"双方真实移动到场，没有传送")
	if response.present():
		game.player.yaw=atan2(-(witness.position-game.player.position).x,-(witness.position-game.player.position).z)
		await physics_frame;game.interact()
		check(game.speaker==witness,"两人邻近时面向见证者不会选中老板")
		choose(game,"story_response_testify")
		check(game.career.facts.has("review_testimony") and not game.career.facts.has("review_acknowledged"),"证言不代替老板回应")
		game.free_chat.attach(witness)
		check(JSON.stringify(game.free_chat.scene_facts()["本人已留下的原话"]).contains("不能把无名额写成成果不合格"),"实际到场后的本人证言可用于后续自由聊天")
		await capture("02-testimony")
		game.close_interaction()
		check(await talk(game,boss),"当面选择用工负责人")
		choose(game,"story_response_acknowledge")
		check(response.state().meeting.phase=="done" and game.career.facts.has("review_acknowledged"),"老板当面承认后才完成")
		check(game.career.employer=="" and not game.career.facts.has("a_regular"),"见证不偷偷改成转正")
		await capture("03-acknowledged")
		game.panels.show_page("journal");await capture("04-next-places")
		await verify_life_buttons(game)
		var done: Dictionary=SaveGame.snapshot(game)
		check(SaveGame.restore(game,json(done)),"见证结果JSON恢复")
		for kind in ["missing","future","person","quote","phase","fact"]:
			var bad: Dictionary=json(done)
			match kind:
				"missing": bad.autumn_story.erase("response")
				"future": bad.autumn_story.response.meeting.finished_at=bad.payroll.minute+1
				"person": bad.autumn_story.response.meeting.person=bad.autumn_story.response.meeting.boss
				"quote": bad.recruitment.promises.pop_back()
				"phase": bad.autumn_story.response.meeting.phase="walking"
				"fact": bad.career.facts.erase("review_written")
			var before: Dictionary=json(SaveGame.snapshot(game))
			check(not SaveGame.restore(game,bad) and json(SaveGame.snapshot(game))==before,"坏档原子拒绝 "+kind)
	# Branch fixtures below isolate interruption/ownership; they do not claim natural arrival.
	check(SaveGame.restore(game,json(walking)),"步行中的会面可恢复")
	game.advance_time(Payroll.DAY)
	check(response.state().meeting.phase=="paused" and not response.owns(witness),"跨日暂缓并释放人物")
	check(SaveGame.valid(SaveGame.snapshot(game),game),"跨日状态可保存")
	check(SaveGame.restore(game,json(walking)),"恢复后检查离场")
	game.player.position=Vector3(0,0,30);response.tick()
	check(response.state().meeting.phase=="paused","离开现场不会后台完成见证")
	check(SaveGame.restore(game,json(walking)),"恢复后检查冲突")
	witness.hit(Vector3.FORWARD,.65,game.next_action());response.tick()
	check(response.state().meeting.phase=="paused" and game.social.state(witness).fear>=20,"动手暂停会面并留下关系后果")
	check(not response.opportunities().any(func(item): return item.id=="person:"+witness.stable_id),"有戒心的人不推荐为自愿聊天对象")
	for stage in ["offered","walking"]:
		check(SaveGame.restore(game,json(requested)),"恢复邀请前状态")
		game.speaker=witness
		game.social.outing={"person":witness.stable_id,"kind":"tea","stage":stage,"elapsed":0.0}
		response.handle("story_response_invite")
		check(response.state().meeting.phase=="walking","存在私人约定时会面仍可开始")
		check(game.social.outing.is_empty() if stage=="offered" else game.social.outing.get("stage")=="paused","未答应邀请不升级，已接受约定保留 "+stage)
		response.cancel_meeting()
		check(not response.owns(witness) and response.target()==null and SaveGame.valid(SaveGame.snapshot(game),game),"取消会面释放人物/导航并可保存")
	check(SaveGame.restore(game,json(requested)),"恢复邀请前测试拒绝")
	game.speaker=witness;game.social.state(witness).fear=25
	var refused: Dictionary=json(response.state())
	response.handle("story_response_invite")
	check(json(response.state())==refused,"见证者拒绝时不留下伪造预约日期")
	check(SaveGame.restore(game,json(start)),"恢复生活选择测试")
	var nav: String=game.transit.waypoint
	check(response.opportunities().size()>=2 and game.transit.waypoint==nav,"列出生活去处不自动导航")
	response.choose_place("waterfront")
	check(game.transit.waypoint=="waterfront" and response.state().guide=="","主动选择才导航海边")
	check(SaveGame.restore(game,start),"恢复无回应状态")
	var old: Dictionary=json(start);old.version=29;old.autumn_story.erase("response")
	check(SaveGame.restore(game,old) and response.state().meeting.is_empty() and response.state().written.is_empty(),"v29不补造书面结论/证言")
	old.mentor.hp="bad"
	check(not SaveGame.valid(old,game),"v29导师校验仍严格")
	check(SaveGame.restore(game,baseline),"恢复隔离基线")
	game.queue_free()
	if capture_viewport!=root: capture_viewport.queue_free()
	await process_frame
	print("DEPARTURE_RESPONSE_TEST failures=",failures);quit(failures)

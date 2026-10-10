extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message);failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(6);game.set_process(false)
	var baseline := SaveGame.snapshot(game)
	game.story.start_new();game.story.refuse()
	game.player.position=game.story.points[1].position+Vector3(0,0,-1)
	game.interact(game.story.points[1]);game.choose(0)
	check(game.rental.required() and game.rental.state().started,"FB10-02 normal campus exit starts rental chapter")
	check(game.payroll.balance==1800000,"FB10-02 explicit moving savings granted once")
	game.rental.begin();check(game.payroll.balance==1800000,"FB10-02 repeated entry does not grant twice")
	game.interviews.schedule("interview_hr")
	check(game.interviews.sessions.is_empty() and game.panels.page=="rental","FB10-02 real interview entry cannot skip settling housing")
	check(not game.rental.sign_lease(false),"FB10-02 cannot sign unseen offers")
	game.panels.show_page("")
	for point in game.rental.points:
		game.player.position=point.position+Vector3(0,.05,1.5);game.player.yaw=0
		await frames(4)
		check(game.can_see(game.player,point),"FB10-02 rental sign visible at actual world location "+point.stable_id)
		check(game.nearest()==point,"FB10-02 facing sign selects rental point "+point.stable_id)
		game.interact()
		check(game.speaker==point and game.conversation.text.contains("押"),"FB10-02 actual viewing dialogue "+point.stable_id)
		game.choose(0)
		check(game.panels.page=="rental","FB10-02 viewing leads to comparison")
		game.panels.show_page("")
	check(game.rental.state().viewed.size()==3,"FB10-02 all real prices recorded")
	game.rental.guide("east")
	game.panels.show_page("city");game.panels.view.buttons["city-home"].pressed.emit()
	check(game.navigation_target()==game.home.entrance and game.rental.target()==null,"FB10-02 selecting home replaces rental navigation")
	game.rental.guide("river");game.panels.show_page("journal");game.panels.activate_key(KEY_1)
	check(game.rental.target()==null and game.career.facts.guide_company=="a","FB10-02 company selection replaces rental navigation")
	game.panels.show_page("")
	var pre_lease := SaveGame.snapshot(game)
	check(game.rental.sign_lease(false) and game.payroll.balance==120000,"FB10-02 three deposits plus first rent actually deducted")
	check(not game.rental.sign_lease(false) and game.payroll.balance==120000,"FB10-02 double click cannot charge twice")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
	check(SaveGame.valid(saved,game) and SaveGame.restore(game,saved),"FB10-02 lease JSON roundtrip")
	game.advance_time(RentalSearch.MONTH*2)
	check(game.payroll.balance==0 and game.rental.state().arrears==720000,"FB10-02 two months charge once, shortage recorded without negative balance")
	game.rental.tick();check(game.rental.state().arrears==720000,"FB10-02 repeated tick no duplicate rent")
	check(SaveGame.restore(game,pre_lease) and game.rental.sign_lease(true) and game.payroll.balance==880000,"FB10-02 alternative lower deposit costs higher monthly rent")
	for action in InterviewFlow.ACTIONS:
		var firm := "b" if action=="interview_b" else "a"
		game.interviews.schedule(action)
		check(game.interviews.pages(action).size()==6,"FB10-03 each new fixed round has six stages")
		var session: Dictionary=game.interviews.sessions[firm]
		var host: OfficeNPC=game.npc_for_role(InterviewFlow.HOSTS[action])
		host.position=OfficeRooms.point(game,firm,"interview_host");session.call_stage="room"
		game.speaker=host;game.interviews.handle("interview_seat_"+firm)
		check(game.player.seated and game.conversation.get("scene",false),"FB10-03 expanded interview retains physical seating")
		for i in range(6):
			game.interviews.handle("interview_answer_0");game.interviews.handle("interview_next")
		check(session.answers.size()==6 and session.step==6,"FB10-03 fixed six answers recorded")
		check(SaveGame.valid(SaveGame.snapshot(game),game),"FB10-03 extended cursor and promises valid "+action)
		game.close_interaction();game.player.stand_up()
	check(game.recruitment.promises.size()==4,"FB10-03 all four rounds record their real HC/role promises at new indices")
	var bad: Dictionary=saved.duplicate(true);bad.autumn_story.rental.deposit=-1
	check(not SaveGame.restore(game,bad),"FB10-02 malformed lease rejected")
	check(SaveGame.restore(game,baseline) and not game.rental.required(),"FB10-02 existing progress without rental is not forced backward")
	print("RENTAL_INTERVIEW_TEST failures=",failures)
	game.queue_free();await process_frame;quit(failures)

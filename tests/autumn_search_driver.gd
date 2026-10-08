extends RefCounted

static func press(game: Node3D,id: String,check: Callable) -> void:
	check.call(game.panels.view.buttons.has(id),"投递页面按钮存在："+id)
	if game.panels.view.buttons.has(id): game.panels.view.buttons[id].pressed.emit()

static func run(tree: SceneTree,game: Node3D,check: Callable,capture: Callable=Callable()) -> void:
	var search: AutumnSearch=game.story.search
	game.panels.show_page("search")
	for job in AutumnSearch.JOBS:
		for character in job.company: check.call(game.panels.view.theme.default_font.has_char(character.unicode_at(0)),"随包字体覆盖公司名："+character)
	for i in range(3):
		press(game,"search-job-"+str(i),check)
		press(game,"search-submit",check)
	check.call(search.records().size()==3,"三份真实投递，无自动生成申请")
	var sent: Dictionary=SaveGame.snapshot(game)
	search.submit()
	check.call(search.records()==sent.autumn_story.search,"重复投递不重置时间")
	game.panels.show_page("")
	game.advance_time(game.recruitment.next_time()-game.payroll.minute)
	check.call(search.state("ai").status=="cancelled" and search.state("experience").status=="invited","等待一天，取消与面试邀请分别出现")
	game.panels.show_page("search")
	press(game,"search-job-0",check)
	check.call(search.state("ai").body.contains("AI工具") and AutumnSearch.JOBS[0].listing.contains("招聘中"),"原招聘与后来取消同时保留")
	if capture.is_valid(): await capture.call(game,"01-ai-cancelled")
	press(game,"search-job-1",check)
	var invitation: Dictionary=SaveGame.snapshot(game)
	# Every response acknowledges the player's argument, with the same fixed no-offer outcome.
	for answer in range(3):
		check.call(SaveGame.restore(game,JSON.parse_string(JSON.stringify(invitation))),"邀请处JSON恢复")
		game.panels.show_page("search"); press(game,"search-job-1",check)
		press(game,"search-answer-"+str(answer),check)
		var reply: Dictionary=SaveGame.snapshot(game)
		check.call(SaveGame.restore(game,JSON.parse_string(JSON.stringify(reply))),"线上回答中断JSON恢复")
		game.panels.show_page("search"); press(game,"search-job-1",check)
		check.call(search.state("experience").reply==answer,"回复游标保留，不重复选择")
		press(game,"search-next",check)
		press(game,"search-answer-"+str(answer),check)
		press(game,"search-next",check)
		check.call(search.state("experience").status=="rejected" and search.state("experience").answers.size()==2,"三种态度均因经验门槛被拒，实际回应保留")
	if capture.is_valid(): await capture.call(game,"02-experience-rejected")
	game.panels.show_page("")
	game.advance_time(game.recruitment.next_time()-game.payroll.minute)
	check.call(search.state("silence").status=="silent" and not search.ready_to_end(),"三天无回复不等于已收到拒信或故事结束")
	game.panels.show_page("search"); press(game,"search-job-2",check)
	press(game,"search-followup",check)
	var follow_time: int=search.state("silence").due
	search.follow_up()
	check.call(search.state("silence").due==follow_time,"重复追问不延后时间")
	game.panels.show_page(""); game.advance_time(game.recruitment.next_time()-game.payroll.minute)
	check.call(search.state("silence").status=="silent_final" and not search.ready_to_end(),"未查看最后状态不自动结束故事")
	game.panels.show_page("search"); press(game,"search-job-2",check)
	check.call(search.ready_to_end() and search.state("silence").body.contains("不是一封拒信"),"明确无人回应，不能伪造拒信")
	if capture.is_valid(): await capture.call(game,"03-still-no-response")
	press(game,"search-finish",check)
	check.call(game.story.data.phase=="ending" and game.career.employer=="" and game.career.facts.has("autumn_no_offer"),"主线停在没有工作，无逆袭或保底录用")
	if capture.is_valid(): await capture.call(game,"04-no-offer-ending")
	var end: Dictionary=SaveGame.snapshot(game)
	check.call(SaveGame.restore(game,JSON.parse_string(JSON.stringify(end))),"完整结尾JSON恢复")
	game.panels.show_page("")
	game.advance_time(Payroll.DAY*7)
	check.call(game.story.data.phase=="ending" and game.career.employer=="" and game.career.records==end.career.records,"继续生活一周不凭空录用，不重复结算剧情")
	for id in ["ai","experience","silence"]:
		for key in ["status","due","answers","seen"]:
			var bad: Dictionary=SaveGame.snapshot(game); bad.autumn_story.search[id][key]=null
			var original: Dictionary=game.story.data.duplicate(true)
			check.call(not SaveGame.restore(game,bad) and game.story.data==original,"坏投递档原子拒绝："+id+"/"+key)
	var forged: Dictionary=end.duplicate(true);forged.autumn_story.search.erase("ai")
	check.call(not SaveGame.restore(game,forged),"缺少实际投递结果不能伪造结尾")
	check.call(SaveGame.restore(game,end),"恢复真实结尾")
	game.panels.show_page("")
	game.speaker=game.npc_for_role("a_boss")
	game.story.career_action("story_verdict")
	check.call(game.story.data.phase=="ending","结尾重访老板不倒退到领取证明章节")
	game.story.career_action("story_verdict_result")
	check.call(game.conversation.text.contains("成果没有问题") and game.story.data.phase=="ending","重看原解释保留结尾和业务通过事实")
	game.close_interaction()
	for i in range(3): await tree.physics_frame

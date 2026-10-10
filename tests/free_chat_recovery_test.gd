extends "res://tests/free_chat_test.gd"

func envelope(content: String,reason: String="stop") -> Dictionary:
	return {"choices":[{"finish_reason":reason,"message":{"content":content}}]}

func parsed(content: String,reason: String="stop") -> Dictionary:
	return FreeChat.parse_reply(JSON.stringify(envelope(content,reason)).to_utf8_buffer())

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10): await physics_frame
	game.story.start_new()
	var mentor: AutumnStoryPoint=game.story.points[0]
	game.player.position=mentor.position+Vector3(0,0,1)
	var chat: FreeChat=game.free_chat
	var port := 18503
	while port<18513 and server.listen(port,"127.0.0.1")!=OK: port+=1
	check(port<18513,"恢复测试HTTP服务启动")
	if port>=18513: quit(1);return
	chat.configure("http://127.0.0.1:%d/v1/chat/completions"%port,"fixture-model","")
	chat.open(mentor)
	chat.apply_reply(answer,"你在狗叫什么")
	var payload := chat.payload("好好谈，你再跟老子好好谈吗")
	var history := JSON.new()
	check(history.parse(payload.messages[2].content)==OK and history.data is Dictionary,"CHAT01 历史assistant保持JSON格式")
	check(payload.max_tokens>=1400,"CHAT03 输出预算容纳中文台词及JSON")
	var local_endpoint := chat.endpoint
	chat.endpoint=FreeChat.DEFAULT_ENDPOINT
	var cloud_payload := chat.payload("你在狗叫什么")
	check(cloud_payload.response_format.type=="json_object" and cloud_payload.thinking.type=="disabled","官方端点维持JSON模式与非思考模式")
	chat.endpoint=local_endpoint
	for content in ['{"reply":"先把话说清楚。"}', '```\n{"reply":"先把话说清楚。"}\n```', '```json{"reply":"先把话说清楚。"}```', '{"reply":"先把话说清楚。","affinity":2}']:
		var reply := parsed(content)
		check(reply.get("reply")=="先把话说清楚。" and reply.get("affinity")==0 and reply.get("trust")==0,"CHAT02 完整台词缺关系字段仍可显示，零增量")
	for content in ['{"reply":"答应了。","command":"hire"}', '{"reply":"答应了。","trust":3}', '{"reply":"答应了。","affinity":"2"}', '{"reply":"答应了。","attitude":"unknown"}', '{"reply":""}', '普通文本', '{"reply":"未闭合']:
		check(parsed(content).is_empty(),"CHAT02 非法数据不作为有效回答："+content)
	check(parsed(JSON.stringify(answer),"length").is_empty(),"CHAT03 截断即使有JSON也不直接应用")
	# Finish baseline assertions before exercising recovery added by this repair.
	if failures>0:
		chat.close();server.stop();game.queue_free();await process_frame
		print("FREE_CHAT_RECOVERY_TEST baseline failures=",failures);quit(failures);return
	var saved := SaveGame.snapshot(game)
	for reason in ["empty","length","invalid","missing_metadata"]:
		check(SaveGame.restore(game,saved),"恢复独立初始档")
		chat.open(mentor)
		var body := envelope("")
		if reason=="length": body=envelope('{"reply":"未完',"length")
		if reason=="invalid": body=envelope("not json")
		if reason=="missing_metadata": body=envelope('{"reply":"公司实习和论文安排要讲清楚。"}')
		queued_responses=[body,envelope(JSON.stringify(answer))] if reason!="missing_metadata" else [body]
		var before := requests.size()
		var liking := mentor.affinity
		check(chat.send("我自己在公司做啊，你在狗叫什么"),"截图输入实际发送")
		await until_done(chat)
		check(not chat.pending and chat.records[mentor.stable_id].history.size()==2,"CHAT03 恢复只记一次历史："+reason)
		check(requests.size()-before==(1 if reason=="missing_metadata" else 2),"CHAT03 格式失败最多重试一次："+reason)
		check(mentor.affinity==liking+(0 if reason=="missing_metadata" else 1),"CHAT02/03 不重复改变关系："+reason)
		check(game.story.data==saved.autumn_story and SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)==saved.career,"自动恢复及缺字段不改变剧情或职业")
		if reason=="missing_metadata": check(chat.records[mentor.stable_id].attitude=="guarded","缺字段不抹掉原态度")
		check(chat.draft=="" and game.hud.chat_reply.text.contains("导师"),"恢复后显示台词并清草稿")
		if reason!="missing_metadata":
			check(requests[-1].messages[-1].content=="我自己在公司做啊，你在狗叫什么","重试保留原问题")
			check(requests[-1].messages[0].content.contains("重新"),"重试追加格式纠正说明")
	check(SaveGame.restore(game,saved),"恢复耗尽测试基线");chat.open(mentor)
	queued_responses=[envelope(""),envelope("", "length")]
	var before := requests.size()
	chat.send("好好谈，你再跟老子好好谈吗");await until_done(chat)
	check(not chat.pending and requests.size()==before+2 and chat.notice.contains("截断"),"CHAT03 耗尽后停止并区分截断")
	check(chat.draft=="好好谈，你再跟老子好好谈吗" and chat.records[mentor.stable_id].history.size()==1 and mentor.affinity==saved.mentor.affinity,"失败保留输入且不改历史关系")
	# Cancel while the second request is waiting; late success must not apply.
	queued_responses=[envelope("")];chat.send("等待修复时取消")
	before=requests.size()
	var deadline := Time.get_ticks_msec()+4000
	while requests.size()==before and Time.get_ticks_msec()<deadline: serve();await process_frame
	mode="wait"
	while requests.size()<before+2 and Time.get_ticks_msec()<deadline: serve();await process_frame
	check(chat.pending and requests.size()==before+2,"自动重试已进入等待")
	var token := chat.serial
	chat.cancel()
	chat.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(envelope(JSON.stringify(answer))).to_utf8_buffer(),token)
	check(not chat.pending and chat.records[mentor.stable_id].history.size()==1,"取消使自动重试迟到回复失效")
	mode="unauthorized";before=requests.size();chat.send("认证错误不重试");await until_done(chat)
	check(requests.size()==before+1 and chat.notice.contains("401"),"401不自动重试")
	mode="ok";queued_responses=[envelope("","content_filter")];before=requests.size()
	chat.send("服务拒绝本轮");await until_done(chat)
	check(requests.size()==before+1 and chat.notice.contains("未提供"),"服务过滤不自动重试，不伪造台词")
	for action in ["restore","branch"]:
		check(SaveGame.restore(game,saved),"重试边界恢复基线");chat.open(mentor)
		mode="ok";queued_responses=[envelope("")];before=requests.size();chat.send("重试期间更换场景")
		deadline=Time.get_ticks_msec()+4000
		while requests.size()==before and Time.get_ticks_msec()<deadline: serve();await process_frame
		mode="wait"
		while requests.size()<before+2 and Time.get_ticks_msec()<deadline: serve();await process_frame
		check(chat.pending and requests.size()==before+2,"读档/剧情切换前自动重试已发送")
		token=chat.serial
		if action=="restore": check(SaveGame.restore(game,saved),"自动重试中读档成功")
		else: game.choose(0)
		chat.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(envelope(JSON.stringify(answer))).to_utf8_buffer(),token)
		check(not chat.pending and chat.records[mentor.stable_id].history.size()==1 and chat.reply_text=="","自动重试迟到不污染"+action)
	chat.close();server.stop();game.queue_free();await process_frame
	print("FREE_CHAT_RECOVERY_TEST failures=",failures);quit(failures)

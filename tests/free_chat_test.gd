extends SceneTree
var failures := 0
var game: Node3D
var server := TCPServer.new()
var peer: StreamPeerTCP
var received := PackedByteArray()
var requests: Array=[]
var answer := {"reply":"刚才的事让我有些不安，我们慢慢说。","attitude":"guarded","affinity":1,"trust":1}
var mode := "ok"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: push_error(message);failures+=1
func serve() -> void:
	if server.is_connection_available(): peer=server.take_connection();received=PackedByteArray()
	if not is_instance_valid(peer): return
	peer.poll()
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED: peer=null;return
	if peer.get_available_bytes()>0: received.append_array(peer.get_data(peer.get_available_bytes())[1])
	var raw := received.get_string_from_utf8()
	if not "\r\n\r\n" in raw: return
	var split := raw.find("\r\n\r\n")
	var expected := 0
	for line in raw.left(split).split("\r\n"):
		if line.to_lower().begins_with("content-length:"): expected=int(line.get_slice(":",1))
	var body := raw.substr(split+4)
	if body.to_utf8_buffer().size()<expected: return
	requests.append(JSON.parse_string(body));received=PackedByteArray()
	if mode=="wait": return
	var data := {"choices":[{"finish_reason":"stop","message":{"content":JSON.stringify(answer)}}]}
	var content := "bad json" if mode=="bad" else JSON.stringify(data)
	var status := "401 Unauthorized" if mode=="unauthorized" else "200 OK"
	peer.put_data(("HTTP/1.1 "+status+"\r\nContent-Type: application/json\r\nContent-Length: "+str(content.to_utf8_buffer().size())+"\r\nConnection: close\r\n\r\n"+content).to_utf8_buffer())
	peer=null
func until_done(chat: FreeChat) -> void:
	var deadline := Time.get_ticks_msec()+4000
	while chat.pending and Time.get_ticks_msec()<deadline:
		serve();await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10): await physics_frame
	game.story.start_new()
	var mentor: AutumnStoryPoint=game.story.points[0]
	game.player.position=mentor.position+Vector3(0,0,1)
	var chat: FreeChat=game.free_chat
	var port := 18463
	while port<18473 and server.listen(port,"127.0.0.1")!=OK: port+=1
	check(port<18473,"隔离HTTP测试服务启动")
	if port>=18473: quit(1);return
	check(chat.configure("http://127.0.0.1:%d/v1/chat/completions"%port,"fixture-model",""),"本地兼容端点可配置")
	for url in ["http://example.com/chat/completions","https://user:secret@example.com/chat/completions","file:///tmp/key"]:
		check(not FreeChat.valid_endpoint(url),"拒绝不安全地址 "+url)
	chat.open(mentor)
	check(paused and game.panels.page=="free_chat","自由输入暂停世界")
	var input: TextEdit=game.panels.view.body.get_node("FreeChatInput")
	input.grab_focus()
	var key := InputEventKey.new();key.physical_keycode=KEY_N;key.keycode=KEY_N;key.unicode=110;key.pressed=true
	root.push_input(key);await process_frame
	check(game.panels.page=="free_chat" and input.text.contains("n"),"输入N进入文字框，不打开招聘消息")
	key.pressed=false;root.push_input(key)
	var story: Dictionary=game.story.data.duplicate(true)
	var career := SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)
	check(chat.send("老师，我想解释一下实习安排。"),"真实HTTP请求发出")
	check(not chat.send("重复发送"),"等待时不重复请求")
	await until_done(chat)
	check(not chat.pending and chat.records.has(mentor.stable_id),"兼容服务返回已应用 "+chat.notice)
	check(requests.size()==1 and requests[0].model=="fixture-model" and requests[0].messages[-1].content.contains("实习安排"),"发送正确模型和当前玩家文字")
	check(mentor.affinity==1 and mentor.trust==1,"仅有限关系更新")
	check(game.story.data==story and SaveGame.fields(game.career,SaveGame.CAREER_FIELDS)==career,"LLM不能改剧情或职业事实")
	for invalid in [answer.merged({"command":"approve_internship"}),answer.merged({"trust":3},true),answer.merged({"reply":"字".repeat(501)},true)]:
		var envelope := {"choices":[{"finish_reason":"stop","message":{"content":JSON.stringify(invalid)}}]}
		check(FreeChat.parse_reply(JSON.stringify(envelope).to_utf8_buffer()).is_empty(),"额外命令/越界数值/超长回答拒绝")
	var saved := SaveGame.snapshot(game)
	check(SaveGame.restore(game,saved) and game.free_chat.records[mentor.stable_id].history.size()==1,"真实聊天记忆读档恢复")
	chat.open(mentor);mode="bad";check(chat.send("坏格式测试"),"发起坏格式请求");await until_done(chat)
	check(chat.records[mentor.stable_id].history.size()==1 and chat.notice.contains("格式"),"坏JSON不改关系/记忆")
	mode="unauthorized";chat.send("认证失败测试");await until_done(chat)
	check(chat.notice.contains("401") and chat.records[mentor.stable_id].history.size()==1,"认证失败可回退且不暴露原始响应")
	mode="wait";chat.send("等待取消");var token: int=chat.serial
	for i in range(10): serve();await process_frame
	chat.cancel()
	chat.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"choices":[{"finish_reason":"stop","message":{"content":JSON.stringify(answer)}}]}).to_utf8_buffer(),token)
	check(chat.records[mentor.stable_id].history.size()==1,"取消后的迟到回复不得写入")
	mode="wait";chat.send("超时回退测试");chat.request.timeout=.1
	await until_done(chat)
	check(not chat.pending and chat.notice.contains("超时") and chat.records[mentor.stable_id].history.size()==1,"超时不修改关系，可继续交谈")
	mode="wait";chat.send("读档前请求");token=chat.serial
	check(SaveGame.restore(game,saved),"等待中恢复存档")
	chat.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"choices":[{"finish_reason":"stop","message":{"content":JSON.stringify(answer)}}]}).to_utf8_buffer(),token)
	check(chat.records[mentor.stable_id].history.size()==1 and not chat.pending,"读档后的迟到回复失效")
	chat.open(mentor);mode="ok";mentor.hit(Vector3.RIGHT,.5,game.next_action(),false)
	chat.open(mentor);chat.send("对不起，我们能重新谈吗？");await until_done(chat)
	check(mentor.trust<=-19 and mentor.fear>0,"一句道歉不抹掉攻击经历")
	for i in range(6):
		chat.send("继续讨论第%d次"%i);await until_done(chat)
	check(chat.records[mentor.stable_id].history.size()<=8 and chat.records[mentor.stable_id].changes<=3,"记忆有上限，关系变动每日限额")
	var malformed := SaveGame.snapshot(game);malformed.free_chat[mentor.stable_id].history[0].reply=[]
	check(not SaveGame.restore(game,malformed),"非法对话档原子拒绝")
	var legacy := saved.duplicate(true);legacy.version=27;legacy.erase("mentor");legacy.erase("free_chat")
	check(SaveGame.restore(game,legacy) and chat.records.is_empty() and mentor.hp==100,"v27无新字段存档可迁移，主线保留")
	chat.open(mentor)
	var fixed: Button=game.panels.view.buttons.get("chat_fixed")
	check(is_instance_valid(fixed),"保留固定选项按钮")
	if is_instance_valid(fixed):
		fixed.pressed.emit()
		check(game.panels.page=="" and game.speaker==mentor,"返回原交谈对象的固定选项")
	game.panels.show_page("");server.stop();game.queue_free();await process_frame
	print("FREE_CHAT_TEST failures=",failures);quit(failures)

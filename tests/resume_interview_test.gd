extends "res://tests/free_chat_test.gd"

func wait_ai() -> void:
	var deadline := Time.get_ticks_msec()+4500
	while game.interview_ai.pending and Time.get_ticks_msec()<deadline:
		serve();await process_frame

func seat() -> void:
	game.panels.show_page("")
	var host: OfficeNPC=game.npc_for_role("a_hr")
	host.position=OfficeRooms.point(game,"a","interview_host")
	game.interviews.sessions.a.call_stage="room"
	game.interviews.handle("interview_seat_a")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(8): await physics_frame
	game.set_process(false)
	game.story.start_new();game.story.data.phase="early_autumn";game.story.sync_scene()
	game.player.position=OfficeRooms.point(game,"a","interview_seat")
	game.interviews.schedule("interview_hr")
	var host: OfficeNPC=game.npc_for_role("a_hr")
	host.position=OfficeRooms.point(game,"a","interview_host");game.interviews.sessions.a.call_stage="room"
	for station in game.stations:
		if station.stable_id=="interview_a": game.interact(station)
	check(game.conversation.choices.size()==3,"FB10-03 normal room offers resume interview mode")
	game.choose(1)
	check(game.panels.page=="interview_setup","FB10-03 actual room selection opens local resume preview")
	var ai: InterviewAI=game.interview_ai
	var profile := "我负责一个离线演示项目，用Python整理实验数据，为三个版本建立对照测试和来源记录。项目中遇到环境差异，我独立实现了可重复运行的检查脚本。"
	var path := "/tmp/resume-fixture-"+str(Time.get_ticks_usec())+".txt"
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(profile);file.close()
	ai.import_file(path)
	check(ai.resume_text==profile and not ai.pending,"FB10-03 import local, no request before explicit send")
	DirAccess.remove_absolute(path)
	var zip_path := path+".docx"
	var zip := ZIPPacker.new();zip.open(zip_path);zip.start_file("word/document.xml")
	zip.write_file(("<w:document xmlns:w=\"x\"><w:body><w:p><w:r><w:t>"+profile+"</w:t></w:r></w:p></w:body></w:document>").to_utf8_buffer());zip.close_file();zip.close()
	check(ResumeImport.read(zip_path).get("text")==profile,"FB10-03 DOCX text extracted locally")
	var bytes := FileAccess.get_file_as_bytes(zip_path)
	for at in range(bytes.size()-46):
		if bytes.decode_u32(at)==0x02014b50: bytes.encode_u32(at+24,900000000);break
	check(not ResumeImport.bounded_docx(bytes),"FB10-03 oversized decompressed XML rejected before inflation")
	DirAccess.remove_absolute(zip_path)
	check(not ResumeImport.bounded_docx(PackedByteArray([1,2,3])),"FB10-03 malformed archive rejected")
	var port := 18503
	while port<18513 and server.listen(port,"127.0.0.1")!=OK: port+=1
	check(port<18513,"FB10-03 isolated model fixture server")
	if port>=18513: quit(1);return
	game.free_chat.configure("http://127.0.0.1:%d/v1/chat/completions"%port,"interview-fixture","")
	answer={"questions":["你在离线演示项目里独立负责什么？","三个版本怎么验证差异？","环境差异是如何定位的？","客户临时加需求你会怎么处理？","你会向面试官反问哪些岗位条件？"]}
	ai.generate();await wait_ai()
	check(game.interviews.sessions.a.has("ai") and requests.size()==1,"FB10-03 real HTTP generates five resume questions")
	if not game.interviews.sessions.a.has("ai"): game.queue_free();await process_frame;quit(1);return
	check(requests[0].messages[1].content.contains(profile),"FB10-03 only explicit generation includes resume")
	check(not JSON.stringify(SaveGame.snapshot(game)).contains(profile),"FB10-03 raw resume not stored in game save")
	seat();await process_frame
	check(game.player.seated and game.conversation.get("ai_interview",false) and ai.panel.visible,"FB10-03 AI questions remain in seated scene")
	ai.input.grab_focus();await process_frame
	var event := InputEventKey.new();event.keycode=KEY_N;event.physical_keycode=KEY_N;event.unicode=110;event.pressed=true
	root.push_input(event);await process_frame;event.pressed=false;root.push_input(event)
	check(paused and game.panels.page=="" and ai.input.text.contains("n"),"FB10-03 answer field owns shortcut keys")
	ai.input.clear()
	for character in "项目验证":
		event=InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true
		root.push_input(event);await process_frame;event.pressed=false;root.push_input(event)
	check(ai.input.text=="项目验证","FB10-03 Chinese characters reach answer field (not an OS IME test)")
	ai.input.clear()
	for i in range(4): ai.input.text="我负责对照测试，保留来源、版本和可复现步骤。";ai.submit()
	var midpoint := SaveGame.snapshot(game)
	check(SaveGame.valid(midpoint,game),"FB10-03 mid-interview save valid")
	ai.input.text="尚未提交的旧草稿"
	check(SaveGame.restore(game,JSON.parse_string(JSON.stringify(midpoint))),"FB10-03 mid-interview JSON restores")
	check(game.interviews.sessions.a.ai.answers.size()==4,"FB10-03 four answers preserved, no fabricated answers")
	seat()
	check(ai.input.text=="","FB10-03 restore and resume do not carry an old unsent draft")
	mode="bad";ai.input.text="我会问清职责、工资和转正标准。";ai.submit();await wait_ai()
	check(game.interviews.sessions.a.ai.result=="" and game.career.recruit.a==0,"FB10-03 malformed service response is not interview failure or career advancement")
	mode="ok";answer={"passed":false,"reason":"证据不够具体，需要解释验证方法。","feedback":["贡献需要具体化","应解释差异","需要定位步骤","应说明优先级","反问有边界意识"]}
	ai.judge();await wait_ai()
	check(game.interviews.sessions.a.ai.result=="failed","FB10-03 actual model rejection applied")
	ai.complete();check(game.career.recruit.a==0 and game.interviews.sessions.a.status=="completed","FB10-03 failed interview does not grant internship")
	# Reapplying is allowed; successful judgement advances the same career gate once.
	game.interviews.schedule("interview_hr")
	game.interviews.sessions.a.ai={"questions":midpoint.interviews.a.ai.questions,"answers":[],"feedback":[],"result":"","reason":""}
	seat();answer.passed=true;answer.reason="能够说明个人贡献和验证路径，本轮通过。"
	for i in range(5): ai.input.text="我用三个版本的输入输出对照定位环境差异，保留了可重现记录。";ai.submit()
	await wait_ai();check(game.interviews.sessions.a.ai.result=="passed","FB10-03 actual model pass applied")
	var accepted := SaveGame.snapshot(game)
	check(SaveGame.valid(accepted,game),"FB10-03 successful assessment can save before acknowledgement")
	ai.complete();ai.complete()
	check(game.career.recruit.a==1 and game.career.employer=="" and game.recruitment.promises.size()==1,"FB10-03 acknowledgement advances once and records actual role terms")
	check(not game.career.facts.has("regular"),"FB10-03 AI cannot grant final HC or permanent employment")
	var bad := accepted.duplicate(true);bad.interviews.a.ai.answers=[]
	check(not SaveGame.restore(game,bad),"FB10-03 outcome without five answers rejected")
	game.interviews.schedule("interview_lead");ai.prepare("a")
	mode="wait";ai.generate();var token := ai.serial
	game.panels.show_page("")
	ai.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"choices":[{"message":{"content":JSON.stringify({"questions":midpoint.interviews.a.ai.questions})}}]}).to_utf8_buffer(),token,"a","interview_lead")
	check(not game.interviews.sessions.a.has("ai"),"FB10-03 late reply after leaving cannot replace the session")
	mode="wait";ai.timeout_seconds=.05;ai.prepare("a");ai.generate();await wait_ai()
	check(not ai.pending and not game.interviews.sessions.a.has("ai"),"FB10-03 timeout keeps fixed route available")
	server.stop();game.queue_free();await process_frame
	print("RESUME_INTERVIEW_TEST failures=",failures);quit(failures)

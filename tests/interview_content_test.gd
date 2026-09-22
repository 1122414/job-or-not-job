extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.set_disable_input(true)
	await physics_frame
	for action in InterviewFlow.ACTIONS:
		var firm := "b" if action=="interview_b" else "a"
		game.interviews.schedule(action)
		check(game.interviews.pages(action).size()==3,"每轮三个核心段落："+action)
		game.interviews.sessions[firm].answers=[InterviewContent.FOLLOW[action][0]]
		check(game.interviews.pages(action).size()==4,"实际提出问题才增加追问："+action)
		for item in game.interviews.pages(action):
			check(item[1].size()<=3 and item[1].size()==item[2].size(),"选择与结果一一对应且最多三项")
			for line in InterviewFlow.segments(item[0]): check(line.length()<=46,"字幕分段上限")
	game.interviews.sessions={"a":{"action":"interview_hr","step":5,"status":"scheduled","phase":"reply","answers":["旧1","旧2","旧3","旧4","旧5","旧6"],"reply":2}}
	var old: Dictionary=SaveGame.snapshot(game)
	old.version=10; old.erase("recruitment")
	check(SaveGame.restore(game,old),"旧六页交流迁移")
	check(game.interviews.sessions.a.step==3 and game.interviews.sessions.a.phase=="question","旧已完成核心内容不要求重做")
	check(str(game.career.records).contains("旧6"),"旧完整回答保留在记录，不截断历史")
	game.queue_free()
	await process_frame
	print("INTERVIEW_CONTENT_TEST failures=",failures)
	quit(failures)

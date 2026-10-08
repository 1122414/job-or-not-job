extends SceneTree
var failures := 0
var capture_view: Viewport
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.mode=Window.MODE_MINIMIZED
	call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(10): await physics_frame
	paused=true
	for frame in range(3): await process_frame
	RenderingServer.force_draw()
	var folder := "res://docs/evidence/2026-10-08-autumn-prologue"
	DirAccess.make_dir_recursive_absolute(folder)
	check(capture_view.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"图形证据保存")
	paused=false
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	capture_view=root
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1280,800); viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.set_disable_input(true); root.add_child(viewport); capture_view=viewport
	capture_view.add_child(game)
	root.set_disable_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for frame in range(10): await physics_frame
	var base: Dictionary=SaveGame.snapshot(game)
	for answer in range(3):
		check(SaveGame.restore(game,base),"恢复独立夹具")
		game.story.start_new()
		check(game.story.campus() and game.player.position==AutumnStory.CAMPUS_SPAWN,"新故事在学校出生")
		game.player.yaw=0
		Input.action_press("forward")
		for frame in range(35): await physics_frame
		Input.action_release("forward")
		check(game.nearest()==game.story.points[0],"真实移动后可选中导师，桌子不遮交互")
		game.interact()
		check(game.conversation.text.contains("那个年代"),"真实E入口开启争辩")
		if answer==0: await capture("01-mentor")
		game.choose(answer)
		if answer==0: await capture("02-reply")
		var midway: Dictionary=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
		check(SaveGame.restore(game,midway),"回答中间JSON恢复")
		game.interact()
		check(game.story.data.reply==answer and game.conversation.text==AutumnStory.MENTOR_LINES[0][2][answer],"恢复原回答而非重新选题")
		for beat in range(3):
			if beat>0: game.choose(answer)
			game.choose(0)
		check(game.story.data.phase=="campus_exit" and game.career.facts.has("mentor_refused"),"三种态度均固定拒绝")
		check(game.story.data.answers.size()==3,"不伪造或重复回答")
		game.player.yaw=PI
		Input.action_press("forward")
		for frame in range(240):
			if game.player.position.z>=5.6: break
			await physics_frame
		Input.action_release("forward")
		game.player.yaw=PI
		await physics_frame
		check(game.nearest()==game.story.points[1],"玩家走出办公室到走廊："+str(game.player.position)+" / "+str(game.nearest()))
		game.interact()
		if answer==0: await capture("03-corridor")
		game.choose(0)
		if answer==0: await capture("04-autumn")
		check(game.story.data.phase=="early_autumn" and not game.story.room.visible,"确认离校后才进入秋招")
		check(Vector2(game.player.position.x,game.player.position.z).distance_to(Vector2(AutumnStory.STREET_SPAWN.x,AutumnStory.STREET_SPAWN.z))<.1 and game.player.position.y>=-.1 and game.player.position.y<1 and game.career.employer=="","应届求职者街区出生，无凭空录用")
		check(SaveGame.valid(SaveGame.snapshot(game),game),"每条态度路线结束可保存")
	check(SaveGame.restore(game,base),"恢复测试基线")
	game.story.start_new()
	game.story.points[0].hit(Vector3.FORWARD,.5,1)
	check(game.story.data.phase=="campus_exit" and game.story.data.mentor_interrupted,"冲突结束争辩但不批准实习")
	var good: Dictionary=SaveGame.snapshot(game)
	for key in ["phase","beat","reply","answers","mode","mentor_interrupted"]:
		var bad:=good.duplicate(true); bad.autumn_story[key]=null
		check(not SaveGame.restore(game,bad),"非法章节原子拒绝："+key)
		check(game.story.data==good.autumn_story,"坏档未部分修改")
	var legacy:=base.duplicate(true); legacy.version=25; legacy.erase("autumn_story")
	legacy.career.stage=6; legacy.career.grade="正式员工"; legacy.career.facts["regular"]=true
	check(SaveGame.restore(game,legacy) and not game.story.active() and game.career.facts.has("regular"),"旧已转正档保留，不强制改写前史")
	game.queue_free(); await process_frame
	print("AUTUMN_PROLOGUE_TEST failures=",failures)
	quit(failures)

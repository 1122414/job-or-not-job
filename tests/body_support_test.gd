extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var npc: OfficeNPC=game.npcs[0]
	npc.position=Vector3(0,0,16)
	npc.home=npc.position
	npc.role="guard"
	var keyboard: OfficeProp=game.props[0]
	keyboard.position=npc.position+Vector3(0.04,2.2,0.27)
	for i in range(180): await physics_frame
	check(keyboard.position.y<0.6,"键盘不能停在人体外观外的方形碰撞体边角")
	keyboard.position=npc.position+Vector3(0,2.1,0)
	keyboard.rotation=Vector3.ZERO
	keyboard.linear_velocity=Vector3.ZERO
	keyboard.angular_velocity=Vector3.ZERO
	keyboard.sleeping=false
	for i in range(120): await physics_frame
	check(keyboard.position.y>1.5,"回归夹具应先让物品接触站立人物顶部")
	npc.down=10
	for i in range(180): await physics_frame
	check(keyboard.position.y<0.6,"人物倒地后，键盘不能被不可见的站立碰撞体托在空中")
	print("BODY_SUPPORT_TEST failures=",failures," final_height=",keyboard.position.y)
	game.queue_free()
	await process_frame
	quit(failures)

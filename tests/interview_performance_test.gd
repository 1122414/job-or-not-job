extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value: push_error(message); failures+=1
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 root.set_disable_input(true)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for i in range(10): await physics_frame
 game.interviews.schedule("interview_b")
 var host: OfficeNPC=game.npc_for_role("b_hr")
 host.position=OfficeRooms.INTERVIEW_HOSTS.b
 game.player.position=OfficeRooms.INTERVIEW_SEATS.b
 game.speaker=host
 game.interviews.handle("interview_seat_b")
 var box: Node3D=game.get_node("InterviewBoxB")
 var phone: Node3D=game.get_node("InterviewPhoneB")
 check(box.position.distance_to(OfficeRooms.B_BOX_START)<0.05,"纸箱存在于桌面侧边")
 check(not game.conversation.text.contains("把旁边椅子上的纸箱搬开"),"字幕仅显示讲话，不叙述未演出的动作")
 game.interviews.sessions.b.step=2
 game.conversation=game.interviews.question("b")
 for i in range(95): await physics_frame
 check(host.visual.current=="box_message","第三段触发独立骨骼演出")
 check(box.position.distance_to(OfficeRooms.B_BOX_FLOOR)<0.08,"纸箱从桌面滑落到桌下")
 check(host.visual.scene_phone.visible and not phone.visible,"手机随手部动作拿起，桌面手机不复制")
 for i in range(220): await physics_frame
 check(phone.visible and not host.visual.scene_phone.visible,"语音动作结束后手机回到桌面")
 game.career.conflict.b=2
 game.interviews.tick()
 check(game.conversation.is_empty() and not game.interviews.sessions.has("b"),"招聘关闭时中止正在进行的面试")
 check(not game.interviews.room_options("b").choices.size(),"冲突后面试室不继续提供选择")
 game.interviews.schedule("interview_lead")
 var lead: OfficeNPC=game.npc_for_role("a_lead")
 lead.position=OfficeRooms.INTERVIEW_HOSTS.a
 game.player.position=OfficeRooms.INTERVIEW_SEATS.a
 game.speaker=lead
 game.interviews.handle("interview_seat_a")
 check(game.player.seated and game.interviews.active_firm()=="a","A 公司面试确实落座并进入现场")
 game.interviews.sessions.a.step=1
 game.conversation=game.interviews.question("a")
 var a_phone: Node3D=game.get_node("InterviewPhoneA")
 for i in range(65): await physics_frame
 check(lead.visual.current=="phone_reply" and lead.visual.scene_phone.visible and not a_phone.visible,"A 公司面试官拿起手机，桌面物件同步隐藏")
 game.interviews.interrupt()
 for i in range(3): await physics_frame
 check(a_phone.visible and not lead.visual.scene_phone.visible,"离场中断后手机回到桌面")
 game.queue_free()
 await process_frame
 print("INTERVIEW_PERFORMANCE_TEST failures=",failures)
 quit(failures)

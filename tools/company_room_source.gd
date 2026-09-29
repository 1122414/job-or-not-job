extends RefCounted

# Initial authored-room source. Runtime loads the reviewed scenes, never this builder.
static func build(game: Node3D, firm: String) -> void:
	var center := 0.0
	var accent := Color("416b77") if firm=="a" else Color("a76e46")
	# A normal-width doorway, no raised threshold; glass preserves indoor sightlines.
	for side in [-1,1]:
		OfficeRooms.glazing(game,Vector3(center+side*2.1,1.5,2),Vector3(2.0,3.0,0.08))
		Shapes.solid(game,Vector3(0.10,3.0,0.12),Vector3(center+side*1.07,1.5,2),Color("37444b"))
	Shapes.box(game,Vector3(3.1,0.12,1.6),Vector3(center,3.2,2.55),accent)
	OfficeRooms.plaque(game,"规程科技  /  接待" if firm=="a" else "自己人网络  /  招聘",Vector3(center,2.75,2.15),3.8)
	var reception: Vector3=Vector3(-2.2,0,0)
	Shapes.solid(game,Vector3(1.5,0.92,0.65),reception+Vector3(0,0.46,0),Color("737b78"))
	Shapes.box(game,Vector3(1.58,0.045,0.74),reception+Vector3(0,0.945,0),Color("c8bda5"))
	Shapes.box(game,Vector3(1.4,0.42,0.015),reception+Vector3(0,0.65,0.34),accent)
	OfficeRooms.plaque(game,"招聘接待",reception+Vector3(0,0.65,0.39),1.0)
	var desk_lamp := preload("res://scenes/props/reception_lamp.tscn").instantiate() as StaticBody3D
	desk_lamp.name="ReceptionLamp"+firm.to_upper()
	game.add_child(desk_lamp)
	# The source is a clamp lamp: its origin mounts on the back edge, below the top.
	desk_lamp.position=reception+Vector3(-0.52,0.9675,-0.37)
	desk_lamp.rotation.y=PI
	# Waiting furniture leaves the entrance axis and all desk aisles open.
	for side in [-1,1]:
		var waiting_chair := preload("res://scenes/props/waiting_chair.tscn").instantiate() as StaticBody3D
		waiting_chair.name="WaitingChair"+firm.to_upper()+str(side)
		game.add_child(waiting_chair)
		waiting_chair.position=Vector3(center+4+side*0.47,0.012,1.2)
		waiting_chair.rotation.y=PI
	# Interview room at the rear left. The two-metre doorway faces the public aisle.
	var room_x := center-7
	OfficeRooms.glazing(game,Vector3(room_x-3.1,1.5,-12.3),Vector3(3.2,3.0,0.07))
	OfficeRooms.glazing(game,Vector3(room_x+2.75,1.5,-12.3),Vector3(2.5,3.0,0.07))
	Shapes.solid(game,Vector3(0.10,3.0,3.6),Vector3(room_x+4.05,1.5,-14.2),Color("b2b2a7"))
	OfficeRooms.plaque(game,"01  面试室",Vector3(room_x-2.35,2.7,-12.25),1.8)
	Shapes.solid(game,Vector3(2.0,0.08,0.85),Vector3(room_x,0.75,-14.15),Color("b3a185"))
	for side in [-1,1]: Shapes.solid(game,Vector3(0.08,0.71,0.65),Vector3(room_x+side*0.78,0.355,-14.15),Color("465157"))
	# Wall treatment and a small working surface make this a meeting room, not a blank box.
	var wall_panel := Shapes.box(game,Vector3(4.5,1.15,0.05),Vector3(room_x,1.95,-15.74),accent)
	wall_panel.material_override=OfficeDress.fabric(accent)
	OfficeRooms.plaque(game,"规程科技" if firm=="a" else "自己人网络",Vector3(room_x,2.0,-15.66),1.8)
	for i in range(9):
		var slat := Shapes.box(game,Vector3(0.075,2.6,0.04),Vector3(room_x-3.3+i*0.12,1.45,-15.72),Color("aa9575"))
		slat.material_override=OfficeDress.wood(Color("aa9575"))
	Shapes.box(game,Vector3(0.38,0.022,0.28),Vector3(room_x+0.55,0.81,-14.15),Color("37414b"))
	Shapes.box(game,Vector3(0.34,0.005,0.25),Vector3(room_x+0.55,0.825,-14.15),Color("ddd9cb"))
	Shapes.box(game,Vector3(0.015,0.012,0.2),Vector3(room_x+0.78,0.80,-14.1),Color("28313c"))
	# Objects stay on the 0.79 m tabletop; no new collision crosses the approach.
	var phone_holder := Node3D.new()
	phone_holder.name="InterviewPhoneB" if firm=="b" else "InterviewPhoneA"
	game.add_child(phone_holder)
	phone_holder.position=Vector3(room_x+0.22,0.798,-14.42)
	var phone := Shapes.box(phone_holder,Vector3(0.075,0.014,0.14),Vector3.ZERO,Color("19242c"))
	phone.rotation.y=0.12
	Shapes.box(phone_holder,Vector3(0.060,0.002,0.12),Vector3(0,0.009,0),Color("6f9297"))
	var resume := Shapes.label(game,"个人简历\n项目经历  /  交付记录",Vector3(room_x-0.34,0.832,-14.02),24)
	resume.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	resume.rotation.x=-PI/2
	resume.pixel_size=0.0017
	resume.modulate=Color("343c43")
	resume.outline_size=0
	var interview_light := OmniLight3D.new()
	game.add_child(interview_light)
	interview_light.position=Vector3(room_x,2.5,-14.2)
	interview_light.light_color=Color("e6f0f4") if firm=="a" else Color("ffddb6")
	interview_light.light_energy=0.55
	interview_light.omni_range=3.2
	var waiting_sign := Node3D.new()
	game.add_child(waiting_sign)
	waiting_sign.position=Vector3(center+4,1.8,1.80)
	waiting_sign.rotation.y=PI
	OfficeRooms.plaque(waiting_sign,"招聘 · 正式项目岗位 / 急招" if firm=="a" else "招同事 / 有事一起扛",Vector3.ZERO,3.4)
	if firm=="b":
		var box := Node3D.new()
		box.name="InterviewBoxB"
		game.add_child(box)
		box.position=Vector3(-6.45,0.88,-14.48)
		Shapes.box(box,Vector3(0.38,0.24,0.29),Vector3.ZERO,Color("98714c"))
		Shapes.box(box,Vector3(0.34,0.025,0.27),Vector3(0,0.132,0),Color("d9d0b9"))
	OfficeDress.chair(game,Vector3(-7,0,-13.15))
	var host_chair := Node3D.new()
	game.add_child(host_chair)
	host_chair.position=Vector3(-7,0,-15)
	host_chair.rotation.y=PI
	OfficeDress.chair(host_chair,Vector3.ZERO)
	if firm=="a":
		var papers := Node3D.new()
		papers.name="InterviewPapersA"
		game.add_child(papers)
		papers.position=Vector3(room_x-0.4,0.80,-14.0)
		for i in range(2): Shapes.box(papers,Vector3(0.21,0.008,0.29),Vector3(i*0.02,i*0.009,0),Color("e7e2d7"))
		var top_page := Shapes.box(papers,Vector3(0.21,0.008,0.29),Vector3(0.04,0.018,0),Color("e7e2d7"))
		top_page.name="TopPage"
	else:
		for i in range(3): Shapes.box(game,Vector3(0.21,0.008,0.29),Vector3(room_x-0.4+i*0.02,0.80+i*0.009,-14.0),Color("e7e2d7"))
	OfficeRooms.plaque(game,"会议 / 交付" if firm=="a" else "讨论 / 交接",Vector3(center+0.5,2.4,-15.72),2.1)
	# Lit entry draws the eye from the street without adding floating instructions.
	var light := OmniLight3D.new()
	game.add_child(light)
	light.position=Vector3(center,2.55,0.8)
	light.light_color=Color("e5efff") if firm=="a" else Color("ffe4bf")
	light.light_energy=0.65
	light.omni_range=4.5

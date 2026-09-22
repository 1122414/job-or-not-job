class_name OfficeRooms
extends RefCounted

const INTERVIEW_SEATS := {"a":Vector3(-21,0,-13.15),"b":Vector3(7,0,-13.15)}
const INTERVIEW_HOSTS := {"a":Vector3(-21,0,-15.0),"b":Vector3(7,0,-15.0)}
const RECEPTIONS := {"a":Vector3(-16.2,0,0),"b":Vector3(11.8,0,0)}

static func plaque(parent: Node3D,text: String,pos: Vector3,width: float=1.8) -> void:
	Shapes.box(parent,Vector3(width,0.42,0.055),pos,Color("233038"))
	var label := Shapes.label(parent,text,pos+Vector3(0,0,0.035),32)
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	label.pixel_size=0.0028
	label.outline_size=0
	label.modulate=Color("f0ece3")

static func glazing(game: Node3D,pos: Vector3,size: Vector3) -> void:
	var wall := Shapes.solid(game,size,pos,Color("a0b2b5"))
	var glass := Shapes.material(Color(0.51,0.65,0.68,0.22))
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness=0.17
	wall.get_child(0).material_override=glass
	for y in [-size.y/2,size.y/2]:
		Shapes.box(game,Vector3(size.x+0.04,0.045,size.z+0.04),pos+Vector3(0,y,0),Color("3b454a"))
	for x in [-size.x/2,size.x/2]:
		Shapes.box(game,Vector3(0.045,size.y,size.z+0.04),pos+Vector3(x,0,0),Color("3b454a"))

static func build(game: Node3D) -> void:
	for firm in ["a","b"]:
		var center := -14.0 if firm=="a" else 14.0
		var accent := Color("416b77") if firm=="a" else Color("a76e46")
		# A normal-width doorway, no raised threshold; glass preserves indoor sightlines.
		for side in [-1,1]:
			glazing(game,Vector3(center+side*2.1,1.5,2),Vector3(2.0,3.0,0.08))
			Shapes.solid(game,Vector3(0.10,3.0,0.12),Vector3(center+side*1.07,1.5,2),Color("37444b"))
		Shapes.box(game,Vector3(3.1,0.12,1.6),Vector3(center,3.2,2.55),accent)
		plaque(game,"规程科技  /  接待" if firm=="a" else "自己人网络  /  招聘",Vector3(center,2.75,2.15),3.8)
		var reception: Vector3=RECEPTIONS[firm]
		Shapes.solid(game,Vector3(1.5,0.92,0.65),reception+Vector3(0,0.46,0),Color("737b78"))
		Shapes.box(game,Vector3(1.58,0.045,0.74),reception+Vector3(0,0.945,0),Color("c8bda5"))
		Shapes.box(game,Vector3(1.4,0.42,0.015),reception+Vector3(0,0.65,0.34),accent)
		plaque(game,"招聘接待",reception+Vector3(0,1.35,0),1.35)
		# Waiting furniture leaves the entrance axis and all desk aisles open.
		Shapes.solid(game,Vector3(1.8,0.43,0.60),Vector3(center+4,0.215,0.7),Color("4b595c"))
		Shapes.solid(game,Vector3(1.8,0.52,0.12),Vector3(center+4,0.67,1.0),Color("4b595c"))
		Shapes.box(game,Vector3(1.8,0.04,0.60),Vector3(center+4,0.45,0.7),accent)
		# Interview room at the rear left. The two-metre doorway faces the public aisle.
		var room_x := center-7
		glazing(game,Vector3(room_x-3.1,1.5,-12.3),Vector3(3.2,3.0,0.07))
		glazing(game,Vector3(room_x+2.75,1.5,-12.3),Vector3(2.5,3.0,0.07))
		Shapes.solid(game,Vector3(0.10,3.0,3.6),Vector3(room_x+4.05,1.5,-14.2),Color("b2b2a7"))
		plaque(game,"01  面试室",Vector3(room_x,2.7,-12.25),2.0)
		Shapes.solid(game,Vector3(2.0,0.08,0.85),Vector3(room_x,0.75,-14.15),Color("b3a185"))
		for side in [-1,1]: Shapes.solid(game,Vector3(0.08,0.71,0.65),Vector3(room_x+side*0.78,0.355,-14.15),Color("465157"))
		# Wall treatment and a small working surface make this a meeting room, not a blank box.
		var wall_panel := Shapes.box(game,Vector3(4.5,1.15,0.05),Vector3(room_x,1.95,-15.74),accent)
		wall_panel.material_override=OfficeDress.fabric(accent)
		plaque(game,"规程科技" if firm=="a" else "自己人网络",Vector3(room_x,2.0,-15.66),1.8)
		for i in range(9):
			var slat := Shapes.box(game,Vector3(0.075,2.6,0.04),Vector3(room_x-3.3+i*0.12,1.45,-15.72),Color("aa9575"))
			slat.material_override=OfficeDress.wood(Color("aa9575"))
		Shapes.box(game,Vector3(0.38,0.022,0.28),Vector3(room_x+0.55,0.81,-14.15),Color("37414b"))
		Shapes.box(game,Vector3(0.34,0.005,0.25),Vector3(room_x+0.55,0.825,-14.15),Color("ddd9cb"))
		Shapes.box(game,Vector3(0.015,0.012,0.2),Vector3(room_x+0.78,0.80,-14.1),Color("28313c"))
		# Objects stay on the 0.79 m tabletop; no new collision crosses the approach.
		var phone := Shapes.box(game,Vector3(0.075,0.014,0.14),Vector3(room_x+0.22,0.798,-14.42),Color("19242c"))
		phone.rotation.y=0.12
		Shapes.box(game,Vector3(0.060,0.002,0.12),Vector3(room_x+0.22,0.807,-14.42),Color("6f9297"))
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
		plaque(game,"招聘 · 正式项目岗位 / 急招" if firm=="a" else "招同事 / 有事一起扛",Vector3(center+4,1.8,1.85),3.4)
		if firm=="b":
			Shapes.box(game,Vector3(0.45,0.26,0.35),Vector3(room_x+0.68,0.13,-15.5),Color("98714c"))
			Shapes.box(game,Vector3(0.40,0.04,0.31),Vector3(room_x+0.67,0.28,-15.5),Color("d9d0b9"))
		OfficeDress.chair(game,INTERVIEW_SEATS[firm])
		var host_chair := Node3D.new()
		game.add_child(host_chair)
		host_chair.position=INTERVIEW_HOSTS[firm]
		host_chair.rotation.y=PI
		OfficeDress.chair(host_chair,Vector3.ZERO)
		for i in range(3): Shapes.box(game,Vector3(0.21,0.008,0.29),Vector3(room_x-0.4+i*0.02,0.80+i*0.009,-14.0),Color("e7e2d7"))
		plaque(game,"会议 / 交付" if firm=="a" else "讨论 / 交接",Vector3(center+0.5,2.4,-15.72),2.1)
		# Lit entry draws the eye from the street without adding floating instructions.
		var light := OmniLight3D.new()
		game.add_child(light)
		light.position=Vector3(center,2.55,0.8)
		light.light_color=Color("e5efff") if firm=="a" else Color("ffe4bf")
		light.light_energy=0.65
		light.omni_range=4.5

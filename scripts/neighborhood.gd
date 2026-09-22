class_name Neighborhood
extends RefCounted

static func build(game: Node3D) -> void:
	var ground := Shapes.solid(game,Vector3(80,0.4,60),Vector3(0,-0.2,0),Color("858984"))
	# Keep collision seamless, but separate the rendered surface from road/floor tops.
	ground.get_child(0).position.y=-0.04
	Shapes.solid(game,Vector3(64,0.08,8),Vector3(0,-0.04,8),Color("343e48"))
	for x in range(-30,31,5):
		Shapes.box(game,Vector3(2,0.02,0.12),Vector3(x,0.01,8),Color("e4cb82"))
	for center in [-14.0,14.0]:
		var firm := "a" if center < 0 else "b"
		var color := Color("aaada8") if firm == "a" else Color("b3aaa0")
		Shapes.solid(game,Vector3(24,0.1,18),Vector3(center,-0.05,-7),Color("626769"))
		Shapes.solid(game,Vector3(24,3.7,0.3),Vector3(center,1.8,-16),color)
		for side in [-1,1]:
			Shapes.solid(game,Vector3(0.3,3.7,18),Vector3(center+side*12,1.8,-7),color)
			Shapes.solid(game,Vector3(8.8,3.7,0.3),Vector3(center+side*7.6,1.8,2),color)
		Shapes.box(game,Vector3(6.2,0.5,0.4),Vector3(center,3.45,2),color)
		for side in [-1,1]:
			var window_pos := Vector3(center+side*7.6,1.9,2.17)
			Shapes.box(game,Vector3(4.2,1.4,0.04),window_pos,Color("405b66"))
			for offset in [-2.1,0,2.1]: Shapes.box(game,Vector3(0.055,1.5,0.06),window_pos+Vector3(offset,0,0.03),Color("303d42"))
			for offset in [-0.73,0.73]: Shapes.box(game,Vector3(4.3,0.055,0.06),window_pos+Vector3(0,offset,0.03),Color("303d42"))

		OfficeRooms.plaque(game,"流程创新 · 流程先行" if firm=="a" else "我们不是公司，是一家人",Vector3(center,2.72,-15.67),3.6)
		game.add_prop(firm+"_keyboard","keyboard",Vector3(center-1,1.3,-5))
		game.add_prop(firm+"_cup","cup",Vector3(center+1,1.3,-5))
		game.add_prop(firm+"_table","table",Vector3(center,1,-5))
		game.add_prop(firm+"_chair","chair",Vector3(center+2,0.6,-5))
		game.add_prop(firm+"_printer","printer",Vector3(center-4,0.8,-3))
	OfficeRooms.plaque(game,"公交站  /  下班以后",Vector3(-6,2.5,14),3.0)
	Shapes.solid(game,Vector3(6,0.2,2),Vector3(-6,2.9,14),Color("415d63"))
	for x in [-8,-4]: Shapes.solid(game,Vector3(0.1,3,0.1),Vector3(x,1.5,14.6),Color("415d63"))
	Shapes.solid(game,Vector3(4,0.5,0.6),Vector3(-6,0.3,14),Color("b59876"))
	OfficeRooms.plaque(game,"路边摊  /  不买也能聊",Vector3(10,2.6,14),3.0)
	Shapes.box(game,Vector3(4.2,0.12,1.7),Vector3(10,2.93,14.2),Color("93674f"))
	for x in [8.1,11.9]: Shapes.solid(game,Vector3(0.08,2.9,0.08),Vector3(x,1.45,14.7),Color("63594c"))
	Shapes.solid(game,Vector3(4,1,1.4),Vector3(10,0.5,14),Color("ba8051"))
	for x in [-30,0,30]:
		Shapes.solid(game,Vector3(0.3,4,0.3),Vector3(x,2,4),Color("3d5056"))
		Shapes.box(game,Vector3(1.2,0.2,0.5),Vector3(x,4,4),Color("eedcaa"))
	# The finite neighborhood has visible boundaries, unrelated to career progress.
	for z in [-22,23]: Shapes.solid(game,Vector3(72,2,0.5),Vector3(0,1,z),Color("536c68"))
	for x in [-36,36]: Shapes.solid(game,Vector3(0.5,2,45),Vector3(x,1,0),Color("536c68"))
	game.add_npc("a_hr","林岚 · HR",OfficeRooms.RECEPTIONS.a+Vector3(0,0,-0.85),"a","hr")
	game.add_npc("a_lead","周工 · 技术主管",Vector3(-21,0,-4.9),"a","lead")
	game.add_npc("a_boss","方总 · 老板",Vector3(-21,0,-8.4),"a","boss")
	game.add_npc("a_friend","小夏 · 同事",Vector3(-8,0,-4.9),"a","friend")
	game.add_npc("a_group","许姐 · 二组负责人",Vector3(-8,0,-8.4),"a","group")
	game.add_npc("a_guard","保安 · 规程",Vector3(-19,0,0),"a","guard")
	game.add_npc("b_hr","阿诚 · 招聘",OfficeRooms.RECEPTIONS.b+Vector3(0,0,-0.85),"b","hr")
	game.add_npc("b_friend","阿乐 · 同事",Vector3(7,0,-4.9),"b","friend")
	game.add_npc("b_boss","赵总 · 老板",Vector3(7,0,-8.4),"b","boss")
	game.add_npc("b_guard","保安 · 自己人",Vector3(23,0,0),"b","guard")

	OfficeDress.build(game)
	OfficeRooms.build(game)

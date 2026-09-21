class_name Neighborhood
extends RefCounted

static func build(game: Node3D) -> void:
	Shapes.solid(game,Vector3(80,0.4,60),Vector3(0,-0.2,0),Color("607b70"))
	Shapes.solid(game,Vector3(64,0.08,8),Vector3(0,-0.04,8),Color("343e48"))
	for x in range(-30,31,5):
		Shapes.box(game,Vector3(2,0.02,0.12),Vector3(x,0.01,8),Color("e4cb82"))
	for center in [-14.0,14.0]:
		var firm := "a" if center < 0 else "b"
		var color := Color("65969d") if firm == "a" else Color("c89462")
		Shapes.solid(game,Vector3(24,0.1,18),Vector3(center,-0.05,-7),Color("92978e"))
		Shapes.solid(game,Vector3(24,3.7,0.3),Vector3(center,1.8,-16),color)
		for side in [-1,1]:
			Shapes.solid(game,Vector3(0.3,3.7,18),Vector3(center+side*12,1.8,-7),color)
			Shapes.solid(game,Vector3(8.8,3.7,0.3),Vector3(center+side*7.6,1.8,2),color)
		Shapes.box(game,Vector3(6.2,0.5,0.4),Vector3(center,3.45,2),color)
		Shapes.label(game,"规程科技" if firm=="a" else "自己人网络",Vector3(center,3.1,2.3),45)
		Shapes.label(game,"流程创新 · 流程先行" if firm=="a" else "我们不是公司，是一家人",Vector3(center,2.9,-15.6),30)
		for dx in [-7,6]:
			for z in [-6,-11]:
				Shapes.solid(game,Vector3(3.5,0.12,1.5),Vector3(center+dx,0.85,z),Color("ac9579"))
				Shapes.box(game,Vector3(1.1,0.65,0.08),Vector3(center+dx,1.35,z-0.4),Color("253c4d"))
				Shapes.box(game,Vector3(0.95,0.5,0.09),Vector3(center+dx,1.35,z-0.34),Color("739dad"))
				Shapes.solid(game,Vector3(3.6,1.4,0.12),Vector3(center+dx,0.7,z-0.9),Color("687578"))
		game.add_prop(firm+"_keyboard","keyboard",Vector3(center-1,1.3,-5))
		game.add_prop(firm+"_cup","cup",Vector3(center+1,1.3,-5))
		game.add_prop(firm+"_table","table",Vector3(center,1,-5))
		game.add_prop(firm+"_chair","chair",Vector3(center+2,0.6,-5))
		game.add_prop(firm+"_printer","printer",Vector3(center-4,0.8,-3))
		for z in [-4,-12]:
			Shapes.box(game,Vector3(6,0.06,0.5),Vector3(center,3.5,z),Color("d4ddd1"))
	Shapes.label(game,"公交站  /  下班以后",Vector3(-6,2.5,14),32)
	Shapes.solid(game,Vector3(6,0.2,2),Vector3(-6,2.9,14),Color("415d63"))
	for x in [-8,-4]: Shapes.solid(game,Vector3(0.1,3,0.1),Vector3(x,1.5,14.6),Color("415d63"))
	Shapes.solid(game,Vector3(4,0.5,0.6),Vector3(-6,0.3,14),Color("b59876"))
	Shapes.label(game,"路边摊  /  不买也能聊",Vector3(10,2.6,14),30)
	Shapes.solid(game,Vector3(4,1,1.4),Vector3(10,0.5,14),Color("ba8051"))
	for x in [-30,0,30]:
		Shapes.solid(game,Vector3(0.3,4,0.3),Vector3(x,2,4),Color("3d5056"))
		Shapes.box(game,Vector3(1.2,0.2,0.5),Vector3(x,4,4),Color("eedcaa"))
	# The finite neighborhood has visible boundaries, unrelated to career progress.
	for z in [-22,23]: Shapes.solid(game,Vector3(72,2,0.5),Vector3(0,1,z),Color("536c68"))
	for x in [-36,36]: Shapes.solid(game,Vector3(0.5,2,45),Vector3(x,1,0),Color("536c68"))
	game.add_npc("a_hr","林岚 · HR",Vector3(-14,0,-1),"a","hr")
	game.add_npc("a_lead","周工 · 技术主管",Vector3(-21,0,-8),"a","lead")
	game.add_npc("a_boss","方总 · 老板",Vector3(-14,0,-13),"a","boss")
	game.add_npc("a_friend","小夏 · 同事",Vector3(-10.5,0,-8),"a","friend")
	game.add_npc("a_group","许姐 · 二组负责人",Vector3(-10.5,0,-13),"a","group")
	game.add_npc("a_guard","保安 · 规程",Vector3(-19,0,0),"a","guard")
	game.add_npc("b_hr","阿诚 · 招聘",Vector3(14,0,-1),"b","hr")
	game.add_npc("b_friend","阿乐 · 同事",Vector3(10,0,-8),"b","friend")
	game.add_npc("b_boss","赵总 · 老板",Vector3(14,0,-12),"b","boss")
	game.add_npc("b_guard","保安 · 自己人",Vector3(20,0,0),"b","guard")

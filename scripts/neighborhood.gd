class_name Neighborhood
extends RefCounted

static func build(game: Node3D) -> void:
	var ground := Shapes.solid(game,Vector3(80,0.4,60),Vector3(0,-0.2,0),Color("858984"))
	# Keep collision seamless, but separate the rendered surface from road/floor tops.
	ground.get_child(0).position.y=-0.04
	ground.get_child(0).material_override=preload("res://assets/materials/pavement.tres")
	var road := Shapes.solid(game,Vector3(64,0.08,8),Vector3(0,-0.04,8),Color.WHITE)
	road.get_child(0).material_override=preload("res://assets/materials/asphalt.tres")
	for x in range(-30,31,5):
		Shapes.box(game,Vector3(2,0.02,0.12),Vector3(x,0.01,8),Color("e4cb82"))
	for firm in ["a","b"]:
		var company: Node3D=load("res://scenes/companies/company_"+firm+".tscn").instantiate()
		company.name="Company"+firm.to_upper()
		game.add_child(company)
		company.position=Vector3(-14 if firm=="a" else 14,0,0)
		for spawn in company.get_node("PropSpawns").get_children():
			game.add_prop(String(spawn.name),spawn.get_meta("kind"),spawn.global_position)
		for spawn in company.get_node("PeopleSpawns").get_children():
			game.add_npc(String(spawn.name),spawn.get_meta("title"),spawn.global_position,firm,spawn.get_meta("role"))
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
	# Context across the street remains a separate neighborhood layer.
	for x in [-30,-18,-6,6,18,30]:
		Shapes.box(game,Vector3(10,12,5),Vector3(x,6,27),Color("778087"))
		for y in [2,5,8,11]:
			for dx in [-3,0,3]: Shapes.box(game,Vector3(1.6,1.8,0.03),Vector3(x+dx,y,24.45),Color("495d68"))

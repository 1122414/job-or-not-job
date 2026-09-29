class_name CityLayout
extends RefCounted

# The first connected district is a transport blockout, not the metropolitan extent.
const BOUNDS := Rect2(-108,-24,216,156)
const STOPS := [
	{"id":"office","title":"下班路 · 双公司","point":Vector3(-6,0,8),"platform":Vector3(-6,0,12.5)},
	{"id":"market","title":"榕树街 · 老城","point":Vector3(-76,0,58),"platform":Vector3(-71.5,0,58)},
	{"id":"waterfront","title":"海风步道 · 滨水","point":Vector3(-6,0,104),"platform":Vector3(-6,0,99.5)},
	{"id":"homes","title":"东里社区 · 住宅","point":Vector3(76,0,58),"platform":Vector3(71.5,0,58)}
]
const REGIONS := [
	{"id":"office","title":"下班路 · 公共街区","center":Vector3(0,0,8)},
	{"id":"market","title":"榕树街 · 老城街口","center":Vector3(-58,0,58)},
	{"id":"waterfront","title":"海风步道 · 滨水公园","center":Vector3(0,0,116)},
	{"id":"homes","title":"东里社区 · 住宅入口","center":Vector3(58,0,58)}
]

static func region_at(point: Vector3) -> String:
	if point.z<26: return "office"
	if point.z>86: return "waterfront"
	return "market" if point.x<0 else "homes"

static func route_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval=0.3
	curve.add_point(STOPS[0].point)
	# Rounded corners keep the 7m vehicle on its road throughout the turn.
	for corner in [[Vector3(-68,0,16),-90.0,-180.0],[Vector3(-68,0,96),180.0,90.0],[Vector3(68,0,96),90.0,0.0],[Vector3(68,0,16),0.0,-90.0]]:
		for i in range(13):
			var angle := deg_to_rad(lerpf(corner[1],corner[2],i/12.0))
			curve.add_point(corner[0]+Vector3(cos(angle),0,sin(angle))*8)
	curve.add_point(STOPS[0].point)
	return curve

static func build(game: Node3D) -> void:
	var district := Node3D.new()
	district.name="ConnectedDistrict"
	game.add_child(district)
	for road in [[Vector3(0,0,8),Vector3(166,0.04,12)],[Vector3(0,0,104),Vector3(166,0.04,12)],[Vector3(-76,0,56),Vector3(12,0.04,84)],[Vector3(76,0,56),Vector3(12,0.04,84)]]:
		var mesh := Shapes.box(district,road[1],road[0]+Vector3(0,-0.02,0),Color.WHITE)
		mesh.add_to_group("city_road_surfaces")
		mesh.material_override=preload("res://assets/materials/asphalt.tres")
	for x in range(-65,70,8):
		for z in [8,104]: Shapes.box(district,Vector3(3,0.015,0.12),Vector3(x,0.012,z),Color("e4cb82"))
	for z in range(24,94,8):
		for x in [-76,76]: Shapes.box(district,Vector3(0.12,0.015,3),Vector3(x,0.012,z),Color("e4cb82"))
	# Public paths cross the inner block; no invisible barrier gates employment.
	for path in [[Vector3(0,0,58),Vector3(140,0.025,5)],[Vector3(0,0,56),Vector3(6,0.025,84)]]:
		Shapes.box(district,path[1],path[0],Color("c1bcab"))
	for i in range(STOPS.size()):
		var stop: Dictionary=STOPS[i]
		var platform: Vector3=stop.platform
		game.add_station("bus_"+stop.id,"101 · "+stop.title,platform)
		game.stations[-1].rotation.y=PI/2 if i==1 else PI if i==2 else -PI/2 if i==3 else 0.0
		if i==0: continue
		var shelter := Node3D.new()
		district.add_child(shelter)
		shelter.position=platform+Vector3(0,0,-5) if i==1 else platform+Vector3(0,0,5) if i==3 else platform+Vector3(-5,0,0)
		shelter.rotation.y=PI/2 if i==1 else PI if i==2 else -PI/2
		Shapes.solid(shelter,Vector3(5,0.15,2),Vector3(0,2.9,1.8),Color("49696c"))
		for x in [-2,2]: Shapes.solid(shelter,Vector3(0.1,2.9,0.1),Vector3(x,1.45,2.5),Color("49696c"))
		Shapes.solid(shelter,Vector3(3,0.45,0.6),Vector3(0,0.225,2),Color("ae9370"))
		OfficeRooms.plaque(shelter,stop.title,Vector3(0,2.45,1.8),3.4)
	# Distinct massing and traversable public spaces. Interiors/content follow later.
	for z in [32,82]:
		for x in [-96,-52,-34]:
			if x== -52 and z==32:
				var bookshop := CityBookshop.new()
				bookshop.name="CommunityBookshop"
				bookshop.position=Vector3(x,0,z)
				district.add_child(bookshop)
			else: building(district,Vector3(x,0,z),Vector3(13,7 if x!= -34 else 10,13),Color("b6a18c"))
	for x in [-96,-52]:
		Shapes.box(district,Vector3(13.8,0.2,2.4),Vector3(x,3.1,40),Color("875e49"))
	OfficeRooms.plaque(district,"榕树街  /  社区书屋",Vector3(-62,2.4,44),4)
	for x in [36,56,96]:
		for z in [32,82]: building(district,Vector3(x,0,z),Vector3(14,16 if x==96 else 12,14),Color("aab4b3"))
	OfficeRooms.plaque(district,"东里社区  /  公共花园",Vector3(51,3,48),5)
	for x in [-60,-36,28,52]:
		for z in [48,70]: tree(district,Vector3(x,0,z))
	for x in range(-96,100,12):
		Shapes.solid(district,Vector3(0.12,1.15,0.12),Vector3(x,0.575,126),Color("49696c"))
		Shapes.box(district,Vector3(12,0.06,0.06),Vector3(x+6,1.1,126),Color("49696c"))
	Shapes.box(district,Vector3(216,0.04,5),Vector3(0,0.02,116),Color("c9c2ae"))
	Shapes.box(district,Vector3(220,0.1,70),Vector3(0,-0.5,164),Color("4c8992"))
	OfficeRooms.plaque(district,"海风步道  /  城市与海",Vector3(18,2.8,120),5)
	for x in [-36,-18,18,36]:
		Shapes.solid(district,Vector3(3,0.45,0.7),Vector3(x,0.225,120),Color("ad9574"))
	for x in [-107,107]: Shapes.solid(district,Vector3(0.4,1.2,156),Vector3(x,0.6,54),Color("657d75"))
	for z in [-24,131]: Shapes.solid(district,Vector3(216,1.2,0.4),Vector3(0,0.6,z),Color("657d75"))

static func building(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> void:
	Shapes.solid(parent,size,point+Vector3(0,size.y/2,0),color)
	for y in range(2,int(size.y),3):
		for x in [-4,0,4]:
			for side in [-1,1]: Shapes.box(parent,Vector3(1.6,1.8,0.04),point+Vector3(x,y,side*(size.z/2+0.03)),Color("526976"))

static func tree(parent: Node3D, point: Vector3) -> void:
	Shapes.solid(parent,Vector3(0.3,3,0.3),point+Vector3(0,1.5,0),Color("746b54"))
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius=2.2
	sphere.height=4
	crown.mesh=sphere
	crown.material_override=Shapes.material(Color("668166"))
	parent.add_child(crown)
	crown.position=point+Vector3(0,4,0)

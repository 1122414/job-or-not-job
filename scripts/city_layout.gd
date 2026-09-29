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
	var streets := CityStreetscape.new()
	district.add_child(streets)
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
		var surface := Shapes.box(district,path[1],path[0],Color.WHITE)
		surface.material_override=streets.materials.paving
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
			else: streets.facade(Vector3(x,0,z),Vector3(13,7 if x!= -34 else 10,13),true)
	for x in [-96]:
		Shapes.box(district,Vector3(13.8,0.2,2.4),Vector3(x,3.1,40),Color("875e49"))
	for x in [36,56,96]:
		for z in [32,82]: streets.facade(Vector3(x,0,z),Vector3(14,16 if x==96 else 12,14),false)
	var sea := MeshInstance3D.new()
	sea.name="CoastalWater"
	var plane := PlaneMesh.new()
	plane.size=Vector2(4000,4000)
	sea.mesh=plane
	sea.position=Vector3(0,-.48,2129)
	streets.water=ShaderMaterial.new()
	streets.water.shader=preload("res://assets/materials/city_water.gdshader")
	sea.material_override=streets.water
	district.add_child(sea)
	for x in [-107,107]: Shapes.solid(district,Vector3(0.4,1.2,156),Vector3(x,0.6,54),Color("657d75"))
	Shapes.solid(district,Vector3(216,1.2,.4),Vector3(0,.6,-24),Color("657d75"))
	# The outer sea ledge stays below the promenade railing, leaving the water
	# visible from standing height instead of adding a second eye-level fence.
	Shapes.solid(district,Vector3(216,.45,.4),Vector3(0,.225,131),Color("657d75"))

	streets.landscape()
	CityUrbanFabric.build(streets)
	streets.flush()

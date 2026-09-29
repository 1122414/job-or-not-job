class_name CityHomeRoom
extends Node3D

var furnishings: CityStreetscape
var sofa: StaticBody3D
var lamps: Array[OmniLight3D]=[]
var curtains: Array[MeshInstance3D]=[]
var postcard: Sprite3D
var memory: Label3D

func _ready() -> void:
	name="HomeRoom"
	furnishings=CityStreetscape.new()
	add_child(furnishings)
	for item in [["plaster","d9d1bd"],["sage","688077"],["linen","bcaa8d"],["paper","eee4cd"],["ceramic","ddd7ca"],["blue","536d79"],["brass","a68958"]]:
		furnishings.materials[item[0]]=Shapes.material(Color(item[1]))
	furnishings.materials.plaster=load("res://assets/materials/painted_wall.tres").duplicate()
	furnishings.materials.plaster.albedo_color=Color("dfd8c5")
	build_shell()
	build_living()
	build_bedroom()
	build_kitchen()
	furnishings.flush()

func build_shell() -> void:
	for part in [[Vector3(-7,1.7,0),Vector3(.26,3.4,14)],[Vector3(7,1.7,0),Vector3(.26,3.4,14)],[Vector3(0,1.7,-7),Vector3(14,3.4,.26)]]:
		furnishings.solid(part[1],part[0],"plaster")
	# The threshold shares the district's collision plane at y=0.
	var floor_mesh := Shapes.box(self,Vector3(13.75,.025,13.75),Vector3(0,.007,0),Color.WHITE)
	floor_mesh.material_override=preload("res://assets/materials/office_wood.tres")
	furnishings.solid(Vector3(14,.18,14),Vector3(0,3.39,0),"plaster")
	for x in [-6.86,6.86]: furnishings.box(Vector3(.055,.13,13.72),Vector3(x,.075,0),"timber")
	for z in [-6.86,6.86]: furnishings.box(Vector3(13.72,.13,.055),Vector3(0,.075,z),"timber")
	# Two actual glazed openings frame the street; the middle doorway is open.
	for x in [-4.55,4.55]:
		furnishings.solid(Vector3(4.7,.82,.26),Vector3(x,.41,7),"sage")
		furnishings.solid(Vector3(4.7,.5,.26),Vector3(x,3.15,7),"plaster")
		OfficeRooms.glazing(self,Vector3(x,1.85,7),Vector3(4.35,2.05,.05))
		for dx in [-2.21,0,2.21]: furnishings.solid(Vector3(.09,2.1,.18),Vector3(x+dx,1.86,7),"timber")
		for y in [.82,2.9]: furnishings.box(Vector3(4.52,.09,.23),Vector3(x,y,7),"timber")
		furnishings.box(Vector3(4.64,.1,.45),Vector3(x,.82,6.93),"timber")
	for x in [-1.8,1.8]: furnishings.solid(Vector3(.8,3.4,.26),Vector3(x,1.7,7),"sage")
	furnishings.solid(Vector3(2.8,.65,.26),Vector3(0,3.075,7),"sage")
	for x in [-1.41,1.41]: furnishings.box(Vector3(.09,2.75,.38),Vector3(x,1.375,7),"timber")
	furnishings.box(Vector3(3.3,.12,1.0),Vector3(0,3.45,7.35),"metal")
	label("东里 101 · 我的住处",Vector3(0,3.08,7.16),.005,0)
	# A bedroom screen separates rest from the living area without locking it.
	furnishings.solid(Vector3(.18,2.65,7),Vector3(-.7,1.325,-3.35),"sage")
	furnishings.solid(Vector3(3.2,2.65,.18),Vector3(-5.3,1.325,.2),"plaster")
	furnishings.box(Vector3(13.6,.08,.12),Vector3(0,3.25,0),"timber")
	for side in [-1,1]:
		var panel := Shapes.box(self,Vector3(2.24,2.12,.055),Vector3(4.55+side*1.12,1.92,6.73),Color("b6a383"))
		curtains.append(panel)
	furnishings.box(Vector3(4.75,.055,.07),Vector3(4.55,3.0,6.7),"brass")
	for point in [Vector3(2.6,3.13,2.5),Vector3(-3.8,3.1,-3.7)]:
		furnishings.box(Vector3(.66,.14,.66),point,"linen")
		var lamp := OmniLight3D.new()
		lamp.position=point-Vector3(0,.3,0)
		lamp.omni_range=8
		lamp.light_color=Color("ffe0b0")
		lamp.light_energy=1.25
		lamp.shadow_enabled=true
		add_child(lamp);lamps.append(lamp)
	furnishings.box(Vector3(.16,.24,.06),Vector3(1.81,1.24,6.83),"paper")
	furnishings.box(Vector3(.10,.15,.025),Vector3(1.81,1.24,6.785),"sage")

func build_living() -> void:
	sofa=StaticBody3D.new()
	sofa.name="Sofa"
	sofa.position=Vector3(3.6,0,3.9)
	add_child(sofa)
	# Keep the cushion below the seated skin and the plinth behind the calves.
	for part in [[Vector3(0,.20,.09),Vector3(2.95,.24,1.04)],[Vector3(0,.82,.52),Vector3(2.95,.8,.23)],[Vector3(-1.45,.54,0),Vector3(.18,.75,1.3)],[Vector3(1.45,.54,0),Vector3(.18,.75,1.3)]]:
		Shapes.box(sofa,part[1],part[0],Color("5c7770"))
		Shapes.collider(sofa,part[1],part[0])
	for x in [-.7,.7]: Shapes.box(sofa,Vector3(1.34,.115,.88),Vector3(x,.3425,.03),Color("7c9287"))
	for x in [-1.2,1.2]:
		for z in [-.42,.42]: Shapes.box(sofa,Vector3(.08,.15,.08),Vector3(x,.075,z),Color("615044"))
	furnishings.solid(Vector3(2.15,.1,1.1),Vector3(3.6,.44,1.05),"timber")
	for x in [2.72,4.48]:
		for z in [.66,1.44]: furnishings.solid(Vector3(.06,.4,.06),Vector3(x,.2,z),"metal")
	for i in range(3): furnishings.box(Vector3(.36,.045,.27),Vector3(3.1,.515+i*.045,1.1),"blue" if i%2==0 else "paper")
	var rug := Shapes.box(self,Vector3(4.3,.012,3.8),Vector3(3.6,.03,2.1),Color("a99a82"))
	rug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	furnishings.solid(Vector3(2.2,.7,.48),Vector3(6.42,.35,3.7),"timber",PI/2)
	for i in range(6): furnishings.box(Vector3(.055,.22+i%3*.045,.2),Vector3(6.34,.84,3.3+i*.10),"blue" if i%2==0 else "linen",PI/2)
	furnishings.box(Vector3(2.0,1.4,.07),Vector3(6.8,1.9,1.0),"timber",PI/2)
	furnishings.box(Vector3(1.83,1.23,.03),Vector3(6.745,1.9,1.0),"paper",PI/2)
	postcard=CityBookshop.picture(self,CityBookshop.IMAGES[0],Vector3(6.72,1.9,1.0),.0020)
	postcard.rotation.y=-PI/2
	furnishings.box(Vector3(2.3,1.2,.06),Vector3(.76,1.85,-6.81),"timber")
	furnishings.box(Vector3(2.1,1.0,.025),Vector3(.76,1.85,-6.76),"paper")
	memory=label("",Vector3(.76,1.85,-6.73),.003,0)
	memory.width=630;memory.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	memory.modulate=Color("3d504b")
	label("生活留痕",Vector3(.76,2.66,-6.73),.004,0).modulate=Color("3d504b")

func build_bedroom() -> void:
	furnishings.solid(Vector3(2.2,.33,2.65),Vector3(-4.05,.195,-4.8),"timber")
	furnishings.box(Vector3(2.13,.17,2.5),Vector3(-4.05,.445,-4.8),"paper")
	furnishings.box(Vector3(2.13,.045,1.8),Vector3(-4.05,.55,-4.43),"blue")
	furnishings.solid(Vector3(2.28,1.12,.16),Vector3(-4.05,.56,-6.2),"timber")
	for x in [-4.6,-3.5]: furnishings.box(Vector3(.82,.16,.46),Vector3(x,.60,-5.68),"linen")
	furnishings.solid(Vector3(.7,.52,.64),Vector3(-2.36,.26,-5.4),"timber")
	furnishings.box(Vector3(.28,.03,.22),Vector3(-2.36,.54,-5.4),"paper")
	furnishings.solid(Vector3(1.1,2.6,2.3),Vector3(-6.23,1.3,-1.25),"timber")
	for z in [-1.85,-.65]:
		furnishings.box(Vector3(.025,2.44,1.08),Vector3(-5.66,1.3,z),"linen")
		furnishings.box(Vector3(.08,.32,.04),Vector3(-5.6,1.25,z+.36),"brass")

func build_kitchen() -> void:
	for x in [3.0,4.5,6.0]:
		furnishings.solid(Vector3(1.42,.84,.72),Vector3(x,.42,-6.45),"sage")
		furnishings.box(Vector3(1.5,.065,.81),Vector3(x,.89,-6.4),"ceramic")
		furnishings.box(Vector3(.28,.04,.06),Vector3(x,.73,-6.06),"brass")
	furnishings.box(Vector3(.8,.018,.49),Vector3(4.5,.934,-6.4),"metal")
	for x in [3.0,6.0]: furnishings.solid(Vector3(1.4,.85,.37),Vector3(x,2.3,-6.65),"linen")
	furnishings.box(Vector3(.52,.025,.47),Vector3(3,.94,-6.42),"metal")
	for x in [2.85,3.15]: furnishings.box(Vector3(.15,.009,.25),Vector3(x,.958,-6.42),"ceramic")
	# Compact wash area stays off the path from the entrance to the bed.
	for x in [-6.5,-4.45]: furnishings.solid(Vector3(.8,2.7,.16),Vector3(x,1.35,2.0),"plaster")
	furnishings.solid(Vector3(.16,2.7,4.7),Vector3(-3.95,1.35,4.6),"plaster")
	furnishings.solid(Vector3(1.65,.85,.67),Vector3(-5.7,.425,6.45),"ceramic")
	furnishings.box(Vector3(.9,.022,.46),Vector3(-5.7,.865,6.4),"metal")
	furnishings.box(Vector3(1.6,1.1,.035),Vector3(-5.7,1.85,6.75),"glass")
	furnishings.solid(Vector3(.6,.42,.86),Vector3(-6.2,.21,3.45),"ceramic")
	furnishings.solid(Vector3(.63,.72,.25),Vector3(-6.2,.45,3.0),"ceramic")

func label(text: String,at: Vector3,pixel: float,yaw: float) -> Label3D:
	var result := Shapes.label(self,text,at,40)
	result.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	result.double_sided=false;result.outline_size=0
	result.pixel_size=pixel;result.rotation.y=yaw
	return result

func apply(lights_on: bool,curtains_closed: bool,selected: int) -> void:
	for lamp in lamps: lamp.light_energy=1.25 if lights_on else 0.0
	for i in range(curtains.size()):
		curtains[i].scale.x=1.0 if curtains_closed else .16
		curtains[i].position.x=4.55+(-1 if i==0 else 1)*(1.12 if curtains_closed else 2.08)
	postcard.texture=CityBookshop.IMAGES[selected]

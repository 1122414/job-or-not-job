class_name CityStreetFront
extends RefCounted

const ROOT := "res://assets/city_street/"
const MODELS := ["rollershutter_door","plastic_crate_01","potted_plant_02","industrial_wall_lamp"]

static func face_for(at: Vector3) -> int:
	if at.x< -80:return 1
	if at.x>80:return 3
	return 0 if at.z<58 else 2

static func shell(s: CityStreetscape,at: Vector3,size: Vector3,wall: String) -> void:
	var yaw := face_for(at)*PI/2
	var rot := Basis(Vector3.UP,yaw)
	var width := size.x if face_for(at)%2==0 else size.z
	var depth := size.z if face_for(at)%2==0 else size.x
	# Keep the original upper mass and a solid rear building. Only the shallow
	# ground-floor porch is recessed, with its floor on the existing y=0 plane.
	s.solid(Vector3(width,size.y-3.4,depth),at+Vector3(0,(size.y+3.4)/2,0),wall,yaw)
	s.solid(Vector3(width,3.4,depth-1.5),at+rot*Vector3(0,1.7,-.75),wall,yaw)
	for side in [-1,1]:s.solid(Vector3(.34,3.4,1.5),at+rot*Vector3(side*(width/2-.17),1.7,depth/2-.75),wall,yaw)

static func model(s: CityStreetscape,id: String,at: Vector3,yaw: float=0,scale_value: Vector3=Vector3.ONE) -> void:
	s.piece(ROOT+id+".res","",Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(scale_value),at))
	# Material resources are shared by the repeated mesh. Register a light's
	# emissive face once, so the existing daylight owner controls every copy.
	if id=="industrial_wall_lamp":
		var mesh: ArrayMesh=load(ROOT+id+".res")
		for surface in range(mesh.get_surface_count()):
			var material: StandardMaterial3D=mesh.surface_get_material(surface)
			if material.emission_enabled and not s.night_materials.has(material):s.night_materials.append(material)

static func pot(s: CityStreetscape,at: Vector3,yaw: float) -> void:
	model(s,"potted_plant_02",at,yaw)
	var body := StaticBody3D.new();s.add_child(body);body.position=at
	# Leaves can brush past the player; the ceramic pot remains solid.
	Shapes.collider(body,Vector3(.43,.32,.43),Vector3(0,.16,0))

static func writing(s: CityStreetscape,text: String,at: Vector3,yaw: float,pixel: float,color: Color) -> void:
	var label := Shapes.label(s,text,at,48)
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED;label.double_sided=false
	label.rotation.y=yaw;label.pixel_size=pixel;label.outline_size=0;label.modulate=color

static func entrance_light(s: CityStreetscape,at: Vector3) -> void:
	var lamp := OmniLight3D.new();s.add_child(lamp);lamp.position=at
	lamp.light_color=Color("ffdab0");lamp.light_energy=0;lamp.omni_range=4.2
	lamp.shadow_enabled=true;lamp.distance_fade_enabled=true
	lamp.distance_fade_begin=18;lamp.distance_fade_length=10
	s.lamps.append(lamp)

static func build(s: CityStreetscape,at: Vector3,size: Vector3,old_town: bool) -> void:
	var face := face_for(at)
	var yaw := face*PI/2
	var rot := Basis(Vector3.UP,yaw)
	var width := size.x if face%2==0 else size.z
	var depth := size.z if face%2==0 else size.x
	var center := at+rot*Vector3(0,0,depth/2)
	var variant := (int(absf(at.x))+int(at.z))%3
	var trim := "awning" if old_town else "metal"
	# Framed bays and a shallow porch replace the flat repeated ground windows.
	s.box(Vector3(width+.14,.13,2.05),center+rot*Vector3(0,3.31,-.47),trim,yaw)
	s.box(Vector3(width-.36,.025,1.52),center+rot*Vector3(0,.018,-.68),"paving",yaw)
	s.box(Vector3(width-.34,.58,.11),center+rot*Vector3(0,2.98,.035),trim,yaw)
	var title: String=["榕树里 · 街坊维修","榕树街 · 日常杂货","海风里 · 洗护小铺"][variant] if old_town else "东里社区 · %d幢"%(int(at.x/10)+int(at.z/20))
	writing(s,title,center+rot*Vector3(0,3.01,.105),yaw,.0085,Color("eee5cf"))
	for x in [-width/2+.22,-1.45,1.45,width/2-.22]:
		s.solid(Vector3(.28,2.68,.35),center+rot*Vector3(x,1.34,-.15),"brick" if old_town else "stone",yaw)
	# Closed entrance doors remain physical, without adding an interaction or
	# claiming a new business simulation. Existing home/bookshop stay separate.
	s.solid(Vector3(2.65,2.5,.12),center+rot*Vector3(0,1.25,-.82),"timber" if old_town else "metal",yaw)
	for x in [-.69,.69]:
		s.box(Vector3(1.21,1.68,.025),center+rot*Vector3(x,1.53,-.743),"glass",yaw)
		for bar in [-.58,.58]:s.box(Vector3(.055,2.42,.055),center+rot*Vector3(x+bar,1.23,-.7),"metal",yaw)
		s.box(Vector3(.035,.38,.11),center+rot*Vector3(x*.22,1.12,-.66),"trim",yaw)
	writing(s,"住户入口" if not old_town else "暂未营业",center+rot*Vector3(0,1.92,-.68),yaw,.0026,Color("e0d4b9"))
	# One broad display pane looks into a real recessed shelf, not a blue slab.
	var bay_x := 3.82
	var bay_width := width/2-1.82
	s.solid(Vector3(bay_width,.65,.2),center+rot*Vector3(bay_x,.325,-.1),"brick" if old_town else "stone",yaw)
	s.box(Vector3(bay_width-.2,1.77,.08),center+rot*Vector3(bay_x,1.55,-1.28),"timber" if old_town else "curtain",yaw)
	for shelf in [.79,1.34,1.94]:
		s.box(Vector3(bay_width-.26,.055,.64),center+rot*Vector3(bay_x,shelf,-.9),"timber",yaw)
		if old_town:
			for i in range(6):s.box(Vector3(.26,.29+(i%3)*.055,.22),center+rot*Vector3(bay_x-1.42+i*.52,shelf+.2,-.89),"curtain" if (i+variant)%2==0 else "brick_red",yaw)
	var pane := Node3D.new();s.add_child(pane)
	pane.position=center+rot*Vector3(bay_x,1.53,-.30);pane.rotation.y=yaw
	OfficeRooms.glazing(pane,Vector3.ZERO,Vector3(bay_width-.16,1.7,.025))
	for x in [bay_x-bay_width/2,bay_x,bay_x+bay_width/2]:s.solid(Vector3(.065,1.86,.10),center+rot*Vector3(x,1.54,-.24),"metal",yaw)
	for y in [.65,2.46]:s.box(Vector3(bay_width+.1,.06,.18),center+rot*Vector3(bay_x,y,-.24),"metal",yaw)
	if not old_town:
		writing(s,"街坊公告\n\n保持通道畅通\n请轻声慢行",center+rot*Vector3(bay_x,1.58,-1.215),yaw,.0034,Color("43524b"))
	# Maintenance shutter, meters and rainwater pipes belong against the wall.
	if old_town:
		model(s,"rollershutter_door",center+rot*Vector3(-3.1,0,-.72),yaw)
		for x in [-3.72,-2.48]:s.solid(Vector3(.14,2.5,.78),center+rot*Vector3(x,1.25,-1.1),"stone",yaw)
		s.box(Vector3(1.36,.14,.82),center+rot*Vector3(-3.1,2.48,-1.1),"stone",yaw)
	else:
		for row in range(3):
			for column in range(3):
				var point := center+rot*Vector3(-3.66+column*.51,1.05+row*.33,-1.37)
				s.box(Vector3(.46,.29,.24),point,"metal",yaw)
				s.box(Vector3(.29,.014,.025),point+rot*Vector3(0,.075,.133),"reveal",yaw)
				writing(s,"%d0%d"%[row+1,column+1],point+rot*Vector3(-.07,-.025,.127),yaw,.0015,Color("e7dec8"))
	for x in [-4.84,-4.27]:
		s.box(Vector3(.44,.63,.20),center+rot*Vector3(x,1.65,-1.397),"metal",yaw)
		s.box(Vector3(.21,.12,.015),center+rot*Vector3(x,1.79,-1.287),"glass",yaw)
		s.box(Vector3(.025,.58,.025),center+rot*Vector3(x,2.25,-1.478),"trim",yaw)
	s.box(Vector3(.07,3.18,.07),center+rot*Vector3(-width/2+.5,1.59,.13),"metal",yaw)
	for y in [.25,1.5,2.8]:s.box(Vector3(.14,.04,.13),center+rot*Vector3(-width/2+.5,y,.08),"trim",yaw)
	for x in [-1.45,1.45]:model(s,"industrial_wall_lamp",center+rot*Vector3(x,2.22,.027),yaw)
	entrance_light(s,center+rot*Vector3(-1.45,2.22,.23))
	pot(s,center+rot*Vector3(width/2-.7,0,.45),yaw+.25)
	if old_town:
		for i in range(2):model(s,"plastic_crate_01",center+rot*Vector3(-4.55+i*.45,0,.25),yaw)
		var body := StaticBody3D.new();s.add_child(body)
		body.position=center+rot*Vector3(-4.32,.132,.25);body.rotation.y=yaw
		Shapes.collider(body,Vector3(.77,.264,.408))
	else:pot(s,center+rot*Vector3(-width/2+.8,0,.46),yaw-.4)
	s.set_meta("street_frontages",int(s.get_meta("street_frontages",0))+1)

static func gallery(s: CityStreetscape,lot: Dictionary) -> void:
	var at: Vector3=lot.at+Vector3(0,0,-5.005)
	var yaw := PI
	# Service-side fixtures use the back of the existing core. The public seats
	# and the through passage on the other side retain their authored space.
	model(s,"rollershutter_door",at,yaw)
	for x in [-1.6,1.6]:model(s,"industrial_wall_lamp",at+Vector3(x,2.25,0),yaw)
	writing(s,{"west":"连廊维护间","east":"街坊工具间","north":"海风园务间"}[lot.id],at+Vector3(0,2.63,-.1),yaw,.005,Color("e7ddc6"))
	for x in [-3.25,3.25]:pot(s,at+Vector3(x,0,-.5),x*.1)

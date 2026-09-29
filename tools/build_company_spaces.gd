extends SceneTree

const RoomSource = preload("res://tools/company_room_source.gd")
var materials: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func group(parent: Node3D, title: String) -> Node3D:
	var node := Node3D.new()
	node.name=title
	parent.add_child(node)
	return node

func material(color: String, roughness: float=0.7, metal: float=0.0) -> StandardMaterial3D:
	var key := color+str(roughness)+str(metal)
	if not materials.has(key):
		var value := StandardMaterial3D.new()
		value.albedo_color=Color(color)
		value.roughness=roughness
		value.metallic=metal
		materials[key]=value
	return materials[key]

func box(parent: Node3D, title: String, size: Vector3, at: Vector3, mat: Material, solid: bool=false) -> Node3D:
	var node: Node3D=Shapes.solid(parent,size,at,Color.WHITE) if solid else Shapes.box(parent,size,at,Color.WHITE)
	node.name=title
	var mesh: MeshInstance3D=node.get_child(0) if solid else node
	mesh.material_override=mat
	return node

func tube(parent: Node3D, title: String, radius: float, length: float, at: Vector3, axis: Vector3, mat: Material) -> void:
	var mesh := OfficeDress.cylinder(parent,radius,length,at,Color.WHITE)
	mesh.name=title
	mesh.rotation=axis
	mesh.material_override=mat

func sign_at(parent: Node3D, text: String, at: Vector3, width: float, size: int=48) -> void:
	OfficeRooms.plaque(parent,text,at,width)
	var label: Label3D=parent.get_child(parent.get_child_count()-1)
	label.font_size=size
	label.pixel_size=0.0028

func anchors(parent: Node3D, firm: String) -> void:
	var points := {
		"reception":Vector3(-2.2,0,0), "interview_seat":Vector3(-7,0,-13.15),
		"interview_host":Vector3(-7,0,-15), "interview_call":Vector3(-6.1,0,-12.95),
		"box_start":Vector3(-6.45,0.88,-14.48), "box_table":Vector3(-6.68,0.88,-14.42),
		"box_edge":Vector3(-6.68,0.88,-13.56), "box_floor":Vector3(-6.45,0.15,-14.06),
		"tour_greet":Vector3(3,0,-3.1) if firm=="a" else Vector3(-5.5,0,-4),
		"tour_desk":Vector3(4,0,0.2), "tea":Vector3(-4,0,0.4),
		"desk_"+firm:Vector3(6,0,-0.9), "entry":Vector3(0,0,3.4)
	}
	if firm=="a":
		points.merge({"desk_a2":Vector3(0,0,-13.5),"archive":Vector3(-10,0,-4),"demo":Vector3(-1.5,0,-10.5),"backup":Vector3(9,0,-12)})
	else: points["handover"]=Vector3(9,0,-4)
	var holder := group(parent,"Anchors")
	for key in points:
		var marker := Marker3D.new()
		marker.name=key
		marker.position=points[key]
		holder.add_child(marker)
	var props := group(parent,"PropSpawns")
	var items := [[firm+"_keyboard","keyboard",Vector3(-1,1.3,-5)], [firm+"_cup","cup",Vector3(1,1.3,-5)],
		[firm+"_table","table",Vector3(0,1,-5)], [firm+"_chair","chair",Vector3(2,0.6,-5)],
		[firm+"_printer","printer",Vector3(-4,0.8,-3)]]
	for dx in [-7,6]:
		for z in [-2,-6,-11]:
			var id := firm+"_desk_"+str(dx)+"_"+str(z)
			var depth: float=z+1.5 if z==-11 else z
			items.append_array([[id,"desk",Vector3(dx,0.72,depth)], [id+"_monitor","monitor",Vector3(dx,1.20,depth-0.28)],
				[id+"_keyboard","keyboard",Vector3(dx,0.85,depth+0.58)], [id+"_cup","cup",Vector3(dx+1,0.94,depth+0.15)],
				[id+"_seat","chair",Vector3(dx,0.55,depth+1.1)], [id+"_back","panel",Vector3(dx,0.7,depth-0.9)]])
			for side in [-1,1]: items.append([id+"_side_"+str(side),"side_panel",Vector3(dx+side*1.77,0.7,depth-0.1)])
	for side in [-1,1]: items.append([firm+"_plant_"+str(side),"plant",Vector3(side*10.5,0.45,0 if side<0 else -14)])
	items.append([firm+"_cooler","cooler",Vector3(-4.8,0.75,0)])
	for item in items:
		var marker := Marker3D.new()
		marker.name=item[0]
		marker.set_meta("kind",item[1])
		marker.position=item[2]
		props.add_child(marker)
	var people := group(parent,"PeopleSpawns")
	var cast := [["a_hr","林岚 · HR",Vector3(-2.2,0,-0.85),"hr"], ["a_lead","周工 · 技术主管",Vector3(-7,0,-4.9),"lead"],
		["a_boss","方总 · 老板",Vector3(-7,0,-8.4),"boss"], ["a_friend","小夏 · 同事",Vector3(6,0,-4.9),"friend"],
		["a_group","许姐 · 二组负责人",Vector3(6,0,-8.4),"group"], ["a_guard","保安 · 规程",Vector3(-5,0,0),"guard"]] if firm=="a" else [
		["b_hr","阿诚 · 招聘",Vector3(-2.2,0,-0.85),"hr"], ["b_friend","阿乐 · 同事",Vector3(-7,0,-4.9),"friend"],
		["b_boss","赵总 · 老板",Vector3(-7,0,-8.4),"boss"], ["b_guard","保安 · 自己人",Vector3(9,0,0),"guard"]]
	for item in cast:
		var marker := Marker3D.new()
		marker.name=item[0]
		marker.set_meta("title",item[1])
		marker.set_meta("role",item[3])
		marker.position=item[2]
		people.add_child(marker)

func window(parent: Node3D, at: Vector3, width: float, height: float, side: bool=false) -> void:
	var frame := group(parent,"Window")
	frame.position=at
	if side: frame.rotation.y=PI/2
	var glass := material("6d8991",0.15,0.45)
	var frame_mat := material("343d40",0.34,0.7)
	box(frame,"Glass",Vector3(width,height,0.025),Vector3.ZERO,glass)
	for x in [-width/2,0.0,width/2]: box(frame,"Mullion",Vector3(0.05,height+0.08,0.10),Vector3(x,0,0),frame_mat)
	for y in [-height/2,height/2]: box(frame,"Rail",Vector3(width+0.08,0.055,0.10),Vector3(0,y,0),frame_mat)
	box(frame,"Sill",Vector3(width+0.14,0.065,0.22),Vector3(0,-height/2-0.025,0),material("b8b6ab",0.6))

func shell(parent: Node3D, firm: String) -> void:
	var architecture := group(parent,"Architecture")
	var white: StandardMaterial3D=load("res://assets/materials/painted_wall.tres").duplicate()
	white.albedo_color=Color("deddd4") if firm=="a" else Color("d5cbb7")
	var brick: Material=load("res://assets/materials/office_brick.tres")
	var wood: Material=load("res://assets/materials/office_wood.tres")
	var dark := material("343d3b",0.8,0.1)
	var height := 3.6 if firm=="a" else 4.3
	box(architecture,"Foundation",Vector3(24,0.1,18),Vector3(0,-0.05,-7),material("747774"),true)
	var carpet := OfficeDress.fabric(Color("596369"))
	box(architecture,"Floor",Vector3(23.72,0.012,17.72),Vector3(0,0.006,-7),carpet if firm=="a" else wood)
	# Continuous floor collision avoids raised thresholds across the entrance.
	box(architecture,"RearWall",Vector3(24,height,0.3),Vector3(0,height/2,-16),white if firm=="a" else brick,true)
	for side in [-1,1]:
		box(architecture,"SideWall",Vector3(0.3,height,18),Vector3(side*12,height/2,-7),white if firm=="a" else brick,true)
		box(architecture,"FrontSill",Vector3(8.8,0.72,0.3),Vector3(side*7.6,0.36,2),white if firm=="a" else brick,true)
		box(architecture,"FrontHeader",Vector3(8.8,height-2.8,0.3),Vector3(side*7.6,(height+2.8)/2,2),white if firm=="a" else brick,true)
		for offset in [-4.3,4.3]: box(architecture,"FrontPier",Vector3(0.25,2.08,0.3),Vector3(side*7.6+offset,1.76,2),white if firm=="a" else brick,true)
		window(architecture,Vector3(side*7.6,1.76,2.02),8.3,2.0)
		# A thin blocker matches the visible pane; the entrance stays fully open.
		var blocker := StaticBody3D.new()
		architecture.add_child(blocker)
		Shapes.collider(blocker,Vector3(8.3,2.0,0.07),Vector3(side*7.6,1.76,2.02))
		box(architecture,"Skirting",Vector3(0.09,0.13,17.6),Vector3(side*11.8,0.075,-7),dark)
		for z in [-4.4,-9.6]:
			window(architecture,Vector3(side*11.78,2.0,z),3.3,1.8,true)
			for slat in range(9): box(architecture,"Blind",Vector3(0.06,0.016,3.3),Vector3(side*11.70,2.75-slat*0.18,z),material("a3a69e"))
	box(architecture,"EntranceHeader",Vector3(6.2,height-3.0,0.3),Vector3(0,(height+3)/2,2),white if firm=="a" else brick,true)
	box(architecture,"Ceiling",Vector3(24,0.2,18),Vector3(0,height+0.10,-7),material("d4d1c6") if firm=="a" else material("535957"),true)
	var roof := group(parent,"CeilingServices")
	if firm=="a":
		for z in [-1.5,-5.5,-9.5,-14.2]:
			box(roof,"AcousticRaft",Vector3(20,0.13,1.7),Vector3(0,3.32,z),material("caccc5"))
			for x in [-9,0,9]: box(roof,"Suspension",Vector3(0.025,0.2,0.025),Vector3(x,3.48,z),dark)
		for x in [-10,-3.7,3.7,10]: box(roof,"CeilingJoint",Vector3(0.018,0.015,17.7),Vector3(x,3.595,-7),material("777f80"))
	else:
		for z in [-1,-6,-11,-15.5]:
			box(roof,"ExposedBeam",Vector3(23.7,0.22,0.18),Vector3(0,3.95,z),dark)
			for y in [3.81,4.08]: box(roof,"BeamFlange",Vector3(23.7,0.04,0.30),Vector3(0,y,z),dark)
		for x in [-3.8,4.4]:
			tube(roof,"Duct",0.21,17.6,Vector3(x,3.7,-7),Vector3(PI/2,0,0),material("949b98",0.43,0.7))
			for z in [-2,-6,-10,-14]:
				box(roof,"DuctHanger",Vector3(0.5,0.035,0.05),Vector3(x,3.48,z),dark)
		box(roof,"CableTray",Vector3(0.32,0.09,17.6),Vector3(0.6,4.02,-7),dark)
	# A genuine multi-storey street frontage replaces the single flat roof edge.
	var facade := group(parent,"StreetFacade")
	var levels := 3 if firm=="a" else 1
	for level in range(levels):
		var base := height+0.2+level*3.0
		box(facade,"UpperVolume",Vector3(24,3,18),Vector3(0,base+1.5,-7),material("b1b7b5") if firm=="a" else brick)
		box(facade,"FloorBand",Vector3(24.3,0.19,0.36),Vector3(0,base,2.04),material("6d787a") if firm=="a" else dark)
		for x in [-10,-6,-2,2,6,10]: window(facade,Vector3(x,base+1.5,2.17),3.1,2.0)
	for x in [-11.8,-3.25,3.25,11.8]:
		box(facade,"FacadeFin",Vector3(0.16,height+levels*3,0.3),Vector3(x,(height+levels*3)/2,2.23),material("85918e") if firm=="a" else dark)
	box(facade,"Canopy",Vector3(7.1,0.18,1.65),Vector3(0,3.14,2.75),dark)
	sign_at(facade,"GUICHENG  /  规程科技" if firm=="a" else "ZIJIREN  /  自己人网络",Vector3(0,3.63,3.25),6.5,60)

func lighting(parent: Node3D, firm: String) -> void:
	var lights := group(parent,"Lighting")
	var warm := Color("edf3f4") if firm=="a" else Color("ffdeae")
	var glow := material("f7ecda",0.5).duplicate() as StandardMaterial3D
	glow.emission_enabled=true
	glow.emission=warm
	for x in [-7,0,7]:
		for z in [-2.5,-8,-14]:
			var y := 3.12 if firm=="a" else 3.20
			box(lights,"Pendant",Vector3(1.9,0.065,0.20),Vector3(x,y,z),material("394446"))
			box(lights,"Diffuser",Vector3(1.82,0.02,0.16),Vector3(x,y-0.035,z),glow)
			if firm=="b":
				for dx in [-0.7,0.7]: tube(lights,"PendantWire",0.009,0.8,Vector3(x+dx,y+0.4,z),Vector3.ZERO,material("292e2e"))
			var light := OmniLight3D.new()
			lights.add_child(light)
			light.position=Vector3(x,y-0.15,z)
			light.omni_range=6.2
			light.light_energy=0.9 if firm=="a" else 1.05
			light.light_color=warm
	for x in [-7,6]:
		var key := SpotLight3D.new()
		lights.add_child(key)
		key.position=Vector3(x,3.1,-5.5)
		key.rotation.x=-PI/2
		key.spot_range=11
		key.spot_angle=70
		key.light_energy=1.8
		key.light_color=warm
		key.shadow_enabled=true
		key.shadow_bias=0.035

func dressing(parent: Node3D, firm: String) -> void:
	var details := group(parent,"WorkplaceDetails")
	var wood: Material=load("res://assets/materials/office_wood.tres")
	var metal := material("465451",0.45,0.6)
	# The public aisle and every v11 work/contact position remain unobstructed.
	if firm=="a":
		box(details,"ReceptionBackdrop",Vector3(3.6,2.55,0.06),Vector3(-3.15,1.45,-1.4),wood,true)
		for x in range(17): box(details,"ReceptionSlat",Vector3(0.035,2.5,0.07),Vector3(-4.85+x*0.21,1.45,-1.34),metal)
		sign_at(details,"规程科技\nGUICHENG TECHNOLOGY",Vector3(-3.2,2.17,-1.26),3.2,46)
	else:
		box(details,"ReceptionLowScreen",Vector3(3.6,1.05,0.10),Vector3(-3.15,0.54,-1.4),wood,true)
		box(details,"ReceptionNotice",Vector3(1.18,0.85,0.07),Vector3(-4.3,1.9,-1.4),material("716953"))
		for i in range(3): box(details,"RecruitmentNote",Vector3(0.22,0.28,0.008),Vector3(-4.62+i*0.3,1.9,-1.35),material("e4d9b5"))
		sign_at(details,"招聘 / 找阿诚",Vector3(-4.3,2.4,-1.32),1.8,40)
	# Tea counter occupies the rear-right corner, away from meeting and delivery routes.
	var tea := group(details,"TeaPoint")
	box(tea,"Cabinet",Vector3(3.4,0.88,0.62),Vector3(8.3,0.44,-15.48),material("647773") if firm=="a" else wood,true)
	box(tea,"CounterLeft",Vector3(1.37,0.055,0.72),Vector3(7.225,0.91,-15.46),material("c5c2b4",0.35))
	box(tea,"CounterRight",Vector3(1.37,0.055,0.72),Vector3(9.375,0.91,-15.46),material("c5c2b4",0.35))
	for z in [-15.77,-15.15]: box(tea,"SinkRim",Vector3(0.78,0.055,0.10),Vector3(8.3,0.91,z),material("c5c2b4",0.35))
	box(tea,"SinkBasin",Vector3(0.70,0.035,0.50),Vector3(8.3,0.81,-15.46),material("7b8584",0.28,0.65))
	for x in [7.935,8.665]: box(tea,"SinkSide",Vector3(0.035,0.10,0.52),Vector3(x,0.855,-15.46),material("7b8584",0.28,0.65))
	tube(tea,"TapStem",0.025,0.24,Vector3(8.3,1.06,-15.72),Vector3.ZERO,metal)
	tube(tea,"TapSpout",0.024,0.22,Vector3(8.3,1.18,-15.62),Vector3(PI/2,0,0),metal)
	for x in [7.1,8.3,9.5]:
		box(tea,"DoorSeam",Vector3(0.016,0.78,0.008),Vector3(x,0.44,-15.16),metal)
		box(tea,"Handle",Vector3(0.20,0.03,0.045),Vector3(x+0.3,0.70,-15.12),metal)
	box(tea,"CoffeeMachine",Vector3(0.45,0.52,0.42),Vector3(7.5,1.20,-15.42),material("333d3f",0.35,0.35))
	box(tea,"CoffeeSpout",Vector3(0.26,0.025,0.10),Vector3(7.5,1.15,-15.17),metal)
	for x in [9.0,9.3,9.6]: tube(tea,"Mug",0.06,0.12,Vector3(x,0.998,-15.25),Vector3.ZERO,material("e0dbcf",0.22))
	sign_at(tea,"茶水 / TEA POINT" if firm=="a" else "杯子用完记得洗",Vector3(8.3,1.9,-15.76),2.5,40)
	# Pinboard and shelves give B a different working culture and silhouette.
	if firm=="b":
		box(details,"NoticeBoard",Vector3(2.8,1.45,0.065),Vector3(2.4,1.8,-15.74),material("887052"))
		for i in range(9):
			var note := box(details,"PinnedPaper",Vector3(0.30,0.36,0.009),Vector3(1.42+(i%4)*0.57,2.16-(i/4)*0.46,-15.69),material("e4d9b5") if i%2 else material("b6c9c0"))
			note.rotation.z=0.035*(i%3-1)
		for y in [0.2,0.95,1.7,2.45]: box(details,"StorageShelf",Vector3(0.70,0.04,3.5),Vector3(11.35,y,-7),wood)
		for z in [-8.7,-5.3]: box(details,"ShelfUpright",Vector3(0.045,2.6,0.045),Vector3(11.65,1.3,z),metal)
		for i in range(5): box(details,"ArchiveBox",Vector3(0.42,0.42,0.43),Vector3(11.27,1.18,-8.35+i*0.58),material("9c8766"))
	else:
		box(details,"MeetingBackdrop",Vector3(6.4,2.7,0.045),Vector3(0.7,1.5,-15.75),wood)
		sign_at(details,"会议与交付\nMEETING  /  REVIEW",Vector3(1.3,2.35,-15.67),3.6,48)
		for i in range(4): box(details,"ArchiveBinder",Vector3(0.09,0.31,0.24),Vector3(-10.12+i*0.11,1.46,-4.04),material("566d71"))
	# Wall sockets and HVAC grilles sit flush, never in actor paths.
	for side in [-1,1]:
		for z in [-2,-7,-12]:
			box(details,"Socket",Vector3(0.03,0.085,0.13),Vector3(side*11.81,0.32,z),material("c8c9bd"))
			box(details,"Conduit",Vector3(0.025,0.025,4.7),Vector3(side*11.80,0.19,z),material("8a9089"))
		for z in [-3,-11]:
			for i in range(8): box(details,"AirGrille",Vector3(0.03,0.018,1.2),Vector3(side*11.80,2.85+i*0.035,z),metal)

func own_descendants(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner=scene
		# Preserve external PackedScenes and their own child ownership.
		if child.scene_file_path.is_empty(): own_descendants(child,scene)

func run() -> void:
	var output := "res://build/company-scenes"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for firm in ["a","b"]:
		var company := Node3D.new()
		company.name="Company"+firm.to_upper()
		root.add_child(company)
		anchors(company,firm)
		shell(company,firm)
		RoomSource.build(company,firm)
		lighting(company,firm)
		dressing(company,firm)
		own_descendants(company,company)
		var scene := PackedScene.new()
		if scene.pack(company)!=OK or ResourceSaver.save(scene,output.path_join("company_"+firm+".tscn"))!=OK:
			quit(1)
			return
		print("COMPANY_SCENE ",firm," nodes=",company.find_children("*","",true,false).size())
		company.queue_free()
		await process_frame
	quit()

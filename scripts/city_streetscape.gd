class_name CityStreetscape
extends Node3D

const GRASS_PATCHES := [[Vector3(-6.5,0,35),Vector3(3,.025,24)],[Vector3(6.5,0,35),Vector3(3,.025,24)],[Vector3(-4.5,0,78),Vector3(2,.025,20)],[Vector3(44,0,68),Vector3(39,.025,7)]]

# Authored lots share repeated geometry. Batches stay within 32 m cells so the
# entire district does not become a single unculled render object.
var materials := {}
var batches := {}
var lamps: Array[OmniLight3D]=[]
var night_materials: Array[StandardMaterial3D]=[]
var last_night := -1.0
var piece_count := 0
var trees: Array[CityTree]=[]
var water: ShaderMaterial
var wave_time := 0.0

func _init() -> void:
	name="Streetscape"
	for item in [["stone","bcb9a9"],["trim","c7bfa9"],["metal","39494a"],["glass","344e55"],["reveal","263638"],["timber","8d704e"],["roof","70746b"],["soil","6b7050"],["grass","687951"],["brick_red","805a46"],["warm_light","e5c38a"]]:
		materials[item[0]]=Shapes.material(Color(item[1]))
	materials.glass.roughness=.26
	materials.glass.metallic=.35
	materials.metal.metallic=.45
	materials.metal.roughness=.5
	for key in ["old_wall","home_wall","paving","brick"]:
		materials[key]=load("res://assets/materials/"+({"old_wall":"painted_wall","home_wall":"painted_wall","paving":"pavement","brick":"office_brick"}[key])+".tres").duplicate()
	materials.old_wall.albedo_color=Color("c1b396")
	materials.home_wall.albedo_color=Color("b6c0b7")
	materials.brick.albedo_color=Color("c7b49d")
	for entry in [["old_ochre","b89b77"],["old_rose","b68c7b"],["home_chalk","d0c9b6"],["home_sage","a6b3a8"],["curtain","c3bda6"],["awning","466b60"]]:
		materials[entry[0]]=materials.old_wall.duplicate()
		materials[entry[0]].albedo_color=Color(entry[1])
	for key in ["paving"]:
		var surface := ShaderMaterial.new()
		surface.shader=load("res://assets/materials/city_"+key+".gdshader")
		materials[key]=surface
	materials.grass=load("res://assets/materials/city_grass.tres")
	materials.timber=load("res://assets/materials/office_wood.tres").duplicate()
	materials.timber.albedo_color=Color("bdab8b")
	materials.stone=load("res://assets/materials/pavement.tres").duplicate()
	# Cast concrete uses the source's surface relief, not its floor aggregate
	# colour: the latter reads as gravel on the gallery's vertical structure.
	materials.stone.albedo_texture=null
	materials.stone.albedo_color=Color("bcb9a9")
	for entry in [["surface_color","Diffuse"],["surface_normal","nor_gl"],["surface_arm","arm"]]:
		materials.paving.set_shader_parameter(entry[0],load("res://assets/polyhaven/concrete_floor_01/concrete_floor_01_"+entry[1]+"_2k.jpg"))
	for key in ["warm_light","window_lit"]:
		if key=="window_lit": materials[key]=Shapes.material(Color("766f53"))
		materials[key].emission_enabled=true
		materials[key].emission=Color("ffd39a")
		materials[key].emission_energy_multiplier=0
		night_materials.append(materials[key])

func piece(kind: String,material: String,transform: Transform3D) -> void:
	var cell := Vector2i(floori(transform.origin.x/32),floori(transform.origin.z/32))
	var key := "%s_%s_%d_%d" % [kind,material,cell.x,cell.y]
	if not batches.has(key): batches[key]={"kind":kind,"material":material,"transforms":[]}
	batches[key].transforms.append(transform)
	piece_count+=1

func box(size: Vector3,at: Vector3,material: String,yaw: float=0) -> void:
	piece("box",material,Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),at))

func solid(size: Vector3,at: Vector3,material: String,yaw: float=0) -> void:
	box(size,at,material,yaw)
	var body := StaticBody3D.new()
	add_child(body)
	body.position=at
	body.rotation.y=yaw
	Shapes.collider(body,size)

func facade(point: Vector3,size: Vector3,old_town: bool) -> void:
	var variant := (int(absf(point.x))+int(point.z))%3
	var wall: String=["old_wall","old_ochre","old_rose"][variant] if old_town else ["home_wall","home_chalk","home_sage"][variant]
	solid(size,point+Vector3(0,size.y/2,0),wall)
	box(Vector3(size.x+.18,.85,size.z+.18),point+Vector3(0,.425,0),"brick" if old_town else "stone")
	box(Vector3(size.x+.3,.16,size.z+.3),point+Vector3(0,size.y+.04,0),"trim")
	box(Vector3(size.x-.3,.08,size.z-.3),point+Vector3(0,size.y+.15,0),"roof")
	for face in range(4):
		var yaw := face*PI/2
		var rot := Basis(Vector3.UP,yaw)
		var width := size.x if face%2==0 else size.z
		var depth := size.z if face%2==0 else size.x
		var center := point+rot*Vector3(0,0,depth/2+.06)
		box(Vector3(width+.18,.5,.18),center+Vector3(0,size.y+.36,0),wall,yaw)
		var columns := 3 if old_town or variant==1 else 4
		var spacing := (width-1.8)/columns
		var window_width := spacing*.68
		for floor_index in range(int((size.y-1)/3)):
			var y := 1.72+floor_index*3.0
			if old_town: box(Vector3(width+.22,.09,.18),center+Vector3(0,y+1.27,0),"trim",yaw)
			for column in range(columns):
				# Leave the actual ground-floor entrance readable, without a window
				# protruding through its lintel or handles.
				if floor_index==0 and face in [0,2] and (column==floori(columns*.5) or columns==4 and column==1): continue
				var window := center+rot*Vector3((column-(columns-1)*.5)*spacing,y,0)
				box(Vector3(window_width+.22,2.02,.12),window,"reveal",yaw)
				var lit := (floor_index*3+column+face+variant)%5==1
				box(Vector3(window_width,1.8,.1),window+rot*Vector3(0,0,.045),"window_lit" if lit else "glass",yaw)
				var blind := (column*3+face+floor_index+variant)%4
				if blind==0:
					for slat in range(7): box(Vector3(window_width-.06,.07,.018),window+rot*Vector3(0,.77-slat*.105,.106),"curtain",yaw)
				elif blind==1:
					for side in [-1,1]: box(Vector3(window_width*.18,1.7,.018),window+rot*Vector3(side*window_width*.37,0,.106),"curtain",yaw)
				for dx in [-window_width/2,0,window_width/2]: box(Vector3(.055,1.93,.22),window+rot*Vector3(dx,0,.12),"timber" if old_town else "metal",yaw)
				for dy in [-.94,.94]: box(Vector3(window_width+.12,.07,.22),window+rot*Vector3(0,dy,.12),"trim",yaw)
				box(Vector3(window_width+.3,.12,.42),window+rot*Vector3(0,-1.02,.12),"stone",yaw)
				if floor_index>0:
					if old_town:
						if (column+face)%2==0:
							box(Vector3(.72,.48,.39),window+rot*Vector3(window_width/2+.6,-.79,.25),"stone",yaw)
							for bar in range(4): box(Vector3(.55,.025,.04),window+rot*Vector3(window_width/2+.6,-.94+bar*.09,.47),"metal",yaw)
						if variant==1: box(Vector3(window_width+.4,.09,.72),window+rot*Vector3(0,1.02,.29),"awning",yaw)
					elif (column+variant)%2==0:
						box(Vector3(window_width+.5,.16,1),window+rot*Vector3(0,-1.03,.45),"stone",yaw)
						box(Vector3(window_width+.38,.06,.065),window+rot*Vector3(0,-.05,.94),"metal",yaw)
						for bar in range(8): box(Vector3(.035,.94,.035),window+rot*Vector3(-window_width/2+bar*window_width/7,-.52,.94),"metal",yaw)
						# A planter sits on the balcony slab, inside the rail.
						if (floor_index+face+column)%3==0:
							box(Vector3(.65,.25,.27),window+rot*Vector3(.25,-.82,.66),"brick_red",yaw)
							for stem in range(5): box(Vector3(.11,.16+stem%2*.08,.16),window+rot*Vector3(.02+stem*.11,-.63,.66),"awning",yaw)
		for dx in [-width/2+.25,width/2-.25]: box(Vector3(.1,size.y,.1),center+rot*Vector3(dx,size.y/2,.12),"metal",yaw)
		if not old_town:
			box(Vector3(.55,size.y,.12),center+rot*Vector3(0,size.y/2,.11),"brick",yaw)
		if face in [0,2]:
			var doorway := center+rot*Vector3(0,1.25,.1)
			box(Vector3(2.9,2.5,.2),doorway,"reveal",yaw)
			box(Vector3(2.55,2.32,.25),doorway,"timber" if old_town else "glass",yaw)
			box(Vector3(.06,2.3,.3),doorway,"metal",yaw)
			for dx in [-.18,.18]: box(Vector3(.04,.4,.08),doorway+rot*Vector3(dx,0,.17),"trim",yaw)
			box(Vector3(3.6,.13,1.0),center+rot*Vector3(0,2.95,.35),"awning" if old_town else "metal",yaw)
			var address := "榕树街 %d号 · 住户入口" % (int(absf(point.x))+int(point.z)) if old_town else "东里 · %d幢" % (int(point.x/10)+int(point.z/20))
			plaque(address,center+rot*Vector3(0,2.65,.3),3.1,yaw)
			if not old_town:
				for row in range(3):
					for column in range(3): box(Vector3(.29,.22,.16),center+rot*Vector3(2.05+column*.32,.65+row*.26,.18),"metal",yaw)
	# Low parapets, stair access and equipment differ by use; no new floor
	# becomes a traversable destination just because it has a facade.
	box(Vector3(3.5,1.8,3),point+Vector3(-2,size.y+.95,-2),wall)
	box(Vector3(3.85,.15,3.3),point+Vector3(-2,size.y+1.9,-2),"roof")
	for side in [-1,1]:
		box(Vector3(1.5,.85,1.3),point+Vector3(3,size.y+.6,side*2),"stone")
		for slat in range(5): box(Vector3(1.27,.05,.04),point+Vector3(3,size.y+.28+slat*.14,side*2+.68),"metal")

func plaque(text: String,at: Vector3,width: float,yaw: float=0) -> void:
	box(Vector3(width,.38,.07),at,"metal",yaw)
	var label := Shapes.label(self,text,at+Basis(Vector3.UP,yaw)*Vector3(0,0,.045),40)
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation.y=yaw
	label.pixel_size=.004
	label.outline_size=0
	label.modulate=Color("eadfc4")

func tree(at: Vector3,seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var visual := CityTree.new()
	visual.name="Tree"+str(seed_value)
	visual.position=at
	visual.rotation.y=rng.randf_range(0,TAU)
	visual.scale=Vector3.ONE*rng.randf_range(1.15,1.32)
	add_child(visual)
	trees.append(visual)
	var body := StaticBody3D.new()
	add_child(body)
	body.position=at+Vector3(0,1.5,0)
	Shapes.collider(body,Vector3(.35,3,.35))

func bench(at: Vector3,yaw: float=0,id: String="") -> StaticBody3D:
	var rot := Basis(Vector3.UP,yaw)
	var seat: StaticBody3D=StaticBody3D.new() if id=="" else CityBench.new()
	if seat is CityBench: seat.stable_id=id
	add_child(seat)
	seat.position=at
	seat.rotation.y=yaw
	for dx in [-.95,.95]:
		box(Vector3(.14,.44,.6),at+rot*Vector3(dx,.22,0),"metal",yaw)
		Shapes.collider(seat,Vector3(.14,.44,.6),Vector3(dx,.22,0))
	for slat in range(4): box(Vector3(2.4,.07,.13),at+rot*Vector3(0,.47,-.23+slat*.15),"timber",yaw)
	Shapes.collider(seat,Vector3(2.4,.07,.6),Vector3(0,.47,0))
	box(Vector3(2.4,.55,.12),at+rot*Vector3(0,.8,.3),"timber",yaw)
	Shapes.collider(seat,Vector3(2.4,.55,.12),Vector3(0,.8,.3))
	return seat

func lamp(at: Vector3) -> void:
	solid(Vector3(.13,4.4,.13),at+Vector3(0,2.2,0),"metal")
	box(Vector3(1.6,.12,.36),at+Vector3(.65,4.4,0),"metal")
	box(Vector3(.8,.035,.27),at+Vector3(.85,4.32,0),"warm_light")
	var light := OmniLight3D.new()
	light.position=at+Vector3(.75,4.05,0)
	light.light_color=Color("ffdcab")
	light.omni_range=10
	light.light_energy=0
	light.shadow_enabled=false
	light.distance_fade_enabled=true
	light.distance_fade_begin=55
	light.distance_fade_length=15
	add_child(light)
	lamps.append(light)

func wayfinding(title: String,at: Vector3) -> void:
	solid(Vector3(.09,2.4,.09),at+Vector3(0,1.2,0),"metal")
	box(Vector3(2.5,.6,.09),at+Vector3(0,2.1,0),"metal")
	plaque(title,at+Vector3(0,2.1,.055),2.4)

func landscape() -> void:
	# Thin surfaces preserve y=0 collision: the character has no step-climbing.
	for item in [[Vector3(0,0,18),Vector3(140,.018,6)],[Vector3(0,0,94),Vector3(140,.018,6)],[Vector3(-66,0,56),Vector3(6,.018,78)],[Vector3(66,0,56),Vector3(6,.018,78)],[Vector3(-87,0,56),Vector3(8,.018,90)],[Vector3(87,0,56),Vector3(8,.018,90)],[Vector3(-47,0,52),Vector3(38,.018,17)],[Vector3(47,0,56),Vector3(38,.018,18)],[Vector3(0,0,116),Vector3(214,.018,12)]]:
		box(item[1],item[0]+Vector3(0,.005,0),"paving")
	for item in GRASS_PATCHES:
		box(item[1]+Vector3(1,0,1),item[0]+Vector3(0,.015,0),"stone")
		box(item[1],item[0]+Vector3(0,.02,0),"grass")
	# Flush paving joints, spaced in metres rather than scaled over the whole map.
	for x in range(-102,103,3): box(Vector3(.025,.005,12),Vector3(x,.017,116),"stone")
	for z in [111,114,117,120]: box(Vector3(212,.005,.025),Vector3(0,.017,z),"stone")
	for z in [16,20,92,96]: box(Vector3(138,.006,.14),Vector3(0,.019,z),"trim")
	for x in [-69,-63,63,69]: box(Vector3(.14,.006,77),Vector3(x,.019,56),"trim")
	var tree_points := [Vector3(-60,0,48),Vector3(-36,0,48),Vector3(28,0,48),Vector3(52,0,48),Vector3(-60,0,70),Vector3(-36,0,70),Vector3(28,0,70),Vector3(52,0,70),Vector3(-6.5,0,29),Vector3(-6.5,0,45),Vector3(-4.5,0,70),Vector3(-4.5,0,87),Vector3(6.5,0,29),Vector3(6.5,0,45),Vector3(38,0,68)]
	for x in [-90,-66,-42,-18,18,42,66,90]: tree_points.append(Vector3(x,0,122))
	for i in range(tree_points.size()):
		tree(tree_points[i],900+i)
		box(Vector3(2,.022,2),tree_points[i]+Vector3(0,.015,0),"soil")
	for at in [Vector3(-64,0,43),Vector3(-64,0,73),Vector3(64,0,43),Vector3(64,0,73),Vector3(-19,0,54),Vector3(21,0,54),Vector3(-48,0,118),Vector3(-12,0,118),Vector3(24,0,118),Vector3(60,0,118)]: lamp(at)
	for at in [Vector3(-43,0,63),Vector3(-23,0,63),Vector3(32,0,49),Vector3(54,0,63)]: bench(at)
	for x in [-36,-18,18,36]: bench(Vector3(x,0,120))
	# A continuous sea wall and repeated upright rails ground the waterfront.
	solid(Vector3(213,.48,.45),Vector3(0,.24,125.8),"stone")
	for x in range(-104,106,2): box(Vector3(.045,.72,.045),Vector3(x,.84,125.8),"metal")
	box(Vector3(213,.065,.065),Vector3(0,1.2,125.8),"metal")
	for at in [Vector3(-62,0,61),Vector3(60,0,62),Vector3(-31,0,120),Vector3(31,0,120)]:
		solid(Vector3(.55,.9,.55),at+Vector3(0,.45,0),"metal")
		box(Vector3(.62,.09,.62),at+Vector3(0,.94,0),"timber")
	wayfinding("榕树街 · 社区书屋",Vector3(-62,0,44))
	wayfinding("东里 · 公共花园",Vector3(55,0,50))
	wayfinding("海风步道 · 城市与海",Vector3(8,0,120))

func flush() -> void:
	var cube := BoxMesh.new()
	cube.size=Vector3.ONE
	for key in batches:
		var batch: Dictionary=batches[key]
		var mesh := MultiMesh.new()
		mesh.transform_format=MultiMesh.TRANSFORM_3D
		mesh.mesh=cube
		mesh.instance_count=batch.transforms.size()
		for i in range(mesh.instance_count): mesh.set_instance_transform(i,batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name=key
		instance.multimesh=mesh
		instance.material_override=materials[batch.material]
		add_child(instance)
	set_meta("pieces",piece_count)
	set_meta("batches",batches.size())
	batches.clear()

func daylight(value: float) -> void:
	if water: water.set_shader_parameter("daylight",value)
	var night := 1.0-smoothstep(.04,.35,value)
	if is_equal_approx(night,last_night): return
	last_night=night
	for light in lamps: light.light_energy=night*1.1
	for material in night_materials: material.emission_energy_multiplier=night*.8

func _process(delta: float) -> void:
	if not water: return
	# The inherited process mode pauses with the world. All wave frequencies
	# share this period, so wrapping time cannot introduce a surface jump.
	wave_time=fmod(wave_time+delta,TAU*200)
	water.set_shader_parameter("wave_time",wave_time)

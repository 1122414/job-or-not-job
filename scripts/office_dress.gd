class_name OfficeDress
extends RefCounted

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius=radius
	shape.bottom_radius=radius
	shape.height=height
	shape.radial_segments=16
	mesh.mesh=shape
	mesh.material_override=Shapes.material(color)
	parent.add_child(mesh)
	mesh.position=pos
	return mesh

static func fabric(color: Color) -> StandardMaterial3D:
	var mat := Shapes.material(color)
	var noise := FastNoiseLite.new()
	noise.seed=17
	noise.frequency=0.28
	var texture := NoiseTexture2D.new()
	texture.width=128
	texture.height=128
	texture.noise=noise
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.65,0.65,0.65))
	gradient.set_color(1,Color(1,1,1))
	texture.color_ramp=gradient
	mat.albedo_texture=texture
	mat.uv1_triplanar=true
	mat.uv1_scale=Vector3(2,2,2)
	return mat

static func chair(parent: Node3D, pos: Vector3) -> void:
	var group := Node3D.new()
	parent.add_child(group)
	group.position=pos
	var black := Color("20252a")
	Shapes.box(group,Vector3(0.62,0.12,0.55),Vector3(0,0.52,0),black)
	var back := Shapes.box(group,Vector3(0.6,0.65,0.09),Vector3(0,0.84,0.23),Color("30353a"))
	back.rotation.x=-0.12
	cylinder(group,0.055,0.38,Vector3(0,0.27,0),Color("838a90"))
	for angle in range(5):
		var limb := Shapes.box(group,Vector3(0.065,0.045,0.42),Vector3.ZERO,black)
		limb.rotation.y=angle*TAU/5
		limb.position=Vector3(sin(limb.rotation.y)*0.16,0.1,cos(limb.rotation.y)*0.16)
		cylinder(group,0.055,0.065,limb.position*Vector3(1.8,1,1.8),black)
	for side in [-1,1]:
		Shapes.box(group,Vector3(0.045,0.3,0.045),Vector3(side*0.32,0.67,0),black)
		Shapes.box(group,Vector3(0.075,0.055,0.36),Vector3(side*0.32,0.82,0),black)

static func plant(parent: Node3D, pos: Vector3) -> void:
	cylinder(parent,0.22,0.4,pos+Vector3.UP*0.2,Color("d2d0c5"))
	for i in range(7):
		var angle := i*2.4
		var leaf := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius=0.13
		sphere.height=0.7
		leaf.mesh=sphere
		leaf.material_override=Shapes.material(Color("3b5e3d"))
		parent.add_child(leaf)
		leaf.position=pos+Vector3(sin(angle)*0.13,0.65+i*0.05,cos(angle)*0.13)
		leaf.rotation=Vector3(cos(angle)*0.45,angle,sin(angle)*0.45)

static func build(game: Node3D) -> void:
	var carpet := fabric(Color("56595b"))
	for center in [-14.0,14.0]:
		var floor_mesh := Shapes.box(game,Vector3(23.7,0.012,17.7),Vector3(center,0.006,-7),Color.WHITE)
		floor_mesh.material_override=carpet
		# Full height ceiling and grids keep the camera inside a finished office volume.
		Shapes.solid(game,Vector3(24,0.2,18),Vector3(center,3.75,-7),Color("a5a59f"))
		for x in range(-12,13,2): Shapes.box(game,Vector3(0.022,0.025,18),Vector3(center+x,3.63,-7),Color("7d817f"))
		for z in range(-16,3,2): Shapes.box(game,Vector3(24,0.025,0.022),Vector3(center,3.63,z),Color("7d817f"))
		for x in [-7,0,7]:
			for z in [-3,-9,-14]:
				Shapes.box(game,Vector3(1.5,0.07,0.62),Vector3(center+x,3.58,z),Color("343b3e"))
				var lamp := Shapes.box(game,Vector3(1.38,0.03,0.51),Vector3(center+x,3.53,z),Color("e3e2d6"))
				var lamp_mat := Shapes.material(Color("dedfd3"))
				lamp_mat.emission_enabled=true
				lamp_mat.emission=Color("dedfd3")
				lamp.material_override=lamp_mat
				var light := OmniLight3D.new()
				game.add_child(light)
				light.position=Vector3(center+x,2.9,z)
				light.omni_range=6.5
				light.light_energy=0.85
				light.light_color=Color("fff4dc")
		# Wall trim and window frames.
		for side in [-1,1]:
			Shapes.box(game,Vector3(0.08,0.15,17.5),Vector3(center+side*11.8,0.1,-7),Color("494f51"))
			for z in [-4,-10]:
				Shapes.box(game,Vector3(0.035,1.55,3.5),Vector3(center+side*11.78,2.1,z),Color("65818b"))
				for dy in [-0.8,0.8]: Shapes.box(game,Vector3(0.055,0.055,3.6),Vector3(center+side*11.74,2.1+dy,z),Color("393f42"))
				for dz in [-1.8,0,1.8]: Shapes.box(game,Vector3(0.055,1.65,0.06),Vector3(center+side*11.74,2.1,z+dz),Color("393f42"))
				for slat in range(7): Shapes.box(game,Vector3(0.07,0.025,3.5),Vector3(center+side*11.7,2.8-slat*0.18,z),Color("a0a6a5"))
		var firm := "a" if center<0 else "b"
		for dx in [-7,6]:
			for z in [-2,-6,-11]:
				var id := firm+"_desk_"+str(dx)+"_"+str(z)
				game.add_prop(id,"desk",Vector3(center+dx,0.85,z))
				game.add_prop(id+"_monitor","monitor",Vector3(center+dx,1.425,z-0.4))
				game.add_prop(id+"_keyboard","keyboard",Vector3(center+dx,1.0,z+0.28))
				game.add_prop(id+"_cup","cup",Vector3(center+dx+1,1.08,z+0.15))
				game.add_prop(id+"_seat","chair",Vector3(center+dx,0.55,z+1.1))
				game.add_prop(id+"_back","panel",Vector3(center+dx,0.7,z-0.9))
				for side in [-1,1]:
					game.add_prop(id+"_side_"+str(side),"side_panel",Vector3(center+dx+side*1.77,0.7,z-0.1))
		for side in [-1,1]: game.add_prop(firm+"_plant_"+str(side),"plant",Vector3(center+side*10.5,0.45,0 if side<0 else -14))
		game.add_prop(firm+"_cooler","cooler",Vector3(center-4.8,0.75,0))
		# Glass meeting-room dividers are visual only; the existing open aisles stay traversable.
		var glass := Shapes.material(Color(0.45,0.6,0.62,0.20))
		glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness=0.2
		for dx in [-9,9]:
			var pane := Shapes.box(game,Vector3(5.4,2.8,0.03),Vector3(center+dx,1.55,-14),Color.WHITE)
			pane.material_override=glass
			for edge in [-2.7,0,2.7]: Shapes.box(game,Vector3(0.045,2.9,0.065),Vector3(center+dx+edge,1.55,-14),Color("465257"))
	# Context beyond the playable block: façades rather than a bare horizon.
	for x in [-30,-18,-6,6,18,30]:
		Shapes.box(game,Vector3(10,12,5),Vector3(x,6,27),Color("778087"))
		for y in [2,5,8,11]:
			for dx in [-3,0,3]: Shapes.box(game,Vector3(1.6,1.8,0.03),Vector3(x+dx,y,24.45),Color("495d68"))

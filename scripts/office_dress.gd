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

static var wood_texture: ImageTexture

static func wood(color: Color) -> StandardMaterial3D:
	if wood_texture==null:
		var image := Image.create(256,256,false,Image.FORMAT_RGB8)
		for y in range(256):
			for x in range(256):
				var grain := sin(y*0.32+sin(x*0.025)*2.4)+0.35*sin(y*1.7+x*0.02)
				var shade := 0.94+grain*0.012
				image.set_pixel(x,y,Color(shade,shade,shade))
		image.generate_mipmaps()
		wood_texture=ImageTexture.create_from_image(image)
	var mat := Shapes.material(color)
	mat.albedo_texture=wood_texture
	mat.uv1_triplanar=true
	mat.uv1_scale=Vector3(0.65,0.65,0.65)
	mat.roughness=0.48
	return mat

static func chair(parent: Node3D, pos: Vector3) -> void:
	var group := Node3D.new()
	parent.add_child(group)
	group.position=pos
	var black := Color("20252a")
	Shapes.box(group,Vector3(0.62,0.12,0.55),Vector3(0,0.52,0),black)
	var back := Shapes.box(group,Vector3(0.6,0.46,0.09),Vector3(0,0.78,0.23),Color("30353a"))
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

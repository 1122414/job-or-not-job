class_name Shapes
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

static func collider(parent: CollisionObject3D, size: Vector3, pos: Vector3 = Vector3.ZERO) -> void:
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	parent.add_child(c)
	c.position = pos

static func solid(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	box(body, size, Vector3.ZERO, color)
	collider(body, size)
	return body

static func label(parent: Node3D, text: String, pos: Vector3, size: int = 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 8
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	l.position = pos
	return l

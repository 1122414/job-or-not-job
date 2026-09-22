class_name OfficeProp
extends RigidBody3D

const TYPES := {
	"keyboard":["键盘",Vector3(0.7,0.12,0.25),Color("35495b"),1.0],
	"cup":["杯子",Vector3(0.22,0.3,0.22),Color("cbb489"),0.5],
	"chair":["办公椅",Vector3(0.65,0.75,0.65),Color("30383e"),5.0],
	"table":["会议桌",Vector3(2.8,0.22,1.3),Color("bd8f62"),12.0],
	"printer":["打印机",Vector3(0.9,0.7,0.8),Color("dce3e5"),8.0],
	"desk":["办公桌",Vector3(3.5,0.12,1.5),Color("a68f71"),25.0],
	"monitor":["显示器",Vector3(0.85,0.50,0.12),Color("232a30"),2.0],
	"panel":["工位隔板",Vector3(3.6,1.4,0.12),Color("687578"),20.0],
	"side_panel":["工位隔板",Vector3(0.1,1.4,1.7),Color("687578"),20.0],
	"plant":["盆栽",Vector3(0.5,0.9,0.5),Color("b7b3a5"),6.0],
	"cooler":["饮水机",Vector3(0.55,1.5,0.48),Color("c3c5c4"),15.0]
}
var damage_parts: Array[Node3D] = []
var rest_transforms: Dictionary = {}
var rest_materials: Dictionary = {}
var stable_id := ""
var kind := ""
var title := ""
var home := Vector3.ZERO
var damaged := false
var thrown := false
var flight_time := 0.0
var attack_id := 0
var hits: Dictionary = {}
var base_material: Material
var mesh: MeshInstance3D
var label: Label3D
var game: Node3D

func setup(id: String, type: String, pos: Vector3, owner_game: Node3D) -> void:
	stable_id = id
	kind = type
	game = owner_game
	home = pos
	position = pos
	title = TYPES[kind][0]

func portable() -> bool:
	return kind in ["keyboard", "cup", "monitor"]

func _ready() -> void:
	var size: Vector3 = TYPES[kind][1]
	var color: Color = TYPES[kind][2]
	mesh = Shapes.box(self, size, Vector3.ZERO, color)
	base_material=mesh.material_override
	if kind=="chair":
		Shapes.collider(self,Vector3(0.62,0.12,0.55),Vector3(0,-0.03,0))
		Shapes.collider(self,Vector3(0.60,0.65,0.09),Vector3(0,0.29,0.23))
	else: Shapes.collider(self,size)
	if kind == "chair":
		mesh.hide()
		OfficeDress.chair(self,Vector3(0,-0.55,0))
	if kind == "cup":
		var cup := CylinderMesh.new()
		cup.top_radius=0.11
		cup.bottom_radius=0.085
		cup.height=0.28
		mesh.mesh=cup
		OfficeDress.cylinder(self,0.087,0.006,Vector3(0,0.143,0),Color("44352b"))
		var handle := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius=0.045
		ring.outer_radius=0.073
		handle.mesh=ring
		handle.material_override=Shapes.material(color)
		add_child(handle)
		handle.position.x=0.13
		handle.rotation.x=PI/2
	if kind == "keyboard":
		for row in range(4):
			for col in range(12): Shapes.box(self,Vector3(0.043,0.024,0.039),Vector3(-0.30+col*0.053,0.068,-0.084+row*0.05),Color("72797b"))
	if kind == "printer":
		Shapes.box(self,Vector3(0.75,0.06,0.55),Vector3(0,0.38,0.02),Color("626a6d"))
		Shapes.box(self,Vector3(0.7,0.08,0.55),Vector3(0,-0.22,0.42),Color("3a4145"))
		Shapes.box(self,Vector3(0.56,0.025,0.48),Vector3(0,-0.17,0.46),Color("e4e1d7"))
		Shapes.box(self,Vector3(0.23,0.12,0.03),Vector3(0.2,0.18,0.413),Color("467b86"))
	if kind == "monitor":
		Shapes.box(self,Vector3(0.75,0.42,0.025),Vector3(0,0,0.075),Color("73929c"))
		Shapes.box(self,Vector3(0.10,0.2,0.1),Vector3(0,-0.32,0),Color("292e32"))
		Shapes.box(self,Vector3(0.55,0.035,0.3),Vector3(0,-0.40,0.02),Color("292e32"))
		Shapes.collider(self,Vector3(0.55,0.035,0.3),Vector3(0,-0.40,0.02))
	if kind in ["panel","side_panel"]:
		Shapes.box(self,Vector3(size.x+0.02,0.45,size.z+0.02),Vector3(0,0.45,0),Color("c9c8bc"))
		Shapes.box(self,Vector3(size.x+0.05,0.04,size.z+0.05),Vector3(0,0.72,0),Color("b4b6b2"))
	if kind=="plant":
		mesh.hide()
		OfficeDress.plant(self,Vector3(0,-0.45,0))
	if kind=="cooler":
		OfficeDress.cylinder(self,0.21,0.52,Vector3(0,0.35,0),Color("63889c"))
		Shapes.box(self,Vector3(0.3,0.22,0.03),Vector3(0,0,0.25),Color("424b51"))
	if kind in ["table","desk"]:
		for x in [-1.1,1.1]:
			var leg_height := home.y-0.06
			Shapes.box(self,Vector3(0.1,leg_height,0.85),Vector3(x,-home.y+leg_height/2,0),Color("455665"))
			Shapes.collider(self,Vector3(0.1,leg_height,0.85),Vector3(x,-home.y+leg_height/2,0))
	mass = TYPES[kind][3]
	freeze=anchored()
	collision_layer=world_layer()
	collision_mask=3
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_contact)
	label = Shapes.label(self, title, Vector3(0,0.8,0), 25)
	label.pixel_size=0.0035
	for child in get_children():
		if child is Node3D and child!=label: rest_transforms[child]=child.transform
		if child is MeshInstance3D: rest_materials[child]=child.material_override
	for i in range(4):
		var piece := Shapes.box(self,Vector3(0.16,0.035,0.1),Vector3((i-1.5)*0.16,-size.y*0.4,0.12+i*0.035),Color("3c4141"))
		piece.rotation=Vector3(0.1*i,0.7*i,0.2*i)
		piece.hide()
		damage_parts.append(piece)

func anchored() -> bool:
	return kind in ["desk","panel","side_panel","plant","cooler"] or stable_id.ends_with("_seat")

func world_layer() -> int:
	# Seat layer is included in actors; only the owner has a temporary collision exception.
	return 2 if stable_id.ends_with("_seat") else 1

func apply_damage_state() -> void:
	for child in rest_transforms:
		child.transform=rest_transforms[child]
		if rest_materials.has(child): child.material_override=rest_materials[child]
		if damaged:
			if kind in ["panel","side_panel","desk","plant","cooler"]:
				child.position.y=child.position.y*0.28-home.y*0.72
				child.scale.y=0.28
			elif child is MeshInstance3D or child is Node3D and not child is CollisionShape3D:
				child.rotation.z+=0.18
			if child is MeshInstance3D and child.material_override:
				child.material_override=child.material_override.duplicate()
				child.material_override.albedo_color=Color("414547")
	mesh.material_override=Shapes.material(Color("414547")) if damaged else base_material
	for piece in damage_parts:
		piece.visible=damaged
		if anchored(): piece.position.y=-home.y+0.025

func _physics_process(delta: float) -> void:
	flight_time = maxf(0, flight_time - delta)
	if flight_time == 0:
		thrown = false
	label.visible = false
	if position.y < -8 or absf(position.x) > 60 or absf(position.z) > 60:
		reset_position()

func reset_position() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	position = home
	rotation = Vector3.ZERO

func strike(direction: Vector3, action: int) -> void:
	attack_id = action
	if not damaged:
		damaged=true
		apply_damage_state()
		game.queue_save()
	game.navigation_dirty=2.0
	if anchored(): return
	hits.clear()
	thrown = true
	flight_time = 2.0
	if kind == "table":
		apply_central_impulse((direction + Vector3.UP * 1.4) * 35)
		apply_torque_impulse(Vector3(0,0,30))
	elif kind == "printer":
		apply_central_impulse(direction * 12)
	else:
		apply_central_impulse(direction * 16 + Vector3.UP * 3)

func _contact(body: Node) -> void:
	if not thrown or hits.has(body.get_instance_id()):
		return
	if body is OfficeNPC:
		hits[body.get_instance_id()] = true
		body.hit((body.global_position - global_position).normalized(), 2.0, attack_id)
		game.impact()
	elif body is OfficeProp:
		hits[body.get_instance_id()]=true
		if not body.damaged:
			body.strike((body.position-position).normalized(),attack_id)
			game.on_property_hit(body,attack_id)

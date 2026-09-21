class_name OfficeProp
extends RigidBody3D

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
	title = {"keyboard":"键盘", "cup":"杯子", "chair":"办公椅", "table":"会议桌", "printer":"打印机"}[kind]

func portable() -> bool:
	return kind in ["keyboard", "cup"]

func _ready() -> void:
	var size: Vector3 = {"keyboard":Vector3(0.7,0.12,0.25), "cup":Vector3(0.22,0.3,0.22), "chair":Vector3(0.65,0.75,0.65), "table":Vector3(2.8,0.22,1.3), "printer":Vector3(0.9,0.7,0.8)}[kind]
	var color: Color = {"keyboard":Color("35495b"), "cup":Color("f7bf64"), "chair":Color("3a8d92"), "table":Color("bd8f62"), "printer":Color("dce3e5")}[kind]
	mesh = Shapes.box(self, size, Vector3.ZERO, color)
	base_material=mesh.material_override
	Shapes.collider(self, size)
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
	if kind == "table":
		for x in [-1.1,1.1]:
			Shapes.box(self, Vector3(0.1,0.85,1.0), Vector3(x,-0.5,0), Color("455665"))
		Shapes.collider(self, Vector3(2.4,0.85,1.0), Vector3(0,-0.5,0))
	mass = {"keyboard":1.0,"cup":0.5,"chair":5.0,"table":12.0,"printer":8.0}[kind]
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_contact)
	label = Shapes.label(self, title, Vector3(0,0.8,0), 25)
	label.pixel_size=0.0035

func _physics_process(delta: float) -> void:
	flight_time = maxf(0, flight_time - delta)
	if flight_time == 0:
		thrown = false
	label.visible = visible and game.focus_target==self and game.player.held!=self
	if position.y < -8 or absf(position.x) > 60 or absf(position.z) > 60:
		reset_position()

func reset_position() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	position = home
	rotation = Vector3.ZERO

func strike(direction: Vector3, action: int) -> void:
	attack_id = action
	hits.clear()
	thrown = true
	flight_time = 2.0
	if kind == "table":
		apply_central_impulse((direction + Vector3.UP * 1.4) * 35)
		apply_torque_impulse(Vector3(0,0,30))
	elif kind == "printer":
		damaged = true
		mesh.material_override = Shapes.material(Color("7b7274"))
		label.text = "打印机 · 已损坏"
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

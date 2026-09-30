class_name CityBusVisual
extends Node3D

const ROOT := "res://assets/vehicles/city_bus/"
const DOOR_SECONDS := .8
const DRIVER_SEAT := Vector3(-.65,.40,-2.55)
var door_open := 1.0
var doors: Array[MeshInstance3D]=[]
var wheels: Array[MeshInstance3D]=[]
var front_axles: Array[Node3D]=[]
var driver: HumanVisual
var steering_wheel: MeshInstance3D
var lamps: Array[Light3D]=[]

func part(id: String,parent: Node3D=self) -> MeshInstance3D:
	var instance := MeshInstance3D.new();instance.name=id.to_pascal_case()
	instance.mesh=load(ROOT+id+".res");parent.add_child(instance)
	return instance

func _ready() -> void:
	name="BusVisual"
	part("body");part("cabin")
	for id in ["door_front","door_rear"]:doors.append(part(id))
	for x in [-1.19,1.19]:
		for z in [-2.4,2.1]:
			var axle := Node3D.new();axle.name="Axle"+str(wheels.size());add_child(axle)
			axle.position=Vector3(x,.43,z)
			if z<0:front_axles.append(axle)
			wheels.append(part("wheel",axle))
	steering_wheel=MeshInstance3D.new();steering_wheel.name="SteeringWheel"
	var torus := TorusMesh.new();torus.inner_radius=.16;torus.outer_radius=.20
	steering_wheel.mesh=torus;steering_wheel.material_override=Shapes.material(Color("252d30"))
	add_child(steering_wheel);steering_wheel.position=Vector3(-.65,1.30,-2.82)
	steering_wheel.rotation.x=1.05
	driver=HumanVisual.new();driver.name="Driver";driver.outfit="office";add_child(driver)
	driver.position=DRIVER_SEAT+driver.seated_offset
	driver.pose(0,false,false,true)
	# A static driver must finish the initial idle-to-seat blend before pausing.
	driver.animation.play("work",0);driver.animation.advance(.4);driver.animation.pause()
	for z in [-2.2,.5,2.5]:
		var lamp := OmniLight3D.new();lamp.name="CabinLight"+str(lamps.size());add_child(lamp)
		lamp.position=Vector3(0,2.58,z);lamp.light_color=Color("fff0d2")
		lamp.light_energy=.75;lamp.omni_range=3;lamp.shadow_enabled=true;lamps.append(lamp)
	for x in [-.92,.92]:
		var lamp := SpotLight3D.new();lamp.name="Headlight"+str(lamps.size());add_child(lamp)
		lamp.position=Vector3(x,.9,-3.52);lamp.rotation.x=-.06
		lamp.light_color=Color("f0efdf");lamp.light_energy=1.8;lamp.spot_range=22
		lamp.spot_angle=36;lamp.shadow_enabled=true;lamps.append(lamp)
	set_night(false);apply_doors();set_motion(0,0)

func set_night(value: bool) -> void:
	for lamp in lamps:lamp.visible=value

func apply_doors() -> void:
	# First unplug outwards, then slide along the exterior without swinging
	# through the passenger aisle. This is presentation, not a new entry path.
	var slide := smoothstep(.15,1,door_open)
	var out := smoothstep(0,.2,door_open)*.13
	for i in range(doors.size()):
		doors[i].position=Vector3(-1.255-out,1.505,(-1.61 if i==0 else -1.07)+(-.58 if i==0 else .58)*slide)

func step_doors(delta: float,opening: bool) -> void:
	door_open=move_toward(door_open,1.0 if opening else 0.0,maxf(0,delta)/DOOR_SECONDS)
	apply_doors()

func snap_doors(opening: bool) -> void:
	door_open=1.0 if opening else 0.0;apply_doors()

func doors_closed() -> bool:return is_zero_approx(door_open)

func palm_target(side: String) -> Transform3D:
	var sign_value := -1.0 if side=="L" else 1.0
	var normal := Vector3(-sign_value,0,0);var along := Vector3(0,0,-1)
	return steering_wheel.global_transform*Transform3D(Basis(along.cross(normal),along,normal),Vector3(sign_value*.205,0,0))

func set_motion(distance: float,steering: float) -> void:
	for wheel in wheels:wheel.rotation.x=fposmod(-distance/.43,TAU)
	for axle in front_axles:axle.rotation.y=-steering
	steering_wheel.basis=Basis(Vector3.RIGHT,1.05)*Basis(Vector3.UP,-steering*2.5)
	for side in ["L","R"]:
		driver.contacts.reach(side,palm_target(side));driver.contacts.fingers(side,.72)

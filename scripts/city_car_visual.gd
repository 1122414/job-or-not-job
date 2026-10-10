class_name CityCarVisual
extends Node3D

const ROOT := "res://assets/vehicles/city_car/"
var car: CityCar
var wheels: Array[Node3D]=[]
var front_axles: Array[Node3D]=[]
var steering_wheel: MeshInstance3D
var driver: HumanVisual
var headlights: MeshInstance3D
var taillights: MeshInstance3D
var lamps: Array[SpotLight3D]=[]
var doors: Array[Node3D]=[]

func part(id: String,parent: Node3D=self) -> MeshInstance3D:
	var instance := MeshInstance3D.new();instance.name=id.to_pascal_case()
	instance.mesh=load(ROOT+id+".res");parent.add_child(instance);return instance

func _ready() -> void:
	name="CarVisual"
	var body := part("body");part("cabin")
	for i in range(body.mesh.get_surface_count()):
		var source: StandardMaterial3D=body.mesh.surface_get_material(i)
		if source.resource_name=="paint":
			var material: StandardMaterial3D=source.duplicate();material.albedo_color=car.paint
			body.set_surface_override_material(i,material)
	for side in [-1,1]:
		var pivot := Node3D.new();add_child(pivot);doors.append(pivot)
		pivot.position=Vector3(side*.84,0,-.854)
		var id := "door_left" if side<0 else "door_right"
		for suffix in ["","_glass"]:
			var panel := part(id+suffix,pivot);panel.position=-pivot.position
			for i in range(panel.mesh.get_surface_count()):
				var source: StandardMaterial3D=panel.mesh.surface_get_material(i)
				if source.resource_name=="paint":
					var material: StandardMaterial3D=source.duplicate();material.albedo_color=car.paint
					panel.set_surface_override_material(i,material)
	part("glass").cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	headlights=part("headlights");taillights=part("taillights")
	for lens in [headlights,taillights]:
		lens.material_override=lens.mesh.surface_get_material(0).duplicate()
		lens.material_override.emission_enabled=true
		lens.material_override.emission=lens.material_override.albedo_color
	for x in [-.88,.88]:
		for z in [-1.38,1.27]:
			var axle := Node3D.new();axle.name="Axle"+str(wheels.size());add_child(axle)
			axle.position=Vector3(x,.34,z)
			if z<0:front_axles.append(axle)
			wheels.append(part("wheel",axle))
	steering_wheel=MeshInstance3D.new();steering_wheel.name="SteeringWheel"
	var torus := TorusMesh.new();torus.inner_radius=.16;torus.outer_radius=.20;torus.rings=48;torus.ring_segments=12
	steering_wheel.mesh=torus;steering_wheel.material_override=Shapes.material(Color("222b30"))
	add_child(steering_wheel);steering_wheel.position=Vector3(-.43,1.05,-.22)
	steering_wheel.rotation.x=1.05
	Shapes.box(steering_wheel,Vector3(.15,.055,.12),Vector3.ZERO,Color("2b3236"))
	for x in [-.12,.12]:Shapes.box(steering_wheel,Vector3(.15,.025,.034),Vector3(x,0,0),Color("666f73"))
	Shapes.box(steering_wheel,Vector3(.04,.025,.13),Vector3(0,0,.1),Color("666f73"))
	for x in [-.61,.61]:
		var lamp := SpotLight3D.new();lamp.name="Headlight"+str(lamps.size());add_child(lamp)
		lamp.position=Vector3(x,.78,-2.14);lamp.rotation.x=-.07
		lamp.light_color=Color("e4edf3");lamp.light_energy=1.9;lamp.spot_range=25;lamp.spot_angle=32
		lamp.shadow_enabled=true;lamp.visible=false;lamps.append(lamp)
	if car.traffic:
		driver=HumanVisual.new();driver.name="Driver";driver.outfit="casual";add_child(driver)
		driver.position=CityCar.SEAT+driver.seated_offset
		driver.pose(0,false,false,true)
		# The old single advance paused before idle-to-seat blending took effect.
		driver.animation.play("work",0);driver.animation.advance(.4);driver.animation.pause()
	set_lighting(false,false,false)

func set_lighting(night: bool,powered: bool,braking: bool) -> void:
	for lamp in lamps:lamp.visible=night and powered
	headlights.material_override.emission_energy_multiplier=1.5 if night and powered else 0.0
	taillights.material_override.emission_energy_multiplier=2.4 if powered and braking else .45 if night and powered else 0.0
	taillights.material_override.albedo_color=Color("dd3730") if powered and braking else Color("942b26")

func set_door(side: float,amount: float) -> void:
	for index in range(doors.size()):
		var sign_value := -1.0 if index==0 else 1.0
		doors[index].rotation.y=sign_value*1.15*amount if side==sign_value else 0.0

class_name VehicleDriver
extends CharacterBody3D

var vehicle: CityCar
var visual: HumanVisual
var retreat := 3.0

func _ready() -> void:
	collision_layer=1;collision_mask=3
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	Shapes.collider(self,Vector3(.45,1.7,.45),Vector3(0,.87,0))
	visual=HumanVisual.new();visual.outfit="office" if vehicle.bus_mode else "casual";add_child(visual)
	visual.rotation.y=vehicle.rotation.y
	add_collision_exception_with(vehicle)

func _physics_process(delta: float) -> void:
	retreat=maxf(0,retreat-delta)
	var direction:=Vector3.LEFT.rotated(Vector3.UP,vehicle.rotation.y)
	velocity=direction*1.4 if retreat>0 else Vector3.ZERO
	move_and_slide();position.y=0
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z) if retreat>0 else atan2(vehicle.position.x-position.x,vehicle.position.z-position.z),minf(1,delta*5))
	visual.pose(Vector2(velocity.x,velocity.z).length(),false,false,false,false,false,retreat==0)

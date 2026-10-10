class_name VehicleDriver
extends CharacterBody3D

var vehicle: CityCar
var visual: HumanVisual
var retreat := 3.0
var exit_elapsed := -1.0
var seat_start := Vector3.ZERO
var exit_yaw := 0.0

func begin_exit() -> void:
	exit_elapsed=0
	seat_start=vehicle.to_global(vehicle.seat())-position+visual.seated_offset
	exit_yaw=vehicle.rotation.y
	visual.position=seat_start
	visual.animation.play("work",0);visual.animation.advance(.4)

func finish_exit() -> void:
	exit_elapsed=-1;visual.position=Vector3.ZERO

func step_exit(delta: float) -> void:
	exit_elapsed+=delta
	var progress := smoothstep(.25,1.35,exit_elapsed)
	visual.position=seat_start.lerp(Vector3.ZERO,progress)
	visual.rotation.y=lerp_angle(exit_yaw,atan2(vehicle.position.x-position.x,vehicle.position.z-position.z),progress)
	visual.pose(0,false,false,progress<.25,false,progress>=.25)
	if exit_elapsed>=1.65: finish_exit()


func _ready() -> void:
	collision_layer=1;collision_mask=3
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	Shapes.collider(self,Vector3(.45,1.7,.45),Vector3(0,.87,0))
	visual=HumanVisual.new();visual.outfit="office" if vehicle.bus_mode else "casual";add_child(visual)
	visual.rotation.y=vehicle.rotation.y
	add_collision_exception_with(vehicle)

func _physics_process(delta: float) -> void:
	if exit_elapsed>=0:
		step_exit(delta);return
	retreat=maxf(0,retreat-delta)
	var direction:=(position-vehicle.position).normalized();direction.y=0
	velocity=direction*1.4 if retreat>0 else Vector3.ZERO
	move_and_slide();position.y=0
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z) if retreat>0 else atan2(vehicle.position.x-position.x,vehicle.position.z-position.z),minf(1,delta*5))
	visual.pose(Vector2(velocity.x,velocity.z).length(),false,false,false,false,false,retreat==0)

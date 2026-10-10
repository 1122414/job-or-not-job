class_name VehicleDriver
extends CharacterBody3D

var vehicle: CityCar
var visual: HumanVisual
var hp := 100
var down := 0.0
var hit_velocity := Vector3.ZERO
var body: CollisionShape3D
var retreat := 3.0
var exit_elapsed := -1.0
var seat_start := Vector3.ZERO
var exit_yaw := 0.0

func begin_exit() -> void:
	exit_elapsed=0
	add_collision_exception_with(vehicle)
	seat_start=vehicle.to_global(vehicle.seat())-position+visual.seated_offset
	exit_yaw=vehicle.rotation.y
	visual.position=seat_start
	visual.animation.play("work",0);visual.animation.advance(.4)

func finish_exit() -> void:
	exit_elapsed=-1;visual.position=Vector3.ZERO
	remove_collision_exception_with(vehicle)

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
	body=get_child(0)
	body.shape=CapsuleShape3D.new();body.shape.radius=.25;body.shape.height=1.7
	visual=HumanVisual.new();visual.outfit="office" if vehicle.bus_mode else "casual";add_child(visual)
	visual.rotation.y=vehicle.rotation.y

func _physics_process(delta: float) -> void:
	if exit_elapsed>=0:
		step_exit(delta);return
	if not available():
		down=maxf(0,down-delta)
		velocity=hit_velocity;move_and_slide();position.y=0
		hit_velocity=hit_velocity.move_toward(Vector3.ZERO,4*delta)
		sync_body();visual.pose(0,false,true,false,false,false)
		return
	sync_body()
	retreat=maxf(0,retreat-delta)
	var direction:=(position-vehicle.position).normalized();direction.y=0
	velocity=direction*1.4 if retreat>0 else Vector3.ZERO
	move_and_slide();position.y=0
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z) if retreat>0 else atan2(vehicle.position.x-position.x,vehicle.position.z-position.z),minf(1,delta*5))
	visual.pose(Vector2(velocity.x,velocity.z).length(),false,false,false,false,false,retreat==0)

func available() -> bool:
	return hp>0 and down<=0

func vehicle_hit(direction: Vector3,speed: float) -> void:
	if not available() or exit_elapsed>=0: return
	hp=maxi(0,hp-roundi(speed*9))
	down=12;retreat=0
	hit_velocity=direction*minf(speed*.65,10);hit_velocity.y=0
	visual.rotation.y=atan2(direction.z,-direction.x)
	sync_body()
	var game: Node3D=vehicle.get_parent().game
	game.career.record("driver_hit_"+vehicle.stable_id+("_injured" if hp>0 else "_dead"),"离车司机被车辆撞倒。" if hp>0 else "离车司机遭车辆撞击后死亡。")
	game.say("司机被撞倒，暂时无法起身。" if hp>0 else "司机已死亡。")
	game.queue_save()

func sync_body() -> void:
	var fallen := not available()
	visual.rotation.z=PI/2 if fallen else 0
	visual.position=Vector3(0,.28 if fallen else 0,0)
	body.rotation=Vector3(0,visual.rotation.y,PI/2 if fallen else 0)
	body.position=Vector3(-.7,.28,0).rotated(Vector3.UP,visual.rotation.y) if fallen else Vector3(0,.87,0)

func snapshot() -> Dictionary:
	return {"hp":hp,"down":down,"yaw":wrapf(visual.rotation.y,-PI,PI),"motion":SaveGame.vector(hit_velocity)}

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if not CityPopulation.number(data.get("hp"),0,100,true) or not CityPopulation.number(data.get("down"),0,12) or not CityPopulation.number(data.get("yaw"),-PI,PI) or not SaveGame.valid_vector(data.get("motion")): return false
	var motion := SaveGame.unvector(data.motion)
	return absf(motion.y)<.001 and motion.length()<=10.001

func restore(data: Dictionary) -> void:
	hp=int(data.get("hp",100));down=float(data.get("down",0))
	visual.rotation.y=float(data.get("yaw",vehicle.rotation.y))
	hit_velocity=SaveGame.unvector(data.get("motion",[0,0,0]))
	sync_body()

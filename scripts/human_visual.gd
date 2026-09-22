class_name HumanVisual
extends Node3D

var outfit := "casual"
var personality := ""
var variation := 0
var skeleton: Skeleton3D
var animation: AnimationPlayer
var current := ""
var grip: Node3D
var seated_offset := Vector3.ZERO

func _ready() -> void:
	var model: Node3D = load("res://assets/characters/"+outfit+".glb").instantiate()
	model.name="Model"
	model.rotation.y=PI
	add_child(model)
	var tint: Color={"boss":Color("c9c0b6"),"hr":Color("d6c8b5"),"lead":Color("b3cbd6"),"friend":Color("c0d1c0"),"group":Color("c5b6ca"),"guard":Color("8293ad")}.get(personality,Color.WHITE)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if "suit" in str(mesh.name):
			for surface in range(mesh.mesh.get_surface_count()):
				var source: Material=mesh.mesh.surface_get_material(surface)
				if source is StandardMaterial3D:
					var material: StandardMaterial3D=source.duplicate()
					material.albedo_color=tint
					mesh.set_surface_override_material(surface,material)
	for node in model.find_children("*","Skeleton3D",true,false): skeleton=node
	animation=AnimationPlayer.new()
	add_child(animation)
	var library := AnimationLibrary.new()
	for clip in ["idle","walk","run","strike","work","sit","fallen","recoil","talk","sit_talk"]: library.add_animation(clip,make_clip(clip))
	animation.add_animation_library("",library)
	animation.play("idle")
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg01.L")).origin
	# Retarget the hip joint to the seat, rather than an arbitrary visual-root drop.
	seated_offset=Vector3(0,0.53-hip.y,0)
	if skeleton:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name="wrist.R"
		skeleton.add_child(attachment)
		grip=Node3D.new()
		attachment.add_child(grip)
		grip.position=Vector3(0, -0.05, 0.06)

func make_clip(clip: String) -> Animation:
	var anim := Animation.new()
	anim.length=0.32 if clip=="recoil" else 0.45 if clip=="strike" else 4.0 if clip in ["idle","sit","talk","sit_talk"] else 1.0
	anim.loop_mode=Animation.LOOP_NONE if clip in ["strike","recoil"] else Animation.LOOP_LINEAR
	var bones := ["upperarm01.L","upperarm01.R","lowerarm01.L","lowerarm01.R","upperleg01.L","upperleg01.R","lowerleg01.L","lowerleg01.R","spine02","head","wrist.L","wrist.R","foot.L","foot.R"]
	for side in ["L","R"]:
		for finger in range(2,6):
			for joint in range(1,4): bones.append("finger%d-%d.%s"%[finger,joint,side])
	var root_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(root_track,NodePath(str(get_path_to(skeleton))+":root"))
	var root_rest := skeleton.get_bone_rest(skeleton.find_bone("root")).origin
	for i in range(33):
		var phase := float(i)/32.0
		anim.position_track_insert_key(root_track,phase*anim.length,root_rest+Vector3.UP*gait_drop(clip,phase))
	for bone in bones:
		if skeleton.find_bone(bone)<0: continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track,NodePath(str(get_path_to(skeleton))+":"+bone))
		for i in range(33):
			var phase := float(i)/32.0
			var wave := sin(phase*TAU)
			var euler := Vector3.ZERO
			if bone.begins_with("finger"):
				euler.x=0.22 if clip!="strike" else 0.85
				if clip=="work": euler.x=0.12+0.07*sin(phase*TAU*2+float(bone.unicode_at(6)))
			if bone=="upperarm01.L": euler.z=-0.62
			if bone=="upperarm01.R": euler.z=0.62
			if clip in ["walk","run"]:
				var amount := 0.5 if clip=="walk" else 0.8
				var side := "L" if bone.ends_with("L") else "R"
				var leg := gait_angles(clip,phase,side)
				if bone.begins_with("upperleg"): euler.x=leg.x
				if bone.begins_with("lowerleg"): euler.x=leg.y
				if bone.begins_with("foot"): euler.x=leg.z
				if bone=="upperarm01.L": euler.x=cos(phase*TAU)*amount*0.85
				if bone=="upperarm01.R": euler.x=-cos(phase*TAU)*amount*0.85
				if bone.begins_with("lowerarm"): euler.x=-0.35 if clip=="run" else 0.25
				if bone=="spine02": euler=Vector3(0.12 if clip=="run" else 0.025,wave*0.07,wave*0.025)
			elif clip in ["work","sit","sit_talk"]:
				if bone.begins_with("upperleg"): euler.x=-1.4
				if bone.begins_with("lowerleg"): euler.x=1.4
				if bone.begins_with("upperarm"): euler.x=-1.05; euler.z*=0.65
				if bone.begins_with("lowerarm"): euler.x=0.45+wave*0.025
				if bone=="spine02": euler.x=0.06+wave*0.012
				if bone=="head": euler.y=wave*0.025
				if bone.begins_with("wrist"): euler.x=wave*0.025 if clip=="work" else 0.05
				if clip in ["sit","sit_talk"]:
					if bone.begins_with("upperarm"): euler.x=-0.4
					if bone.begins_with("lowerarm"): euler.x=-0.3
			elif clip=="recoil":
				var flinch := sin(phase*PI)
				if bone=="spine02": euler.x=-0.18*flinch
				if bone=="head": euler.x=-0.10*flinch
				if bone.begins_with("lowerarm"): euler.x=-0.4*flinch
			elif clip=="fallen":
				if bone.begins_with("upperarm"): euler=Vector3(-0.25,0,-1.05 if bone.ends_with("L") else 1.05)
				if bone.begins_with("lowerarm"): euler.x=0.25
				if bone=="lowerleg01.R": euler.x=0.28
				if bone=="head": euler.z=0.12
			elif clip=="strike":
				var punch := sin(phase*PI)
				if bone=="upperarm01.R": euler=Vector3(-1.5*punch,-0.25*punch,0.62*(1-punch))
				if bone=="lowerarm01.R": euler.x=-0.3*punch
				if bone=="spine02": euler.y=-0.3*punch
			else:
				if bone=="spine02": euler.x=wave*0.012
				if bone=="head": euler.y=wave*(0.07 if personality=="friend" else 0.025)
				if personality=="boss" and bone.begins_with("lowerarm"): euler.x=-0.35
				if personality=="hr" and bone=="head": euler.x=wave*0.03
			if clip in ["talk","sit_talk"]:
				var gesture := pow(maxf(0,wave),2)*(0.65 if personality=="boss" else 1.2 if personality=="friend" else 0.85)
				var hand := "L" if personality=="friend" else "R"
				if bone=="upperarm01."+hand: euler.x-=gesture*0.25
				if bone=="lowerarm01."+hand: euler.x-=gesture*0.40
				if bone=="head": euler.x=wave*0.035; euler.y=wave*0.045
			anim.rotation_track_insert_key(track,phase*anim.length,Quaternion.from_euler(euler))
	return anim

# Flat-ground two-bone solve. Stance feet travel backwards at the world speed;
# swing feet clear the floor. Use imported proportions instead of fixed joint angles.
func gait_drop(clip: String,phase: float) -> float:
	if clip=="walk": return -0.10+0.012*cos(phase*TAU*2)
	if clip=="run": return -0.125+0.008*sin(phase*TAU*2)
	return 0.0

func gait_angles(clip: String,phase: float,side: String) -> Vector3:
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg01."+side)).origin
	var knee := skeleton.get_bone_global_rest(skeleton.find_bone("lowerleg01."+side)).origin
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot."+side)).origin
	var upper := Vector2(knee.y-hip.y,knee.z-hip.z)
	var lower := Vector2(ankle.y-knee.y,ankle.z-knee.z)
	var upper_length := upper.length()
	var lower_length := lower.length()
	var t := fposmod(phase+(0.5 if side=="R" else 0.0),1.0)
	var stance := 0.25 if clip=="run" else 0.5
	var reach := 0.43 if clip=="run" else 0.37
	var lift := 0.0
	var stride: float
	if t<stance:
		stride=lerpf(reach,-reach,t/stance)
	else:
		var swing := (t-stance)/(1.0-stance)
		stride=lerpf(-reach,reach,swing*swing*(3.0-2.0*swing))
		lift=sin(swing*PI)*(0.20 if clip=="run" else 0.12)
	var depth := hip.y+gait_drop(clip,phase)-ankle.y-lift
	var forward := ankle.z+stride-hip.z
	var distance := minf(Vector2(depth,forward).length(),upper_length+lower_length-0.001)
	var direction := atan2(forward,depth)
	var upper_angle := direction+acos(clampf((upper_length*upper_length+distance*distance-lower_length*lower_length)/(2*upper_length*distance),-1,1))
	var lower_angle := direction-acos(clampf((lower_length*lower_length+distance*distance-upper_length*upper_length)/(2*lower_length*distance),-1,1))
	var thigh := atan2(upper.y,-upper.x)-upper_angle
	var shin := upper_angle-lower_angle+atan2(lower.y,-lower.x)-atan2(upper.y,-upper.x)
	return Vector3(thigh,shin,-thigh-shin)

func pose(speed: float, attacking: bool, fallen: bool, working: bool = false, talking: bool = false, stunned: bool = false, conversing: bool = false) -> void:
	if fallen:
		if current!="fallen":
			# Discard queued locomotion blends; body-root motion supplies the fall transition.
			animation.stop()
			animation.speed_scale=1.0
			animation.play("fallen")
			animation.advance(0)
			current="fallen"
		return
	var next := "recoil" if stunned else ("sit_talk" if conversing else "sit") if talking else "talk" if conversing and speed<0.2 else "work" if working else "strike" if attacking else "run" if speed>3.2 else "walk" if speed>0.2 else "idle"
	if next!=current:
		animation.play(next,0.04 if stunned else 0.20)
		if next in ["idle","work"]: animation.seek(float(variation%11)/11.0,true)
		current=next
	animation.speed_scale=speed/3.44 if next=="run" else speed/1.48 if next=="walk" else 0.85+float(variation%5)*0.06

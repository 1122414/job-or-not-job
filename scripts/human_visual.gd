class_name HumanVisual
extends Node3D

var outfit := "casual"
var carrying := false
var blocking := false
var scene_action := ""
var personality := ""
var variation := 0
var skeleton: Skeleton3D
var animation: AnimationPlayer
var current := ""
var grip: Node3D
var scene_phone: Node3D
var seated_offset := Vector3.ZERO

func _ready() -> void:
	var model: Node3D = load("res://assets/characters/"+outfit+".glb").instantiate()
	model.name="Model"
	model.rotation.y=PI
	add_child(model)
	var tint: Color={"boss":Color("c9c0b6"),"hr":Color("d6c8b5"),"lead":Color("b3cbd6"),"friend":Color("c0d1c0"),"group":Color("c5b6ca"),"guard":Color("8293ad"),"medic":Color("72b7ba")}.get(personality,Color.WHITE)
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
	for clip in ["idle","walk","run","strike","work","sit","fallen","recoil","talk","sit_talk","carry","carry_idle","block","read","write","message","pause","move_box","phone_reply","box_message"]: library.add_animation(clip,make_clip(clip))
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
		scene_phone=Node3D.new()
		grip.add_child(scene_phone)
		scene_phone.visible=false
		scene_phone.position=Vector3(0,0.05,0.02)
		Shapes.box(scene_phone,Vector3(0.075,0.14,0.015),Vector3.ZERO,Color("19242c"))
		Shapes.box(scene_phone,Vector3(0.062,0.12,0.002),Vector3(0,0,0.009),Color("6f9297"))

func make_clip(clip: String) -> Animation:
	var anim := Animation.new()
	anim.length=4.0 if clip=="box_message" else 1.4 if clip in ["move_box","phone_reply"] else 0.32 if clip=="recoil" else 0.45 if clip=="strike" else 4.0 if clip in ["idle","sit","talk","sit_talk"] else 1.0
	anim.loop_mode=Animation.LOOP_NONE if clip in ["strike","recoil","move_box","phone_reply","box_message"] else Animation.LOOP_LINEAR
	var bones := ["upperarm01.L","upperarm01.R","lowerarm01.L","lowerarm01.R","upperleg01.L","upperleg01.R","lowerleg01.L","lowerleg01.R","spine02","head","wrist.L","wrist.R","foot.L","foot.R"]
	for side in ["L","R"]:
		for finger in range(2,6):
			for joint in range(1,4): bones.append("finger%d-%d.%s"%[finger,joint,side])
	var root_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(root_track,NodePath(str(get_path_to(skeleton))+":root"))
	var root_rest := skeleton.get_bone_rest(skeleton.find_bone("root")).origin
	for i in range(33):
		var phase := float(i)/32.0
		anim.position_track_insert_key(root_track,phase*anim.length,root_rest+Vector3.UP*gait_drop("walk" if clip=="carry" else clip,phase))
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
			if clip in ["walk","run","carry"]:
				var amount := 0.5 if clip=="walk" else 0.8
				var side := "L" if bone.ends_with("L") else "R"
				var leg := gait_angles("walk" if clip=="carry" else clip,phase,side)
				if bone.begins_with("upperleg"): euler.x=leg.x
				if bone.begins_with("lowerleg"): euler.x=leg.y
				if bone.begins_with("foot"): euler.x=leg.z
				if bone=="upperarm01.L": euler.x=cos(phase*TAU)*amount*0.85
				if bone=="upperarm01.R": euler.x=-cos(phase*TAU)*amount*0.85
				if bone.begins_with("lowerarm"): euler.x=-0.35 if clip=="run" else 0.25
				if bone=="spine02": euler=Vector3(0.12 if clip=="run" else 0.025,wave*0.07,wave*0.025)
			elif clip in ["work","sit","sit_talk","read","write","message","pause","move_box","phone_reply","box_message"]:
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
			elif clip=="block":
				if bone.begins_with("upperarm"): euler=Vector3(-1.0,0,-0.25 if bone.ends_with("L") else 0.25)
				if bone.begins_with("lowerarm"): euler.x=-1.1
				if bone=="spine02": euler.x=-0.08
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
			if clip in ["carry","carry_idle","block"]:
				if bone.begins_with("upperarm"): euler=Vector3(-0.25,0,-1.05 if bone.ends_with("L") else 1.05)
				if bone.begins_with("lowerarm"): euler.x=-0.25
			if clip in ["read","write","message","pause"]:
				if bone=="head": euler.x=0.18 if clip!="pause" else 0.0; euler.y=0.14 if clip=="message" else wave*0.025
				if clip=="write" and bone=="wrist.R": euler.y=wave*0.10
				if clip=="message" and bone=="upperarm01.R": euler.x=-0.75
				if clip=="message" and bone=="lowerarm01.R": euler.x=-0.70
				if clip=="pause" and bone.begins_with("upperarm"): euler.x=-0.35
				if clip=="move_box":
					var reach := sin(minf(1.0,phase*1.5)*PI)
					if bone=="spine02": euler.x=0.06+0.22*reach; euler.y=-0.18*reach
					if bone=="upperarm01.L": euler.x=-1.05-0.48*reach
					if bone=="lowerarm01.L": euler.x=0.45+0.35*reach
					if bone=="head": euler.x=0.18+0.13*reach; euler.y=-0.12*reach
				if clip=="phone_reply":
					var phone_reach := sin(phase*PI)
					if bone=="upperarm01.R": euler.x=-1.05-0.28*phone_reach
					if bone=="lowerarm01.R": euler.x=-0.50-0.45*phone_reach
					if bone=="head": euler.x=0.12; euler.y=0.14*phone_reach
				if clip=="box_message":
					var push_box := sin(minf(1.0,phase/0.28)*PI)
					var record := smoothstep(0.28,0.42,phase)*(1.0-smoothstep(0.78,0.96,phase))
					if bone=="spine02": euler.x=0.06+0.25*push_box; euler.y=-0.14*push_box
					if bone=="upperarm01.L": euler.x=-1.05-0.62*push_box
					if bone=="lowerarm01.L": euler.x=0.45+0.22*push_box
					if bone=="upperarm01.R": euler.x=-1.05-0.35*record
					if bone=="lowerarm01.R": euler.x=0.45-1.18*record
					if bone=="head": euler.x=0.10+0.18*record; euler.y=0.28*record
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
	var next := ("carry" if speed>0.2 else "carry_idle") if carrying else "recoil" if stunned else "block" if blocking else ("sit_talk" if conversing else "sit") if talking else "talk" if conversing and speed<0.2 else "work" if working else "strike" if attacking else "run" if speed>3.2 else "walk" if speed>0.2 else "idle"
	if talking and not stunned and not blocking and not attacking and speed<0.2 and scene_action!="": next=scene_action
	if next!=current:
		animation.play(next,0.04 if stunned else 0.20)
		if next in ["idle","work"]: animation.seek(float(variation%11)/11.0,true)
		current=next
	animation.speed_scale=speed/3.44 if next=="run" else speed/1.48 if next in ["walk","carry"] else 0.85+float(variation%5)*0.06

class_name HumanVisual
extends Node3D

var outfit := "casual"
var cast_id := ""
var use_authored_motion := true
var carrying := false
var blocking := false
var scene_action := ""
var personality := ""
var variation := 0
var skeleton: Skeleton3D
var animation: AnimationPlayer
var current := ""
var grip: Node3D
var seated_offset := Vector3.ZERO
var standing_height := 1.8
var face_meshes: Array[MeshInstance3D]=[]
var facial_expression := {}
var attention_target := Vector3.ZERO
var attention_enabled := false
var face_clock := 0.0
var contacts: HandContact

func _ready() -> void:
	var model_path := "res://assets/characters/"+outfit+".glb" if cast_id.is_empty() else "res://assets/characters/cast/"+cast_id+".glb"
	var model: Node3D = load(model_path).instantiate()
	model.name="Model"
	model.rotation.y=PI
	add_child(model)
	var tint: Color={"boss":Color("c9c0b6"),"hr":Color("d6c8b5"),"lead":Color("b3cbd6"),"friend":Color("c0d1c0"),"group":Color("c5b6ca"),"guard":Color("8293ad"),"medic":Color("72b7ba")}.get(personality,Color.WHITE)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if cast_id.is_empty() and "suit" in str(mesh.name):
			for surface in range(mesh.mesh.get_surface_count()):
				var source: Material=mesh.mesh.surface_get_material(surface)
				if source is StandardMaterial3D:
					var material: StandardMaterial3D=source.duplicate()
					material.albedo_color=tint
					mesh.set_surface_override_material(surface,material)
	for node in model.find_children("*","Skeleton3D",true,false): skeleton=node
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.get_blend_shape_count()>0: face_meshes.append(mesh)
		if not cast_id.is_empty() and mesh.name=="body": standing_height=mesh.get_aabb().end.y
	face_clock=float(variation%17)*0.19
	process_priority=1
	set_process(not cast_id.is_empty())
	animation=AnimationPlayer.new()
	add_child(animation)
	var library := AnimationLibrary.new()
	for clip in ["idle","walk","run","strike","work","sit","fallen","recoil","talk","sit_talk","carry","carry_idle","block","read","write","message","pause","beckon","move_box","phone_reply","box_message","story_read","story_listen","story_present"]: library.add_animation(clip,make_clip(clip))
	if use_authored_motion:
		var path := "res://assets/animations/quaternius_upper_body.res" if cast_id.is_empty() else "res://assets/animations/cast/"+cast_id+".res"
		var authored: AnimationLibrary=load(path)
		for clip in authored.get_animation_list():
			library.remove_animation(clip)
			library.add_animation(clip,authored.get_animation(clip))
	animation.add_animation_library("",library)
	animation.play("idle")
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg01.L")).origin
	# Retarget the hip joint to the seat, rather than an arbitrary visual-root drop.
	seated_offset=Vector3(0,0.53-hip.y,0)
	contacts=HandContact.new(self)
	if skeleton:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name="wrist.R"
		skeleton.add_child(attachment)
		grip=Node3D.new()
		attachment.add_child(grip)
		grip.transform=contacts.palms.R

func face_position() -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin+Vector3(0,0.08,0))

# Explicit mouth weights are reserved for a synchronized voice/performance driver.
# A text conversation alone must not produce a looping fake mouth animation.
func set_facial_expression(values: Dictionary) -> void:
	facial_expression.clear()
	for key in ["blink","brow_raise","brow_lower","mouth_open"]:
		var value := float(values.get(key,0.0))
		facial_expression[key]=clampf(value,0.0,1.0) if is_finite(value) else 0.0

func set_attention(target: Vector3,enabled: bool) -> void:
	attention_target=target
	attention_enabled=enabled and target.is_finite()

func _process(delta: float) -> void:
	update_face(delta)

func update_face(delta: float) -> void:
	if cast_id.is_empty(): return
	face_clock+=delta
	var resting := current=="fallen"
	var blink_phase := fposmod(face_clock,3.8+float(variation%5)*0.27)
	var blink := sin(blink_phase/0.18*PI) if blink_phase<0.18 and not resting else 0.0
	for mesh in face_meshes:
		for id in range(mesh.get_blend_shape_count()):
			var key := String(mesh.mesh.get_blend_shape_name(id))
			var weight := float(facial_expression.get(key,0.0)) if not resting else 0.0
			mesh.set_blend_shape_value(id,maxf(weight,blink) if key=="blink" else weight)
	for side in ["L","R"]:
		var eye := skeleton.find_bone("eye."+side)
		if eye<0: continue
		var target := Quaternion.IDENTITY
		if attention_enabled and not resting:
			var rest := skeleton.get_bone_rest(eye)
			var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(eye))
			var eye_frame := parent*rest
			var direction := eye_frame.affine_inverse()*skeleton.to_local(attention_target)
			if direction.z>0.01:
				target=Quaternion.from_euler(Vector3(clampf(-atan2(direction.y,direction.z),-0.15,0.15),clampf(atan2(direction.x,direction.z),-0.25,0.25),0))
		skeleton.set_bone_pose_rotation(eye,skeleton.get_bone_pose_rotation(eye).slerp(target,1.0-exp(-delta*12)))

func make_clip(clip: String) -> Animation:
	var anim := Animation.new()
	anim.length=4.0 if clip=="box_message" else 3.2 if clip=="phone_reply" else 1.8 if clip=="beckon" else 1.4 if clip=="move_box" else 0.32 if clip=="recoil" else 0.45 if clip=="strike" else 4.0 if clip in ["idle","sit","talk","sit_talk","story_read","story_listen","story_present"] else 1.0
	anim.loop_mode=Animation.LOOP_NONE if clip in ["strike","recoil","beckon","move_box","phone_reply","box_message"] else Animation.LOOP_LINEAR
	var bones := ["upperarm01.L","upperarm01.R","lowerarm01.L","lowerarm01.R","upperleg01.L","upperleg01.R","lowerleg01.L","lowerleg01.R","spine02","head","wrist.L","wrist.R","foot.L","foot.R"]
	# Every clip owns the same bones so an interrupted authored gesture cannot linger.
	bones.append_array(["spine05","spine03","spine01","neck01","clavicle.L","clavicle.R"])
	for side in ["L","R"]:
		for finger in range(1,6):
			for joint in range(1,4): bones.append("finger%d-%d.%s"%[finger,joint,side])
	var root_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(root_track,NodePath(str(get_path_to(skeleton))+":root"))
	var root_rest := skeleton.get_bone_rest(skeleton.find_bone("root")).origin
	var gait_samples := 128 if not cast_id.is_empty() and clip in ["walk","run","carry"] else 32
	for i in range(gait_samples+1):
		var phase := float(i)/gait_samples
		anim.position_track_insert_key(root_track,phase*anim.length,root_rest+Vector3.UP*gait_drop("walk" if clip=="carry" else clip,phase))
	for bone in bones:
		if skeleton.find_bone(bone)<0: continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track,NodePath(str(get_path_to(skeleton))+":"+bone))
		var samples := gait_samples if bone.begins_with("upperleg") or bone.begins_with("lowerleg") or bone.begins_with("foot") else 32
		for i in range(samples+1):
			var phase := float(i)/samples
			var wave := sin(phase*TAU)
			var euler := Vector3.ZERO
			if bone.begins_with("finger") and not bone.begins_with("finger1-"):
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
				if not cast_id.is_empty() and (bone.begins_with("upperleg") or bone.begins_with("lowerleg") or bone.begins_with("foot")):
					var leg := seated_leg_angles("L" if bone.ends_with("L") else "R")
					euler.x=leg.x if bone.begins_with("upperleg") else leg.y if bone.begins_with("lowerleg") else leg.z
				if bone.begins_with("upperarm"): euler.x=-1.05; euler.z*=0.65
				if bone.begins_with("lowerarm"): euler.x=0.45+wave*0.025
				if bone=="spine02": euler.x=0.06+wave*0.012
				if bone=="head": euler.y=wave*0.025
				if bone.begins_with("wrist"): euler.x=wave*0.025 if clip=="work" else 0.05
				if clip in ["sit","sit_talk"]:
					if bone.begins_with("upperarm"): euler.x=-0.4
					if bone.begins_with("lowerarm"): euler.x=-0.3
			elif clip in ["story_read","story_listen","story_present"]:
				if bone=="spine02": euler=Vector3(.015+wave*.008,wave*.018,0)
				if bone=="head": euler.x=.15 if clip=="story_read" else sin(phase*TAU*2)*.025
				if clip=="story_read":
					if bone.begins_with("upperarm"): euler=Vector3(-.65,0,-.3 if bone.ends_with("L") else .3)
					if bone.begins_with("lowerarm"): euler.x=-.7
				elif clip=="story_present":
					if bone=="upperarm01.L": euler.x=-.3-wave*.12
					if bone=="lowerarm01.L": euler.x=-.4-wave*.1
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
				if bone=="upperarm01.L": euler.x=-1.05-0.18*phone_reach
				if bone=="lowerarm01.L": euler.x=-0.50-0.28*phone_reach
				if bone=="head": euler.x=0.12; euler.y=-0.14*phone_reach
			if clip=="box_message":
				var push_box := sin(minf(1.0,phase/0.28)*PI)
				var record := smoothstep(0.28,0.42,phase)*(1.0-smoothstep(0.78,0.96,phase))
				if bone=="spine02": euler.x=0.06+0.25*push_box; euler.y=-0.14*push_box
				if bone=="upperarm01.L": euler.x=-1.05-0.62*push_box-0.12*record
				if bone=="lowerarm01.L": euler.x=0.45+0.22*push_box-0.75*record
				if bone=="head": euler.x=0.10+0.18*record; euler.y=-0.28*record
			if clip=="beckon":
				var gesture := sin(phase*PI)
				if bone=="spine02": euler.y=0.13*gesture
				if bone=="upperarm01.R": euler.x=-0.55-0.50*gesture
				if bone=="lowerarm01.R": euler.x=-0.35-0.45*gesture
				if bone=="head": euler.y=-0.25*gesture
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
	if clip not in ["walk","run"]: return 0.0
	var drop := -0.10+0.012*cos(phase*TAU*2) if clip=="walk" else -0.125+0.008*sin(phase*TAU*2)
	if not cast_id.is_empty():
		# Shorter bodies need a lower hip for the same world-speed stride. Otherwise
		# the IK distance clamp silently shortens the stance and slides the foot.
		for side in ["L","R"]:
			var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg01."+side)).origin
			var knee := skeleton.get_bone_global_rest(skeleton.find_bone("lowerleg01."+side)).origin
			var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot."+side)).origin
			var length := Vector2(knee.y-hip.y,knee.z-hip.z).length()+Vector2(ankle.y-knee.y,ankle.z-knee.z).length()-0.002
			var reach := (0.43 if clip=="run" else 0.37)+absf(ankle.z-hip.z)
			var max_depth := sqrt(maxf(0.0,length*length-reach*reach))
			drop=minf(drop,max_depth-(hip.y-ankle.y))
	return drop

func gait_angles(clip: String,phase: float,side: String) -> Vector3:
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg01."+side)).origin
	var knee := skeleton.get_bone_global_rest(skeleton.find_bone("lowerleg01."+side)).origin
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot."+side)).origin
	var upper := Vector2(knee.y-hip.y,knee.z-hip.z)
	var lower := Vector2(ankle.y-knee.y,ankle.z-knee.z)
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
	return solve_leg(upper,lower,depth,forward)

func seated_leg_angles(side: String) -> Vector3:
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg01."+side)).origin
	var knee := skeleton.get_bone_global_rest(skeleton.find_bone("lowerleg01."+side)).origin
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot."+side)).origin
	var upper := Vector2(knee.y-hip.y,knee.z-hip.z)
	var lower := Vector2(ankle.y-knee.y,ankle.z-knee.z)
	return solve_leg(upper,lower,0.53-ankle.y,upper.length())

func solve_leg(upper: Vector2,lower: Vector2,depth: float,forward: float) -> Vector3:
	var upper_length := upper.length()
	var lower_length := lower.length()
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
			facial_expression.clear()
			# Discard queued locomotion blends; body-root motion supplies the fall transition.
			animation.stop()
			animation.speed_scale=1.0
			animation.play("fallen")
			animation.advance(0)
			current="fallen"
		return
	var next := ("carry" if speed>0.2 else "carry_idle") if carrying else "recoil" if stunned else "block" if blocking else ("sit_talk" if conversing else "sit") if talking else "talk" if conversing and speed<0.2 else "work" if working else "strike" if attacking else "run" if speed>3.2 else "walk" if speed>0.2 else "idle"
	if talking and not stunned and not blocking and not attacking and speed<0.2 and scene_action!="": next=scene_action
	if not talking and not working and not carrying and not stunned and not blocking and not attacking and speed<.2 and scene_action in ["story_read","story_listen","story_present"]: next=scene_action
	if next!=current:
		animation.play(next,0.04 if stunned else 0.20)
		if next in ["idle","work"]: animation.seek(float(variation%11)/11.0,true)
		current=next
	animation.speed_scale=speed/3.44 if next=="run" else speed/1.48 if next in ["walk","carry"] else 0.85+float(variation%5)*0.06

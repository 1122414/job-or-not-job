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
	for clip in ["idle","walk","run","strike","work","sit","fallen"]: library.add_animation(clip,make_clip(clip))
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
	anim.length=0.45 if clip=="strike" else 1.0
	anim.loop_mode=Animation.LOOP_NONE if clip=="strike" else Animation.LOOP_LINEAR
	var bones := ["upperarm01.L","upperarm01.R","lowerarm01.L","lowerarm01.R","upperleg01.L","upperleg01.R","lowerleg01.L","lowerleg01.R","spine02","head"]
	for bone in bones:
		if skeleton.find_bone(bone)<0: continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track,NodePath(str(get_path_to(skeleton))+":"+bone))
		for i in range(9):
			var phase := float(i)/8.0
			var wave := sin(phase*TAU)
			var euler := Vector3.ZERO
			if bone=="upperarm01.L": euler.z=-0.62
			if bone=="upperarm01.R": euler.z=0.62
			if clip in ["walk","run"]:
				var amount := 0.5 if clip=="walk" else 0.8
				if bone=="upperleg01.L": euler.x=wave*amount
				if bone=="upperleg01.R": euler.x=-wave*amount
				if bone=="lowerleg01.L": euler.x=maxf(0,-wave)*amount*1.3
				if bone=="lowerleg01.R": euler.x=maxf(0,wave)*amount*1.3
				if bone=="upperarm01.L": euler.x=-wave*amount*0.65
				if bone=="upperarm01.R": euler.x=wave*amount*0.65
				if bone=="spine02": euler.y=wave*0.05
			elif clip in ["work","sit"]:
				if bone.begins_with("upperleg"): euler.x=-1.4
				if bone.begins_with("lowerleg"): euler.x=1.4
				if bone.begins_with("upperarm"): euler.x=-1.05; euler.z*=0.65
				if bone.begins_with("lowerarm"): euler.x=0.45+wave*0.025
				if bone=="spine02": euler.x=0.06+wave*0.012
				if bone=="head": euler.y=wave*0.04
				if clip=="sit":
					if bone.begins_with("upperarm"): euler.x=-0.4
					if bone.begins_with("lowerarm"): euler.x=-0.3
			elif clip=="fallen":
				if bone.begins_with("upperarm"): euler=Vector3(-0.15,0,-0.12 if bone.ends_with("L") else 0.12)
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
			anim.rotation_track_insert_key(track,phase*anim.length,Quaternion.from_euler(euler))
	return anim

func pose(speed: float, attacking: bool, fallen: bool, working: bool = false, talking: bool = false) -> void:
	if fallen:
		if current!="fallen":
			# Discard queued locomotion blends; body-root motion supplies the fall transition.
			animation.stop()
			animation.speed_scale=1.0
			animation.play("fallen")
			animation.advance(0)
			current="fallen"
		return
	var next := "sit" if talking else "work" if working else "strike" if attacking else "run" if speed>5.5 else "walk" if speed>0.2 else "idle"
	if next!=current:
		animation.play(next,0.20)
		if next in ["idle","work"]: animation.seek(float(variation%11)/11.0,true)
		current=next
	animation.speed_scale=clampf(speed/3.8,1.0,2.4) if next=="run" else clampf(speed/1.65,0.6,2.5) if next=="walk" else 0.85+float(variation%5)*0.06

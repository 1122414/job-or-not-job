class_name HumanVisual
extends Node3D

var outfit := "casual"
var skeleton: Skeleton3D
var animation: AnimationPlayer
var current := ""
var grip: Node3D

func _ready() -> void:
	var model: Node3D = load("res://assets/characters/"+outfit+".glb").instantiate()
	model.name="Model"
	model.rotation.y=PI
	add_child(model)
	for node in model.find_children("*","Skeleton3D",true,false): skeleton=node
	animation=AnimationPlayer.new()
	add_child(animation)
	var library := AnimationLibrary.new()
	for clip in ["idle","walk","run","strike"]: library.add_animation(clip,make_clip(clip))
	animation.add_animation_library("",library)
	animation.play("idle")
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
			elif clip=="strike":
				var punch := sin(phase*PI)
				if bone=="upperarm01.R": euler=Vector3(-1.5*punch,-0.25*punch,0.62*(1-punch))
				if bone=="lowerarm01.R": euler.x=-0.3*punch
				if bone=="spine02": euler.y=-0.3*punch
			else:
				if bone=="spine02": euler.x=wave*0.012
			anim.rotation_track_insert_key(track,phase*anim.length,Quaternion.from_euler(euler))
	return anim

func pose(speed: float, attacking: bool, fallen: bool) -> void:
	if fallen:
		animation.pause()
		current="fallen"
		return
	var next := "strike" if attacking else "run" if speed>5.5 else "walk" if speed>0.2 else "idle"
	if next!=current:
		animation.play(next,0.13)
		current=next
	animation.speed_scale=1.5 if next=="run" else 1.15 if next=="walk" else 1.0

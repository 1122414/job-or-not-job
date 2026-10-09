class_name AutumnStoryPoint
extends CharacterBody3D

var story: AutumnStory
var stable_id := ""
var title := ""
var person := false
var visual: HumanVisual
var body: CollisionShape3D
var hp := 100
var down := 0.0
var recoil := 0.0
var affinity := 0
var trust := 0
var fear := 0
var last_hit := -1
var hit_push := Vector3.ZERO

func _ready() -> void:
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer=1;collision_mask=3
	if person:
		Shapes.collider(self,Vector3(.6,1.8,.5),Vector3(0,.9,0))
		for child in get_children():
			if child is CollisionShape3D: body=child
		visual=HumanVisual.new(); visual.outfit="office"; visual.personality="lead"
		add_child(visual); visual.rotation.y=PI
	else:
		Shapes.box(self,Vector3(1.1,1.4,.1),Vector3(0,1.4,0),Color("486261"))
		var sign := Shapes.label(self,"实习申请 / 秋招\nE 查看",Vector3(0,1.45,-.07),28)
		sign.pixel_size=.003

func available() -> bool:
	return person and down<=0

func _physics_process(delta: float) -> void:
	if not person or not visible: return
	recoil=maxf(0,recoil-delta)
	var was_down := down>0
	down=maxf(0,down-delta)
	if was_down and down==0:
		hp=35;story.game.say("导师撑着身体起身，仍然拒绝继续争辩。")
		story.game.queue_save()
	velocity=hit_push*minf(1,recoil/.35) if down<=0 else Vector3.ZERO
	move_and_slide();position.y=40
	visual.rotation.z=move_toward(visual.rotation.z,PI/2 if down>0 else 0,delta*5)
	visual.position.y=move_toward(visual.position.y,.28 if down>0 else 0,delta*3)
	body.rotation.z=PI/2 if down>0 else 0
	body.position=Vector3(-.65,.3,0) if down>0 else Vector3(0,.9,0)
	visual.blocking=fear>0 and recoil<=0 and down<=0
	visual.pose(0,false,down>0,false,false,recoil>0 and down<=0,story.game.speaker==self)

func hit(direction: Vector3,strength: float,action: int,_dangerous: bool=false) -> void:
	if not available() or not story.campus() or last_hit==action: return
	last_hit=action;hp=maxi(1,hp-roundi(strength*24))
	affinity=maxi(-100,affinity-18);trust=maxi(-100,trust-20);fear=mini(100,fear+25)
	recoil=.5;hit_push=direction*2.0
	visual.rotation.y=atan2(direction.x,direction.z)
	if hp==1: down=12
	if story.data.phase=="mentor": story.refuse(true)
	else: story.game.close_interaction()
	story.game.say("导师暂时昏迷，仍有呼吸。" if down>0 else "导师后退护住身体：停手！今天不谈了。")
	story.game.queue_save()

func snapshot() -> Dictionary:
	return {"hp":hp,"down":down,"affinity":affinity,"trust":trust,"fear":fear,"position":SaveGame.vector(position)}

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	for limits in [["hp",1,100],["down",0,12],["affinity",-100,100],["trust",-100,100],["fear",0,100]]:
		if not CityPopulation.number(data.get(limits[0]),limits[1],limits[2],limits[0]!="down"): return false
	if not SaveGame.valid_vector(data.get("position")): return false
	var p := SaveGame.unvector(data.position)
	return absf(p.x)<6 and p.z> -5 and p.z<9 and absf(p.y-40)<.01 and (data.hp!=1 or data.down>0)

func restore(data: Dictionary) -> void:
	hp=int(data.get("hp",100));down=float(data.get("down",0))
	affinity=int(data.get("affinity",0));trust=int(data.get("trust",0));fear=int(data.get("fear",0))
	position=SaveGame.unvector(data.get("position",[0,40,-2.2]));velocity=Vector3.ZERO;hit_push=Vector3.ZERO;recoil=0;last_hit=-1

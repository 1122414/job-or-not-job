class_name AutumnStoryPoint
extends StaticBody3D

var story: AutumnStory
var stable_id := ""
var title := ""
var person := false
var visual: HumanVisual
var recoil := 0.0

func _ready() -> void:
	if person:
		Shapes.collider(self,Vector3(.6,1.8,.5),Vector3(0,.9,0))
		visual=HumanVisual.new(); visual.outfit="office"; visual.personality="lead"
		add_child(visual); visual.rotation.y=PI
	else:
		Shapes.box(self,Vector3(1.1,1.4,.1),Vector3(0,1.4,0),Color("486261"))
		var sign := Shapes.label(self,"实习申请 / 秋招\nE 查看",Vector3(0,1.45,-.07),28)
		sign.pixel_size=.003

func _process(delta: float) -> void:
	if visual:
		recoil=maxf(0,recoil-delta)
		visual.pose(0,false,false,false,false,recoil>0,story.game.speaker==self)

func hit(_direction: Vector3,_strength: float,_action: int,_dangerous: bool=false) -> void:
	if not person or not story.campus(): return
	recoil=.7
	story.refuse(true)
	story.game.say("争辩被冲突打断，实习仍未获允许。可以从走廊离开。")

class_name WorkStation
extends StaticBody3D
var stable_id := ""
var title := ""
var color := Color("648ca8")
var label: Label3D
func _ready() -> void:
	Shapes.box(self,Vector3(1,0.8,0.7),Vector3(0,0.4,0),color)
	Shapes.collider(self,Vector3(1,0.8,0.7),Vector3(0,0.4,0))
	label=Shapes.label(self,title,Vector3(0,1.25,0),25)

func _process(_delta: float) -> void:
	var game = get_parent()
	label.visible=game.focus_target==self

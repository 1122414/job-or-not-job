class_name CityActivityPoint
extends StaticBody3D

var stable_id := ""
var title := ""

func _ready() -> void:
	collision_layer=1
	Shapes.collider(self,Vector3(.65,1,.4),Vector3(0,.5,0))
	Shapes.box(self,Vector3(.55,.06,.32),Vector3(0,1,0),Color("536d68"))
	for x in [-.2,.2]: Shapes.box(self,Vector3(.05,1,.05),Vector3(x,.5,0),Color("536d68"))
	var label := Shapes.label(self,title,Vector3(0,1.4,0),28)
	label.pixel_size=.0028
	label.outline_size=2

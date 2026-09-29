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
	label.visibility_range_end=4.5
	# The HUD supplies the selected action. Distant billboards should not fill
	# the room or show backward through the new transparent storefront.
	if stable_id=="notice":
		label.visibility_range_end=0
		Shapes.box(self,Vector3(.78,.85,.09),Vector3(0,1.25,0),Color("355e53"))
		Shapes.box(self,Vector3(.65,.71,.02),Vector3(0,1.25,.06),Color("e7ddc2"))
		label.text="街区记忆\n今日分享\n\nE 查看活动"
		label.position=Vector3(0,1.3,.078)
		label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		label.double_sided=false
		label.outline_size=0
		label.modulate=Color("355e53")
		Shapes.collider(self,Vector3(.78,.85,.09),Vector3(0,1.25,0))

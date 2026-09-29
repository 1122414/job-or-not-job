class_name CityStoryAlbum
extends Node3D

# A scene-owned reading copy, never an inventory item or a saved duplicate.
var left_page: Sprite3D
var right_page: Sprite3D
var turning_page: Node3D
var turning_front: Sprite3D
var turning_back: Sprite3D
var page := 0
var turn := 0.0

func _ready() -> void:
	for x in [-.25,.25]:
		Shapes.box(self,Vector3(.5,.018,.57),Vector3(x,-.012,0),Color("477473"))
		Shapes.box(self,Vector3(.48,.018,.55),Vector3(x,0,0),Color("ddd8c9"))
	left_page=picture(self,Vector3(-.25,.012,0))
	right_page=picture(self,Vector3(.25,.012,0))
	turning_page=Node3D.new()
	add_child(turning_page)
	turning_page.position.y=.015
	Shapes.box(turning_page,Vector3(.48,.002,.55),Vector3(.25,0,0),Color("eee6ce"))
	turning_front=picture(turning_page,Vector3(.25,.002,0))
	turning_back=picture(turning_page,Vector3(.25,-.002,0))
	turning_back.rotation.x=PI/2
	show_story(0)

func picture(parent: Node3D,at: Vector3) -> Sprite3D:
	var result := CityBookshop.picture(parent,CityBookshop.IMAGES[0],at,.0005)
	result.rotation.x=-PI/2
	result.double_sided=false
	return result

func show_story(index: int,progress: float=0.0,next_page: int=-1) -> void:
	page=clampi(index,0,2)
	turn=clampf(progress,0,1) if page<2 or next_page>=0 else 0.0
	var following := clampi(next_page,0,2) if next_page>=0 else mini(2,page+1)
	left_page.texture=CityBookshop.IMAGES[maxi(0,page-1)]
	right_page.texture=CityBookshop.IMAGES[following if turn>0 else page]
	turning_front.texture=CityBookshop.IMAGES[page]
	turning_back.texture=CityBookshop.IMAGES[following]
	turning_page.visible=turn>0 and turn<1
	turning_page.rotation.z=PI*smoothstep(0,1,turn)

class_name CityBookshop
extends Node3D

const IMAGES := [preload("res://assets/city_story/railway.svg"),preload("res://assets/city_story/street.svg"),preload("res://assets/city_story/bookshop.svg")]

var screen: Label3D
var announcement: Label3D
var album: Node3D
var projection: Sprite3D
var lamps: Array[OmniLight3D]=[]

func _ready() -> void:
	var wall := Color("dad5c4")
	for piece in [[Vector3(-6.5,2,0),Vector3(.25,4,13)],[Vector3(6.5,2,0),Vector3(.25,4,13)],[Vector3(0,2,-6.5),Vector3(13,4,.25)],[Vector3(-4.5,2,6.5),Vector3(4,4,.25)],[Vector3(4.5,2,6.5),Vector3(4,4,.25)],[Vector3(0,3.55,6.5),Vector3(5,.9,.25)]]:
		var body := Shapes.solid(self,piece[1],piece[0],wall)
		body.get_child(0).material_override=preload("res://assets/materials/painted_wall.tres")
	var floor_mesh := Shapes.box(self,Vector3(13,.025,13),Vector3(0,.006,0),Color.WHITE)
	floor_mesh.material_override=preload("res://assets/materials/office_wood.tres")
	Shapes.solid(self,Vector3(13.5,.22,13.5),Vector3(0,4.1,0),Color("737b73"))
	Shapes.box(self,Vector3(5.5,.7,.12),Vector3(0,3.5,6.7),Color("42675e"))
	label("榕树街 · 社区书屋",Vector3(0,3.5,6.78),.006)
	announcement=label("",Vector3(4.45,.65,6.72),.0035)
	for x in [-4.5,4.5]:
		Shapes.box(self,Vector3(2.7,1.6,.07),Vector3(x,1.9,6.67),Color("748d8d"))
		for dx in [-1.35,0,1.35]: Shapes.box(self,Vector3(.07,1.65,.1),Vector3(x+dx,1.9,6.72),Color("47645d"))
	for z in [-2.8,1.5]:
		Shapes.solid(self,Vector3(.65,2.4,3.1),Vector3(-5.9,1.2,z),Color("887458"))
		for row in range(4):
			for book in range(10):
				Shapes.box(self,Vector3(.42,.38,.12),Vector3(-5.53,.32+row*.55,z-1.3+book*.27),[Color("607b72"),Color("af9b71"),Color("775854")][book%3])
	Shapes.solid(self,Vector3(3,.12,1.25),Vector3(-3.5,.78,-3.8),Color("aa926b"))
	for x in [-4.6,-2.4]: Shapes.solid(self,Vector3(.1,.75,1),Vector3(x,.375,-3.8),Color("566258"))
	album=Node3D.new()
	add_child(album)
	album.position=Vector3(-3.5,.86,-3.8)
	for x in [-.25,.25]:
		Shapes.box(album,Vector3(.48,.018,.55),Vector3(x,0,0),Color("ddd8c9"))
		Shapes.box(album,Vector3(.36,.003,.28),Vector3(x,.012,0),Color("668584"))
		var page := picture(album,IMAGES[0 if x<0 else 1],Vector3(x,.023,0),.0005)
		page.rotation.x=-PI/2
	Shapes.box(self,Vector3(5,2.35,.06),Vector3(0,2.05,-6.29),Color("293c3d"))
	projection=picture(self,IMAGES[0],Vector3(0,2.15,-6.23),.0042)
	projection.visible=false
	screen=label("街区记忆分享\n网络影像暂不可用",Vector3(0,.6,-6.24),.003)
	screen.width=850
	screen.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for z in [-3,3]:
		Shapes.box(self,Vector3(2,.06,.25),Vector3(0,3.85,z),Color("efe3c5"))
		var light := OmniLight3D.new()
		light.position=Vector3(0,3.3,z)
		light.omni_range=8
		light.light_color=Color("ffe6c6")
		light.light_energy=.65
		add_child(light)
		lamps.append(light)

func label(text: String,at: Vector3,pixel: float) -> Label3D:
	var result := Shapes.label(self,text,at,40)
	result.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	result.pixel_size=pixel
	result.outline_size=0
	return result

static func picture(parent: Node3D,texture: Texture2D,at: Vector3,pixel: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture=texture
	sprite.pixel_size=pixel
	sprite.position=at
	sprite.shaded=true
	parent.add_child(sprite)
	return sprite

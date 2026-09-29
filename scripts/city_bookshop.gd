class_name CityBookshop
extends Node3D

const IMAGES := [preload("res://assets/city_story/railway.svg"),preload("res://assets/city_story/street.svg"),preload("res://assets/city_story/bookshop.svg")]

var screen: Label3D
var announcement: Label3D
var album: Node3D
var projection: Sprite3D
var lamps: Array[OmniLight3D]=[]
var furnishings: CityStreetscape

func _ready() -> void:
	build_room()
	furnishings.solid(Vector3(3,.12,1.25),Vector3(-3.5,.78,-3.8),"timber")
	for x in [-4.6,-2.4]: furnishings.solid(Vector3(.1,.75,1),Vector3(x,.375,-3.8),"metal")
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
	furnishings.flush()

func build_room() -> void:
	furnishings=CityStreetscape.new()
	furnishings.name="BookshopFurnishings"
	add_child(furnishings)
	furnishings.materials.old_wall.albedo_color=Color("ece4d0")
	furnishings.materials.timber.albedo_color=Color("c8a876")
	for item in [["green","355e53"],["paper","e7ddc2"],["clay","966652"],["linen","bba98a"],["book_blue","587583"],["book_red","925b4d"],["book_green","677860"],["book_yellow","c5a765"]]:
		furnishings.materials[item[0]]=Shapes.material(Color(item[1]))
	for part in [[Vector3(-6.5,2,0),Vector3(.25,4,13)],[Vector3(6.5,2,0),Vector3(.25,4,13)],[Vector3(0,2,-6.5),Vector3(13,4,.25)],[Vector3(0,3.55,6.5),Vector3(13,.9,.25)]]:
		furnishings.solid(part[1],part[0],"old_wall")
	# Real window openings admit the street view and daylight. Glazing still
	# blocks bodies, so a transparent pane cannot become an accidental exit.
	for x in [-4.5,4.5]:
		furnishings.solid(Vector3(4,.75,.25),Vector3(x,.375,6.5),"green")
		OfficeRooms.glazing(self,Vector3(x,1.92,6.5),Vector3(3.85,2.32,.055))
		for dx in [-1.92,0,1.92]: furnishings.solid(Vector3(.09,2.35,.16),Vector3(x+dx,1.92,6.5),"green")
		for y in [.78,2.7,3.09]: furnishings.box(Vector3(4,.085,.18),Vector3(x,y,6.5),"green")
		furnishings.box(Vector3(4.12,.1,.46),Vector3(x,.76,6.48),"timber")
	for x in [-2.49,2.49]: furnishings.solid(Vector3(.13,3.1,.36),Vector3(x,1.55,6.5),"green")
	var floor_mesh := Shapes.box(self,Vector3(13,.025,13),Vector3(0,.006,0),Color.WHITE)
	floor_mesh.material_override=preload("res://assets/materials/office_wood.tres")
	furnishings.solid(Vector3(13.5,.22,13.5),Vector3(0,4.1,0),"old_wall")
	for x in [-6.3,6.3]:
		furnishings.box(Vector3(.1,.8,12.65),Vector3(x,.4,0),"green")
		furnishings.box(Vector3(.15,.09,12.7),Vector3(x,.83,0),"timber")
		furnishings.box(Vector3(.15,.12,12.7),Vector3(x,.09,0),"timber")
	for z in [-4.3,0,4.3]: furnishings.box(Vector3(13,.18,.17),Vector3(0,3.94,z),"timber")
	furnishings.box(Vector3(12.9,.72,.19),Vector3(0,3.51,6.7),"green")
	label("榕树街  ·  社区书屋",Vector3(0,3.51,6.82),.009)
	furnishings.box(Vector3(13.5,.12,1.15),Vector3(0,3.95,6.85),"green")
	for x in [-5.7,5.7]: furnishings.box(Vector3(.075,.65,.7),Vector3(x,3.58,6.65),"metal")
	announcement=label("",Vector3(4.45,1.95,6.62),.0035)
	announcement.modulate=Color("f1e5c6")
	# Quiet reading stays left of the circulation spine. The three existing
	# activity audiences and the right-hand exhibition retain their clear space.
	for z in [-2.7,1.2]: bookshelf(Vector3(-5.94,0,z),PI/2,3.0)
	bookshelf(Vector3(5.94,0,-2.5),-PI/2,2.9)
	for x in [-4.5,4.5]: bookshelf(Vector3(x,0,-6.06),0,2.3)
	reading_corner()
	furnishings.solid(Vector3(1.3,.85,.7),Vector3(5.65,.425,4.8),"timber")
	furnishings.box(Vector3(1.39,.06,.8),Vector3(5.65,.88,4.8),"paper")
	book_stack(Vector3(5.5,.92,4.8),3)
	var returns := label("邻里借阅 / 归还处",Vector3(5.64,1.65,6.28),.003)
	returns.rotation.y=PI
	furnishings.box(Vector3(.8,1.25,.045),Vector3(3.05,1.85,6.26),"timber")
	for i in range(3):
		furnishings.box(Vector3(.65,.29,.012),Vector3(3.05,2.23-i*.37,6.23),"paper")
		var notice := label(["邻居留书 / 自由阅览","周末 · 街区记忆分享","看完请放回原处"][i],Vector3(3.05,2.23-i*.37,6.21),.0015)
		notice.rotation.y=PI
		notice.modulate=Color("355e53")
	for x in [-3.6,3.6]:
		for z in [-3.3,3.4]:
			furnishings.box(Vector3(.035,.63,.035),Vector3(x,3.59,z),"metal")
			var shade := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius=.16; cone.bottom_radius=.37; cone.height=.28
			shade.mesh=cone; shade.material_override=furnishings.materials.green
			add_child(shade); shade.position=Vector3(x,3.14,z)
			furnishings.box(Vector3(.5,.015,.5),Vector3(x,3.01,z),"paper")
			var light := OmniLight3D.new()
			light.position=Vector3(x,2.85,z)
			light.omni_range=5.5
			light.light_color=Color("ffe8c9")
			light.light_energy=.65
			add_child(light); lamps.append(light)
	# Frame the existing projection instead of adding another text-heavy UI.
	for x in [-2.7,2.7]: furnishings.box(Vector3(.11,2.7,.13),Vector3(x,2.05,-6.25),"timber")
	for y in [.7,3.4]: furnishings.box(Vector3(5.5,.11,.13),Vector3(0,y,-6.25),"timber")
	var heading := label("街 区 记 忆",Vector3(0,3.66,-6.26),.004)
	heading.modulate=Color("355e53")

func bookshelf(at: Vector3,yaw: float,width: float) -> void:
	var rot := Basis(Vector3.UP,yaw)
	furnishings.solid(Vector3(width,2.52,.46),at+rot*Vector3(0,1.26,0),"timber",yaw)
	furnishings.box(Vector3(width-.1,2.37,.035),at+rot*Vector3(0,1.26,.25),"green",yaw)
	for x in [-width/2+.035,width/2-.035]: furnishings.box(Vector3(.075,2.52,.54),at+rot*Vector3(x,1.26,.02),"timber",yaw)
	for row in range(6): furnishings.box(Vector3(width,.055,.57),at+rot*Vector3(0,.14+row*.46,.025),"timber",yaw)
	var colors := ["book_blue","book_red","book_green","book_yellow","linen"]
	for row in range(5):
		var count := int((width-.2)/.115)
		for i in range(count):
			if (i+row*3)%13 in [0,1]: continue
			var height := .25+float((i*7+row*3)%9)*.016
			var pos := at+rot*Vector3(-width/2+.13+i*.115,.17+row*.46+height/2,.14)
			furnishings.box(Vector3(.085,height,.27),pos,colors[(i+row*2)%5],yaw)
			for dy in [-height*.3,height*.27]: furnishings.box(Vector3(.055,.014,.009),pos+rot*Vector3(0,dy,.14),"paper",yaw)
	var title := label("文学 / 城市 / 邻里",at+rot*Vector3(0,2.7,.26),.0027)
	title.rotation.y=yaw
	title.modulate=Color("355e53")

func book_stack(at: Vector3,count: int) -> void:
	for i in range(count):
		furnishings.box(Vector3(.38,.044,.28),at+Vector3((i%2)*.02,i*.058,0),"book_red" if i%2==0 else "book_blue")
		furnishings.box(Vector3(.36,.027,.276),at+Vector3((i%2)*.02,i*.058+.004,0),"paper")

func reading_corner() -> void:
	furnishings.solid(Vector3(2.6,.08,1.0),Vector3(-3.95,.75,5.52),"timber")
	for x in [-5,-2.9]:
		for z in [5.15,5.89]: furnishings.solid(Vector3(.07,.71,.07),Vector3(x,.355,z),"metal")
	for x in [-4.65,-3.25]:
		var chair := preload("res://scenes/props/waiting_chair.tscn").instantiate()
		add_child(chair)
		chair.position=Vector3(x,.012,4.35)
		chair.rotation.y=0
	book_stack(Vector3(-4.75,.83,5.46),3)
	book_stack(Vector3(-3.3,.81,5.45),1)
	var desk_lamp := preload("res://scenes/props/reception_lamp.tscn").instantiate()
	add_child(desk_lamp)
	desk_lamp.position=Vector3(-3.8,.8175,5.89)
	desk_lamp.rotation.y=PI

func label(text: String,at: Vector3,pixel: float) -> Label3D:
	var result := Shapes.label(self,text,at,40)
	result.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	result.double_sided=false
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

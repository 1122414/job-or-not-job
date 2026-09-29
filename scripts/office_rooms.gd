class_name OfficeRooms
extends RefCounted

const INTERVIEW_SEATS := {"a":Vector3(-21,0,-13.15),"b":Vector3(7,0,-13.15)}
const INTERVIEW_HOSTS := {"a":Vector3(-21,0,-15.0),"b":Vector3(7,0,-15.0)}
const INTERVIEW_CALLS := {"a":Vector3(-20.1,0,-12.95),"b":Vector3(7.9,0,-12.95)}
const RECEPTIONS := {"a":Vector3(-16.2,0,0),"b":Vector3(11.8,0,0)}
const B_BOX_START := Vector3(7.55,0.88,-14.48)
const B_BOX_TABLE := Vector3(7.32,0.88,-14.42)
const B_BOX_EDGE := Vector3(7.32,0.88,-13.56)
const B_BOX_FLOOR := Vector3(7.55,0.15,-14.06)

static func plaque(parent: Node3D,text: String,pos: Vector3,width: float=1.8) -> void:
	Shapes.box(parent,Vector3(width,0.42,0.055),pos,Color("233038"))
	var label := Shapes.label(parent,text,pos+Vector3(0,0,0.035),32)
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	label.pixel_size=0.0028
	label.outline_size=0
	label.modulate=Color("f0ece3")

static func glazing(game: Node3D,pos: Vector3,size: Vector3) -> void:
	var wall := Shapes.solid(game,size,pos,Color("a0b2b5"))
	var glass := Shapes.material(Color(0.51,0.65,0.68,0.22))
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness=0.17
	wall.get_child(0).material_override=glass
	for y in [-size.y/2,size.y/2]:
		Shapes.box(game,Vector3(size.x+0.04,0.045,size.z+0.04),pos+Vector3(0,y,0),Color("3b454a"))
	for x in [-size.x/2,size.x/2]:
		Shapes.box(game,Vector3(0.045,size.y,size.z+0.04),pos+Vector3(x,0,0),Color("3b454a"))

# Legacy world coordinates above remain reference points for v11 fixtures/migration.
# Gameplay reads editable scene markers rather than copying those coordinates.
static func space(game: Node3D, firm: String) -> Node3D:
	return game.get_node("Company"+firm.to_upper())

static func point(game: Node3D, firm: String, key: String) -> Vector3:
	var marker: Node3D=space(game,firm).get_node("Anchors/"+key)
	return marker.global_position

static func object(game: Node3D, firm: String, key: String) -> Node3D:
	return space(game,firm).get_node(key)

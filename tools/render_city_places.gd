extends "res://tools/render_city_streets.gd"

func fingerprint(game: Node3D) -> Dictionary:
	var result := super.fingerprint(game)
	for node in game.city_life.room.find_children("*","MultiMeshInstance3D",true,false):
		var buffer: PackedFloat32Array=node.multimesh.buffer
		if buffer.size()!=node.multimesh.instance_count*12:
			push_error("Bookshop fingerprint requires actual GPU transforms"); return {}
		result["bookshop/"+String(node.name)]=hash(buffer)
	return result

func views() -> Array:
	return VIEWS+[
		["bookshop-inside",Vector3(-51,1.7,37),Vector3(-52,1.55,28),630],
		["bookshop-gallery",Vector3(-55,1.7,29.7),Vector3(-46.3,1.55,35),630],
		["bookshop-window",Vector3(-53,1.7,32),Vector3(-50.5,1.8,39),630],
		["bookshop-evening",Vector3(-51,1.7,37),Vector3(-52,1.55,28),1140],
		["central-walk",Vector3(0,1.75,23),Vector3(0,2.2,78),540]
	]

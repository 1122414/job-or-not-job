extends "res://tools/render_city_streets.gd"

func prepare_scene(game: Node3D) -> void:
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	var count := 0
	for lot in CityUrbanFabric.LOTS:
		var architecture: Node3D=streets.get_node("Architecture_"+lot.id)
		for batch in architecture.find_children("*","MultiMeshInstance3D",true,false):
			for i in range(batch.multimesh.instance_count):
				var box: AABB=batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb()
				if box.position.y<CityArchitecture.GROUND_HEIGHT-.001 or box.end.y>lot.size.y+.001:
					push_error("Actual architecture mesh exceeds gallery/roof boundary: "+str(box));quit(1);return
				count+=1
	print("ARCHITECTURE_GPU_CLEARANCE_OK bays=",count)

func views() -> Array:
	return [
		["central-walk",Vector3(0,1.75,23),Vector3(0,4.5,78),540],
		["west-street",Vector3(-2,1.75,48),Vector3(-18,6,35),540],
		["east-street",Vector3(1,1.75,51),Vector3(18,7,35),540],
		["north-street",Vector3(2,1.75,92),Vector3(-16,6,78),540],
		["west-detail",Vector3(-6,3.5,43),Vector3(-10,5.5,38),540],
		["west-gallery",Vector3(-18,1.75,42),Vector3(-18,1.6,32),540],
		["district-overview",Vector3(-59,18,95),Vector3(2,1,50),540],
		["central-night",Vector3(0,1.75,23),Vector3(0,4.5,78),1230],
		["west-night",Vector3(-2,1.75,48),Vector3(-18,6,35),1230],
		["east-night",Vector3(1,1.75,51),Vector3(18,7,35),1230],
		["north-night",Vector3(2,1.75,92),Vector3(-16,6,78),1230]
	]

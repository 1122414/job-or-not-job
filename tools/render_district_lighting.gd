extends "res://tools/render_city_places.gd"

func prepare_scene(game: Node3D) -> void:
	# Fixed lighting subjects at actual C3g venues. This is not a route proof.
	for id in CityEvening.PLANS:
		var npc: OfficeNPC=game.npc_for_role(id)
		npc.position=CityOuting.place_position(npc,CityEvening.PLANS[id][0])
		npc.visual.rotation.y=PI
	game.player.position=Vector3(44,0,57)

func views() -> Array:
	return super.views()+[
		["company-a",Vector3(-14,1.7,-1.8),Vector3(-8.5,1.35,-8),540],
		["company-b",Vector3(14,1.7,-1.8),Vector3(19.5,1.35,-8),540],
		["company-a-night",Vector3(-14,1.7,-1.8),Vector3(-8.5,1.35,-8),1230],
		["company-b-night",Vector3(14,1.7,-1.8),Vector3(19.5,1.35,-8),1230],
		["garden-day",Vector3(43,1.7,57),Vector3(41.2,1.4,54),540],
		["garden-dusk",Vector3(43,1.7,57),Vector3(41.2,1.4,54),1080],
		["garden-night",Vector3(43,1.7,57),Vector3(41.2,1.4,54),1230],
		["coast-dusk",Vector3(30,1.7,120),Vector3(28,1.4,116),1080],
		["coast-night",Vector3(30,1.7,120),Vector3(28,1.4,116),1230]
	]

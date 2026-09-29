extends "res://tools/profile_district_render.gd"

func views() -> Array:
	return VIEWS+[
		["central-walk",Vector3(0,1.75,23),Vector3(0,2.2,78),540],
		["garden-night",Vector3(43,1.7,57),Vector3(41.2,1.4,54),1230],
		["bookshop-evening",Vector3(-51,1.7,37),Vector3(-52,1.55,28),1140],
		["company-a-night",Vector3(-14,1.7,-1.8),Vector3(-8.5,1.35,-8),1230],
		["company-b-night",Vector3(14,1.7,-1.8),Vector3(19.5,1.35,-8),1230]
	]

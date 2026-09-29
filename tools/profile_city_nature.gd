extends "res://tools/profile_district_render.gd"

func views() -> Array:
	return [["central-walk",Vector3(0,1.7,23),Vector3(0,2.5,65),540],
		["west-arcade",Vector3(-8,1.7,46),Vector3(-21,1.65,43),540]]+VIEWS

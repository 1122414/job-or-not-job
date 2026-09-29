extends "res://tools/render_city_streets.gd"

func views() -> Array:
	return VIEWS+[
		["central-walk",Vector3(0,1.7,23),Vector3(0,2.5,65),540],
		["west-arcade",Vector3(-8,1.7,46),Vector3(-21,1.65,43),540],
		["open-sea",Vector3(25,1.7,123),Vector3(-15,1.4,245),540]
	]

func capture(viewport: SubViewport,title: String) -> bool:
	if title!="open-sea": return await super.capture(viewport,title)
	var streets: CityStreetscape=viewport.get_child(0).get_node("ConnectedDistrict/Streetscape")
	streets.water.set_shader_parameter("wave_time",0.0)
	if not await super.capture(viewport,title): return false
	var first := viewport.get_texture().get_image().get_data()
	streets.water.set_shader_parameter("wave_time",2.0)
	if not await super.capture(viewport,"sea-wave-shift"): return false
	var second := viewport.get_texture().get_image().get_data()
	var changed := 0
	for i in range(first.size()):
		if first[i]!=second[i]: changed+=1
	if changed==0: push_error("Water phase does not change actual rendered pixels"); return false
	FileAccess.open(output.path_join("water-render.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase_seconds":[0,2],"changed_image_bytes":changed,"total_image_bytes":first.size(),"actual_gpu_images":true,"normal_game_performance":false},"\t")+"\n")
	return true

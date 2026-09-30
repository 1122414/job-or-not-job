extends "res://tools/render_city_architecture.gd"

func prepare_scene(game: Node3D) -> void:
	super.prepare_scene(game)
	var streets: CityStreetscape=game.get_node("ConnectedDistrict/Streetscape")
	var mounted := 0
	for batch in streets.find_children("*","MultiMeshInstance3D",true,false):
		if not batch.multimesh.mesh.resource_path.ends_with("industrial_wall_lamp.res"):continue
		for i in range(batch.multimesh.instance_count):
			var pose: Transform3D=batch.global_transform*batch.multimesh.get_instance_transform(i)
			# The reviewed source's mounting plane is z=0, facing local +Z.
			var normal: Vector3=pose.basis*Vector3(0,0,1)
			var ray := PhysicsRayQueryParameters3D.create(pose.origin+normal*.03,pose.origin-normal*.03,1)
			if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				push_error("Actual street lamp has no wall support: "+str(pose.origin));quit(1);return
			mounted+=1
	if mounted!=26:push_error("Expected every street lamp mounting check, got "+str(mounted));quit(1);return
	print("STREET_FIXTURE_MOUNT_OK lamps=",mounted)

func views() -> Array:
	return [
		["old-lane",Vector3(-64,1.75,54),Vector3(-40,1.9,35),540],
		["old-front",Vector3(-35,1.75,44),Vector3(-34,1.7,37),540],
		["old-service",Vector3(-84,1.75,41),Vector3(-91,1.6,32),540],
		["home-street",Vector3(32,1.75,53),Vector3(49,2,33),540],
		["home-entrance",Vector3(40,1.75,69),Vector3(36,1.7,76),540],
		["gallery-service",Vector3(-25,1.75,25),Vector3(-18,1.5,30),540],
		["old-lane-night",Vector3(-64,1.75,54),Vector3(-40,1.9,35),1230],
		["home-street-night",Vector3(32,1.75,53),Vector3(49,2,33),1230]
	]

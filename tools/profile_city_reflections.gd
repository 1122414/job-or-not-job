extends "res://tools/profile_city_indirect.gd"

# A controlled candidate, not a runtime lighting configuration.
const CAPTURE_LAYER := 1 << 19
var reflection_probes: Array[ReflectionProbe] = []
var refresh_number := 0
var reflection_strength := 1.0

func prepare_scene(game: Node3D) -> void:
	await super.prepare_scene(game)
	for argument in OS.get_cmdline_user_args():
		if argument=="--without-reflections": return
		if argument.begins_with("--reflection-strength="): reflection_strength=float(argument.trim_prefix("--reflection-strength="))
	for branch in [game.get_node("CompanyA"),game.get_node("CompanyB"),game.get_node("ConnectedDistrict"),game.get_node("DistrictGround")]:
		for node in branch.find_children("*","GeometryInstance3D",true,false):
			if node is Label3D or node.name=="CoastalWater": continue
			node.layers|=CAPTURE_LAYER
	for item in [["office-a",Vector3(-14,1.8,-7),Vector3(24,3.6,18)], ["office-b",Vector3(14,2.15,-7),Vector3(24,4.3,18)], ["bookshop",Vector3(-52,2,32),Vector3(13,4,13)], ["home",Vector3(56,1.7,32),Vector3(14,3.4,14)]]:
		var probe := ReflectionProbe.new()
		probe.name="Reflection-"+item[0]
		probe.position=item[1]
		probe.size=item[2]
		probe.box_projection=true
		probe.intensity=reflection_strength
		probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
		probe.cull_mask=CAPTURE_LAYER
		probe.enable_shadows=true
		probe.max_distance=40
		probe.blend_distance=.2
		game.add_child(probe)
		reflection_probes.append(probe)
	game.set_meta("candidate_mode",str(game.get_meta("candidate_mode"))+"-reflections")
	game.set_meta("candidate_reflection_strength",reflection_strength)

func prepare_view(_game: Node3D, _shot: Array) -> void:
	# UPDATE_ONCE does not react to light changes. Refresh after each fixed time,
	# then the inherited real-draw warmup completes all cubemap faces.
	refresh_number+=1
	for probe in reflection_probes:
		probe.position.y+=.0001 if refresh_number%2 else -.0001

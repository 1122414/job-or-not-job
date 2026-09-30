extends "res://tools/profile_district_render.gd"

func warmup_frames() -> int:
	return 128

func prepare_scene(game: Node3D) -> void:
	var mode := "baseline"
	var indirect := 1.0
	var voxel_bias := 1.5
	var voxel_normal_bias := 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
		if argument.begins_with("--indirect="): indirect=float(argument.trim_prefix("--indirect="))
		if argument.begins_with("--voxel-bias="): voxel_bias=float(argument.trim_prefix("--voxel-bias="))
		if argument.begins_with("--voxel-normal-bias="): voxel_normal_bias=float(argument.trim_prefix("--voxel-normal-bias="))
	if mode not in ["baseline","ssil","sdfgi","combined","voxel"]:
		push_error("Unknown indirect-light candidate"); quit(1); return
	var env: Environment=game.environment
	env.ssil_enabled=mode in ["ssil","combined"]
	env.ssil_radius=2.0
	env.ssil_intensity=0.6
	env.sdfgi_enabled=mode in ["sdfgi","combined"]
	env.sdfgi_cascades=4
	env.sdfgi_min_cell_size=.2
	env.sdfgi_use_occlusion=true
	env.sdfgi_y_scale=Environment.SDFGI_Y_SCALE_50_PERCENT
	var count := 0
	if env.sdfgi_enabled or mode=="voxel":
		for branch in [game.get_node("CompanyA"),game.get_node("CompanyB"),game.get_node("ConnectedDistrict"),game.get_node("DistrictGround")]:
			for node in branch.find_children("*","GeometryInstance3D",true,false):
				if node is Label3D or node.name=="CoastalWater": continue
				node.gi_mode=GeometryInstance3D.GI_MODE_STATIC
				count+=1
	game.set_meta("static_gi_instances",count)
	game.set_meta("candidate_mode",mode)
	game.set_meta("candidate_indirect_multiplier",indirect)
	game.set_meta("candidate_voxel_bias",[voxel_bias,voxel_normal_bias])
	for light in game.find_children("*","Light3D",true,false):
		light.light_indirect_energy*=indirect
	if mode=="voxel":
		for item in [["office-a",Vector3(-14,2,-7),Vector3(29,8,28)], ["office-b",Vector3(14,2,-7),Vector3(29,8,28)], ["bookshop",Vector3(-52,2,32),Vector3(16,6,17)], ["home",Vector3(56,2,32),Vector3(17,6,17)]]:
			var probe := VoxelGI.new()
			probe.name=item[0]
			probe.position=item[1]
			probe.size=item[2]
			probe.subdiv=VoxelGI.SUBDIV_128
			game.add_child(probe)
			await process_frame
			probe.bake(game)
			if probe.data==null:
				push_error("Voxel candidate bake failed: "+item[0]); quit(1); return
			probe.data.bias=voxel_bias
			probe.data.normal_bias=voxel_normal_bias
			print("CITY_VOXEL_BAKED ",item[0])
	print("CITY_GI_CANDIDATE mode=",mode," static=",count)

func views() -> Array:
	return VIEWS+[
		["bookshop-day",Vector3(-51,1.7,37),Vector3(-52,1.55,28),630],
		["bookshop-night",Vector3(-51,1.7,37),Vector3(-52,1.55,28),1140],
		["company-a-night",Vector3(-14,1.7,-1.8),Vector3(-8.5,1.35,-8),1230],
		["company-b-night",Vector3(14,1.7,-1.8),Vector3(19.5,1.35,-8),1230],
		["home-day",Vector3(56.4,1.8,37.5),Vector3(61,1.2,32),600],
		["home-night",Vector3(56.4,1.8,37.5),Vector3(61,1.2,32),1230],
		["central-walk",Vector3(0,1.75,23),Vector3(0,2.2,78),540]
	]

class_name CityTree
extends Node3D

const ROOT := "res://assets/city_nature/"
static var meshes: Array[ArrayMesh]=[]
var lods: Array[MeshInstance3D]=[]

static func tree_material(part: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var prefix := "tree_small_02"+("_"+part if part!="trunk" else "")
	material.albedo_texture=load(ROOT+"textures/"+("tree_small_02_leaves_rgba_2k.png" if part=="leaves" else prefix+"_diff_2k.jpg"))
	material.normal_enabled=true
	material.normal_texture=load(ROOT+"textures/"+prefix+"_nor_gl_2k.jpg")
	material.normal_scale=.7
	material.roughness_texture=load(ROOT+"textures/"+prefix+"_arm_2k.jpg")
	material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled=true
	material.ao_texture=material.roughness_texture
	material.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	if part=="branch":
		material.uv1_scale=Vector3(3,.6,1)
		material.uv1_offset=Vector3(0,.4,0)
	if part=="leaves":
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold=.4
		material.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		material.backlight_enabled=true
		material.backlight=Color(.28,.32,.18)
	return material

func _init() -> void:
	if meshes.is_empty():
		var materials := [tree_material("branch"),tree_material("leaves"),tree_material("trunk")]
		for level in range(3):
			var mesh: ArrayMesh=load(ROOT+"tree_lod%d.res"%level).duplicate()
			for surface in range(3): mesh.surface_set_material(surface,materials[surface])
			meshes.append(mesh)
	for level in range(3):
		var instance := MeshInstance3D.new()
		instance.name="Detail"+str(level)
		instance.mesh=meshes[level]
		instance.visibility_range_begin=[0,18,38][level]
		instance.visibility_range_end=[18,38,0][level]
		instance.visibility_range_begin_margin=1.5 if level>0 else 0
		instance.visibility_range_end_margin=1.5 if level<2 else 0
		add_child(instance)
		lods.append(instance)

extends RefCounted

# Bake only durable room structure. Never traverse the live game with bake().
const ROOMS := [
	["office-a","CompanyA",Vector3(-14,2,-7),Vector3(29,8,28)],
	["office-b","CompanyB",Vector3(14,2,-7),Vector3(29,8,28)],
	["bookshop","ConnectedDistrict/CommunityBookshop",Vector3(-52,2,32),Vector3(16,6,17)],
	["home","ConnectedDistrict/HomeRoom",Vector3(56,2,32),Vector3(17,6,17)]
]
const MOVING_COMPANY_OBJECTS := ["InterviewPhoneA","InterviewPhoneB","InterviewBoxB","InterviewPapersA"]
var materials := {}
var textures := {}
var failed := false
var audit := {"sources":[],"excluded":[],"averaged_materials":[],"mesh_instances":0}

func collect(node: Node, game: Node3D, result: Array) -> void:
	var path := str(game.get_path_to(node))
	if str(node.name) in MOVING_COMPANY_OBJECTS or node is CityStoryAlbum:
		audit.excluded.append({"path":path,"reason":"interactive_object"})
		return
	if node is CityHomeRoom:
		for curtain in node.curtains:
			audit.excluded.append({"path":str(game.get_path_to(curtain)),"reason":"moving_curtain"})
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		if node.get_parent() is CityHomeRoom and node in node.get_parent().curtains: return
		if node.is_visible_in_tree(): result.append(node)
	for child in node.get_children(): collect(child,game,result)

func texture_mean(texture: Texture2D) -> Color:
	if textures.has(texture): return textures[texture]
	var picture := texture.get_image()
	if picture==null or picture.is_empty():
		failed=true
		push_error("Bake texture has no pixels: "+texture.resource_path)
		return Color.MAGENTA
	picture=picture.duplicate()
	if picture.is_compressed(): picture.decompress()
	var sum := Color(0,0,0,0)
	# Low-frequency albedo for GI only. Convert before averaging; visible
	# materials keep their original world-triplanar textures and normal maps.
	for y in range(64):
		for x in range(64):
			sum+=picture.get_pixel(mini(int((x+.5)*picture.get_width()/64),picture.get_width()-1),mini(int((y+.5)*picture.get_height()/64),picture.get_height()-1)).srgb_to_linear()
	var mean := (sum/4096).linear_to_srgb()
	textures[texture]=mean
	return mean

func bake_material(material: Material) -> StandardMaterial3D:
	if material==null: return StandardMaterial3D.new()
	if materials.has(material): return materials[material]
	if not material is StandardMaterial3D:
		failed=true
		push_error("Unsupported GI source material: "+material.resource_path)
		return null
	if material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
		materials[material]=null
		return null
	var result: StandardMaterial3D=material.duplicate()
	if result.albedo_texture and (result.uv1_triplanar or result.uv1_scale!=Vector3.ONE or result.uv1_offset!=Vector3.ZERO):
		var mean := texture_mean(result.albedo_texture)
		result.albedo_color*=mean
		audit.averaged_materials.append({"material":material.resource_path,"texture":result.albedo_texture.resource_path,"mean_srgb":[mean.r,mean.g,mean.b]})
		result.albedo_texture=null
		result.uv1_triplanar=false
		result.uv1_scale=Vector3.ONE
		result.uv1_offset=Vector3.ZERO
	materials[material]=result
	return result

func add_mesh(parent: Node3D, mesh: Mesh, transform: Transform3D, overrides: Array, material: Material) -> void:
	if mesh==null:
		failed=true
		push_error("GI source has no mesh")
		return
	var proxy := MeshInstance3D.new()
	proxy.mesh=mesh
	proxy.transform=transform
	proxy.layers=0
	proxy.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	for surface in range(mesh.get_surface_count()):
		var original: Material=material if material else overrides[surface] if surface<overrides.size() and overrides[surface] else mesh.surface_get_material(surface)
		var converted := bake_material(original)
		if converted==null:
			# Mixed opaque/transparent surfaces need an explicit authored proxy.
			if mesh.get_surface_count()>1:
				failed=true
				push_error("GI source requires an explicit opaque proxy for mixed surfaces")
			proxy.free()
			return
		proxy.set_surface_override_material(surface,converted)
	parent.add_child(proxy)
	audit.mesh_instances+=1

func make_source(game: Node3D) -> Node3D:
	var source := Node3D.new()
	source.name="StaticLightingBakeSource"
	game.add_child(source)
	var selected := []
	for room in ROOMS: collect(game.get_node(room[1]),game,selected)
	collect(game.get_node("DistrictGround"),game,selected)
	for geometry in selected:
		audit.sources.append(str(game.get_path_to(geometry)))
		if geometry is MeshInstance3D:
			var overrides := []
			for surface in range(geometry.mesh.get_surface_count()): overrides.append(geometry.get_surface_override_material(surface))
			add_mesh(source,geometry.mesh,game.global_transform.affine_inverse()*geometry.global_transform,overrides,geometry.material_override)
		else:
			var batch: MultiMesh=geometry.multimesh
			var count := batch.instance_count if batch.visible_instance_count<0 else batch.visible_instance_count
			for index in range(count):
				# MultiMesh's instance override is resolved explicitly, unlike the
				# engine's generic get_meshes() path used by VoxelGI.bake().
				add_mesh(source,batch.mesh,game.global_transform.affine_inverse()*geometry.global_transform*batch.get_instance_transform(index),[],geometry.material_override)
	return source

extends SceneTree

const SOURCE := "res://production/environment/polyhaven_nature"
const OUTPUT := "res://assets/city_nature"

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("textures"))
	var provenance: Variant=JSON.parse_string(FileAccess.get_file_as_string(SOURCE.path_join("provenance.json")))
	if not provenance is Dictionary or not provenance.get("assets") is Array:
		push_error("Missing nature source provenance"); quit(1); return
	for asset in provenance.assets:
		for relative in asset.files:
			var path: String=SOURCE.path_join(asset.id).path_join(relative)
			if FileAccess.get_sha256(path)!=asset.files[relative].sha256: push_error("Nature source changed: "+path); quit(1); return
	var textures := []
	for file in DirAccess.get_files_at(SOURCE.path_join("tree_small_02/textures")):
		if file.ends_with(".jpg") and file!="tree_small_02_leaves_diff_2k.jpg":
			if DirAccess.copy_absolute(SOURCE.path_join("tree_small_02/textures").path_join(file),OUTPUT.path_join("textures").path_join(file))!=OK: quit(1); return
			textures.append(file)
	for file in DirAccess.get_files_at(SOURCE.path_join("leafy_grass")):
		if file.ends_with(".jpg"):
			if DirAccess.copy_absolute(SOURCE.path_join("leafy_grass").path_join(file),OUTPUT.path_join("textures").path_join(file))!=OK: quit(1); return
			textures.append(file)
	var leaf := Image.load_from_file(SOURCE.path_join("tree_small_02/textures/tree_small_02_leaves_diff_2k.jpg"))
	var alpha := Image.load_from_file(SOURCE.path_join("tree_small_02/textures/tree_small_02_leaves_alpha_2k.png"))
	leaf.convert(Image.FORMAT_RGBA8)
	alpha.convert(Image.FORMAT_L8)
	if leaf.get_size()!=alpha.get_size(): push_error("Leaf opacity size mismatch"); quit(1); return
	var pixels := leaf.get_data()
	var opacity := alpha.get_data()
	for i in range(opacity.size()): pixels[i*4+3]=opacity[i]
	leaf=Image.create_from_data(leaf.get_width(),leaf.get_height(),false,Image.FORMAT_RGBA8,pixels)
	var leaf_name := "tree_small_02_leaves_rgba_2k.png"
	if leaf.save_png(OUTPUT.path_join("textures").path_join(leaf_name))!=OK: quit(1); return
	textures.append(leaf_name)
	# Ground every LOD using the same source base. Never normalize each LOD
	# separately: that would make the trunk move when its detail changes.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(SOURCE.path_join("tree_small_02/tree_small_02_2k.gltf"),state)!=OK: quit(1); return
	var original: ImporterMesh=state.get_meshes()[0].mesh
	var source_bounds := original.get_mesh().get_aabb()
	var records := {}
	for level in range(3):
		var input: ArrayMesh=load("res://build/c4d-tree-production/tree_lod%d.res"%level)
		var mesh := ArrayMesh.new()
		for surface in range(input.get_surface_count()):
			var arrays := input.surface_get_arrays(surface)
			var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(positions.size()): positions[i].y-=source_bounds.position.y
			arrays[Mesh.ARRAY_VERTEX]=positions
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			if mesh.get_surface_count()!=surface+1: push_error("Runtime tree assembly failed"); quit(1); return
		var relative := "tree_lod%d.res"%level
		if ResourceSaver.save(mesh,OUTPUT.path_join(relative),ResourceSaver.FLAG_COMPRESS)!=OK: quit(1); return
		records[relative]=FileAccess.get_sha256(OUTPUT.path_join(relative))
	for file in textures:
		var relative: String="textures/"+file
		records[relative]=FileAccess.get_sha256(OUTPUT.path_join(relative))
		var config := ConfigFile.new()
		var import_path: String=OUTPUT.path_join(relative)+".import"
		if FileAccess.file_exists(import_path) and config.load(import_path)!=OK:
			push_error("Cannot preserve texture import settings: "+import_path); quit(1); return
		config.set_value("remap","importer","texture")
		config.set_value("remap","type","CompressedTexture2D")
		config.set_value("deps","source_file",OUTPUT.path_join(relative))
		config.set_value("params","compress/mode",2)
		config.set_value("params","mipmaps/generate",true)
		if config.save(import_path)!=OK: push_error("Cannot write texture import settings"); quit(1); return
	var record := {"source_provenance":provenance,"processing":"tree_leaf_components.py -> bake_city_tree.gd -> prepare_city_nature.gd; source leaf RGB + original opacity; shared source ground offset",
		"source_ground_y":source_bounds.position.y,"derived_files":records,
		"mesh_bake":JSON.parse_string(FileAccess.get_file_as_string("res://build/c4d-tree-production/bake.json"))}
	FileAccess.open(OUTPUT.path_join("provenance.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	print("CITY_NATURE_PREPARED textures=",textures.size()," levels=3 base_y=",source_bounds.position.y)
	quit()

@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material: StandardMaterial3D=mesh.mesh.surface_get_material(surface)
			if material==null: continue
			material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			# Preserve the source cutout silhouette, with sample coverage at its edge.
			if material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				material.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				material.alpha_antialiasing_edge=0.3
	return scene

extends SceneTree
func _initialize() -> void:
	var file := FileAccess.open("res://build/GODOT-LICENSES.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"+JSON.stringify(Engine.get_license_info(),"  "))
	file.close()
	quit()

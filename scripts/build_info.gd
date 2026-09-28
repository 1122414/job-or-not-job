class_name BuildInfo
extends RefCounted

static func read() -> Dictionary:
	var path := OS.get_executable_path().get_base_dir().path_join("../Resources/build-manifest.json")
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return {}
	for key in ["build_id", "source_commit", "source_sha256", "app_version"]:
		if not value.get(key) is String or value[key].is_empty(): return {}
	return value

static func label() -> String:
	var info := read()
	if info.is_empty(): return "源码运行 · 存档 v%d" % SaveGame.VERSION
	return "v%s · %s / %s%s" % [info.app_version, info.source_commit.left(8), info.source_sha256.left(8), "（含未提交修改）" if info.get("runtime_dirty", false) else ""]

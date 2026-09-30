extends "res://tools/profile_city_indirect.gd"

func prepare_scene(game: Node3D) -> void:
	game.room_lighting.set_enabled("--without-room-lighting" not in OS.get_cmdline_user_args())
	game.set_meta("candidate_mode","runtime-room-lighting" if game.room_lighting.enabled else "runtime-lighting-off")
	game.set_meta("static_gi_instances",game.room_lighting.captured_geometry.size())
	if not game.room_lighting.available:
		if "--expect-fallback" in OS.get_cmdline_user_args():
			if not game.room_lighting.indirect.is_empty() or not game.room_lighting.reflections.is_empty():
				push_error("Fallback allocated unsupported lights");quit(1)
			game.set_meta("candidate_mode","runtime-backend-fallback")
			return
		push_error("Runtime room lighting needs Forward+");quit(1)

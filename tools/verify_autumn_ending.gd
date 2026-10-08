extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from="): path=argument.trim_prefix("--from=")
	if path=="":
		push_error("Expected -- --from=<isolated ending save>"); quit(1); return
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(10): await physics_frame
	var value := SaveGame.read(path,game)
	if value.is_empty() or not SaveGame.restore(game,value):
		push_error("Packaged ending restore rejected"); quit(1); return
	for frame in range(5): await physics_frame
	var ok: bool=game.story.data.phase=="ending" and game.career.employer=="" and not game.career.facts.has("regular") and game.story.search.ready_to_end()
	ok=ok and game.career.facts.has("internship_certificate") and game.career.facts.has("output_one") and game.career.facts.has("output_two")
	# Compare every story field in the JSON numeric domain, not int/float variants.
	ok=ok and JSON.parse_string(JSON.stringify(game.story.data))==JSON.parse_string(JSON.stringify(value.autumn_story))
	game.advance_time(Payroll.DAY*7)
	ok=ok and game.career.employer=="" and game.story.data.phase=="ending"
	game.queue_free(); await process_frame
	if not ok: push_error("Packaged ending changed across independent restore")
	print("PACKAGED_ENDING_RESTORE_OK=",ok)
	quit(0 if ok else 1)

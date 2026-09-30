extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var source := "";var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source=arg.trim_prefix("--source=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if source=="" or output=="":push_error("Explicit source/output required");quit(1);return
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);root.set_disable_input(true)
	for i in range(10):await physics_frame
	game.set_process(false);paused=true
	var saved := SaveGame.read(source,game)
	if saved.is_empty() or not SaveGame.restore(game,saved):push_error("Actual meal save rejected "+source);quit(1);return
	var actual: Dictionary=JSON.parse_string(JSON.stringify(SaveGame.snapshot(game)))
	var player_ok := true
	for field in ["position","yaw","pitch","hp"]:
		if actual.player[field]!=saved.player[field]:player_ok=false
	player_ok=player_ok and actual.player.protection==maxf(1,saved.player.protection)
	var same: bool=actual.city_meals==saved.city_meals and actual.payroll==saved.payroll and actual.social==saved.social and player_ok
	if not same or not SaveGame.valid(actual,game) or game.persistence_enabled or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:push_error("Meal state recovery mismatch "+source);quit(1);return
	var result := {"source":source,"version":saved.version,"orders":actual.city_meals,"all_meal_fields_equal":same,"balance":actual.payroll.balance,"world_valid":true,"paused":true,"persistence":false}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("STREET_MEAL_SAVE_RECOVERY_OK ",source);paused=false;game.queue_free();await process_frame;quit()

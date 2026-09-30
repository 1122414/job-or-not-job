extends SceneTree

var source := ""
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source=arg.trim_prefix("--source=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	if source=="" or output=="":push_error("Explicit route source and result path required");quit(1);return
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(10):await physics_frame
	var saved := SaveGame.read(source,game)
	paused=true
	if saved.is_empty() or not SaveGame.restore(game,saved):push_error("Actual route file cannot restore");quit(1);return
	var driving: CityDriving=game.driving
	# Compare both snapshots in the JSON domain; its schema number is a float.
	var actual: Dictionary=JSON.parse_string(JSON.stringify(driving.snapshot()))
	if actual!=saved.city_driving or game.payroll.minute!=saved.payroll.minute or not driving.suspended:
		push_error("Actual route driving/time identity changed");quit(1);return
	var minute: int=game.payroll.minute%Payroll.DAY
	for car in driving.cars:
		var expected: bool=(minute<360 or minute>=1080) and (car.traffic or car==driving.active)
		if not car.visual.lamps.all(func(lamp):return lamp.visible==expected):push_error("Paused route lights incorrect");quit(1);return
	if driving.active and game.player.position.distance_to(driving.active.to_global(CityCar.SEAT))>.01:
		push_error("Restored player is outside driving seat");quit(1);return
	game.set_process(false);paused=false
	for i in range(90):await physics_frame
	if driving.active and (not driving.suspended or driving.active.speed>.01 or game.player.position.distance_to(driving.active.to_global(CityCar.SEAT))>.01):
		push_error("Resume lost driver or reused throttle");quit(1);return
	var build := BuildInfo.read()
	var result := {"source_sha256":FileAccess.get_sha256(source),"active":saved.city_driving.active,"minute":saved.payroll.minute,"vehicles":saved.city_driving.vehicles.size(),"all_vehicle_fields_restored":true,"paused_lights":true,"resume_brakes_without_input":true,"persistence":game.persistence_enabled,"build_id":build.get("build_id",""),"runtime_source_sha256":build.get("source_sha256","")}
	if game.persistence_enabled or not SaveGame.valid(SaveGame.snapshot(game),game):push_error("Unsafe or invalid restored world");quit(1);return
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CAR_JOURNEY_SAVE_OK ",JSON.stringify(result));game.queue_free();await process_frame;quit()

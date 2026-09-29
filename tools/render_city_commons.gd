extends "res://tools/render_character_candidates.gd"

var game: Node3D
var viewport: SubViewport
var camera: Camera3D
var data := {}

func shot(label: String,eye: Vector3,target: Vector3) -> void:
	for i in range(45): await physics_frame
	game.process_mode=Node.PROCESS_MODE_DISABLED
	camera.position=eye; camera.look_at(target)
	if not await capture(viewport,label): quit(1); return
	data[label]={"camera":SaveGame.vector(eye),"target":SaveGame.vector(target),"commons":game.commons.snapshot()}
	game.process_mode=Node.PROCESS_MODE_INHERIT

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1440,900); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	camera=Camera3D.new(); game.add_child(camera); camera.make_current(); camera.fov=55
	var commons: CityCommons=game.commons
	var captured := {}
	for minute in [540,800]:
		game.payroll.minute=minute; game.update_daylight()
		for i in range(15000):
			await physics_frame
			for person in game.population.residents:
				if not commons.sitting(person): continue
				var place: String=person.seat_body.stable_id.get_slice("_",1)
				if not captured.has(place):
					var at: Vector3=person.seat_body.position
					await shot(place+"-daily-life",at+Vector3(4,1.75,6),at+Vector3(0,1,0))
					captured[place]=true
				if commons.reading(person) and not captured.has("reading"):
					await shot("reading-contact",person.position+Vector3(1.6,1.25,2),person.position+Vector3(0,.85,0))
					captured.reading=true
				if commons.companion(person)!=null and not captured.has("pair"):
					game.player.position=person.position+Vector3(0,0,3)
					await shot("neighbours-talking",person.position+Vector3(3,1.65,3.5),person.position+Vector3(0,1,0))
					captured.pair=true
				if not captured.has("player"):
					var slot: String=commons.visits[person.stable_id].slot
					var other: String=slot.get_slice("/",0)+"/"+str(1-int(slot.get_slice("/",1)))
					if not commons.occupied(other):
						var bench: CityBench=person.seat_body
						game.player.position=bench.approach()
						commons.use_bench(bench)
						if not game.player.seated: continue
						game.population.talk(person)
						for frame in range(45): await physics_frame
						await shot("player-joins",bench.position+Vector3(3,1.65,4),bench.position+Vector3(0,1,0))
						commons.answer(person,"commons_work")
						await shot("shared-time",bench.position+Vector3(3,1.65,4),bench.position+Vector3(0,1,0))
						game.close_interaction()
						if not game.player.stand_up():
							push_error("Player cannot leave the public bench"); quit(1); return
						await shot("player-leaves",bench.position+Vector3(3,1.65,4),bench.position+Vector3(0,1,0))
						game.player.position=Vector3(0,0,45)
						captured.player=true
			if captured.size()==6: break
		if captured.size()==6: break
	data["guard"]={"root_minimized":root.mode==Window.MODE_MINIMIZED,"root_unfocusable":root.get_flag(Window.FLAG_NO_FOCUS),"root_focused":root.has_focus(),"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"captured":captured,"ordinary_play_performance":false}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	if captured.size()!=6 or root.mode!=Window.MODE_MINIMIZED or not root.get_flag(Window.FLAG_NO_FOCUS) or root.has_focus() or Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		push_error("Incomplete commons views or unsafe background window"); quit(1); return
	print("CITY_COMMONS_RENDER ",data.guard)
	viewport.queue_free()
	await process_frame
	quit()

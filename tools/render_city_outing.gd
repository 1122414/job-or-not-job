extends "res://tools/render_city_bookshop.gd"

func guard() -> bool:
	return root.mode==Window.MODE_MINIMIZED and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and root.is_input_disabled()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.set_disable_input(true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,900); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	for i in range(10): await physics_frame
	game.set_process(false)
	var observations: Array=[]
	var navigation_only := "--navigation-only" in OS.get_cmdline_user_args()
	for item in [["bookshop","a_friend","people_listen"],["garden","b_friend","people_boundary"],["waterfront","a_friend","people_city_quiet"]]:
		if navigation_only and item[0]!="garden": continue
		var saved := SaveGame.read("res://build/c3e/"+item[0]+"-arrival.json",game)
		if saved.is_empty() or not SaveGame.restore(game,saved): push_error("Missing actual arrival "+item[0]); quit(1); return
		for i in range(10): await physics_frame
		game.update_daylight()
		var npc: OfficeNPC=game.npc_for_role(item[1])
		if navigation_only:
			game.person_index=game.social.roster().find(npc)
			game.social.outing.guiding=false
			key(viewport,KEY_P)
			for i in range(5): await process_frame
			var view: GamePageView=game.panels.view
			if not view.buttons.has("follow-companion"): push_error("Missing companion navigation button"); quit(1); return
			var button: Button=view.buttons["follow-companion"]
			view.scroll.ensure_control_visible(button)
			for i in range(5): await process_frame
			if not await capture(viewport,"people-navigation"): quit(1); return
			var point := button.get_global_rect().get_center()
			if not view.scroll.get_global_rect().has_point(point): push_error("Companion button is outside scroll view"); quit(1); return
			for pressed in [true,false]:
				var event := InputEventMouseButton.new()
				event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
				viewport.push_input(event,true)
			for i in range(5): await process_frame
			if game.panels.page!="" or game.navigation_target()!=npc or not guard(): push_error("Actual navigation click failed"); quit(1); return
			observations.append({"people_key_open":true,"actual_mouse_click":true,"companion_target":npc.stable_id,"pointer_visible":true})
			break
		var direction: Vector3=npc.position-game.player.position
		game.player.yaw=atan2(-direction.x,-direction.z); game.player.pitch=-.05
		for i in range(10): await physics_frame
		key(viewport,KEY_E)
		if game.speaker!=npc:
			push_error("Actual E did not select companion at "+item[0]); quit(1); return
		key(viewport,KEY_1)
		if game.social.outing.get("stage")!="sharing": push_error("Actual choice did not open place conversation"); quit(1); return
		for i in range(45): await physics_frame
		if not guard() or not await capture(viewport,item[0]+"-conversation"): quit(1); return
		var index: int=game.conversation.choices.find_custom(func(c): return c[1]==item[2])
		if index<0: push_error("Missing reply"); quit(1); return
		key(viewport,KEY_1+index)
		if not game.social.outing.is_empty(): push_error("Actual reply failed"); quit(1); return
		if not await capture(viewport,item[0]+"-response"): quit(1); return
		game.close_interaction()
		# Continue physical return movement under the player's normal spring camera.
		var start: Vector3=npc.position
		var metres := 0.0
		var maximum := 0.0
		var previous: Vector3=npc.position
		var path := PackedVector3Array()
		for frame in range(600):
			if frame%30==0: path=game.walking.route(game.player.position,npc.position,null,game.player)
			while not path.is_empty() and game.player.position.distance_to(path[0])<.15: path.remove_at(0)
			if game.player.position.distance_to(npc.position)>1.65 and not path.is_empty():
				var offset: Vector3=path[0]-game.player.position
				game.player.yaw=atan2(-offset.x,-offset.z); Input.action_press("forward")
			else: Input.action_release("forward")
			await physics_frame
			var step: float=npc.position.distance_to(previous)
			metres+=step; maximum=maxf(maximum,step); previous=npc.position
		Input.action_release("forward")
		if metres<5 or maximum>.1 or not guard():
			push_error("Graphical return failed at %s: metres=%f max_step=%f guard=%s" % [item[0],metres,maximum,guard()]); quit(1); return
		if not await capture(viewport,item[0]+"-return-walk"): quit(1); return
		observations.append({"venue":item[0],"start":SaveGame.vector(start),"end":SaveGame.vector(npc.position),"metres":metres,"max_step":maximum,"physics_frames":600})
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify({"images":captures,"root_minimized":root.mode==Window.MODE_MINIMIZED,"root_unfocusable":root.get_flag(Window.FLAG_NO_FOCUS),"root_focused":root.has_focus(),"pointer_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"normal_player_camera":true,"returns":observations,"normal_fps_measured":false,"independent_player_acceptance":false},"\t")+"\n")
	viewport.queue_free(); await process_frame
	print("CITY_OUTING_RENDER images=",captures," guard=",guard())
	quit()

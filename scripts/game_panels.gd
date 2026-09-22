class_name GamePanels
extends Node

var game: Node3D
var page := ""
var return_page := ""

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func show_page(next: String) -> void:
	page=next
	if page=="": return_page=""
	game.player.bag_open=page=="bag"
	game.journal_open=page=="journal"
	game.ledger_open=page=="ledger"
	game.help_open=page=="help"
	game.history_open=page=="history"
	game.menu.visible=page=="pause"
	if page=="messages": game.recruitment.message_page=0
	game.close_interaction()
	get_tree().paused=page!=""
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if page!="" else Input.MOUSE_MODE_CAPTURED
	game.hud.queue_redraw()

func toggle(next: String) -> void:
	if page==next:
		back()
	else:
		return_page="pause" if page=="pause" else "journal" if page=="journal" and next=="history" else ""
		show_page(next)

func back() -> void:
	var destination := return_page
	return_page=""
	show_page(destination)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for action in ["bag","journal","ledger","help","history","people","messages"]:
			if event.is_action_pressed(action):
				toggle(action)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("cancel"):
			if page=="": toggle("pause")
			else: back()
			get_viewport().set_input_as_handled()
			return
		if page!="":
			var key: int=event.physical_keycode if event.physical_keycode else event.keycode
			if page=="computer" and key>=KEY_1 and key<=KEY_7: game.projects.key(key-KEY_1+1)
			if page=="messages":
				if key==KEY_LEFT: game.recruitment.selected="a"; game.recruitment.message_page=0
				if key==KEY_RIGHT: game.recruitment.selected="b"; game.recruitment.message_page=0
				if key>=KEY_1 and key<=KEY_3: game.recruitment.message_action(key-KEY_1)
				if key==KEY_Q: game.recruitment.ask_conditions(); game.recruitment.message_page=0
				if key==KEY_PAGEUP: game.recruitment.message_page+=1
				if key==KEY_PAGEDOWN: game.recruitment.message_page=maxi(0,game.recruitment.message_page-1)
			if page=="people":
				if key==KEY_DOWN: game.person_index+=1
				if key==KEY_UP: game.person_index=maxi(0,game.person_index-1)
			if page=="bag":
				if key==KEY_PAGEDOWN: game.player.bag_page+=1
				if key==KEY_PAGEUP: game.player.bag_page=maxi(0,game.player.bag_page-1)
				if key>=KEY_1 and key<=KEY_8:
					var index: int=game.player.bag_page*8+key-KEY_1
					if index<game.player.inventory.size(): game.player.pick(game.player.inventory[index])
				if event.is_action_pressed("store"): game.player.store_held()
				if event.is_action_pressed("drop"): game.player.release(false)
			if page=="journal" and key in [KEY_1,KEY_2] and game.career.employer=="":
				game.career.facts.erase("guide_visit")
				game.career.facts["guide_company"]="a" if key==KEY_1 else "b"
				game.queue_save()
			if page=="journal":
				if key==KEY_3: game.career.facts.erase("guide_visit")
				if key>=KEY_4 and key<=KEY_9:
					var pending: Array=game.office.pending_visits()
					if key-KEY_4<pending.size(): game.career.facts.guide_visit=pending[key-KEY_4].key
				game.queue_save()
			if page=="history":
				if key==KEY_PAGEDOWN: game.history_page+=1
				if key==KEY_PAGEUP: game.history_page=maxi(0,game.history_page-1)
			if page=="ledger":
				if key==KEY_PAGEDOWN: game.ledger_page+=1
				if key==KEY_PAGEUP: game.ledger_page=maxi(0,game.ledger_page-1)
			if event.is_action_pressed("save"): game.save_game()
			if event.is_action_pressed("load"): game.load_game()
			game.hud.queue_redraw()
			get_viewport().set_input_as_handled()
	# The pause menu receives mouse events through Control; other panels consume them.
	elif page!="" and page!="pause":
		get_viewport().set_input_as_handled()

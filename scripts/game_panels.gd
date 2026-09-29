class_name GamePanels
extends Node

var game: Node3D
var page := ""
var return_pages: Array[String]=[]
var view: GamePageView

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func show_page(next: String) -> void:
	page=next
	if page=="": return_pages.clear()
	game.player.bag_open=page=="bag"
	game.journal_open=page=="journal"
	game.ledger_open=page=="ledger"
	game.help_open=page=="help"
	game.history_open=page=="history"
	game.menu.visible=page=="pause"
	if page=="messages": game.recruitment.message_page=0
	game.close_interaction()
	get_tree().paused=page!=""
	# Returning from UI does not constitute permission to lock the desktop pointer.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.hud.queue_redraw()
	if view: view.refresh()
	if page=="pause": game.menu.focus_first.call_deferred()

func toggle(next: String) -> void:
	if page==next:
		back()
	else:
		if page=="pause" or page=="journal" and next=="history": return_pages.append(page)
		else: return_pages.clear()
		show_page(next)

func open_child(next: String) -> void:
	if page!="": return_pages.append(page)
	show_page(next)

func back() -> void:
	var destination: String=return_pages.pop_back() if not return_pages.is_empty() else ""
	show_page(destination)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START:
		if page=="": toggle("pause")
		else: back()
		get_viewport().set_input_as_handled()
		return
	if page!="" and event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int=event.physical_keycode if event.physical_keycode else event.keycode
	# Once a page is open, Tab and navigation keys belong to Control focus.
	if page!="" and key in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: return
	for action in ["city","bag","journal","ledger","help","history","people","messages","promises"]:
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
		if page in ["help","history","ledger"] and key in [KEY_PAGEUP,KEY_PAGEDOWN]:
			view.scroll.scroll_vertical+=roundi(view.scroll.size.y*0.85)*(1 if key==KEY_PAGEDOWN else -1)
			get_viewport().set_input_as_handled()
			return
		if key>=KEY_1 and key<=KEY_9 or key in [KEY_Q,KEY_G,KEY_PAGEUP,KEY_PAGEDOWN,KEY_F5,KEY_F9]: activate_key(key)
		get_viewport().set_input_as_handled()

func activate_key(key: int) -> void:
	if page=="promises":
		if key==KEY_PAGEUP: game.promises.page+=1
		if key==KEY_PAGEDOWN: game.promises.page=maxi(0,game.promises.page-1)
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
		if key==KEY_Q: game.player.store_held()
		if key==KEY_G: game.player.release(false)
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
	if key==KEY_F5: game.save_game()
	if key==KEY_F9: game.load_game()
	game.hud.queue_redraw()
	if view: view.refresh.call_deferred()

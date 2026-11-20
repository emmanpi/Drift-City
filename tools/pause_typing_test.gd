extends SceneTree

## Vérifie la vraie saisie clavier dans le champ NPC : clic (focus), frappe
## de chiffres via Input, puis Entrée pour valider.

func _initialize() -> void:
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	game.set("npc_count", 16)
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 20:
		await physics_frame
	var pause: CanvasLayer = root.get_node("PauseMenu") as CanvasLayer
	var field: LineEdit = pause.get("_count_edit") as LineEdit
	var traffic: Node = root.get_node("Traffic")

	pause.call("show_menu")
	# "Clic" : le champ prend le focus et sélectionne la valeur courante.
	field.grab_focus()
	field.select_all()
	print("focus    : %s  texte=%s" % [str(field.has_focus()), field.text])

	# Frappe réelle de 4 puis 2.
	for code in [KEY_4, KEY_2]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = true
		ev.unicode = ("4" if code == KEY_4 else "2").unicode_at(0)
		Input.parse_input_event(ev)
		await process_frame
		var up := InputEventKey.new()
		up.physical_keycode = code
		up.keycode = code
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame
	print("frappe   : texte=%s" % field.text)

	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	print("entree   : Game=%d trafic=%d champ=%s focus=%s" % [
		int(game.get("npc_count")), (traffic.get("_cars") as Array).size(),
		field.text, str(field.has_focus())])

	# Échap pendant la saisie annule la modification et garde le menu ouvert.
	field.grab_focus()
	field.text = "99"
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	print("echap    : visible=%s champ=%s Game=%d focus=%s" % [
		str(pause.visible), field.text, int(game.get("npc_count")), str(field.has_focus())])
	quit()

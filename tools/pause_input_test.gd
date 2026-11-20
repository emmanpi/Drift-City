extends SceneTree

## Vérifie que la touche Échap ouvre puis ferme le menu pause.

func _initialize() -> void:
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 20:
		await physics_frame
	var pause: CanvasLayer = root.get_node("PauseMenu") as CanvasLayer

	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true

	# 1. Appel direct du gestionnaire : teste la logique ouvrir/fermer.
	pause.call("_unhandled_input", esc)
	print("esc1     : visible=%s paused=%s" % [str(pause.visible), str(paused)])
	pause.call("_unhandled_input", esc)
	print("esc2     : visible=%s paused=%s" % [str(pause.visible), str(paused)])

	# 2. Vrai événement injecté dans Input, comme une frappe clavier.
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	print("esc input: visible=%s paused=%s" % [str(pause.visible), str(paused)])

	var release := InputEventKey.new()
	release.physical_keycode = KEY_ESCAPE
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	print("esc input2: visible=%s paused=%s" % [str(pause.visible), str(paused)])
	quit()

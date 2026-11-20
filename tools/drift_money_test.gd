extends SceneTree

## Vérifie que le drift encaisse toujours de l'argent et que la bourse est
## sauvegardée, après le passage à `Game.add_money()`.

func _initialize() -> void:
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	var scene: PackedScene = load("res://tools/open_test.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 12:
		await physics_frame
	var car: CharacterBody3D = root.get_node("Car")
	var before := int(game.get("wallet"))

	Input.action_press("accelerate")
	for _i in 220:
		await physics_frame

	Input.action_press("handbrake")
	Input.action_press("steer_left")
	for _i in 300:
		await physics_frame
	Input.action_release("steer_left")
	Input.action_release("handbrake")
	for _i in 60:
		await physics_frame
	Input.action_release("accelerate")

	var earned := int(game.get("wallet")) - before
	print("drift     : %.1f m  bourse %d -> %d  gagné=%d" % [
		float(car.drift_meters), before, int(game.get("wallet")), earned])
	print("sauvegarde: %s" % String(game.get("save_path")))
	quit()

extends SceneTree

## Mesure le braquage réel : angle de cap parcouru en 2 s, sans et avec
## frein à main, pour vérifier que la voiture tourne bien plus qu'avant.

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

	for handbrake in [false, true]:
		car.reset_to_spawn()
		for _i in 10:
			await physics_frame
		Input.action_press("accelerate")
		for _i in 140:
			await physics_frame
		if handbrake:
			Input.action_press("handbrake")
		Input.action_press("steer_left")
		var start := car.rotation.y
		for _i in 120:
			await physics_frame
		var turned := rad_to_deg(absf(wrapf(car.rotation.y - start, -PI, PI)))
		print("%-10s : cap %.1f deg en 2 s, vitesse %.1f km/h" % [
			"frein main" if handbrake else "normal", turned,
			Vector2(car.velocity.x, car.velocity.z).length() * 3.6])
		Input.action_release("steer_left")
		if handbrake:
			Input.action_release("handbrake")
		Input.action_release("accelerate")
		for _i in 10:
			await physics_frame
	quit()

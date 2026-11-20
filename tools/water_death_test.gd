extends SceneTree

## La voiture peut rouler vers l'eau sans mur invisible. En entrant dans le
## port elle est ramenée au dernier point sur terre avec un petit message
## « WORLD LIMIT », sans écran de mort ni perte de la bourse.

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
	var car: CharacterBody3D = root.get_node("Car")
	var hud: CanvasLayer = root.get_node("HUD")
	var limit: Control = hud.get("_limit") as Control
	var traffic: Node = root.get_node("Traffic")
	traffic.set_physics_process(false)
	var wallet := int(game.get("wallet"))

	# 1. Depuis la côte est : aucun mur ne doit bloquer la voiture.
	car.global_position = Vector3(100.0, 0.02, 50.0)
	car.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	car.velocity = Vector3.ZERO
	await physics_frame
	Input.action_press("accelerate")
	for _i in 240:
		await physics_frame
	Input.action_release("accelerate")
	print("côte     : x=%.1f  z=%.1f" % [
		car.global_position.x, car.global_position.z])

	# 2. Retour au dernier point sur terre après être entré dans le port.
	car.reset_to_spawn()
	var last_land := Vector3(120.0, 0.02, 0.0)
	car.set("_last_land_position", last_land)
	car.set("_last_land_yaw", 0.0)
	car.global_position = Vector3(250.0, 0.02, 0.0)
	car.velocity = Vector3.ZERO
	for _i in 90:
		await physics_frame
	print("eau      : pos=(%.1f, %.2f, %.1f)  message=%s  bourse=%d" % [
		car.global_position.x, car.global_position.y, car.global_position.z,
		str(limit.visible), int(game.get("wallet"))])

	# 3. Le message se cache tout seul, la bourse reste intacte.
	for _i in 150:
		await physics_frame
	print("message  : visible=%s  bourse=%d" % [str(limit.visible), int(game.get("wallet"))])

	# 4. R ramène toujours au spawn.
	car.reset_to_spawn()
	await physics_frame
	print("reset    : pos=(%.1f, %.1f)  bourse=%d  wallet_avant=%d" % [
		car.global_position.x, car.global_position.z,
		int(game.get("wallet")), wallet])
	quit()

extends SceneTree

## Vérifie le garage : voiture verrouillée sans argent, achat réussi avec
## assez d'argent, et voiture débloquée ensuite.

func _initialize() -> void:
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	var scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Control = scene.instantiate()
	get_root().add_child(menu)
	for _i in 8:
		await process_frame

	var catalog = load("res://scripts/car_catalog.gd")
	var index: int = catalog.index_of_id("datsun240z")
	menu.set("_index", index)

	game.set("wallet", 0)
	game.set("owned", {"aveo": true})
	game.set("selected_car_id", "aveo")
	menu.call("_refresh")
	await process_frame
	menu.call("_start")
	print("sans argent : owns=%s wallet=%d notice=\"%s\"" % [
		str(game.call("owns", "datsun240z")), int(game.get("wallet")),
		String((menu.get("_notice") as Label).text)])

	game.set("wallet", 10000)
	menu.call("_refresh")
	await process_frame
	menu.call("_start")
	print("achat       : owns=%s wallet=%d selected=%s notice=\"%s\"" % [
		str(game.call("owns", "datsun240z")), int(game.get("wallet")),
		String(game.get("selected_car_id")), String((menu.get("_notice") as Label).text)])
	print("bouton      : \"%s\"  prix=\"%s\"" % [
		String((menu.get("_start_button") as Button).text),
		String((menu.get("_price_label") as Label).text)])
	quit()

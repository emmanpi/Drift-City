extends SceneTree

## Vérifie le menu pause : Esc/RESUME, MAIN MENU/QUIT présents, compteur NPC
## 0–100 appliqué en direct au trafic, saisie au clavier et sauvegarde.

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
	var traffic: Node = root.get_node("Traffic")
	var field: LineEdit = pause.get("_count_edit") as LineEdit

	pause.call("show_menu")
	print("pause    : visible=%s paused=%s souris=%d" % [
		str(pause.visible), str(paused), Input.mouse_mode])

	pause.call("_change_count", 1)
	await process_frame
	print("plus     : Game=%d trafic=%d champ=%s" % [
		int(game.get("npc_count")), (traffic.get("_cars") as Array).size(), field.text])

	# Descend jusqu'à 0, puis monte jusqu'à 100 : les bornes doivent tenir.
	for _i in 40:
		pause.call("_change_count", -1)
	await process_frame
	print("min      : Game=%d trafic=%d champ=%s moins_desactive=%s" % [
		int(game.get("npc_count")), (traffic.get("_cars") as Array).size(),
		field.text, str((pause.get("_minus") as Button).disabled)])
	for _i in 110:
		pause.call("_change_count", 1)
	await process_frame
	print("max      : Game=%d trafic=%d champ=%s plus_desactive=%s" % [
		int(game.get("npc_count")), (traffic.get("_cars") as Array).size(),
		field.text, str((pause.get("_plus") as Button).disabled)])

	# Saisie clavier : clic sur le champ, puis frappe de "42".
	field.grab_focus()
	field.text = "42"
	pause.call("_commit_count")
	await process_frame
	print("saisie   : Game=%d trafic=%d champ=%s focus=%s" % [
		int(game.get("npc_count")), (traffic.get("_cars") as Array).size(),
		field.text, str(field.has_focus())])

	# Valeurs invalides : texte libre et dépassement sont ramenés à la plage.
	field.text = "a7b3"
	pause.call("_commit_count")
	print("filtre   : Game=%d champ=%s" % [int(game.get("npc_count")), field.text])
	field.text = ""
	pause.call("_commit_count")
	print("vide     : Game=%d champ=%s" % [int(game.get("npc_count")), field.text])
	field.release_focus()

	# Retour à 16 et fermeture.
	game.call("set_npc_count", 16)
	traffic.call("set_count", 16)
	pause.call("_refresh")
	pause.call("hide_menu")
	print("retour   : visible=%s paused=%s trafic=%d save=%s" % [
		str(pause.visible), str(paused),
		(traffic.get("_cars") as Array).size(), String(game.get("save_path"))])
	# Valeur non standard pour vérifier le rechargement au lancement suivant.
	game.call("set_npc_count", 87)
	print("sauvegarde : npc=%d" % int(game.get("npc_count")))
	quit()

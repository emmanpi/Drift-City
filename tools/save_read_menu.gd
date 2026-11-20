extends SceneTree

## Ouvre le vrai menu (donc l'autoload Game initialisé) et affiche ce qui a
## été rechargé depuis user://progress.cfg.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Control = scene.instantiate()
	get_root().add_child(menu)
	for _i in 12:
		await process_frame
	var game: Node = get_root().get_node_or_null("Game")
	print("menu read : save=%s wallet_label=%s voiture=%s prix=%s npc=%d reflets=%s" % [
		String(game.get("save_path")),
		String((menu.get("_wallet_label") as Label).text),
		String((menu.get("_name_label") as Label).text),
		String((menu.get("_price_label") as Label).text),
		int(game.get("npc_count")), str(game.get("npc_reflections"))])
	quit()

extends SceneTree

## Vérifie que le HUD s'affiche en anglais et que le compteur FPS se met à jour.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 120:
		await process_frame
	var hud: CanvasLayer = root.get_node("HUD")
	print("fps       : %s" % String((hud.get("fps_label") as Label).text))
	print("frein     : %s" % String((hud.get("handbrake_label") as Label).text))
	print("voiture   : %s" % String((hud.get("car_label") as Label).text))
	print("argent    : %s" % String((hud.get("wallet_label") as Label).text))
	print("limite    : panneau=%s" % str((hud.get("_limit") as Control).visible))
	print("limites   : %d murs" % (root.get_node("MapWalls") as Node).get_child_count())
	quit()

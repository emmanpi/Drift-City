extends SceneTree

## Vérifie le réglage « NPC REFLECTIONS » du menu pause : matériaux PBR
## désactivés par défaut, réactivés en direct, puis sauvegardés.

func _initialize() -> void:
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	game.set("npc_reflections", false)
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 20:
		await physics_frame
	var pause: CanvasLayer = root.get_node("PauseMenu") as CanvasLayer
	var traffic: Node = root.get_node("Traffic")
	var button: Button = pause.get("_reflections_button") as Button
	var car: Node = (traffic.get("_cars") as Array)[0]
	var visual: Node = car.get_node("Visual")
	_find_mesh(visual, null)
	var mi: MeshInstance3D = _found

	pause.call("show_menu")
	var mat: StandardMaterial3D = mi.get_surface_override_material(0) as StandardMaterial3D
	print("defaut   : reglage=%s bouton=%s metallic=%s textures=%s" % [
		str(game.get("npc_reflections")), button.text,
		str(mat.metallic), str(mat.metallic_texture != null)])

	pause.call("_toggle_reflections")
	await process_frame
	mat = mi.get_surface_override_material(0) as StandardMaterial3D
	print("active   : reglage=%s bouton=%s metallic=%s textures=%s" % [
		str(game.get("npc_reflections")), button.text,
		str(mat.metallic), str(mat.metallic_texture != null)])

	pause.call("_toggle_reflections")
	await process_frame
	mat = mi.get_surface_override_material(0) as StandardMaterial3D
	print("desactive: reglage=%s bouton=%s metallic=%s textures=%s" % [
		str(game.get("npc_reflections")), button.text,
		str(mat.metallic), str(mat.metallic_texture != null)])

	game.call("set_npc_reflections", true)
	print("sauvegarde : npc_reflections=%s" % str(game.get("npc_reflections")))
	quit()


var _found: MeshInstance3D

func _find_mesh(node: Node, _ignored: MeshInstance3D) -> void:
	if _found != null:
		return
	if node is MeshInstance3D:
		_found = node
		return
	for child in node.get_children():
		_find_mesh(child, null)

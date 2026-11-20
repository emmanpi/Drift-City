extends SceneTree

## Vérifie que le menu tient dans la fenêtre et que les textes sont en anglais.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Control = scene.instantiate()
	get_root().add_child(menu)
	for _i in 12:
		await process_frame
	var center: CenterContainer = null
	for child in menu.get_children():
		if child is CenterContainer:
			center = child
			break
	var box := center.get_child(0) as VBoxContainer
	var viewport := get_root().get_visible_rect()
	print("fenêtre=%s  menu=%s" % [viewport.size, box.get_global_rect()])
	print("débordement bas=%s" % str(box.get_global_rect().end.y > viewport.size.y))
	print("titre=%s  bouton=%s  prix=%s" % [
		String((box.get_child(0) as Label).text),
		String((menu.get("_start_button") as Button).text),
		String((menu.get("_price_label") as Label).text)])
	print("indice=%s" % String((box.get_child(box.get_child_count() - 1) as Label).text))
	quit()

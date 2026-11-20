extends SceneTree

## Vérifie que chaque voiture du catalogue construit un vrai modèle (pas le
## cube de secours) et que la version compacte de la Skyline garde ses surfaces.

var _meshes := 0
var _surfaces := 0
var _names: Array[String] = []


func _initialize() -> void:
	for entry in CarCatalog.CARS:
		_meshes = 0
		_surfaces = 0
		_names = []
		var root: Node3D = CarModel.build(entry)
		_collect(root)
		var size: Vector3 = root.get_meta("size", Vector3.ZERO)
		print("%-10s meshes=%2d surfaces=%2d size=%s fallback=%s" % [
			String(entry.get("id", "?")), _meshes, _surfaces, str(size),
			str(_meshes == 1 and _names.is_empty())])
		if String(entry.get("id", "")) == "skyline":
			print("  surfaces: ", ", ".join(_names))
	quit()


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes += 1
		if node.mesh != null:
			_surfaces += node.mesh.get_surface_count()
			for i in node.mesh.get_surface_count():
				_names.append(node.mesh.surface_get_name(i))
	for child in node.get_children():
		_collect(child)

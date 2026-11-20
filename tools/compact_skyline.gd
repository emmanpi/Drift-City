extends SceneTree

## Convertit le modèle COLLADA de 148 Mo en scène binaire compacte, afin que
## la voiture Skyline puisse être versionnée sous la limite de 100 Mo de GitHub.
## Les matériaux PBR sont reappliqués par car_model.gd à partir des noms de
## surfaces, donc la scène n'a besoin que de la géométrie.

const SRC := "res://assets/cars/skyline/model/model.dae"
const DST := "res://assets/cars/skyline/model/skyline_compact.scn"


var _meshes := 0
var _surfaces := 0


func _initialize() -> void:
	var scene: PackedScene = load(SRC)
	if scene == null:
		push_error("Impossible de charger " + SRC)
		quit(1)
		return
	var root: Node = scene.instantiate()
	_count(root)
	print("import: %d mesh(es), %d surface(s)" % [_meshes, _surfaces])
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack a échoué: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, DST)
	print("save %s -> err=%d" % [DST, err])
	quit(err)


func _count(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes += 1
		if node.mesh != null:
			_surfaces += node.mesh.get_surface_count()
	for child in node.get_children():
		_count(child)

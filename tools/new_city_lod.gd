extends SceneTree

const SCENE := "res://low-poly-city/source/Untitled.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	var names := []
	var lod := {}
	var tree_names := []
	var xf_identity := 0
	var xf_other := 0
	_scan(root, names, lod, tree_names, self)
	root.free()
	print("objets=%d  avec 'Lod_' dans le nom=%d" % [names.size(), lod.size() > 0 if false else _count_lod(names)])
	print("--- exemples de noms avec Lod ---")
	var shown := 0
	for n in names:
		if n.contains("Lod") and shown < 8:
			print("  " + n)
			shown += 1
	print("--- 12 noms d'arbres ---")
	for i in mini(12, tree_names.size()):
		print("  " + tree_names[i])
	quit()

func _count_lod(names: Array) -> int:
	var c := 0
	for n in names:
		if n.contains("Lod"):
			c += 1
	return c

func _scan(node: Node, names: Array, lod: Dictionary, tree_names: Array, self_ref: SceneTree) -> void:
	if node is MeshInstance3D:
		names.append(String(node.name))
		if String(node.name).contains("Tree"):
			tree_names.append(String(node.name))
	for c in node.get_children():
		_scan(c, names, lod, tree_names, self_ref)

extends SceneTree

const SCENE := "res://low-poly-city/source/Untitled.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	var groups := {}
	var tri_groups := {}
	var identity := 0
	var moved := 0
	_scan(root, groups, tri_groups)
	root.free()
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a] > groups[b])
	print("--- familles d'objets (par nombre) ---")
	for k in keys:
		print("  %-26s %5d objets  %8d tris" % [k, groups[k], tri_groups[k]])
	quit()

func _scan(node: Node, groups: Dictionary, tri_groups: Dictionary) -> void:
	if node is Node3D and not (node is MeshInstance3D):
		if node.transform != Transform3D.IDENTITY:
			pass
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var n := mi.name
			var key := "autre"
			for prefix in ["Container Ship", "Building", "Tree", "S1 Tree", "Road", "Car", "Street", "Lamp", "Bench"]:
				if n.begins_with(prefix):
					key = prefix
					break
			var tris := 0
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				tris += (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
			groups[key] = groups.get(key, 0) + 1
			tri_groups[key] = tri_groups.get(key, 0) + tris
	for c in node.get_children():
		_scan(c, groups, tri_groups)

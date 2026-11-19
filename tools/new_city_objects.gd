extends SceneTree

## Structure de la nouvelle map : taille des objets, noms, et répartition des
## triangles, pour décider comment fusionner et comment construire la collision.

const SCENE := "res://low-poly-city/source/Untitled.glb"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	var items := []
	_scan(root, Transform3D.IDENTITY, items)
	root.free()
	items.sort_custom(func(a, b): return a["tris"] > b["tris"])
	print("objets : %d" % items.size())
	print("--- 12 plus gros objets ---")
	for i in mini(12, items.size()):
		var it: Dictionary = items[i]
		print("  %-28s tris=%6d  taille=(%.1f, %.1f, %.1f)  pos=(%.0f, %.0f, %.0f)" % [
			it["name"], it["tris"], it["size"].x, it["size"].y, it["size"].z,
			it["pos"].x, it["pos"].y, it["pos"].z])
	var buckets := {}
	for it in items:
		var b: int = it["tris"] / 1000
		buckets[b] = buckets.get(b, 0) + 1
	print("--- répartition (milliers de triangles -> nb objets) ---")
	var keys := buckets.keys()
	keys.sort()
	for k in keys:
		print("  %4d-%4d k : %d objets" % [k, k + 1, buckets[k]])
	quit()


func _scan(node: Node, parent_xf: Transform3D, items: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var tris := 0
			var box := AABB()
			var first := true
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
				for p in v:
					var w := xf * p
					if first:
						box = AABB(w, Vector3.ZERO)
						first = false
					box = box.expand(w)
			items.append({
				"name": mi.name,
				"tris": tris,
				"size": box.size,
				"pos": box.get_center(),
			})
	for c in node.get_children():
		_scan(c, xf, items)

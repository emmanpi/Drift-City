extends SceneTree

const SCENE := "res://low-poly-city/source/Untitled.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	var groups := {}
	_scan(root, groups)
	root.free()
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a]["tris"] > groups[b]["tris"])
	for k in keys:
		var d: Dictionary = groups[k]
		if d["tris"] > 2000:
			print("%-34s tris=%7d  y=[%.1f, %.1f]  x=[%.0f, %.0f] z=[%.0f, %.0f]" % [
				k, d["tris"], d["ymin"], d["ymax"], d["xmin"], d["xmax"], d["zmin"], d["zmax"]])
	quit()

func _scan(node: Node, groups: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var n := String(mi.name)
			var prefix := n.substr(0, mini(n.length(), 30))
			var box := AABB()
			var first := true
			var tris := 0
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
				for p in v:
					if first:
						box = AABB(p, Vector3.ZERO)
						first = false
					box = box.expand(p)
			if not groups.has(prefix):
				groups[prefix] = {"tris": 0, "ymin": 1e9, "ymax": -1e9,
					"xmin": 1e9, "xmax": -1e9, "zmin": 1e9, "zmax": -1e9}
			var d: Dictionary = groups[prefix]
			d["tris"] += tris
			d["ymin"] = minf(d["ymin"], box.position.y)
			d["ymax"] = maxf(d["ymax"], box.position.y + box.size.y)
			d["xmin"] = minf(d["xmin"], box.position.x)
			d["xmax"] = maxf(d["xmax"], box.position.x + box.size.x)
			d["zmin"] = minf(d["zmin"], box.position.z)
			d["zmax"] = maxf(d["zmax"], box.position.z + box.size.z)
	for c in node.get_children():
		_scan(c, groups)

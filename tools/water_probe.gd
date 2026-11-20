extends SceneTree

## Repère les surfaces d'eau et les objets du port dans la map source, avec
## leurs limites ramenées dans les coordonnées de la ville cuite.

const SRC := "res://low-poly-city/source/Untitled.glb"

var world_aabb := AABB()
var has := false
var hits: Array = []

func _initialize() -> void:
	var packed: PackedScene = load(SRC)
	var root := packed.instantiate()
	_scan(root, Transform3D.IDENTITY)
	root.free()
	var off := Vector3(-(world_aabb.position.x + world_aabb.size.x * 0.5), 0.0,
		-(world_aabb.position.z + world_aabb.size.z * 0.5))
	print("MONDE source pos=%s size=%s  offset=%s" % [world_aabb.position, world_aabb.size, off])
	var interesting: Array = []
	for h in hits:
		var nm: String = String(h["name"]).to_lower()
		var b: AABB = h["box"]
		var flat: bool = b.size.y < 1.0 and b.size.x > 20.0 and b.size.z > 20.0
		if nm.contains("water") or nm.contains("sea") or nm.contains("ocean") \
				or nm.contains("river") or nm.contains("lake") or nm.contains("harbor") \
				or nm.contains("dock") or nm.contains("pier") or nm.contains("quai") \
				or nm.contains("port") or flat:
			interesting.append(h)
	interesting.sort_custom(func(a, b): return float(a["box"].size.y) < float(b["box"].size.y))
	for h in interesting:
		var b: AABB = h["box"]
		b.position += off
		print("%-44s tris=%6d  x=[%7.1f,%7.1f] y=[%6.1f,%6.1f] z=[%7.1f,%7.1f]" % [
			h["name"], h["tris"], b.position.x, b.end.x, b.position.y, b.end.y,
			b.position.z, b.end.z])
	quit()


func _scan(node: Node, xf: Transform3D) -> void:
	var x := xf
	if node is Node3D:
		x = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var box := AABB()
			var first := true
			var tris := 0
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
				for p in v:
					var wp := x * p
					if first:
						box = AABB(wp, Vector3.ZERO)
						first = false
					else:
						box = box.expand(wp)
					if has:
						world_aabb = world_aabb.expand(wp)
					else:
						world_aabb = AABB(wp, Vector3.ZERO)
						has = true
			if not first:
				hits.append({"name": String(mi.name), "box": box, "tris": tris})
	for c in node.get_children():
		_scan(c, x)

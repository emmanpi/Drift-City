extends SceneTree

const DIR := "res://npc_cars"

var _first := true
var _box := AABB()

func _initialize() -> void:
	var d := DirAccess.open(DIR)
	for f in d.get_files():
		if not f.ends_with(".tscn"):
			continue
		var p: PackedScene = load(DIR + "/" + f)
		var r := p.instantiate()
		_first = true
		_box = AABB()
		_walk(r, Transform3D.IDENTITY)
		print("%-24s taille=(%.2f, %.2f, %.2f)  minY=%.3f" % [
			f, _box.size.x, _box.size.y, _box.size.z, _box.position.y])
		r.free()
	quit()

func _walk(node: Node, parent: Transform3D) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		for s in (node as MeshInstance3D).mesh.get_surface_count():
			var a: Array = (node as MeshInstance3D).mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for p in v:
				var w := xf * p
				if _first:
					_box = AABB(w, Vector3.ZERO)
					_first = false
				_box = _box.expand(w)
	for c in node.get_children():
		_walk(c, xf)

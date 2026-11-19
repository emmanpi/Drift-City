extends SceneTree

## Liste les mesh Road_* du GLB source avec leur boîte en monde, pour vérifier
## que les points de passage du bake tombent bien sur la chaussée.

const SRC := "res://low-poly-city/source/Untitled.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SRC)
	var root := packed.instantiate()
	_collect(root, Transform3D.IDENTITY)
	root.free()
	quit()


func _collect(node: Node, parent_xf: Transform3D) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var name := String(mi.name)
		if name.begins_with("Road_"):
			var box := _box(mi, xf)
			print("ROAD %-28s centre=(%7.1f,%5.1f,%7.1f) taille=(%6.1f,%5.1f,%6.1f)" % [
				name, box.get_center().x, box.get_center().y, box.get_center().z,
				box.size.x, box.size.y, box.size.z])
	for c in node.get_children():
		_collect(c, xf)


func _box(mi: MeshInstance3D, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for s in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for p in v:
			var w := xf * p
			if first:
				box = AABB(w, Vector3.ZERO)
				first = false
			box = box.expand(w)
	return box

extends SceneTree

const SCENE := "res://generic_passenger_car_pack.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	get_root().add_child(root)
	var root_node: Node = root
	while root_node.get_child_count() == 1:
		root_node = root_node.get_child(0)
	print("racine utile : ", root_node.name, "  transform=", (root_node as Node3D).transform)
	for c in root_node.get_children():
		if not (c is Node3D):
			continue
		var box := _box(c)
		var tris := _tris(c)
		print("%-22s tris=%5d size=(%6.2f,%6.2f,%6.2f) centre=(%7.2f,%6.2f,%7.2f)" % [
			c.name, tris, box.size.x, box.size.y, box.size.z,
			box.get_center().x, box.get_center().y, box.get_center().z])
	root.free()
	quit()


func _tris(node: Node) -> int:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return _mesh_tris(node as MeshInstance3D)
	var n := 0
	for c in node.get_children():
		n += _tris(c)
	return n


func _mesh_tris(mi: MeshInstance3D) -> int:
	var n := 0
	for s in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		n += (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
	return n


func _box(node: Node) -> AABB:
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var gx := (node as Node3D).global_transform
		for s in (node as MeshInstance3D).mesh.get_surface_count():
			var a: Array = (node as MeshInstance3D).mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for p in v:
				var w := gx * p
				if first:
					box = AABB(w, Vector3.ZERO)
					first = false
				box = box.expand(w)
	for c in node.get_children():
		var b := _box(c)
		if b.size == Vector3.ZERO:
			continue
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box

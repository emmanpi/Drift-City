extends SceneTree

## Inspecte le pack de voitures NPC : groupes, dimensions, orientation.

const SCENE := "res://generic_passenger_car_pack.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	get_root().add_child(root)
	print("--- hiérarchie (profondeur <= 3) ---")
	_walk(root, 0, 7)
	var groups := {}
	_groups(root, groups)
	print("--- groupes ---")
	for g in groups.keys():
		var d: Dictionary = groups[g]
		print("%-22s meshes=%2d  taille=(%.2f, %.2f, %.2f)" % [
			g, d["n"], d["size"].x, d["size"].y, d["size"].z])
	root.free()
	quit()


func _walk(node: Node, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	var line := "  ".repeat(depth) + node.name + " [" + node.get_class() + "]"
	if node is MeshInstance3D:
		line += "  tris=%d" % _tris(node as MeshInstance3D)
	print(line)
	for c in node.get_children():
		_walk(c, depth + 1, max_depth)


func _tris(mi: MeshInstance3D) -> int:
	if mi.mesh == null:
		return 0
	var n := 0
	for s in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		n += (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
	return n


func _groups(node: Node, groups: Dictionary) -> void:
	var is_group := false
	var g := ""
	var n := String(node.name)
	for key in ["Compact", "Coupe", "Hatchback", "minivan", "Offroad", "Sedan",
			"Sports", "SUV", "Van", "Wheel"]:
		if n.to_lower().begins_with(key.to_lower()):
			# Un groupe est un Node3D dont le nom est exactement le type.
			if n.to_lower() == key.to_lower():
				g = key
				is_group = true
			break
	if is_group:
		var box := _box(node)
		if not groups.has(g):
			groups[g] = {"n": 0, "size": box.size}
		groups[g]["n"] += 1
	for c in node.get_children():
		_groups(c, groups)


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

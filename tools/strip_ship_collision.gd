extends SceneTree

## Removes the cargo-ship collision from the baked city collision resource.
## The ships stay visible, but the invisible shoreline keeps the player away
## from them, so their huge hull hitboxes only cost performance.

const SRC := "res://low-poly-city/source/Untitled.glb"
const COLLISION := "res://low-poly-city/city_collision.res"

var world := AABB()
var has_world := false
var ships: Array = []

func _initialize() -> void:
	var packed: PackedScene = load(SRC)
	if packed == null:
		push_error("GLB introuvable : " + SRC)
		quit(1)
		return
	var root := packed.instantiate()
	_scan(root, Transform3D.IDENTITY)
	root.free()
	if ships.is_empty():
		push_error("Aucun cargo trouvé dans " + SRC)
		quit(1)
		return
	var offset := Vector3(-(world.position.x + world.size.x * 0.5), 0.0,
		-(world.position.z + world.size.z * 0.5))
	var boxes: Array = []
	for s in ships:
		var box: AABB = s
		box.position += offset
		box = box.grow(0.6)
		boxes.append(box)
	print("cargos : %d  offset=(%.3f, %.3f)" % [boxes.size(), offset.x, offset.z])

	var data: Resource = load(COLLISION)
	if data == null:
		push_error("Collision introuvable : " + COLLISION)
		quit(1)
		return
	var kept_chunks: Array = []
	var removed := 0
	var kept := 0
	for entry in data.chunks:
		var shape: ConcavePolygonShape3D = entry["shape"]
		if shape == null:
			continue
		var faces := shape.get_faces()
		var out := PackedVector3Array()
		var i := 0
		while i + 2 < faces.size():
			var c := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var inside := false
			for box in boxes:
				if (box as AABB).has_point(c):
					inside = true
					break
			if inside:
				removed += 1
			else:
				out.append(faces[i])
				out.append(faces[i + 1])
				out.append(faces[i + 2])
				kept += 1
			i += 3
		if out.is_empty():
			continue
		var new_shape := ConcavePolygonShape3D.new()
		new_shape.set_faces(out)
		new_shape.backface_collision = true
		kept_chunks.append({"shape": new_shape})

	var result: Resource = load("res://scripts/city_collision.gd").new()
	result.chunks = kept_chunks
	result.tree_positions = data.tree_positions
	result.tree_box_size = data.tree_box_size
	var err := ResourceSaver.save(result, COLLISION)
	print("collision : %d triangles gardés, %d retirés (cargos)  morceaux=%d  save=%d" % [
		kept, removed, kept_chunks.size(), err])
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
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				for p in v:
					var wp := x * p
					if first:
						box = AABB(wp, Vector3.ZERO)
						first = false
					else:
						box = box.expand(wp)
					if has_world:
						world = world.expand(wp)
					else:
						world = AABB(wp, Vector3.ZERO)
						has_world = true
			if not first:
				if String(mi.name).begins_with("Container Ship"):
					ships.append(box)
	for c in node.get_children():
		_scan(c, x)

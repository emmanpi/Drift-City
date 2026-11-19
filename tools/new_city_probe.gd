extends SceneTree

## Analyse de la nouvelle map `low-poly-city/source/Untitled.glb` :
## nombre de triangles, emprise, altitude du sol, empilement de plaques
## horizontales (z-fighting) et part de géométrie verticale (murs).

const SCENE := "res://low-poly-city/source/Untitled.glb"

var tris := 0
var horiz := 0
var vert := 0
var horiz_area := 0.0
var vert_area := 0.0
var layers := {}
var aabb := AABB()
var first := true
var materials := {}
var surfaces := 0
var meshes := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var packed: PackedScene = load(SCENE)
	if packed == null:
		print("impossible de charger ", SCENE)
		quit(1)
		return
	var root := packed.instantiate()
	_scan(root, Transform3D.IDENTITY)
	root.free()
	print("--- résumé ---")
	print("noeuds MeshInstance3D : %d   surfaces : %d" % [meshes, surfaces])
	print("triangles : %d   (horizontaux %d, verticaux %d)" % [tris, horiz, vert])
	print("emprise AABB : pos=%s taille=%s" % [aabb.position, aabb.size])
	print("surface horizontale cumulée : %.0f m²   verticale : %.0f m²" % [horiz_area, vert_area])
	print("matériaux : %d" % materials.size())
	for k in materials.keys():
		print("   %s" % k)
	print("--- altitude -> surface horizontale (top 12) ---")
	var keys := layers.keys()
	keys.sort_custom(func(a, b): return layers[a] > layers[b])
	for i in mini(12, keys.size()):
		print("   y=%7.1f : %10.0f m²" % [keys[i], layers[keys[i]]])
	print("analyse en %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func _scan(node: Node, parent_xf: Transform3D) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		_read(node as MeshInstance3D, xf)
	for c in node.get_children():
		_scan(c, xf)


func _read(mi: MeshInstance3D, xf: Transform3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	meshes += 1
	for s in mesh.get_surface_count():
		surfaces += 1
		var mat := mi.get_active_material(s)
		var key := "sans matériau"
		if mat != null:
			key = mat.resource_name
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
				key += "  [" + (mat as StandardMaterial3D).albedo_texture.resource_path.get_file() + "]"
		materials[key] = true
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if v == null or v.is_empty():
			continue
		var w := PackedVector3Array()
		w.resize(v.size())
		for i in v.size():
			w[i] = xf * v[i]
		var n := idx.size() / 3 if idx != null and idx.size() > 0 else v.size() / 3
		for k in n:
			var i0: int = idx[k * 3] if idx != null and idx.size() > 0 else k * 3
			var i1: int = idx[k * 3 + 1] if idx != null and idx.size() > 0 else k * 3 + 1
			var i2: int = idx[k * 3 + 2] if idx != null and idx.size() > 0 else k * 3 + 2
			var p0 := w[i0]
			var p1 := w[i1]
			var p2 := w[i2]
			var c := (p1 - p0).cross(p2 - p0)
			var area := c.length() * 0.5
			if area < 0.00001:
				continue
			tris += 1
			if first:
				aabb = AABB(p0, Vector3.ZERO)
				first = false
			aabb = aabb.expand(p0)
			aabb = aabb.expand(p1)
			aabb = aabb.expand(p2)
			var ny := absf(c.normalized().y)
			if ny >= 0.7:
				horiz += 1
				horiz_area += area
				var y := snappedf((p0.y + p1.y + p2.y) / 3.0, 0.5)
				layers[y] = layers.get(y, 0.0) + area
			else:
				vert += 1
				vert_area += area

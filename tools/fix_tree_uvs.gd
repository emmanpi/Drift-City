extends SceneTree

## Répare les arbres « arc-en-ciel » de la ville cuite.
##
## La texture « Color » est une palette : chaque triangle d'origine pioche une
## seule case (ses 3 UV sont identiques). La décimation des arbres fusionnait
## les sommets par position seulement, si bien qu'un triangle pouvait recevoir
## des UV de cases différentes et s'étirer sur toute la palette.
## Ici, chaque triangle proche d'un arbre (positions de `city_collision.res`)
## dont les UV s'écartent de plus de 1/32 reçoit l'UV majoritaire de ses
## sommets (sommets dupliqués pour ne pas toucher aux voisins). Ailleurs, les
## écarts sont des dégradés voulus (vitres…) et restent tels quels.
##
## Usage : Godot --headless --path . --script res://tools/fix_tree_uvs.gd

const SCENE := "res://low-poly-city/city.tscn"
const PALETTE_MATERIAL := "Color"
const MAX_SPAN := 1.0 / 32.0
const COLLISION := "res://low-poly-city/city_collision.res"
## Rayon horizontal autour d'un tronc dans lequel un triangle compte comme arbre.
const TREE_RADIUS := 4.5

var _trees := {}
var _skipped := 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	for p in (load(COLLISION) as Resource).get("tree_positions"):
		var key := Vector2i(floori(p.x / TREE_RADIUS), floori(p.z / TREE_RADIUS))
		if not _trees.has(key):
			_trees[key] = PackedVector2Array()
		_trees[key].append(Vector2(p.x, p.z))
	var fixed := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		fixed += _fix_mesh(mi as MeshInstance3D)
	print("triangles recolorés : %d (hors arbres, laissés : %d)" % [fixed, _skipped])
	var out := PackedScene.new()
	out.pack(root)
	print("sauvegarde : ", error_string(ResourceSaver.save(out, SCENE)))
	root.free()
	quit()


func _fix_mesh(mi: MeshInstance3D) -> int:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return 0
	var dst := ArrayMesh.new()
	dst.resource_name = src.resource_name
	var fixed := 0
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var mat := src.surface_get_material(s)
		if mat != null and mat.resource_name == PALETTE_MATERIAL:
			fixed += _fix_surface(arrays, _to_root(mi, root))
		dst.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays)
		dst.surface_set_material(s, mat)
		dst.surface_set_name(s, src.surface_get_name(s))
	mi.mesh = dst
	return fixed


func _to_root(node: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _near_tree(p: Vector3) -> bool:
	var cx := floori(p.x / TREE_RADIUS)
	var cz := floori(p.z / TREE_RADIUS)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for t in _trees.get(Vector2i(cx + dx, cz + dz), PackedVector2Array()):
				if t.distance_to(Vector2(p.x, p.z)) <= TREE_RADIUS:
					return true
	return false


func _fix_surface(arrays: Array, xf: Transform3D) -> int:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tan: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if uv.is_empty() or idx.is_empty():
		return 0
	# Seuls sommet, normale, tangente, UV et index sont gérés : on refuse le reste.
	for t in Mesh.ARRAY_MAX:
		if t in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			continue
		if arrays[t] != null:
			push_warning("attribut %d non géré, surface ignorée" % t)
			return 0
	var fixed := 0
	for k in idx.size() / 3:
		var ids := [idx[k * 3], idx[k * 3 + 1], idx[k * 3 + 2]]
		var u := [uv[ids[0]], uv[ids[1]], uv[ids[2]]]
		var span := 0.0
		for a in 3:
			for b in 3:
				span = maxf(span, maxf(absf(u[a].x - u[b].x), absf(u[a].y - u[b].y)))
		if span < MAX_SPAN:
			continue
		if not _near_tree(xf * ((v[ids[0]] + v[ids[1]] + v[ids[2]]) / 3.0)):
			_skipped += 1
			continue
		var pick: Vector2 = u[0]
		if _same_cell(u[1], u[2]):
			pick = u[1]
		for c in 3:
			var i: int = ids[c]
			idx[k * 3 + c] = v.size()
			v.append(v[i])
			if not n.is_empty():
				n.append(n[i])
			if not tan.is_empty():
				for e in 4:
					tan.append(tan[i * 4 + e])
			uv.append(pick)
		fixed += 1
	arrays[Mesh.ARRAY_VERTEX] = v
	if not n.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = n
	if not tan.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = tan
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	return fixed


func _same_cell(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) < MAX_SPAN and absf(a.y - b.y) < MAX_SPAN

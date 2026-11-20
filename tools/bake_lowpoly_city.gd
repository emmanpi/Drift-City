extends SceneTree

## Intègre la nouvelle ville `low-poly-city/source/Untitled.glb` :
##
##  1. fusionne les 1 930 objets par cellule de 100 m et par matériau : 3
##     surfaces par cellule, ce qui permet au moteur d'éliminer par frustum
##     les cellules hors écran (un mesh unique de 1 M triangles était toujours
##     dessiné en entier) ;
##  2. décime les arbres (clustering de sommets) : ils pèsent 26 % des
##     triangles pour 302 objets ;
##  3. construit une collision **exacte par morceaux** de 60 m : chaque triangle
##     d'objet non-routier est conservé tel quel, les arbres reçoivent une boîte
##     simple autour du tronc ;
##  4. recentre la map sur l'origine en X/Z et cherche un point de spawn dégagé.

const SRC := "res://low-poly-city/source/Untitled.glb"
const OUT_SCENE := "res://low-poly-city/city.tscn"
const OUT_COL := "res://low-poly-city/city_collision.res"
const OUT_GROUND := "res://low-poly-city/city_ground.res"
const OUT_ROADS := "res://low-poly-city/city_roads.res"

## Véhiculesstatiques de la map, supprimés : ils seront remplacés par des
## voitures NPC issues de generic_passenger_car_pack.glb.
const REMOVED := [
	"N_Suv", "N_Muscle Car", "N_Simple Car", "Sport Car", "School Bus",
	"Ambulance Car", "Pick Up", "Sedan Car", "Police Car N",
	"Hatchback Car", "Especial Car", "Military Vehicle", "Truck",
	"Classic Car", "Bus_",
]

## Taille des cellules de clustering pour les arbres (mètres).
const TREE_CELL := 0.18
## Taille des cellules de rendu (frustum culling par cellule).
const VIS_CHUNK := 100.0
## Taille des morceaux de collision (mètres).
const CHUNK := 60.0
## Rayon de la boîte de collision d'un arbre.
const TRUNK_RADIUS := 0.5
const TRUNK_HEIGHT := 4.0

var buckets := {}
var mat_by_key := {}
var col_faces := {}
var ground_faces := {}
var road_points := PackedVector3Array()
var tree_boxes := []
var aabb := AABB()
var has_aabb := false
var tris_before := 0
var tris_after := 0
var tree_tris_before := 0
var tree_tris_after := 0
var objects := 0
var road_objects := 0
var cell_surfaces := 0
var cell_count := 0
var removed_objects := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var packed: PackedScene = load(SRC)
	if packed == null:
		push_error("GLB introuvable : " + SRC)
		quit(1)
		return
	var root := packed.instantiate()
	_collect(root, Transform3D.IDENTITY)
	root.free()

	# Recentrage en X/Z sur l'origine.
	var offset := Vector3(-(aabb.position.x + aabb.size.x * 0.5), 0.0,
		-(aabb.position.z + aabb.size.z * 0.5))
	_shift(offset)

	var city := _build_scene()
	var packed_city := PackedScene.new()
	packed_city.pack(city)
	var err := ResourceSaver.save(packed_city, OUT_SCENE)
	city.free()
	print("mesh : %d cellules, %d surfaces, %d triangles  save=%d" % [
		cell_surfaces, cell_count, tris_after, err])

	var col := _build_collision(offset)
	ResourceSaver.save(col, OUT_COL)

	var ground := _build_ground(offset)
	ResourceSaver.save(ground, OUT_GROUND)

	var roads: Resource = load("res://scripts/city_roads.gd").new()
	for p in road_points:
		roads.points.append(p + offset)
	ResourceSaver.save(roads, OUT_ROADS)

	print("routes : %d points de passage" % roads.points.size())
	print("objets=%d  routes=%d  véhicules retirés=%d" % [objects, road_objects, removed_objects])
	print("sol : %d morceaux" % ground.chunks.size())
	print("triangles : %d -> %d  (arbres %d -> %d)" % [
		tris_before, tris_after, tree_tris_before, tree_tris_after])
	print("collision : %d morceaux, %d arbres" % [col.chunks.size(), col.tree_positions.size()])
	_find_spawn()
	print("bake terminé en %d ms" % (Time.get_ticks_msec() - t0))
	quit()


# ---------------------------------------------------------------- collecte

func _collect(node: Node, parent_xf: Transform3D) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		_read(node as MeshInstance3D, xf)
	for c in node.get_children():
		_collect(c, xf)


func _read(mi: MeshInstance3D, xf: Transform3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	objects += 1
	var name := String(mi.name)
	var is_tree := name.contains("Tree")
	var is_road := name.begins_with("Road_")
	# Les cargos restent visuels : le joueur ne peut plus les atteindre grâce
	# aux bordures du port, et leurs grosses coques n'ont plus de collision.
	var is_ship := name.begins_with("Container Ship")
	var is_ground := name.begins_with("Road_") or name.begins_with("City Ground_") \
		or name.begins_with("Grass_") or name.begins_with("House Road_")
	# Voitures et véhicules statiques retirés : remplacés par les NPC.
	for p in REMOVED:
		if name.begins_with(p):
			removed_objects += 1
			return
	if is_road:
		road_objects += 1
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if v == null or v.is_empty():
			continue
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var n_tris: int = (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
		tris_before += n_tris
		if is_tree:
			tree_tris_before += n_tris
			arrays = _cluster(arrays, TREE_CELL)
			v = arrays[Mesh.ARRAY_VERTEX]
			idx = arrays[Mesh.ARRAY_INDEX]
			n_tris = idx.size() / 3
			tree_tris_after += n_tris
		tris_after += n_tris

		var verts := _apply(v, xf)
		var normals := PackedVector3Array()
		var has_normals := false
		var nsrc = arrays[Mesh.ARRAY_NORMAL]
		if nsrc != null and nsrc.size() == v.size():
			normals = _apply_rot(nsrc, xf)
			# Normales du GLB conservées telles quelles : elles respectent la
			# convention de Godot (face avant = sens horaire). Les retourner
			# éclairait la ville par en dessous (voir tools/fix_city_normals.gd).
			has_normals = true
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

		var mat := mi.get_active_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		# Une cellule de rendu par zone de 100 m : le moteur pourra éliminer
		# celles qui sont hors du champ de vision.
		var centre_obj := _box_of(verts).get_center()
		var key := "%d_%d|%s" % [
			int(floor(centre_obj.x / VIS_CHUNK)), int(floor(centre_obj.z / VIS_CHUNK)), _mat_key(mat)]
		if not buckets.has(key):
			buckets[key] = {
				"v": PackedVector3Array(), "n": PackedVector3Array(),
				"t": PackedVector2Array(), "i": PackedInt32Array(),
			}
			mat_by_key[key] = mat
		var b: Dictionary = buckets[key]
		var base: int = b["v"].size()
		b["v"].append_array(verts)
		if has_normals:
			b["n"].append_array(normals)
		else:
			var pad := PackedVector3Array()
			pad.resize(verts.size())
			pad.fill(Vector3.UP)
			b["n"].append_array(pad)
		if uvs != null and uvs.size() == v.size():
			b["t"].append_array(uvs)
		else:
			var padt := PackedVector2Array()
			padt.resize(verts.size())
			b["t"].append_array(padt)
		var out_idx := PackedInt32Array()
		out_idx.resize(idx.size())
		for i in idx.size():
			out_idx[i] = base + idx[i]
		b["i"].append_array(out_idx)

		for p in verts:
			if has_aabb:
				aabb = aabb.expand(p)
			else:
				aabb = AABB(p, Vector3.ZERO)
				has_aabb = true

		if is_road:
			# Points de passage pour les voitures NPC : centre et extrémités
			# du segment de route.
			var rb := _box_of(verts)
			var rc := rb.get_center()
			var rh := rb.size * 0.5
			if rh.x > rh.z:
				road_points.append(Vector3(rc.x - rh.x, 0.02, rc.z))
				road_points.append(Vector3(rc.x + rh.x, 0.02, rc.z))
			else:
				road_points.append(Vector3(rc.x, 0.02, rc.z - rh.z))
				road_points.append(Vector3(rc.x, 0.02, rc.z + rh.z))

		if is_tree:
			var box := _box_of(verts)
			var c := box.get_center()
			tree_boxes.append([
				Vector3(c.x, box.position.y + TRUNK_HEIGHT * 0.5, c.z),
				Vector3(TRUNK_RADIUS * 2.0, TRUNK_HEIGHT, TRUNK_RADIUS * 2.0),
			])
		else:
			if not is_ground and not is_ship:
				_add_collision(verts, idx)
			if is_ground:
				_add_ground(verts, idx)


func _apply(v: PackedVector3Array, xf: Transform3D) -> PackedVector3Array:
	if xf == Transform3D.IDENTITY:
		return v
	var out := PackedVector3Array()
	out.resize(v.size())
	for i in v.size():
		out[i] = xf * v[i]
	return out


func _apply_rot(v: PackedVector3Array, xf: Transform3D) -> PackedVector3Array:
	if xf == Transform3D.IDENTITY:
		return v
	var out := PackedVector3Array()
	out.resize(v.size())
	for i in v.size():
		out[i] = (xf.basis * v[i]).normalized()
	return out


func _box_of(v: PackedVector3Array) -> AABB:
	var box := AABB(v[0], Vector3.ZERO)
	for i in range(1, v.size()):
		box = box.expand(v[i])
	return box


func _mat_key(mat: Material) -> String:
	if mat == null:
		return "sans_materiau"
	if mat.resource_name != "":
		return mat.resource_name
	if mat.resource_path != "":
		return mat.resource_path
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		var tex := ""
		if sm.albedo_texture != null:
			tex = sm.albedo_texture.resource_path
		return "std_%s_%s" % [sm.albedo_color.to_html(), tex]
	return mat.get_class()


# ------------------------------------------------------------ décimation

## Regroupe les sommets par cellule et jette les triangles dégénérés.
## On garde la première position de chaque cellule (pas de moyenne) pour que
## la surface ne se rétracte pas.
func _cluster(arrays: Array, cell: float) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nrm = arrays[Mesh.ARRAY_NORMAL]
	var uv = arrays[Mesh.ARRAY_TEX_UV]
	var remap := PackedInt32Array()
	remap.resize(v.size())
	var cells := {}
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nt := PackedVector2Array()
	for i in v.size():
		var p := v[i]
		var key := Vector3i(
			int(floor(p.x / cell)), int(floor(p.y / cell)), int(floor(p.z / cell)))
		var j: int = cells.get(key, -1)
		if j < 0:
			j = nv.size()
			cells[key] = j
			nv.append(p)
			nn.append(nrm[i] if nrm != null and nrm.size() > i else Vector3.UP)
			nt.append(uv[i] if uv != null and uv.size() > i else Vector2.ZERO)
		remap[i] = j
	var ni := PackedInt32Array()
	var count: int = (idx.size() / 3) if idx != null and idx.size() > 0 else v.size() / 3
	for k in count:
		var i0: int = idx[k * 3] if idx != null and idx.size() > 0 else k * 3
		var i1: int = idx[k * 3 + 1] if idx != null and idx.size() > 0 else k * 3 + 1
		var i2: int = idx[k * 3 + 2] if idx != null and idx.size() > 0 else k * 3 + 2
		var a := remap[i0]
		var b := remap[i1]
		var c := remap[i2]
		if a == b or b == c or a == c:
			continue
		ni.append(a)
		ni.append(b)
		ni.append(c)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_NORMAL] = nn
	out[Mesh.ARRAY_TEX_UV] = nt
	out[Mesh.ARRAY_INDEX] = ni
	return out


# -------------------------------------------------------------- assemblage

func _build_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "CityChunks"
	var meshes := {}
	var keys := buckets.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = buckets[key]
		if b["i"].is_empty():
			continue
		var cell: String = String(key).substr(0, String(key).find("|"))
		if not meshes.has(cell):
			meshes[cell] = ArrayMesh.new()
		var out: ArrayMesh = meshes[cell]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b["v"]
		arrays[Mesh.ARRAY_NORMAL] = b["n"]
		arrays[Mesh.ARRAY_TEX_UV] = b["t"]
		arrays[Mesh.ARRAY_INDEX] = b["i"]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var s := out.get_surface_count() - 1
		out.surface_set_name(s, key)
		out.surface_set_material(s, mat_by_key[key])
		cell_surfaces += 1
	for cell in meshes.keys():
		var mi := MeshInstance3D.new()
		mi.name = "Chunk_" + cell.replace("_", "-")
		mi.mesh = meshes[cell]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.owner = root
		cell_count += 1
	return root


func _shift(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	for key in buckets.keys():
		var b: Dictionary = buckets[key]
		var v: PackedVector3Array = b["v"]
		for i in v.size():
			v[i] += offset
		b["v"] = v
	aabb.position += offset


func _add_collision(verts: PackedVector3Array, idx: PackedInt32Array) -> void:
	var count: int = (idx.size() / 3) if idx != null and idx.size() > 0 else verts.size() / 3
	for k in count:
		var i0: int = idx[k * 3] if idx != null and idx.size() > 0 else k * 3
		var i1: int = idx[k * 3 + 1] if idx != null and idx.size() > 0 else k * 3 + 1
		var i2: int = idx[k * 3 + 2] if idx != null and idx.size() > 0 else k * 3 + 2
		var a := verts[i0]
		var b := verts[i1]
		var c := verts[i2]
		var cx := (a.x + b.x + c.x) / 3.0
		var cz := (a.z + b.z + c.z) / 3.0
		var key := Vector2i(int(floor(cx / CHUNK)), int(floor(cz / CHUNK)))
		if not col_faces.has(key):
			col_faces[key] = PackedVector3Array()
		var arr: PackedVector3Array = col_faces[key]
		arr.append(a)
		arr.append(b)
		arr.append(c)
		col_faces[key] = arr


## Seules les faces horizontales hautes (routes, trottoirs, pelouses) servent
## de sol pour la physique en Y. Elles sont stockées dans un calque distinct
## (layer 4) : la voiture les sonde par raycast, elle ne glisse pas dessus.
func _add_ground(verts: PackedVector3Array, idx: PackedInt32Array) -> void:
	var count: int = (idx.size() / 3) if idx != null and idx.size() > 0 else verts.size() / 3
	for k in count:
		var i0: int = idx[k * 3] if idx != null and idx.size() > 0 else k * 3
		var i1: int = idx[k * 3 + 1] if idx != null and idx.size() > 0 else k * 3 + 1
		var i2: int = idx[k * 3 + 2] if idx != null and idx.size() > 0 else k * 3 + 2
		var a := verts[i0]
		var b := verts[i1]
		var c := verts[i2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-6:
			continue
		if absf(n.normalized().y) < 0.6:
			continue
		var y := (a.y + b.y + c.y) / 3.0
		if y < -0.3 or y > 2.5:
			continue
		var cx := (a.x + b.x + c.x) / 3.0
		var cz := (a.z + b.z + c.z) / 3.0
		var key := Vector2i(int(floor(cx / CHUNK)), int(floor(cz / CHUNK)))
		if not ground_faces.has(key):
			ground_faces[key] = PackedVector3Array()
		var arr: PackedVector3Array = ground_faces[key]
		arr.append(a)
		arr.append(b)
		arr.append(c)
		ground_faces[key] = arr


func _build_ground(offset: Vector3) -> Resource:
	var col: Resource = load("res://scripts/city_ground.gd").new()
	var chunks := []
	var keys := ground_faces.keys()
	keys.sort()
	for key in keys:
		var faces: PackedVector3Array = ground_faces[key]
		if offset != Vector3.ZERO:
			for i in faces.size():
				faces[i] += offset
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		chunks.append({"shape": shape})
	col.chunks = chunks
	return col


func _build_collision(offset: Vector3) -> Resource:
	var col: Resource = load("res://scripts/city_collision.gd").new()
	var chunks := []
	var keys := col_faces.keys()
	keys.sort()
	for key in keys:
		var faces: PackedVector3Array = col_faces[key]
		if offset != Vector3.ZERO:
			for i in faces.size():
				faces[i] += offset
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		chunks.append({"shape": shape})
	col.chunks = chunks
	var positions := PackedVector3Array()
	for e in tree_boxes:
		positions.append(e[0] + offset)
	col.tree_positions = positions
	col.tree_box_size = Vector3(TRUNK_RADIUS * 2.0, TRUNK_HEIGHT, TRUNK_RADIUS * 2.0)
	return col


# ------------------------------------------------------------------ spawn

func _find_spawn() -> void:
	var cell := 2.0
	var pad := 10.0
	var minx := aabb.position.x - pad
	var minz := aabb.position.z - pad
	var w := int(ceil((aabb.size.x + pad * 2.0) / cell))
	var h := int(ceil((aabb.size.z + pad * 2.0) / cell))
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	blocked.fill(0)
	for key in col_faces.keys():
		var faces: PackedVector3Array = col_faces[key]
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			if maxf(a.y, maxf(b.y, c.y)) < 0.3 or minf(a.y, minf(b.y, c.y)) > 4.0:
				continue
			var x0 := int(floor((minf(a.x, minf(b.x, c.x)) - minx) / cell))
			var x1 := int(floor((maxf(a.x, maxf(b.x, c.x)) - minx) / cell))
			var z0 := int(floor((minf(a.z, minf(b.z, c.z)) - minz) / cell))
			var z1 := int(floor((maxf(a.z, maxf(b.z, c.z)) - minz) / cell))
			for gx in range(maxi(0, x0), mini(w - 1, x1) + 1):
				for gz in range(maxi(0, z0), mini(h - 1, z1) + 1):
					blocked[gz * w + gx] = 1
	for e in tree_boxes:
		var p: Vector3 = e[0]
		var gx := int(floor((p.x - minx) / cell))
		var gz := int(floor((p.z - minz) / cell))
		if gx >= 0 and gx < w and gz >= 0 and gz < h:
			blocked[gz * w + gx] = 1
	# Transformée de distance (chamfer 2 passes).
	var INF := 1.0e9
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	for i in w * h:
		dist[i] = 0.0 if blocked[i] == 1 else INF
	for z in h:
		for x in w:
			var i := z * w + x
			if dist[i] == 0.0:
				continue
			var best := dist[i]
			if x > 0:
				best = minf(best, dist[i - 1] + 1.0)
			if z > 0:
				best = minf(best, dist[i - w] + 1.0)
			if x > 0 and z > 0:
				best = minf(best, dist[i - w - 1] + 1.41)
			if x < w - 1 and z > 0:
				best = minf(best, dist[i - w + 1] + 1.41)
			dist[i] = best
	for z in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := z * w + x
			if dist[i] == 0.0:
				continue
			var best := dist[i]
			if x < w - 1:
				best = minf(best, dist[i + 1] + 1.0)
			if z < h - 1:
				best = minf(best, dist[i + w] + 1.0)
			if x < w - 1 and z < h - 1:
				best = minf(best, dist[i + w + 1] + 1.41)
			if x > 0 and z < h - 1:
				best = minf(best, dist[i + w - 1] + 1.41)
			dist[i] = best
	var centre := Vector2(aabb.position.x + aabb.size.x * 0.5,
		aabb.position.z + aabb.size.z * 0.5)
	var best_score := -1.0e9
	var best_p := Vector3.ZERO
	var best_d := 0.0
	var cands := []
	for z in h:
		for x in w:
			var d := dist[z * w + x]
			if d <= 0.0:
				continue
			var px := minx + (x + 0.5) * cell
			var pz := minz + (z + 0.5) * cell
			var away := Vector2(px, pz).distance_to(centre)
			var score := minf(d * cell, 22.0) - away * 0.02
			cands.append([score, px, pz, d * cell])
			if score > best_score:
				best_score = score
				best_p = Vector3(px, 0.0, pz)
				best_d = d * cell
	cands.sort_custom(func(a, b): return a[0] > b[0])
	print("--- 6 meilleurs points de spawn ---")
	for i in mini(6, cands.size()):
		var c = cands[i]
		print("  (%.1f, %.1f)  dégagement %.1f m" % [c[1], c[2], c[3]])
	print("spawn proposé : (%.1f, 0.02, %.1f)  dégagement ≈ %.1f m" % [
		best_p.x, best_p.z, best_d])
	_ascii(dist, w, h, cell, minx, minz, best_p)


func _ascii(dist: PackedFloat32Array, w: int, h: int, cell: float,
		minx: float, minz: float, spawn: Vector3) -> void:
	var cols := 76
	var rows := 44
	var sx := int((spawn.x - minx) / cell)
	var sz := int((spawn.z - minz) / cell)
	print("--- plan ( '#' mur, '.' libre, 'S' spawn ) ---")
	for ry in rows:
		var line := ""
		for rx in cols:
			var gx := int(float(rx) / cols * w)
			var gz := int(float(ry) / rows * h)
			if absi(gx - sx) <= 1 and absi(gz - sz) <= 1:
				line += "S"
			elif dist[gz * w + gx] <= 0.0:
				line += "#"
			elif dist[gz * w + gx] < 3.0:
				line += ":"
			else:
				line += "."
		print(line)

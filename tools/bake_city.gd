extends SceneTree

## Fusionne les deux OBJ de la ville en un seul mesh (5 surfaces, une par page
## d'atlas) et range les 271 textures dans des atlas de 4096×4096.
## Résultat : 5 draw calls et 5 matériaux au lieu de 299.
##
## Chaque texture occupe une cellule de 512×512 (coin haut-gauche, le reste de
## la cellule est rempli avec sa couleur moyenne pour que les mipmaps restent
## justes). Les UV sont remises à l'échelle en conséquence.

const PARTS := [
	"res://gm-bigcity/gm_bigcity_part1.obj",
	"res://gm-bigcity/gm_bigcity_part2.obj",
]
const OUT_MESH := "res://gm-bigcity/gm_bigcity_city.res"
const ATLAS_DIR := "res://gm-bigcity/atlas"

const CELL := 512
const PAGE := 4096
const COLS := PAGE / CELL
const PER_PAGE := COLS * COLS


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()

	# 1. Inventaire des textures utilisées, dans l'ordre d'apparition.
	var order: Array[String] = []
	var seen := {}
	var surfaces := []
	for part in PARTS:
		var mesh: ArrayMesh = load(part)
		if mesh == null:
			push_error("mesh introuvable : " + part)
			quit(1)
			return
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null:
				push_error("surface %d de %s sans texture" % [s, part])
				continue
			var path := mat.albedo_texture.resource_path
			if not seen.has(path):
				seen[path] = order.size()
				order.append(path)
			surfaces.append({"arrays": mesh.surface_get_arrays(s), "path": path})

	var page_count := int(ceil(order.size() / float(PER_PAGE)))
	print("textures=%d pages=%d surfaces=%d" % [order.size(), page_count, surfaces.size()])

	# 2. Remplissage des pages.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ATLAS_DIR))
	var info := []
	var page_img: Image = null
	var page_idx := -1
	for i in order.size():
		var p: int = i / PER_PAGE
		if p != page_idx:
			if page_img != null:
				_save_page(page_img, page_idx)
			page_idx = p
			page_img = Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
			page_img.fill(Color(0.5, 0.5, 0.5))
		var cell: int = i % PER_PAGE
		var cx := (cell % COLS) * CELL
		var cy := (cell / COLS) * CELL

		var img := Image.load_from_file(ProjectSettings.globalize_path(order[i]))
		if img == null:
			push_error("texture introuvable : " + order[i])
			info.append({"page": p, "cx": cx, "cy": cy, "nw": CELL, "nh": CELL})
			continue
		img.convert(Image.FORMAT_RGBA8)
		var src := img.get_size()
		var k := minf(1.0, float(CELL) / float(maxi(src.x, src.y)))
		var nw := maxi(1, roundi(src.x * k))
		var nh := maxi(1, roundi(src.y * k))
		if nw != src.x or nh != src.y:
			img.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
		page_img.fill_rect(Rect2i(cx, cy, CELL, CELL), _average(img))
		page_img.blit_rect(img, Rect2i(0, 0, nw, nh), Vector2i(cx, cy))
		info.append({"page": p, "cx": cx, "cy": cy, "nw": nw, "nh": nh})
	if page_img != null:
		_save_page(page_img, page_idx)
	print("atlas écrits (%d ms)" % (Time.get_ticks_msec() - t0))

	# 3. Table des cellules : xy = origine dans la page, zw = échelle, en UV.
	var cells := []
	for p in page_count:
		cells.append(PackedVector4Array())
	for i in order.size():
		var inf: Dictionary = info[i]
		var p: int = inf["page"]
		var arr: PackedVector4Array = cells[p]
		while arr.size() <= int(i % PER_PAGE):
			arr.append(Vector4.ZERO)
		arr[int(i % PER_PAGE)] = Vector4(
			float(inf["cx"]) / PAGE, float(inf["cy"]) / PAGE,
			float(inf["nw"]) / PAGE, float(inf["nh"]) / PAGE)
		cells[p] = arr

	# 4. Géométrie fusionnée, une surface par page.
	var buckets := []
	for p in page_count:
		buckets.append({
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"t": PackedVector2Array(),
			"u2": PackedVector2Array(),
			"i": PackedInt32Array(),
		})
	for s in surfaces:
		var inf: Dictionary = info[seen[s.path]]
		var b: Dictionary = buckets[inf["page"]]
		var verts: PackedVector3Array = b["v"]
		var norms: PackedVector3Array = b["n"]
		var uvs: PackedVector2Array = b["t"]
		var uv2: PackedVector2Array = b["u2"]
		var idxs: PackedInt32Array = b["i"]

		var arrays: Array = s["arrays"]
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n = arrays[Mesh.ARRAY_NORMAL]
		var t = arrays[Mesh.ARRAY_TEX_UV]
		var src_idx = arrays[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var cell := float(seen[s["path"]] % PER_PAGE)
		for i in v.size():
			verts.append(v[i])
			norms.append(n[i] if n != null and n.size() > i else Vector3.UP)
			uvs.append(t[i] if t != null and t.size() > i else Vector2.ZERO)
			uv2.append(Vector2(cell, 0.0))
		if src_idx != null and src_idx.size() > 0:
			for i in src_idx.size():
				idxs.append(base + src_idx[i])
		else:
			for i in v.size():
				idxs.append(base + i)

	var out := ArrayMesh.new()
	var tri_total := 0
	for p in page_count:
		var b: Dictionary = buckets[p]
		if b["v"].is_empty():
			continue
		var arrays_out := []
		arrays_out.resize(Mesh.ARRAY_MAX)
		arrays_out[Mesh.ARRAY_VERTEX] = b["v"]
		arrays_out[Mesh.ARRAY_NORMAL] = b["n"]
		arrays_out[Mesh.ARRAY_TEX_UV] = b["t"]
		arrays_out[Mesh.ARRAY_TEX_UV2] = b["u2"]
		arrays_out[Mesh.ARRAY_INDEX] = b["i"]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
		out.surface_set_name(out.get_surface_count() - 1, "atlas_%d" % p)
		tri_total += b["i"].size() / 3
	print("mesh: surfaces=%d triangles=%d aabb=%s" % [
		out.get_surface_count(), tri_total, str(out.get_aabb())])

	for p in page_count:
		var padded: PackedVector4Array = cells[p]
		while padded.size() < PER_PAGE:
			padded.append(Vector4.ZERO)
		cells[p] = padded
	out.set_meta("cells", cells)
	var err := ResourceSaver.save(out, OUT_MESH)
	print("mesh sauvegardé (%d) %s — total %d ms" % [err, OUT_MESH, Time.get_ticks_msec() - t0])
	quit()


func _save_page(img: Image, index: int) -> void:
	var path := "%s/city_atlas_%d.png" % [ATLAS_DIR, index]
	var err := img.save_png(path)
	print("  page %d -> %s (%d, %d×%d)" % [index, path, err, img.get_width(), img.get_height()])


func _average(img: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	var step := maxi(1, mini(img.get_width(), img.get_height()) / 16)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			sum += img.get_pixel(x, y)
			n += 1
	if n == 0:
		return Color(0.5, 0.5, 0.5)
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0)

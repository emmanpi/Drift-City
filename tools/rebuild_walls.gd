extends SceneTree

## Reconstruit la collision des murs en ne gardant que les triangles qui
## traversent vraiment la hauteur de la voiture (du niveau de la route
## jusqu'au-dessus du toit), puis cherche le point le plus dégagé autour du
## spawn actuel.

const MAP_Y := 1.2
const PARTS := [
	"res://gm-bigcity/gm_bigcity_part1.obj",
	"res://gm-bigcity/gm_bigcity_part2.obj",
]
const OUT := "res://gm-bigcity/gm_bigcity_walls.res"

const BIN := 25.0
const REACH := 3
const CAP := 60.0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var faces := PackedVector3Array()
	var total := 0
	var walls := 0
	for part in PARTS:
		var mesh: ArrayMesh = load(part)
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var count: int = (idx.size() if idx != null and idx.size() > 0 else verts.size())
			var i := 0
			while i + 2 < count:
				var ia: int = (idx[i] if idx != null and idx.size() > 0 else i)
				var ib: int = (idx[i + 1] if idx != null and idx.size() > 0 else i + 1)
				var ic: int = (idx[i + 2] if idx != null and idx.size() > 0 else i + 2)
				total += 1
				var a := verts[ia]
				var b := verts[ib]
				var c := verts[ic]
				var n := (b - a).cross(c - a)
				var ln := n.length()
				if ln > 0.0001:
					n /= ln
					if absf(n.y) < 0.6:
						walls += 1
						var ymin := minf(a.y, minf(b.y, c.y))
						var ymax := maxf(a.y, maxf(b.y, c.y))
						# De la route (y = MAP_Y) jusqu'au-dessus du toit.
						if ymin < MAP_Y + 0.5 and ymax > MAP_Y + 1.2:
							faces.append(a)
							faces.append(b)
							faces.append(c)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var err := ResourceSaver.save(shape, OUT)
	print("tris=%d murs=%d gardés=%d (%d ms) err=%d" % [
		total, walls, faces.size() / 3, Time.get_ticks_msec() - t0, err])

	# Index spatial 2D pour le balayage de dégagement.
	var tris := []
	var bins := {}
	for i in range(0, faces.size(), 3):
		var a := Vector2(faces[i].x, faces[i].z)
		var b := Vector2(faces[i + 1].x, faces[i + 1].z)
		var c := Vector2(faces[i + 2].x, faces[i + 2].z)
		var id := tris.size()
		tris.append([a, b, c])
		var mn := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
		var mx := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
		for bx in range(int(floor(mn.x / BIN)), int(floor(mx.x / BIN)) + 1):
			for by in range(int(floor(mn.y / BIN)), int(floor(mx.y / BIN)) + 1):
				var key := Vector2i(bx, by)
				if not bins.has(key):
					bins[key] = PackedInt32Array()
				var arr: PackedInt32Array = bins[key]
				arr.append(id)
				bins[key] = arr

	print("clearance spawn (400,-456) = %.1f" % _clearance(Vector2(400, -456), bins, tris))

	var results := []
	var x := 200.0
	while x <= 620.0:
		var z := -700.0
		while z <= -200.0:
			var p := Vector2(x, z)
			results.append([_clearance(p, bins, tris), p])
			z += 4.0
		x += 4.0
	results.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(8, results.size()):
		var r = results[i]
		var p: Vector2 = r[1]
		var line := "  d=%.1f at %s :" % [r[0], str(p)]
		for ang in [0, 90, 180, 270]:
			var dir := Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang)))
			var run := 0.0
			while run < 300.0 and _clearance(p + dir * run, bins, tris) > 8.0:
				run += 4.0
			line += " %d°=%d" % [ang, int(run)]
		print(line)
	quit()


func _clearance(p: Vector2, b: Dictionary, t: Array) -> float:
	var bx := int(floor(p.x / BIN))
	var by := int(floor(p.y / BIN))
	var best := CAP
	for dx in range(-REACH, REACH + 1):
		for dy in range(-REACH, REACH + 1):
			var key := Vector2i(bx + dx, by + dy)
			if not b.has(key):
				continue
			for idx in b[key]:
				var tri: Array = t[idx]
				var d := _tri_dist(p, tri[0], tri[1], tri[2])
				if d < best:
					best = d
					if best <= 0.0:
						return 0.0
	return best


func _tri_dist(p: Vector2, a: Vector2, bb: Vector2, c: Vector2) -> float:
	var d1 := (bb - a).cross(p - a)
	var d2 := (c - bb).cross(p - bb)
	var d3 := (a - c).cross(p - c)
	var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	if not (neg and pos):
		return 0.0
	return minf(_seg(p, a, bb), minf(_seg(p, bb, c), _seg(p, c, a)))


func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))

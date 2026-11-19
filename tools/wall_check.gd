extends SceneTree

func _initialize() -> void:
	var vis: ArrayMesh = load("res://gm-bigcity/gm_bigcity_city_grey.res")
	var verts_all := 0
	var vert_area := 0.0
	var box := AABB()
	for s in vis.get_surface_count():
		var a: Array = vis.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for k in range(0, idx.size(), 3):
			var p0 := v[idx[k]]
			var p1 := v[idx[k + 1]]
			var p2 := v[idx[k + 2]]
			var n := (p1 - p0).cross(p2 - p0)
			if n.length() < 0.0001:
				continue
			if absf(n.normalized().y) < 0.7:
				vert_area += n.length() * 0.5
				verts_all += 1
	print("VISUEL : %d triangles verticaux, %.0f m²" % [verts_all, vert_area])

	var sh: ConcavePolygonShape3D = load("res://gm-bigcity/gm_bigcity_walls.res")
	var faces := sh.get_faces()
	var area := 0.0
	var low := 0
	for k in range(0, faces.size(), 3):
		var p0 := faces[k]
		var p1 := faces[k + 1]
		var p2 := faces[k + 2]
		var n := (p1 - p0).cross(p2 - p0)
		area += n.length() * 0.5
		if maxf(p0.y, maxf(p1.y, p2.y)) < 3.0:
			low += 1
	print("COLLISION : %d triangles, %.0f m², dont %d sous y=3" % [faces.size() / 3, area, low])
	print("AABB collision : %s" % sh.get_debug_mesh().get_aabb())

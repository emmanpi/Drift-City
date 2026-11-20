extends SceneTree

## Carte ASCII du sol cuit : `#` = terre ferme (y > -0,15), `~` = eau / vide.
## Les faces de fond marin (y <= -0,15) sont ignorées.

const GROUND := "res://low-poly-city/city_ground.res"
const CELL := 5.0
const X0 := -283.0
const Z0 := -343.0
const W := 566.0
const H := 686.0
const MIN_Y := -0.15

func _initialize() -> void:
	var data: Resource = load(GROUND)
	var cols := int(ceil(W / CELL))
	var rows := int(ceil(H / CELL))
	var land := PackedByteArray()
	land.resize(cols * rows)
	land.fill(0)
	for entry in data.chunks:
		var shape: ConcavePolygonShape3D = entry["shape"]
		if shape == null:
			continue
		var faces: PackedVector3Array = shape.get_faces()
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-6:
				continue
			if absf(n.normalized().y) < 0.6:
				continue
			var y := (a.y + b.y + c.y) / 3.0
			if y <= MIN_Y:
				continue
			var gx0 := clampi(int(floor((minf(a.x, minf(b.x, c.x)) - X0) / CELL)), 0, cols - 1)
			var gx1 := clampi(int(floor((maxf(a.x, maxf(b.x, c.x)) - X0) / CELL)), 0, cols - 1)
			var gz0 := clampi(int(floor((minf(a.z, minf(b.z, c.z)) - Z0) / CELL)), 0, rows - 1)
			var gz1 := clampi(int(floor((maxf(a.z, maxf(b.z, c.z)) - Z0) / CELL)), 0, rows - 1)
			for gz in range(gz0, gz1 + 1):
				for gx in range(gx0, gx1 + 1):
					land[gz * cols + gx] = 1
	var lines: Array = []
	for gz in rows:
		var line := ""
		for gx in cols:
			line += "#" if land[gz * cols + gx] == 1 else "~"
		lines.append(line)
	var header := "     "
	for gx in cols:
		header += "|" if gx % 10 == 0 else " "
	header += "   x="
	for gx in range(0, cols, 10):
		header += " %d" % int(X0 + gx * CELL)
	print(header)
	for gz in range(rows - 1, -1, -1):
		print("%4d %s" % [int(Z0 + (gz + 0.5) * CELL), lines[gz]])
	var edges := 0
	for gz in rows:
		for gx in cols:
			if land[gz * cols + gx] == 0:
				continue
			var p := gx > 0 and land[gz * cols + gx - 1] == 1
			var q := gx < cols - 1 and land[gz * cols + gx + 1] == 1
			var r := gz > 0 and land[(gz - 1) * cols + gx] == 1
			var s := gz < rows - 1 and land[(gz + 1) * cols + gx] == 1
			if not (p and q and r and s):
				edges += 1
	print("cellules terre=%d  cellules bord=%d  taille=%.0f m" % [land.count(1), edges, CELL])
	quit()

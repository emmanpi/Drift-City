extends SceneTree

## Vérifie les hauteurs des faces de sol cuites : une face à y = 1.37 ferait
## « flotter » la voiture au-dessus des routes.

func _initialize() -> void:
	var data: Resource = load("res://low-poly-city/city_ground.res")
	var counts := {}
	var samples := {}
	var ymin := 1e9
	var ymax := -1e9
	var total := 0
	for entry in data.chunks:
		var shape: ConcavePolygonShape3D = entry["shape"]
		var faces := shape.get_faces()
		for i in range(0, faces.size(), 3):
			var y := (faces[i].y + faces[i + 1].y + faces[i + 2].y) / 3.0
			ymin = minf(ymin, y)
			ymax = maxf(ymax, y)
			var k: int = int(round(y * 10.0))
			counts[k] = int(counts.get(k, 0)) + 1
			if y > 0.3 and not samples.has(k):
				samples[k] = Vector3((faces[i].x + faces[i + 1].x + faces[i + 2].x) / 3.0,
					y, (faces[i].z + faces[i + 1].z + faces[i + 2].z) / 3.0)
			total += 1
	var keys: Array = counts.keys()
	keys.sort()
	print("faces=%d  y=[%.2f, %.2f]" % [total, ymin, ymax])
	for k in keys:
		if counts[k] < 10:
			continue
		var extra := ""
		if samples.has(k):
			extra = "  ex=" + str(samples[k])
		print("  y=%.2f : %d faces%s" % [float(k) / 10.0, counts[k], extra])
	quit()

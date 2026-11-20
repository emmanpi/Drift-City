extends SceneTree

## Couleur moyenne des textures de carrosserie, pour repérer le prefab
## « bleu ciel » (les matériaux du pack sont blancs, la couleur est dans la
## texture).

const DIR := "res://npc_cars"

func _initialize() -> void:
	var dir := DirAccess.open(DIR)
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".tscn"):
			continue
		var p: PackedScene = load(DIR + "/" + f)
		var car: Node3D = p.instantiate()
		var best := Color.BLACK
		var best_name := "-"
		var best_score := -1.0
		for c in car.get_children():
			if not (c is MeshInstance3D):
				continue
			var mi := c as MeshInstance3D
			var nm := String(mi.name).to_lower()
			if nm.contains("glass") or nm.contains("optics") or nm.contains("wheel"):
				continue
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if not (mat is StandardMaterial3D):
					continue
				var tex: Texture2D = (mat as StandardMaterial3D).albedo_texture
				if tex == null:
					continue
				var img := tex.get_image()
				if img == null:
					continue
				var col := _average(img)
				var score := col.r + col.g + col.b
				if score > best_score:
					best_score = score
					best = col
					best_name = nm + "#" + str(s)
		print("%-22s %-24s RGB=(%.2f, %.2f, %.2f)" % [f, best_name, best.r, best.g, best.b])
		car.free()
	quit()


func _average(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, int(minf(w, h) / 40.0))
	var sum := Color.BLACK
	var n := 0
	for y in range(0, h, step):
		for x in range(0, w, step):
			sum += img.get_pixel(x, y)
			n += 1
	return sum / float(maxi(1, n))

extends SceneTree

## Statistiques des captures : couleurs dominantes, luminosité, part de ciel.
## Sert à vérifier qu'un rendu n'est pas noir / gris / vide sans regarder l'image.

func _initialize() -> void:
	for path in ["res://shot_air.png", "res://shot_spawn.png", "res://shot_npc.png"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			print(path, " : illisible")
			continue
		var w := img.get_width()
		var h := img.get_height()
		var total := 0.0
		var r := 0.0
		var g := 0.0
		var b := 0.0
		var sky := 0
		var dark := 0
		var bright := 0
		var buckets := {}
		var step := 4
		var n := 0
		for y in range(0, h, step):
			for x in range(0, w, step):
				var c := img.get_pixel(x, y)
				r += c.r
				g += c.g
				b += c.b
				total += c.get_luminance()
				n += 1
				if c.b > c.r + 0.06 and c.b > 0.35:
					sky += 1
				if c.get_luminance() < 0.06:
					dark += 1
				if c.get_luminance() > 0.85:
					bright += 1
				var key := Color(c.r * 8.0 / 8.0, c.g * 8.0 / 8.0, c.b * 8.0 / 8.0)
				var k := "%d,%d,%d" % [int(c.r * 12.0), int(c.g * 12.0), int(c.b * 12.0)]
				buckets[k] = buckets.get(k, 0) + 1
		var keys := buckets.keys()
		keys.sort_custom(func(a, bb): return buckets[a] > buckets[bb])
		print("--- %s  (%dx%d) ---" % [path, w, h])
		print("  moyenne RGB = (%.2f, %.2f, %.2f)   luminance = %.2f" % [
			r / n, g / n, b / n, total / n])
		print("  ciel = %.1f%%   sombre = %.1f%%   clair = %.1f%%" % [
			100.0 * sky / n, 100.0 * dark / n, 100.0 * bright / n])
		print("  couleurs distinctes (12 niveaux) = %d" % keys.size())
		var top := ""
		for i in mini(6, keys.size()):
			top += "%s:%.1f%%  " % [keys[i], 100.0 * buckets[keys[i]] / n]
		print("  dominantes : " + top)
	quit()

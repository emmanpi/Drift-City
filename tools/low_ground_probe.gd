extends SceneTree

## Liste les grandes faces de sol basses : permet de distinguer les routes en
## pente (beaucoup de petites faces) d'une nappe d'eau (quelques grands quads).

const GROUND := "res://low-poly-city/city_ground.res"

func _initialize() -> void:
	var data: Resource = load(GROUND)
	var items: Array = []
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
			var area := n.length() * 0.5
			if area < 20.0:
				continue
			var y := (a.y + b.y + c.y) / 3.0
			if y > 0.05:
				continue
			var box := AABB(a, Vector3.ZERO).expand(b).expand(c)
			items.append({"area": area, "y": y, "box": box})
	items.sort_custom(func(x, y): return float(x["area"]) > float(y["area"]))
	print("grandes faces basses : %d" % items.size())
	for i in mini(40, items.size()):
		var it: Dictionary = items[i]
		var b: AABB = it["box"]
		print("aire=%9.1f y=%6.2f  x=[%7.1f,%7.1f] z=[%7.1f,%7.1f]" % [
			it["area"], it["y"], b.position.x, b.end.x, b.position.z, b.end.z])
	quit()

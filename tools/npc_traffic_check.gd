extends SceneTree

## Contrôle du trafic NPC : les voitures doivent avancer, rester sur les routes,
## regarder dans leur sens de marche et ne pas rester bloquées.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 10:
		await physics_frame
	var traffic: Node = root.get_node("Traffic")
	var cars: Array = traffic.get_children()

	var road_res: Resource = load("res://low-poly-city/city_roads.res")
	var pts: PackedVector3Array = road_res.points
	var segments: Array = []
	for i in range(0, pts.size() - 1, 2):
		segments.append([pts[i], pts[i + 1]])

	var last: Array = []
	var path: Array = []
	for c in cars:
		last.append((c as Node3D).global_position)
		path.append(0.0)
	for _i in 420:
		await physics_frame
		for i in cars.size():
			var p: Vector3 = (cars[i] as Node3D).global_position
			path[i] = float(path[i]) + p.distance_to(last[i] as Vector3)
			last[i] = p

	var moving := 0
	var aligned := 0
	var checked := 0
	var on_road := 0
	for i in cars.size():
		var c: CharacterBody3D = cars[i]
		if float(path[i]) > 25.0:
			moving += 1
		var vel: Vector3 = c.velocity
		if vel.length() > 2.0:
			checked += 1
			var sign: float = float(c.get("front_sign"))
			var fwd := (c.global_transform.basis.z * sign).normalized()
			if fwd.dot(vel.normalized()) > 0.75:
				aligned += 1
		if _distance_to_roads(c.global_position, segments) < 12.0:
			on_road += 1
		if i < 6:
			print("%s  chemin=%.1f m  y=%.2f  v=%.1f  route=%.1f m" % [
				c.name, float(path[i]), c.global_position.y, vel.length(),
				_distance_to_roads(c.global_position, segments)])
	print("en mouvement=%d/%d  bien orientées=%d/%d  sur route=%d/%d" % [
		moving, cars.size(), aligned, checked, on_road, cars.size()])
	quit()


func _distance_to_roads(p: Vector3, segments: Array) -> float:
	var best := 1e9
	for s in segments:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var ab := b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best

extends SceneTree

## Contrôle du trafic porté de slop-newyork : les NPC doivent avancer,
## regarder dans leur sens de marche, rester sur les axes et ne pas se
## chevaucher. Marche arrière volontaire exclue du contrôle d'orientation.

const GRID := 11.4

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 10:
		await physics_frame
	var traffic: Node = root.get_node("Traffic")
	var cars: Array = traffic.get_children()

	var nodes := _grid_nodes()
	var edges := _grid_edges(nodes)

	var last: Array = []
	var path: Array = []
	var aligned: Array = []
	var checked: Array = []
	var worst_road: Array = []
	var overlaps := 0
	var deep_overlaps := 0
	for c in cars:
		last.append(Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z))
		path.append(0.0)
		aligned.append(0)
		checked.append(0)
		worst_road.append(0.0)
	for _i in 900:
		await physics_frame
		for i in cars.size():
			var c: CharacterBody3D = cars[i]
			var p := Vector2(c.global_position.x, c.global_position.z)
			var vel: Vector2 = (p - (last[i] as Vector2)) * 60.0
			path[i] = float(path[i]) + p.distance_to(last[i] as Vector2)
			last[i] = p
			if float(c.get("reverse_left")) > 0.0 or float(c.get("impact_time")) > 0.0:
				continue
			if vel.length() > 2.0:
				checked[i] = int(checked[i]) + 1
				var fwd3: Vector3 = c.global_transform.basis.z * float(c.get("front_sign"))
				var fwd := Vector2(fwd3.x, fwd3.z)
				if fwd.normalized().dot(vel.normalized()) > 0.5:
					aligned[i] = int(aligned[i]) + 1
			worst_road[i] = maxf(float(worst_road[i]), _distance_to_edges(p, edges))
		# Chevauchements entre voitures (approximation disque de 1,35 m).
		for i in cars.size():
			for j in range(i + 1, cars.size()):
				var d: float = Vector2(
					(cars[i] as Node3D).global_position.x - (cars[j] as Node3D).global_position.x,
					(cars[i] as Node3D).global_position.z - (cars[j] as Node3D).global_position.z).length()
				if d < 2.7:
					overlaps += 1
				if d < 1.6:
					deep_overlaps += 1

	var moving := 0
	var ok_aligned := 0
	var on_road := 0
	for i in cars.size():
		var c: CharacterBody3D = cars[i]
		if float(path[i]) > 40.0:
			moving += 1
		var n: int = int(checked[i])
		if n > 0 and float(aligned[i]) / float(n) > 0.9:
			ok_aligned += 1
		if float(worst_road[i]) < 4.5:
			on_road += 1
		if i < 6:
			print("%s  chemin=%5.1f m  v=%4.1f  align=%3d%%  écart route=%.1f m" % [
				c.name, float(path[i]), float(c.get("speed")),
				int(100.0 * float(aligned[i]) / maxf(1.0, float(n))), float(worst_road[i])])
	print("en mouvement=%d/%d  bien orientées=%d/%d  sur chaussée=%d/%d" % [
		moving, cars.size(), ok_aligned, cars.size(), on_road, cars.size()])
	print("contacts rapprochés=%d  chevauchements profonds=%d" % [overlaps, deep_overlaps])
	quit()


func _grid_nodes() -> Array:
	var res: Resource = load("res://low-poly-city/city_roads.res")
	var pts: PackedVector3Array = res.points
	var x0 := 1.0e9
	var z0 := 1.0e9
	for i in range(0, pts.size() - 1, 2):
		x0 = minf(x0, (pts[i].x + pts[i + 1].x) * 0.5)
		z0 = minf(z0, (pts[i].z + pts[i + 1].z) * 0.5)
	var map := {}
	var nodes: Array = []
	for i in range(0, pts.size() - 1, 2):
		var cx := (pts[i].x + pts[i + 1].x) * 0.5
		var cz := (pts[i].z + pts[i + 1].z) * 0.5
		var key := Vector2i(roundi((cx - x0) / GRID), roundi((cz - z0) / GRID))
		if map.has(key):
			continue
		map[key] = nodes.size()
		nodes.append(Vector2(x0 + float(key.x) * GRID, z0 + float(key.y) * GRID))
	return nodes


func _grid_edges(nodes: Array) -> Array:
	var edges: Array = []
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var d: float = (nodes[i] as Vector2).distance_to(nodes[j] as Vector2)
			if d < GRID * 1.1:
				edges.append([nodes[i], nodes[j]])
	return edges


func _distance_to_edges(p: Vector2, edges: Array) -> float:
	var best := 1e9
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var ab := b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best

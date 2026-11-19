extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 10:
		await physics_frame
	var cars: Array = (root.get_node("Traffic") as Node).get_children()
	var bad: Array = []
	var bad_frames: Array = []
	for c in cars:
		bad.append(0)
		bad_frames.append(0)
	var prev: Array = []
	for c in cars:
		prev.append(Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z))
	for frame in 600:
		await physics_frame
		for i in cars.size():
			var c = cars[i]
			var p := Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z)
			var vel: Vector2 = (p - (prev[i] as Vector2)) * 60.0
			prev[i] = p
			if vel.length() < 2.0 or float(c.get("reverse_left")) > 0.0 or float(c.get("impact_time")) > 0.0:
				continue
			bad_frames[i] = int(bad_frames[i]) + 1
			var fwd3: Vector3 = (c as Node3D).global_transform.basis.z * float(c.get("front_sign"))
			if Vector2(fwd3.x, fwd3.z).normalized().dot(vel.normalized()) < 0.5:
				bad[i] = int(bad[i]) + 1
				if bad[i] == 1:
					var fwd3b: Vector3 = (c as Node3D).global_transform.basis.z * float(c.get("front_sign"))
					print("PREMIER DÉFAUT %s f=%d v=%.1f err=%.2f fwd=(%.2f,%.2f) vel=(%.2f,%.2f) dl=%.2f knock=%s conn=%.1f s=%.1f yaw=%.2f edge=%d" % [
						c.name, frame, float(c.get("speed")), float(c.get("heading_error")),
						fwd3b.x, fwd3b.z, vel.x, vel.y, float(c.get("dl")), str(c.get("knock")),
						float(c.get("conn_s")), float(c.get("s")), float(c.get("yaw")), int(c.get("edge"))])
	for i in cars.size():
		print("%s mauvais=%d/%d" % [cars[i].name, bad[i], bad_frames[i]])
	quit()

extends SceneTree

## Vérifie que la voiture apparaît sur une zone dégagée de la nouvelle ville :
## aucune collision au spawn, et distance au premier mur.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for i in 20:
		await physics_frame
	var car: Node3D = root.get_node("Car")
	var space := (car as Node3D).get_world_3d().direct_space_state
	var from := car.global_position + Vector3(0.0, 0.6, 0.0)
	print("voiture : %s" % car.global_position)
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print("  %s : rien à 60 m" % dir)
		else:
			print("  %s : mur à %.1f m  (%s)" % [
				dir, from.distance_to(hit["position"]), hit["collider"].name])
	print("collisions au spawn : %d" % (car as CharacterBody3D).get_slide_collision_count())
	quit()

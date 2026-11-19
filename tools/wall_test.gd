extends SceneTree

## Test de traversée de mur : la voiture part du spawn, accélère (nitro) droit
## vers le bâtiment situé à 40 m et ne doit jamais le dépasser.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for i in 10:
		await physics_frame
	var car: CharacterBody3D = root.get_node("Car")
	var start := car.global_position
	print("départ : %s" % start)
	Input.action_press("accelerate")
	Input.action_press("nitro")
	var min_z := start.z
	var max_speed := 0.0
	for i in 360:
		await physics_frame
		min_z = minf(min_z, car.global_position.z)
		max_speed = maxf(max_speed, Vector2(car.velocity.x, car.velocity.z).length())
	Input.action_release("accelerate")
	Input.action_release("nitro")
	var end := car.global_position
	print("arrivée : %s   z mini atteint : %.2f" % [end, min_z])
	print("vitesse max : %.1f m/s (%.0f km/h)" % [max_speed, max_speed * 3.6])
	# Le mur le plus proche dépend du spawn : on le sonde au lieu de supposer
	# une distance fixe (le spawn a changé lors du bake des véhicules retirés).
	var space := car.get_world_3d().direct_space_state
	var from := start + Vector3(0.0, 0.6, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.FORWARD * 80.0, 1)
	var hit := space.intersect_ray(q)
	var wall_z := start.z - 80.0
	if not hit.is_empty():
		wall_z = float(hit["position"].z)
	print("mur attendu vers z = %.1f" % wall_z)
	if min_z < wall_z - 1.0:
		print("ECHEC : la voiture a traversé le mur de %.1f m" % (wall_z - min_z))
	else:
		print("OK : mur bloquant")
	quit()

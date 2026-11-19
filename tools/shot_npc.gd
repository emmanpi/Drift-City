extends SceneTree

## Capture une voiture NPC de près pour vérifier le modèle importé (échelle,
## orientation, matériaux, absence de roues invisibles).

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 30:
		await process_frame
	var traffic: Node = root.get_node("Traffic")
	var car: Node3D = traffic.get_child(0) as Node3D
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 300.0
	get_root().add_child(cam)
	cam.current = true
	var behind := -car.global_transform.basis.z
	cam.global_position = car.global_position - behind * 9.0 + Vector3.UP * 3.2
	cam.look_at(car.global_position + Vector3.UP * 0.8, Vector3.UP)
	for _i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://shot_npc.png")
	print("NPC capturé : %s  pos=%s" % [car.name, str(car.global_position)])
	quit()

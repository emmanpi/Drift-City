extends SceneTree

## Capture la ville pour vérifier le rendu (textures, z-fighting, collisions).
## Usage : Godot --path . --script res://tools/shot_city.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for i in 30:
		await process_frame

	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 2000.0
	get_root().add_child(cam)
	cam.current = true

	# Vue aérienne de la ville.
	cam.global_position = Vector3(150.0, 180.0, 220.0)
	cam.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://shot_air.png")

	# Vue depuis le spawn, à hauteur de voiture.
	cam.global_position = Vector3(-31.8, 12.0, -9.8 + 26.0)
	cam.look_at(Vector3(-31.8, 3.0, -9.8 - 30.0), Vector3.UP)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://shot_spawn.png")
	quit()

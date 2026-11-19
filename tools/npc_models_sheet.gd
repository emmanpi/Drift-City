extends SceneTree

## Planche contact des 10 prefabs NPC, vue de 3/4. Les noms sont affichés dans
## la console dans l'ordre des colonnes (gauche -> droite, haut -> bas).

const DIR := "res://npc_cars"

func _initialize() -> void:
	var dir := DirAccess.open(DIR)
	var files := dir.get_files()
	files.sort()
	var scenes: Array = []
	for f in files:
		if f.ends_with(".tscn"):
			scenes.append(f)
	var root := Node3D.new()
	get_root().add_child(root)
	for i in scenes.size():
		var p: PackedScene = load(DIR + "/" + scenes[i])
		var car: Node3D = p.instantiate()
		car.position = Vector3(float(i % 5) * 7.0 - 14.0, 0.0, float(i / 5) * 8.0)
		root.add_child(car)
		print("colonne %d : %s" % [i % 5, scenes[i]])
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 300.0
	root.add_child(cam)
	cam.global_position = Vector3(-2.0, 16.0, -30.0)
	cam.look_at(Vector3(0.0, 0.0, 4.0), Vector3.UP)
	cam.current = true
	var world := World3D.new()
	root.world_3d = world
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.38)
	world.environment = env
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	root.add_child(light)
	for _i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://npc_models_sheet.png")
	print("planche enregistrée")
	quit()

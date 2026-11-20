extends SceneTree

## Drift sur sol plat puis capture vue de-dessus pour inspecter les traces.

func _initialize() -> void:
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	var scene: PackedScene = load("res://tools/open_test.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in 12:
		await physics_frame
	var car: CharacterBody3D = root.get_node("Car")

	Input.action_press("accelerate")
	for _i in 160:
		await physics_frame
	Input.action_press("handbrake")
	Input.action_press("steer_left")
	for _i in 130:
		await physics_frame
	Input.action_release("steer_left")
	Input.action_release("handbrake")
	Input.action_release("accelerate")

	var skid: Node = car.get_node("SkidMarks")
	var mm: MultiMesh = (skid.get_node("Marks") as MultiMeshInstance3D).multimesh
	var visible := 0
	var max_alpha := 0.0
	for i in mm.instance_count:
		var a := mm.get_instance_color(i).a
		max_alpha = maxf(max_alpha, a)
		if a > 0.0:
			visible += 1
	print("traces   : %d segments actifs, alpha max %.2f, drift=%s, cap %.1f deg" % [
		visible, max_alpha, str(car.drifting), rad_to_deg(car.rotation.y)])

	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 400.0
	get_root().add_child(cam)
	cam.current = true
	cam.global_position = Vector3(-4.0, 34.0, 2.0)
	cam.look_at(Vector3(-4.0, 0.0, 2.0), Vector3(0.0, 0.0, -1.0))
	for _i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://shot_skid.png")

	quit()

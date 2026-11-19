extends SceneTree

## Mesure de fps dans la ville : à l'arrêt puis en roulant (accélérateur + nitro).
## Usage : Godot --path . --script res://tools/fps_probe.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/city.tscn")
	var root := scene.instantiate()
	get_root().add_child(root)
	for i in 90:
		await process_frame
	await _measure("à l'arrêt", 5.0)

	Input.action_press("accelerate")
	Input.action_press("nitro")
	await _measure("en roulant (nitro)", 5.0)
	Input.action_release("accelerate")
	Input.action_release("nitro")
	quit()


func _measure(label: String, seconds: float) -> void:
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while (Time.get_ticks_usec() - t0) < int(seconds * 1000000.0):
		await process_frame
		frames += 1
	var dt := (Time.get_ticks_usec() - t0) / 1000000.0
	print("%-22s : %.1f fps  (%d images en %.1f s)" % [label, frames / dt, frames, dt])

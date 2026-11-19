extends SceneTree

## Planche contact : 10 prefabs, plus un repère vert à leur avant supposé
## (côté -Z local). Si le vert est à l'arrière d'une voiture, sa table FRONT
## est fausse. Ordre : 5 en haut (compact..offroad), 5 en bas (pickup..wagon).

const DIR := "res://npc_cars"
const FRONT := {
	"compact_car.tscn": -1.0, "coupe_car.tscn": -1.0,
	"hatchback_car.tscn": 1.0, "minivan_car.tscn": 1.0,
	"offroad_car.tscn": 1.0, "pickup_car.tscn": -1.0,
	"sedan_car.tscn": 1.0, "sport_car.tscn": -1.0,
	"suv_car.tscn": 1.0, "wagon_car.tscn": 1.0,
}

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
		var f: String = scenes[i]
		var p: PackedScene = load(DIR + "/" + f)
		var car: Node3D = p.instantiate()
		car.position = Vector3(float(i % 5) * 7.0 - 14.0, 0.0, float(i / 5) * 8.0)
		root.add_child(car)
		# Repère : petit cube vert à l'avant supposé, rouge à l'arrière.
		var front := _marker(Color(0.1, 1.0, 0.2))
		front.position = Vector3(0.0, 0.9, 2.6 * float(FRONT.get(f, -1.0)))
		car.add_child(front)
		var back := _marker(Color(1.0, 0.1, 0.1))
		back.position = Vector3(0.0, 0.9, -2.6 * float(FRONT.get(f, -1.0)))
		car.add_child(back)
		print("col %d rang %d : %s" % [i % 5, i / 5, f])
	var cam := Camera3D.new()
	cam.fov = 52.0
	cam.far = 300.0
	root.add_child(cam)
	cam.position = Vector3(0.0, 14.0, -26.0)
	cam.look_at(Vector3(0.0, 0.0, 4.0), Vector3.UP)
	cam.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	root.add_child(light)
	for _i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://npc_models_sheet.png")
	print("planche enregistrée")
	quit()


func _marker(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.55, 0.55)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission = color
	mat.emission_energy_multiplier = 1.0
	mi.material_override = mat
	return mi

extends Node3D

const BLOCKS := [
	[26.0, 28.0, 14.0, 16.0, 10.0],
	[48.0, 26.0, 16.0, 14.0, 22.0],
	[72.0, 28.0, 18.0, 16.0, 13.0],
	[26.0, 52.0, 14.0, 18.0, 30.0],
	[50.0, 54.0, 20.0, 20.0, 16.0],
	[78.0, 56.0, 14.0, 22.0, 20.0],
	[30.0, 80.0, 18.0, 14.0, 9.0],
	[56.0, 82.0, 16.0, 12.0, 18.0],
	[82.0, 80.0, 12.0, 14.0, 11.0],
]

const WALL_COLORS := [
	Color(0.62, 0.64, 0.67),
	Color(0.42, 0.48, 0.55),
	Color(0.58, 0.5, 0.44),
	Color(0.34, 0.39, 0.46),
	Color(0.73, 0.71, 0.66),
	Color(0.3, 0.36, 0.4),
]

var _mats := {}

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_perimeter()

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)

	var car := preload("res://scenes/car.tscn").instantiate()
	car.name = "Car"
	car.position = Vector3(4.6, 0.02, 92.0)
	add_child(car)
	car.bind_hud(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	elif event.is_action_pressed("reset"):
		var car := get_node_or_null("Car")
		if car:
			car.reset_to_spawn()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.27, 0.46, 0.78)
	sky_mat.sky_horizon_color = Color(0.74, 0.8, 0.84)
	sky_mat.ground_bottom_color = Color(0.16, 0.2, 0.14)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.46)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 38, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, -145, 0)
	fill.light_energy = 0.38
	add_child(fill)


func _build_ground() -> void:
	var grass := _mat(Color(0.16, 0.34, 0.18), 0.0, 0.95)
	var asphalt := _mat(Color(0.13, 0.13, 0.14), 0.0, 0.92)
	var sidewalk := _mat(Color(0.45, 0.45, 0.46), 0.0, 0.85)
	var yellow := _mat(Color(0.9, 0.74, 0.18), 0.0, 0.6)
	var white := _mat(Color(0.82, 0.82, 0.8), 0.0, 0.55)

	_visual(Vector3(0, -0.08, 0), Vector3(260, 0.1, 260), grass)
	# Cross of wide roads. Tops sit just under the car wheels.
	_visual(Vector3(0, 0.0, 0), Vector3(220, 0.04, 22), asphalt)
	_visual(Vector3(0, 0.0, 0), Vector3(22, 0.04, 220), asphalt)

	_visual(Vector3(0, 0.025, 12.2), Vector3(220, 0.03, 1.5), sidewalk)
	_visual(Vector3(0, 0.025, -12.2), Vector3(220, 0.03, 1.5), sidewalk)
	for side in [-1.0, 1.0]:
		for end_z in [-60.0, 60.0]:
			_visual(Vector3(side * 12.2, 0.025, end_z), Vector3(1.5, 0.03, 96), sidewalk)

	_lane_marks(yellow, white)


func _lane_marks(yellow: Material, white: Material) -> void:
	var dash := Vector3(3.2, 0.012, 0.16)
	var i := -100.0
	while i < 100.0:
		if abs(i) > 14.0:
			_visual(Vector3(i, 0.035, 0), dash, yellow)
			_visual(Vector3(0, 0.035, i), Vector3(0.16, 0.012, 3.2), yellow)
		i += 8.0
	_visual(Vector3(0, 0.034, 10.3), Vector3(96, 0.01, 0.14), white)
	_visual(Vector3(0, 0.034, -10.3), Vector3(96, 0.01, 0.14), white)
	_visual(Vector3(0, 0.034, 10.3), Vector3(96, 0.01, 0.14), white)
	for z0 in [-104.0, 18.0]:
		_visual(Vector3(10.3, 0.034, z0 + 43.0), Vector3(0.14, 0.01, 86), white)
		_visual(Vector3(-10.3, 0.034, z0 + 43.0), Vector3(0.14, 0.01, 86), white)


func _build_buildings() -> void:
	var index := 0
	for block in BLOCKS:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var color: Color = WALL_COLORS[index % WALL_COLORS.size()]
				_building(block[0] * sx, block[1] * sz, block[2], block[3], block[4], color)
				index += 1


func _building(cx: float, cz: float, sx: float, sz: float, height: float, color: Color) -> void:
	_static(Vector3(cx, height * 0.5, cz), Vector3(sx, height, sz), color)
	var roof_col := color.darkened(0.28)
	_visual(Vector3(cx, height + 0.18, cz), Vector3(sx * 0.92, 0.36, sz * 0.92), _mat(roof_col, 0.0, 0.85))

	var win_h := clampf(height * 0.55, 1.2, height - 1.2)
	var win_y := height * 0.5
	var glass := _mat(Color(0.5, 0.7, 0.8), 0.15, 0.15)
	glass.emission_enabled = true
	glass.emission = Color(0.55, 0.75, 0.9)
	glass.emission_energy_multiplier = 0.25
	if abs(cx) <= abs(cz):
		var dir: float = -signf(cz)
		_visual(Vector3(cx, win_y, cz + dir * (sz * 0.5 + 0.04)), Vector3(sx * 0.7, win_h, 0.06), glass)
	else:
		var dir: float = -signf(cx)
		_visual(Vector3(cx + dir * (sx * 0.5 + 0.04), win_y, cz), Vector3(0.06, win_h, sz * 0.7), glass)


func _build_perimeter() -> void:
	var concrete := Color(0.28, 0.29, 0.31)
	_static(Vector3(0, 1.4, 112), Vector3(228, 2.8, 4), concrete)
	_static(Vector3(0, 1.4, -112), Vector3(228, 2.8, 4), concrete)
	_static(Vector3(112, 1.4, 0), Vector3(4, 2.8, 220), concrete)
	_static(Vector3(-112, 1.4, 0), Vector3(4, 2.8, 220), concrete)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, metallic, roughness]
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	_mats[key] = mat
	return mat


func _visual(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _static(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("building")
	add_child(body)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.0, 0.82)
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

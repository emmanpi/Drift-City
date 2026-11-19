extends Node3D

## Ville low-poly (`low-poly-city/source/Untitled.glb`) fusionnée en 3 surfaces
## par tools/bake_lowpoly_city.gd. Le sol est à y = 0 et la map est recentrée
## sur l'origine en X/Z.
##
## La collision n'est pas un trimesh global mais des morceaux de 60 m, chacun
## contenant la géométrie exacte des objets qu'il recouvre (voir
## scripts/city_collision.gd). Les arbres ont une boîte simple autour du tronc.
## Les faces de sol sont sur le calque 4 pour la physique en Y.
## Les véhicules statiques du GLB ont été retirés au bake : le trafic est assuré
## par des voitures NPC issues de generic_passenger_car_pack.glb.

const CITY_SCENE := "res://low-poly-city/city.tscn"
const CITY_COLLISION := "res://low-poly-city/city_collision.res"
const CITY_GROUND := "res://low-poly-city/city_ground.res"

## Point de départ : grande zone dégagée au centre de la ville (~22 m de
## dégagement), choisie automatiquement par le bake.
const SPAWN := Vector3(-31.8, 0.02, -9.8)
const SPAWN_YAW := 0.0

## Limites invisibles : emprise exacte de la map.
const BOUNDS := Rect2(-283.0, -343.0, 566.0, 686.0)
const WALL_HEIGHT := 6.0


func _ready() -> void:
	_build_environment()
	_build_map()
	_build_bounds()

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)

	var car := preload("res://scenes/car.tscn").instantiate()
	car.name = "Car"
	car.position = SPAWN
	car.rotation.y = SPAWN_YAW
	add_child(car)
	car.bind_hud(hud)

	var traffic := Node3D.new()
	traffic.name = "Traffic"
	traffic.set_script(preload("res://scripts/npc_traffic.gd"))
	add_child(traffic)

	# Esc opens the pause menu with Main menu / Quit and the live NPC counter.
	var pause: Node = load("res://scripts/pause_menu.gd").new()
	pause.name = "PauseMenu"
	add_child(pause)
	pause.connect("npc_count_changed", func(count: int): traffic.set_count(count))
	pause.connect("npc_reflections_changed", func(enabled: bool): traffic.set_reflections(enabled))

	Loading.hide_loading()


func _unhandled_input(event: InputEvent) -> void:
	var car := get_node_or_null("Car")
	if car == null:
		return
	if event.is_action_pressed("reset"):
		car.reset_to_spawn()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.76, 0.82, 0.88)
	sky_mat.ground_bottom_color = Color(0.18, 0.2, 0.2)
	sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.7)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.86)
	env.fog_light_energy = 0.7
	env.fog_density = 0.00035
	env.fog_sky_affect = 0.2
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 38, 0)
	sun.light_energy = 1.2
	# Pas d'ombre temps réel : sur ce GPU intégré, le surcoût divise le fps par
	# trois en GL Compatibility. La voiture garde son ombre plaquée.
	sun.shadow_enabled = false
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, -145, 0)
	fill.light_energy = 0.35
	add_child(fill)


func _build_map() -> void:
	var packed: PackedScene = load(CITY_SCENE)
	if packed == null:
		push_error("Impossible de charger la carte : " + CITY_SCENE)
		return
	# Chaque cellule de 100 m contient au plus 3 surfaces : le moteur élimine
	# par frustum les cellules hors écran.
	var city := packed.instantiate()
	city.name = "City"
	add_child(city)

	_build_collision()


func _build_collision() -> void:
	var data: Resource = load(CITY_COLLISION)
	if data == null:
		push_error("Collision de la carte introuvable : " + CITY_COLLISION)
		return
	var body := StaticBody3D.new()
	body.name = "MapWalls"
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("building")
	add_child(body)

	for entry in data.chunks:
		var shape: ConcavePolygonShape3D = entry["shape"]
		if shape == null:
			continue
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)

	# Arbres : une seule boîte partagée par toutes les instances.
	if data.tree_positions.size() > 0:
		var box := BoxShape3D.new()
		box.size = data.tree_box_size
		var trees := StaticBody3D.new()
		trees.name = "Trees"
		trees.collision_layer = 1
		trees.collision_mask = 1
		trees.add_to_group("building")
		add_child(trees)
		for p in data.tree_positions:
			var col := CollisionShape3D.new()
			col.shape = box
			col.position = p
			trees.add_child(col)

	# Sol sur le calque 4 : uniquement sondé par raycast depuis la voiture et
	# les NPC, il ne gène pas le déplacement horizontal.
	var ground_data: Resource = load(CITY_GROUND)
	if ground_data != null:
		var ground := StaticBody3D.new()
		ground.name = "Ground"
		ground.collision_layer = 8
		ground.collision_mask = 0
		add_child(ground)
		for entry in ground_data.chunks:
			var shape: ConcavePolygonShape3D = entry["shape"]
			if shape == null:
				continue
			var col := CollisionShape3D.new()
			col.shape = shape
			ground.add_child(col)


func _build_bounds() -> void:
	var r := BOUNDS
	_boundary(Vector3(r.position.x, WALL_HEIGHT * 0.5, r.get_center().y), Vector3(2.0, WALL_HEIGHT, r.size.y))
	_boundary(Vector3(r.end.x, WALL_HEIGHT * 0.5, r.get_center().y), Vector3(2.0, WALL_HEIGHT, r.size.y))
	_boundary(Vector3(r.get_center().x, WALL_HEIGHT * 0.5, r.position.y), Vector3(r.size.x, WALL_HEIGHT, 2.0))
	_boundary(Vector3(r.get_center().x, WALL_HEIGHT * 0.5, r.end.y), Vector3(r.size.x, WALL_HEIGHT, 2.0))


func _boundary(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("building")
	add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

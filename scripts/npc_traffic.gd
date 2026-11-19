extends Node3D

## Trafic roulant : voitures NPC issues de `npc_cars/` (extraites de
## generic_passenger_car_pack.glb), qui suivent les routes cuites dans
## `low-poly-city/city_roads.res`.
##
## Le bake stocke les routes par paires de points (début, fin). On construit un
## graphe **orienté** : chaque extrémité de segment connaît les extrémités
## voisines (carrefours). Un NPC roule toujours de l'extrémité où il est vers
## l'autre extrémité de son segment, puis choisit un segment adjacent au
## carrefour. Il ne peut donc ni rouler à contresens, ni couper en diagonale
## à travers les immeubles.

const ROADS := "res://low-poly-city/city_roads.res"
const CAR_DIR := "res://npc_cars"
const COUNT := 16
## Distance max entre deux extrémités pour les considérer reliées (les routes
## perpendiculaires sont décalées d'environ une demi-largeur, ~10 m).
const LINK_RADIUS := 12.0
## Les NPC ne apparaissent pas juste sur le joueur.
const SAFE_RADIUS := 22.0

## Côté vers lequel regarde chaque modèle : -1 = avant en -Z ( défaut ),
## +1 = avant en +Z. Déduit des feux arrière rouges dans la texture Optics.
const FRONT := {
	"compact_car.tscn": -1.0,
	"coupe_car.tscn": -1.0,
	"hatchback_car.tscn": 1.0,
	"minivan_car.tscn": 1.0,
	"offroad_car.tscn": 1.0,
	"pickup_car.tscn": -1.0,
	"sedan_car.tscn": 1.0,
	"sport_car.tscn": -1.0,
	"suv_car.tscn": 1.0,
	"wagon_car.tscn": 1.0,
}

var _segments: Array = []
## _neighbors[i * 2 + side] = liste de [segment_j, side_t] proches.
var _neighbors: Array = []
var _prefabs: Array = []


func _ready() -> void:
	_load_roads()
	_load_prefabs()
	if _segments.is_empty() or _prefabs.is_empty():
		push_warning("Trafic NPC désactivé : routes ou modèles introuvables")
		return
	var links := 0
	for l in _neighbors:
		links += (l as Array).size()
	print("trafic NPC : %d segments, %d liaisons, %d modèles, %d voitures" % [
		_segments.size(), links, _prefabs.size(), COUNT])
	for i in COUNT:
		_spawn(i)


func _load_roads() -> void:
	var res: Resource = load(ROADS)
	if res == null:
		return
	var pts: PackedVector3Array = res.points
	if pts.size() < 4:
		return
	for i in range(0, pts.size() - 1, 2):
		_segments.append([pts[i], pts[i + 1]])
	for i in _segments.size():
		var a: Vector3 = (_segments[i] as Array)[0]
		var b: Vector3 = (_segments[i] as Array)[1]
		for side in 2:
			var p: Vector3 = a if side == 0 else b
			var near := []
			for j in _segments.size():
				if j == i:
					continue
				for t in 2:
					var q: Vector3 = (_segments[j] as Array)[t]
					if p.distance_to(q) < LINK_RADIUS:
						near.append([j, t])
			_neighbors.append(near)


func _load_prefabs() -> void:
	var dir := DirAccess.open(CAR_DIR)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".tscn"):
			continue
		var scene: PackedScene = load(CAR_DIR + "/" + f)
		if scene != null:
			_prefabs.append({"name": f, "scene": scene})


func _spawn(i: int) -> void:
	var pick := _random_segment()
	var idx: int = pick[0]
	var side: int = pick[1]
	var seg: Array = _segments[idx]

	var body := CharacterBody3D.new()
	body.name = "NPC%d" % i
	body.set_script(preload("res://scripts/npc_car.gd"))
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.4, 4.2)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	var entry: Dictionary = _prefabs[i % _prefabs.size()]
	var visual: Node3D = (entry["scene"] as PackedScene).instantiate()
	visual.name = "Visual"
	body.add_child(visual)

	add_child(body)
	body.manager = self
	body.front_sign = float(FRONT.get(entry["name"], -1.0))
	body.segment = idx
	body.side = side
	body.global_position = seg[1 - side]
	body.target = seg[side]
	body.speed = randf_range(10.0, 14.0)
	body.rotation.y = atan2(-(seg[side] as Vector3).x + (seg[1 - side] as Vector3).x,
		-(seg[side] as Vector3).z + (seg[1 - side] as Vector3).z)
	if body.front_sign > 0.0:
		body.rotation.y += PI


func _random_segment() -> Array:
	var player := get_parent().get_node_or_null("Car")
	var pp := Vector3.ZERO
	if player != null and player is Node3D:
		pp = (player as Node3D).global_position
	for _i in 60:
		var idx: int = randi() % _segments.size()
		var seg: Array = _segments[idx]
		var center: Vector3 = ((seg[0] as Vector3) + (seg[1] as Vector3)) * 0.5
		var side: int = randi() % 2
		if center.distance_to(pp) > SAFE_RADIUS and \
				not (_neighbors[idx * 2 + side] as Array).is_empty():
			return [idx, side]
	return [0, 0]


## Appelé par un NPC quand il atteint le bout de sa route ou reste bloqué.
func retarget(car: Node) -> void:
	var idx: int = int(car.get("segment"))
	var side: int = int(car.get("side"))
	if idx < 0 or idx >= _segments.size():
		idx = randi() % _segments.size()
		side = randi() % 2
	var seg: Array = _segments[idx]
	var here: Vector3 = seg[side]
	var came_from: Vector3 = seg[1 - side]
	var incoming: Vector3 = (here - came_from).normalized()

	# On ne repart jamais sur le segment qu'on vient de parcourir, et on
	# écarte les virages en demi-tour (angle trop fermé).
	var options := []
	for n in (_neighbors[idx * 2 + side] as Array):
		var j: int = n[0]
		if j == idx:
			continue
		var t: int = n[1]
		var nseg: Array = _segments[j]
		var outgoing: Vector3 = ((nseg[1 - t] as Vector3) - here).normalized()
		if incoming.dot(outgoing) > -0.2:
			options.append(n)
	if options.is_empty():
		# Dernier recours : faire demi-tour sur la route courante.
		car.set("segment", idx)
		car.set("side", 1 - side)
		car.set("target", seg[1 - side])
		return
	var pick: Array = options[randi() % options.size()]
	var next_idx: int = pick[0]
	var next_side: int = 1 - int(pick[1])
	var next_seg: Array = _segments[next_idx]
	car.set("segment", next_idx)
	car.set("side", next_side)
	car.set("target", next_seg[next_side])

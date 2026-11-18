class_name CarCatalog
extends RefCounted

## Catalogue des voitures jouables.
##
## Chaque entrée décrit :
##  - le modèle 3D et la façon de construire ses matériaux,
##  - son orientation dans le fichier source,
##  - ses limites exactes (boîte englobante réelle, mesurée sur les sommets),
##  - ses réglages de conduite.
##
## up / length indiquent quel axe du fichier source correspond à la hauteur
## et à la longueur de la voiture. nose vaut -1 si le nez pointe vers l'axe
## négatif, +1 sinon.

const CARS := [
	{
		"id": "aveo",
		"ratings": Vector3(0.35, 0.35, 0.35),
		"name": "Chevrolet Aveo",
		"tagline": "La berline pour apprendre",
		"model": "res://assets/cars/aveo/aveo.obj",
		"paint": "obj",
		"color": Color(0.68, 0.03, 0.06),
		"up": "z",
		"length": "x",
		"nose": -1,
		"bounds_min": Vector3(-3796.554, -641.078, -1304.242),
		"bounds_size": Vector3(7827.219, 3936.054, 2859.042),
		"target_length": 4.05,
		"wheels": {
			"parts": ["gum", "silver", "chrome"],
			"centers": [
				Vector3(-0.76, 0.31, -1.13), Vector3(0.76, 0.31, -1.13),
				Vector3(-0.76, 0.31, 1.41), Vector3(0.76, 0.31, 1.41),
			],
			"radius": 0.34,
			"spin_radius": 0.307,
			"half_width": 0.19,
		},
		"stats": {
			"max_speed": 33.0,
			"accel": 17.5,
			"grip": 12.0,
			"handbrake_grip": 2.60,
			"steer_rate": 55.0,
			"handbrake_steer": 85.0,
		},
	},
	{
		"id": "datsun240z",
		"ratings": Vector3(0.55, 0.55, 0.60),
		"name": "Datsun 240Z",
		"tagline": "Classique, léger, joueur",
		"model": "res://assets/cars/datsun240z/1971 Datsun 240Z S30.obj",
		"paint": "mtl",
		"color": Color(0.75, 0.42, 0.08),
		"up": "y",
		"length": "z",
		"nose": -1,
		"bounds_min": Vector3(8.5774, 0.0, -36.0306),
		"bounds_size": Vector3(7.4837, 5.01359, 17.4831),
		"target_length": 4.15,
		"wheels": {
			"parts": ["tire", "rim"],
			"centers": [
				Vector3(-0.76, 0.31, -1.17), Vector3(0.76, 0.31, -1.17),
				Vector3(-0.75, 0.31, 1.17), Vector3(0.75, 0.31, 1.17),
			],
			"radius": 0.33,
			"spin_radius": 0.310,
			"half_width": 0.17,
		},
		"stats": {
			"max_speed": 36.0,
			"accel": 18.5,
			"grip": 11.0,
			"handbrake_grip": 2.50,
			"steer_rate": 58.0,
			"handbrake_steer": 90.0,
		},
	},
	{
		"id": "silvia_s13",
		"ratings": Vector3(0.70, 0.50, 0.95),
		"name": "Nissan Silvia S13",
		"tagline": "La reine du drift",
		"model": "res://assets/cars/silvia_s13/1992 Nissan Silvia K's DIA Selection Custom.obj",
		"paint": "mtl",
		"color": Color(0.62, 0.05, 0.09),
		"up": "y",
		"length": "z",
		"nose": -1,
		"bounds_min": Vector3(-53.8861, 1.00001, -2.78714),
		"bounds_size": Vector3(7.6437, 4.65406, 17.56904),
		"target_length": 4.47,
		"wheels": {
			"parts": ["nissanps"],
			"centers": [
				Vector3(-0.82, 0.30, -1.255), Vector3(0.82, 0.30, -1.255),
				Vector3(-0.82, 0.30, 1.14), Vector3(0.82, 0.30, 1.14),
			],
			"radius": 0.32,
			"spin_radius": 0.300,
			"half_width": 0.18,
		},
		"stats": {
			"max_speed": 37.0,
			"accel": 18.0,
			"grip": 9.8,
			"handbrake_grip": 2.40,
			"steer_rate": 62.0,
			"handbrake_steer": 96.0,
		},
	},
	{
		"id": "miata",
		"ratings": Vector3(0.40, 0.75, 0.85),
		"name": "Mazda MX-5 Miata",
		"tagline": "Petite, vive, insaisissable",
		"model": "res://assets/cars/miata/mazda/miata.glb",
		"paint": "scene",
		"color": Color(0.85, 0.08, 0.07),
		"up": "y",
		"length": "z",
		"nose": 1,
		"bounds_min": Vector3(-0.904518, 0.112058, -1.878581),
		"bounds_size": Vector3(1.809053, 1.148595, 3.928775),
		"target_length": 3.95,
		"wheels": {
			"nodes": [
				"RLA_miata", "RLA_miata_001", "RLA_miata_002", "RLA_miata_003",
				"Object_4_001", "Object_4_002", "Object_4_003", "Object_4_004",
				"amdb11_brakedisc_FR_001", "amdb11_brakedisc_FR_002",
				"amdb11_brakedisc_FR_003", "amdb11_brakedisc_FR_004",
			],
			"exclude": ["caliper"],
			"centers": [
				Vector3(-0.70, 0.30, -1.16), Vector3(0.70, 0.30, -1.16),
				Vector3(-0.70, 0.30, 1.11), Vector3(0.70, 0.30, 1.11),
			],
			"radius": 0.32,
			"spin_radius": 0.302,
			"half_width": 0.18,
		},
		"stats": {
			"max_speed": 32.0,
			"accel": 19.5,
			"grip": 12.5,
			"handbrake_grip": 2.50,
			"steer_rate": 66.0,
			"handbrake_steer": 100.0,
		},
	},
	{
		"id": "skyline",
		"ratings": Vector3(0.95, 0.90, 0.45),
		"name": "Nissan Skyline GT-R",
		"tagline": "Lourde, rapide, impitoyable",
		"model": "res://assets/cars/skyline/model/model.dae",
		"paint": "pbr",
		"pbr_dir": "res://assets/cars/skyline/model/textures",
		"color": Color(0.16, 0.34, 0.72),
		"up": "y",
		"length": "z",
		"nose": 1,
		"bounds_min": Vector3(-52.36231, -5.218473, -136.4514),
		"bounds_size": Vector3(106.9929, 77.33276, 270.674),
		"target_length": 4.60,
		"wheels": {
			"nodes": ["Wheels"],
			"centers": [
				Vector3(-0.75, 0.31, -1.52), Vector3(0.75, 0.31, -1.52),
				Vector3(-0.75, 0.31, 1.17), Vector3(0.75, 0.31, 1.17),
			],
			"radius": 0.33,
			"spin_radius": 0.312,
			"half_width": 0.19,
		},
		"stats": {
			"max_speed": 40.0,
			"accel": 21.0,
			"grip": 13.5,
			"handbrake_grip": 3.00,
			"steer_rate": 50.0,
			"handbrake_steer": 78.0,
		},
	},
]


static func all() -> Array:
	return CARS


static func by_index(index: int) -> Dictionary:
	return CARS[posmod(index, CARS.size())]


static func count() -> int:
	return CARS.size()


static func index_of_id(id: String) -> int:
	for i in CARS.size():
		if CARS[i]["id"] == id:
			return i
	return 0

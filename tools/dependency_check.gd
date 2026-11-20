extends SceneTree

## Parcourt récursivement les dépendances des ressources chargées au runtime et
## signale celles qui manqueraient sur un clone frais.

const ROOTS := [
	"res://scenes/main_menu.tscn",
	"res://low-poly-city/city.tscn",
	"res://low-poly-city/city_collision.res",
	"res://low-poly-city/city_ground.res",
	"res://low-poly-city/city_roads.res",
	"res://assets/cars/aveo/aveo.obj",
	"res://assets/cars/datsun240z/1971 Datsun 240Z S30.obj",
	"res://assets/cars/silvia_s13/1992 Nissan Silvia K's DIA Selection Custom.obj",
	"res://assets/cars/miata/mazda/miata.glb",
	"res://assets/cars/skyline/model/skyline_compact.scn",
	"res://generic_passenger_car_pack.glb",
	"res://assets/audio/music/menu_theme.wav",
	"res://assets/audio/music/game_theme.wav",
]

var _seen := {}
var _total := 0


func _initialize() -> void:
	var missing: Array[String] = []
	for path in ROOTS:
		_walk(String(path), missing)
	print("dépendances visitées: %d" % _total)
	if missing.is_empty():
		print("OK: aucune dépendance manquante")
	else:
		print("MANQUANTS (%d):" % missing.size())
		for path in missing:
			print("  " + path)
	quit()


func _walk(path: String, missing: Array[String]) -> void:
	if path.is_empty() or _seen.has(path):
		return
	_seen[path] = true
	_total += 1
	if not ResourceLoader.exists(path):
		missing.append(path)
		return
	for dep in ResourceLoader.get_dependencies(path):
		var dep_path := String(dep)
		# Godot 4.4+ renvoie parfois "uid://xxx::::res://chemin/reel.png".
		var marker := dep_path.rfind("::::")
		if marker != -1:
			dep_path = dep_path.substr(marker + 4)
		if dep_path.begins_with("uid://"):
			continue
		_walk(dep_path, missing)

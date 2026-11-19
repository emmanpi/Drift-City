extends SceneTree

## Découpe `generic_passenger_car_pack.glb` en 10 voitures NPC indépendantes.
##
## Le pack contient 10 corps de voiture et 40 roues disposés en grille dans un
## repère FBX Z-up, à une échelle de ~1000 unités = 1 m. Pour chaque corps on
## prend les 4 roues les plus proches, on annule la rotation de mise en page,
## on recentre au sol et on passe en mètres. Les modèles sont sauvés dans
## `npc_cars/` et instanciés par scripts/npc_traffic.gd.

const SRC := "res://generic_passenger_car_pack.glb"
const OUT_DIR := "res://npc_cars"
const SCALE := 0.001

const BODIES := [
	"Compact Body", "Coupe Body", "Hatchback Body", "minivan body",
	"Offroad Body", "Pickup Body", "Sedan Body", "Sport body",
	"SUV Body", "Wagon Body",
]


func _initialize() -> void:
	var packed: PackedScene = load(SRC)
	if packed == null:
		push_error("Pack NPC introuvable : " + SRC)
		quit(1)
		return
	var root := packed.instantiate()
	var r: Node = root
	while r.get_child_count() == 1:
		r = r.get_child(0)

	var wheels := []
	for c in r.get_children():
		if String(c.name).begins_with("Wheel") and c is Node3D:
			wheels.append(c)
	print("corps=%d roues=%d" % [BODIES.size(), wheels.size()])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for body_name in BODIES:
		var body: Node3D = r.get_node(body_name)
		if body == null:
			push_warning("Corps introuvable : " + body_name)
			continue
		var chosen := _nearest_wheels(body, wheels)
		var car := _build_car(body, chosen)
		var slug := String(body_name).to_lower().replace(" ", "_").replace("body", "car")
		var out := OUT_DIR + "/" + slug + ".tscn"
		var ps := PackedScene.new()
		ps.pack(car)
		var err := ResourceSaver.save(ps, out)
		var box := _box(car, Transform3D.IDENTITY.scaled(Vector3.ONE * SCALE))
		print("%-16s -> %-28s roues=%d taille=(%.2f, %.2f, %.2f) err=%d" % [
			body_name, out.get_file(), chosen.size(),
			box.size.x, box.size.y, box.size.z, err])
		car.free()
	root.free()
	quit()


func _nearest_wheels(body: Node3D, wheels: Array) -> Array:
	var origin := body.transform.origin
	var scored := []
	for w in wheels:
		var p := (w as Node3D).transform.origin
		var d := Vector2(p.x - origin.x, p.z - origin.z).length()
		scored.append([d, w])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(4, scored.size()):
		out.append(scored[i][1])
	return out


func _build_car(body: Node3D, wheels: Array) -> Node3D:
	var yaw := body.transform.basis.get_euler().y
	var rot := Basis(Vector3.UP, -yaw)
	var xf := Transform3D(rot, -(rot * body.transform.origin))
	# Certains corps du pack sont modélisés le long de X (ex. Coupe) : on
	# aligne toutes les voitures sur Z pour que le NPC avance nez en avant.
	var bb := _box(body, xf)
	if bb.size.x > bb.size.z:
		xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO) * xf
	var meshes := []
	_collect_meshes(body, xf, meshes)
	for w in wheels:
		_collect_meshes(w, xf, meshes)

	var car := Node3D.new()
	car.name = "NpcCar"
	car.scale = Vector3.ONE * SCALE
	for e in meshes:
		var mi := MeshInstance3D.new()
		mi.name = e["name"]
		mi.mesh = e["mesh"]
		mi.transform = e["transform"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.add_child(mi)
		mi.owner = car

	var box := _box(car, Transform3D.IDENTITY)
	var c := box.get_center()
	var shift := Vector3(-c.x, -box.position.y, -c.z)
	for mi in car.get_children():
		(mi as MeshInstance3D).transform.origin += shift
	return car


func _collect_meshes(node: Node, parent: Transform3D, out: Array) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append({
			"name": node.name,
			"mesh": (node as MeshInstance3D).mesh,
			"transform": xf,
		})
	for c in node.get_children():
		_collect_meshes(c, xf, out)


func _box(node: Node, parent: Transform3D) -> AABB:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		for s in (node as MeshInstance3D).mesh.get_surface_count():
			var a: Array = (node as MeshInstance3D).mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for p in v:
				var w := xf * p
				if first:
					box = AABB(w, Vector3.ZERO)
					first = false
				box = box.expand(w)
	for c in node.get_children():
		var b := _box(c, xf)
		if b.size == Vector3.ZERO:
			continue
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box

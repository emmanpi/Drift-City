extends SceneTree

## Remplace les textures de la ville par deux matériaux unis : un gris sombre
## pour la chaussée et les trottoirs, un gris clair pour les immeubles.
## Découpe pour cela chaque surface en deux jeux d'indices :
##   - « sol »      : triangles horizontaux au niveau de la rue ;
##   - « batiment » : murs, toits, tout le reste.
## Le résultat ne dépend plus d'aucune texture (ni des 5 atlas 4096²).

const SRC := "res://gm-bigcity/gm_bigcity_city.res"
const DST := "res://gm-bigcity/gm_bigcity_city_grey.res"

## Altitude (repère du fichier OBJ) sous laquelle un triangle horizontal est
## considéré comme de la chaussée. La rue est à y = 1.2, les toits bien plus haut.
const GROUND_MAX_Y := 2.5
## Composante verticale de la normale au-delà de laquelle un triangle est
## considéré comme horizontal.
const UP := 0.7


func _initialize() -> void:
	var src: ArrayMesh = load(SRC)
	if src == null:
		push_error("Mesh introuvable : " + SRC)
		quit(1)
		return

	var out := ArrayMesh.new()
	var ground_total := 0
	var wall_total := 0
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var ground := PackedInt32Array()
		var wall := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var i0 := idx[t]
			var i1 := idx[t + 1]
			var i2 := idx[t + 2]
			var p0 := verts[i0]
			var p1 := verts[i1]
			var p2 := verts[i2]
			var ny := (p1 - p0).cross(p2 - p0).normalized().y
			var y := (p0.y + p1.y + p2.y) / 3.0
			if ny >= UP and y <= GROUND_MAX_Y:
				ground.append(i0)
				ground.append(i1)
				ground.append(i2)
			else:
				wall.append(i0)
				wall.append(i1)
				wall.append(i2)

		if not ground.is_empty():
			var a := arrays.duplicate()
			a[Mesh.ARRAY_INDEX] = ground
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			out.surface_set_name(out.get_surface_count() - 1, "sol_%d" % s)
			ground_total += ground.size() / 3
		if not wall.is_empty():
			var a := arrays.duplicate()
			a[Mesh.ARRAY_INDEX] = wall
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			out.surface_set_name(out.get_surface_count() - 1, "batiment_%d" % s)
			wall_total += wall.size() / 3

	var err := ResourceSaver.save(out, DST)
	print("sol=%d triangles, batiments=%d triangles, surfaces=%d, save=%d" % [
		ground_total, wall_total, out.get_surface_count(), err])
	quit()

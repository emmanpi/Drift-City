extends SceneTree

## Réoriente les normales de la ville cuite selon la convention de Godot.
##
## Godot considère comme face avant un triangle dont les sommets tournent dans
## le sens horaire : sa normale vaut donc -(p1 - p0) × (p2 - p0). L'ancien bake
## retournait toutes les normales du GLB en supposant l'inverse, ce qui éclairait
## la ville « par en dessous » (sol sombre, dessous des toits éclairés).
##
## Usage : Godot --headless --path . --script res://tools/fix_city_normals.gd

const SCENE := "res://low-poly-city/city.tscn"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	var fixed := 0
	var total := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var res := _fix_mesh(mi as MeshInstance3D)
		fixed += res.x
		total += res.y
	print("normales retournées : %d / %d sommets" % [fixed, total])
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, SCENE)
	print("sauvegarde : ", error_string(err))
	root.free()
	quit()


func _fix_mesh(mi: MeshInstance3D) -> Vector2i:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return Vector2i.ZERO
	var dst := ArrayMesh.new()
	dst.resource_name = src.resource_name
	var fixed := 0
	var total := 0
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if not n.is_empty():
			# Vote par sommet : un sommet partagé suit la majorité de ses triangles.
			var vote := PackedFloat32Array()
			vote.resize(v.size())
			var tri_count := idx.size() / 3 if not idx.is_empty() else v.size() / 3
			for k in tri_count:
				var i0 := idx[k * 3] if not idx.is_empty() else k * 3
				var i1 := idx[k * 3 + 1] if not idx.is_empty() else k * 3 + 1
				var i2 := idx[k * 3 + 2] if not idx.is_empty() else k * 3 + 2
				var front := -(v[i1] - v[i0]).cross(v[i2] - v[i0])
				if front.length_squared() < 1e-12:
					continue
				for i in [i0, i1, i2]:
					vote[i] += signf(n[i].dot(front))
			for i in n.size():
				if vote[i] < 0.0:
					n[i] = -n[i]
					fixed += 1
			total += n.size()
			arrays[Mesh.ARRAY_NORMAL] = n
		dst.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays)
		dst.surface_set_material(s, src.surface_get_material(s))
		dst.surface_set_name(s, src.surface_get_name(s))
	mi.mesh = dst
	return Vector2i(fixed, total)

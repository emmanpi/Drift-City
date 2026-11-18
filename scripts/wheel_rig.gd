class_name WheelRig
extends RefCounted

## Sépare les roues du reste de la carrosserie et crée des pivots animables.
##
## Les modèles OBJ exposent leurs roues via des surfaces matérielles (gum,
## tire, rim...), tandis que les scènes GLB/DAE ont des nœuds dédiés. Dans les
## deux cas, on ne garde que les triangles situés dans un cylindre autour de
## chaque centre de roue : les matériaux partagés avec la carrosserie (chrome,
## gum...) ne sont donc pas arrachés par erreur.
##
## Le découpage se fait dans l'espace local de la voiture (nez vers -Z, essieu
## selon X), après application du transform du wrapper. Le corps reste dans
## l'espace du modèle source ; le rig de roues est ajouté à la racine, à côté
## du wrapper, pour que ses pivots travaillent directement en coordonnées
## voiture (mètres).
##
## Optimisation : les tableaux de sommets/normales/UV ne sont jamais recopiés.
## Chaque roue réutilise les tableaux de la surface d'origine et ne reçoit
## qu'un sous-ensemble d'indices ; c'est le transform du MeshInstance qui la
## ramène autour de son pivot. Le découpage ne coûte donc qu'un test par
## triangle au lieu de quinze copies d'attributs.


static func attach(root: Node3D, wrapper: Node3D, spec: Dictionary) -> Array:
	var data: Dictionary = spec.get("wheels", {})
	if data.is_empty():
		return []

	var centers: Array = data.get("centers", [])
	if centers.size() != 4:
		return []

	var radius: float = float(data.get("radius", 0.32))
	var half_width: float = float(data.get("half_width", 0.18))
	var parts: Array = data.get("parts", [])
	var nodes: Array = data.get("nodes", [])
	var excludes: Array = data.get("exclude", [])

	var xf := wrapper.transform

	var collected := {}
	for i in 4:
		collected[i] = []

	# Les coordonnées restent dans l'espace du modèle source pendant le
	# parcours ; xf les ramène dans l'espace voiture pour le test du cylindre.
	for child in wrapper.get_children():
		_extract(child, Transform3D.IDENTITY, xf, centers, radius, half_width, parts, nodes, excludes, collected)

	var rig := Node3D.new()
	rig.name = "WheelRig"
	root.add_child(rig)

	var wheels: Array = []
	for i in 4:
		var groups: Array = collected[i]
		if groups.is_empty():
			continue
		var center: Vector3 = centers[i]
		var steer := Node3D.new()
		steer.name = "Wheel%d" % i
		steer.position = center
		rig.add_child(steer)
		var spin := Node3D.new()
		spin.name = "Spin"
		steer.add_child(spin)

		for g in groups:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g["arrays"])
			mesh.surface_set_material(0, g["mat"])

			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = mesh
			# Les sommets sont restés dans l'espace source : ce transform les
			# amène autour du centre de roue, dans l'espace voiture.
			var gxf: Transform3D = g["xf"]
			mi.transform = Transform3D(gxf.basis, gxf.origin - center)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spin.add_child(mi)

		wheels.append({
			"pivot": steer,
			"spin": spin,
			"front": center.z < 0.0,
			"radius": float(data.get("spin_radius", radius)),
			"center": center,
		})

	return wheels


static func _extract(node: Node, parent_xf: Transform3D, xf: Transform3D, centers: Array, radius: float, half_width: float, parts: Array, nodes: Array, excludes: Array, collected: Dictionary) -> void:
	var node_xf := parent_xf
	if node is Node3D:
		node_xf = parent_xf * (node as Node3D).transform

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var nm := String(mi.name).to_lower()
		var node_hit := _matches_exact(nm, nodes)
		_extract_mesh(mi, node_xf, xf, centers, radius, half_width, parts, node_hit, excludes, collected)

	for child in node.get_children():
		_extract(child, node_xf, xf, centers, radius, half_width, parts, nodes, excludes, collected)


static func _matches_exact(name_lower: String, patterns: Array) -> bool:
	for p in patterns:
		if name_lower == String(p).to_lower():
			return true
	return false


static func _matches(name_lower: String, patterns: Array) -> bool:
	for p in patterns:
		if name_lower.contains(String(p).to_lower()):
			return true
	return false


static func _extract_mesh(mi: MeshInstance3D, node_xf: Transform3D, xf: Transform3D, centers: Array, radius: float, half_width: float, parts: Array, node_hit: bool, excludes: Array, collected: Dictionary) -> void:
	var mesh: Mesh = mi.mesh
	var full_xf := xf * node_xf
	var flip := full_xf.basis.determinant() < 0.0
	var removed_any := false
	var rebuilt_arrays: Array = []
	var rebuilt_materials: Array = []

	for si in mesh.get_surface_count():
		var sname := String(mesh.surface_get_name(si)).to_lower()
		var candidate := node_hit or _matches(sname, parts)
		if candidate and _matches(sname, excludes):
			candidate = false

		var arr := mesh.surface_get_arrays(si)
		var verts = arr[Mesh.ARRAY_VERTEX]
		if verts == null or verts.size() == 0:
			continue

		var mat := _surface_material(mi, mesh, si)

		if not candidate:
			rebuilt_arrays.append(arr)
			rebuilt_materials.append(mat)
			continue

		var idx: PackedInt32Array
		var raw_idx = arr[Mesh.ARRAY_INDEX]
		if raw_idx != null and raw_idx.size() > 0:
			idx = raw_idx
		else:
			idx = PackedInt32Array()
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i

		# Quatre tableaux locaux plutôt qu'un tableau de tableaux : évite une
		# écriture de Variant dans un Array à chaque triangle.
		var w0 := PackedInt32Array()
		var w1 := PackedInt32Array()
		var w2 := PackedInt32Array()
		var w3 := PackedInt32Array()
		var keep := PackedInt32Array()

		var varr := verts as PackedVector3Array
		var inv3 := 1.0 / 3.0
		for t in range(0, idx.size(), 3):
			var i0 := idx[t]
			var i1 := idx[t + 1]
			var i2 := idx[t + 2]
			# Centroïde directement ramené dans l'espace voiture : un seul
			# transform par triangle, aucun tableau de sommets intermédiaire.
			var centroid := full_xf * ((varr[i0] + varr[i1] + varr[i2]) * inv3)
			var wheel := _wheel_at(centroid, centers, radius, half_width)
			if wheel < 0:
				keep.append(i0)
				keep.append(i1)
				keep.append(i2)
				continue

			removed_any = true
			var a := i0
			var b := i1
			var c := i2
			if flip:
				b = i2
				c = i1
			if wheel == 0:
				w0.append(a)
				w0.append(b)
				w0.append(c)
			elif wheel == 1:
				w1.append(a)
				w1.append(b)
				w1.append(c)
			elif wheel == 2:
				w2.append(a)
				w2.append(b)
				w2.append(c)
			else:
				w3.append(a)
				w3.append(b)
				w3.append(c)

		var groups := [w0, w1, w2, w3]
		for w in 4:
			var dst: PackedInt32Array = groups[w]
			if dst.size() == 0:
				continue
			var out: Array = arr.duplicate(false)
			out[Mesh.ARRAY_INDEX] = dst
			collected[w].append({"arrays": out, "mat": mat, "xf": full_xf})

		if keep.size() == 0:
			continue
		if keep.size() == idx.size():
			rebuilt_arrays.append(arr)
		else:
			var out2: Array = arr.duplicate(false)
			out2[Mesh.ARRAY_INDEX] = keep
			rebuilt_arrays.append(out2)
		rebuilt_materials.append(mat)

	if not removed_any:
		return

	var rebuilt := ArrayMesh.new()
	for i in rebuilt_arrays.size():
		var a: Array = rebuilt_arrays[i]
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, rebuilt_materials[i])

	for si in mesh.get_surface_count():
		mi.set_surface_override_material(si, null)
	mi.mesh = rebuilt
	if rebuilt.get_surface_count() == 0:
		mi.visible = false


static func _surface_material(mi: MeshInstance3D, mesh: Mesh, si: int) -> Material:
	var mat: Material = mi.get_surface_override_material(si)
	if mat == null:
		mat = mesh.surface_get_material(si)
	return mat


static func _wheel_at(p: Vector3, centers: Array, radius: float, half_width: float) -> int:
	var best := -1
	var best_d := INF
	var radius_sq := radius * radius
	var half_sq := half_width * half_width
	for i in 4:
		var c: Vector3 = centers[i]
		var dx := p.x - c.x
		if dx * dx > half_sq:
			continue
		var dy := p.y - c.y
		var dz := p.z - c.z
		var d := dy * dy + dz * dz
		if d > radius_sq:
			continue
		if d < best_d:
			best_d = d
			best = i
	return best

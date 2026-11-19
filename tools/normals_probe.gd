extends SceneTree

## Vérifie l'orientation des normales du mesh de ville cuit :
## une normale opposée à la normale géométrique du triangle signifie que la
## lumière est calculée « à l'envers » sur cette face.

const SCENE := "res://low-poly-city/city.tscn"

var up := 0
var down := 0
var flipped := 0
var total := 0
var up_area := 0.0
var down_area := 0.0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	_scan(root, Transform3D.IDENTITY)
	root.free()
	print("triangles=%d  normale Y>0.5 : %d (surface %.0f m²)" % [total, up, up_area])
	print("normale Y<-0.5 : %d (surface %.0f m²)" % [down, down_area])
	print("normales inversées (dot<0) : %d / %d = %.1f%%" % [
		flipped, total, 100.0 * flipped / maxf(1.0, total)])
	quit()


func _scan(node: Node, parent: Transform3D) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D:
		_read(node as MeshInstance3D, xf)
	for c in node.get_children():
		_scan(c, xf)


func _read(mi: MeshInstance3D, xf: Transform3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		if idx == null or nrm == null:
			continue
		var nb := idx.size() / 3
		for k in nb:
			var i0: int = idx[k * 3]
			var i1: int = idx[k * 3 + 1]
			var i2: int = idx[k * 3 + 2]
			var p0 := xf * v[i0]
			var p1 := xf * v[i1]
			var p2 := xf * v[i2]
			var gn := (p1 - p0).cross(p2 - p0)
			if gn.length_squared() < 1e-10:
				continue
			gn = gn.normalized()
			var sn := (xf.basis * nrm[i0]).normalized()
			total += 1
			if sn.dot(gn) < -0.3:
				flipped += 1
			var area := (p1 - p0).cross(p2 - p0).length() * 0.5
			if sn.y > 0.5:
				up += 1
				up_area += area
			elif sn.y < -0.5:
				down += 1
				down_area += area

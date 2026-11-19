extends SceneTree

func _initialize() -> void:
	var p: PackedScene = load("res://low-poly-city/city.tscn")
	var r := p.instantiate()
	var seen := {}
	_walk(r, seen)
	r.free()
	for k in seen.keys():
		print(k)
	quit()

func _walk(n: Node, seen: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for s in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				var key := "%s cull=%d double=%s tex=%s rough=%.2f" % [
					sm.resource_name, sm.cull_mode,
					sm.cull_mode == BaseMaterial3D.CULL_DISABLED,
					sm.albedo_texture != null, sm.roughness]
				seen[key] = true
	for c in n.get_children():
		_walk(c, seen)

extends SceneTree

const SCENE := "res://generic_passenger_car_pack.glb"

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root := packed.instantiate()
	get_root().add_child(root)
	var r: Node = root
	while r.get_child_count() == 1:
		r = r.get_child(0)
	for c in r.get_children():
		if not (c is Node3D):
			continue
		var n := String(c.name)
		if n.begins_with("Wheel") or n.contains("Body") or n.contains("body"):
			var t := (c as Node3D).transform
			var cp := ""
			for g in c.get_children():
				if g is Node3D:
					cp += " | %s: o=%s s=%s" % [g.name, (g as Node3D).transform.origin, (g as Node3D).transform.basis.get_scale()]
			print("%-20s o=%-24s s=%-18s%s" % [n, t.origin, t.basis.get_scale(), cp])
	root.free()
	quit()

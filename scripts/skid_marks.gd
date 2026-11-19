class_name SkidMarks
extends Node3D

## Persistent tyre marks.
##
## Each rear wheel leaves a narrow rubber strip made of short overlapping
## quads laid on the actual ground height. Segments are short (0.13 m) and
## follow the wheel's real travel direction, so a drift draws two smooth,
## parallel curves instead of wide squares pivoting around the car.

const MAX_MARKS := 2600
const MARK_LIFE := 9.0
const MARK_STEP := 0.13
## Width of one tyre contact patch, in metres.
const MARK_WIDTH := 0.19
## Small overlap hides the join between two consecutive quads in a turn.
const MARK_OVERLAP := 0.09
const GROUND_Y := 0.035
const OPACITY := 0.72

var _mm: MultiMesh
var _ages := PackedFloat32Array()
var _head := 0
## Last emitted world position of each wheel.
var _last := {}
var _ready_done := false


func _ready() -> void:
	setup()


func setup() -> void:
	if _ready_done:
		return
	_ready_done = true
	top_level = true
	global_transform = Transform3D.IDENTITY

	var mesh := _build_quad()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = MAX_MARKS

	var mi := MultiMeshInstance3D.new()
	mi.name = "Marks"
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _build_material()
	add_child(mi)

	_ages.resize(MAX_MARKS)
	var hidden := Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0.0, -200.0, 0.0))
	for i in MAX_MARKS:
		_mm.set_instance_transform(i, hidden)
		_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))


func _build_quad() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	# Local X = tyre width, local Z = travel direction.
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# Dark rubber; the per-instance alpha fades the mark over time.
	mat.albedo_color = Color(0.045, 0.042, 0.048, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat


## pos is the wheel contact point, already placed on (or just above) the road.
func add_point(id: int, pos: Vector3) -> void:
	if not _ready_done:
		return
	if not _last.has(id):
		_last[id] = pos
		return
	var last: Vector3 = _last[id]
	var delta := pos - last
	delta.y = 0.0
	var dist := delta.length()
	if dist < MARK_STEP:
		return
	# Teleport / reset: start a fresh line instead of drawing across the map.
	if dist > 2.5:
		_last[id] = pos
		return

	var angle := atan2(delta.x, delta.z)
	var mid := (last + pos) * 0.5
	mid.y = pos.y
	_emit(mid, angle, dist + MARK_OVERLAP)
	_last[id] = pos


func reset() -> void:
	_last.clear()


func _emit(pos: Vector3, angle: float, length: float) -> void:
	var i := _head
	_head = (_head + 1) % MAX_MARKS
	var basis := Basis(Vector3.UP, angle).scaled(Vector3(MARK_WIDTH, 1.0, length))
	_mm.set_instance_transform(i, Transform3D(basis, pos))
	_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, OPACITY))
	_ages[i] = MARK_LIFE


func _process(delta: float) -> void:
	if not _ready_done:
		return
	for i in MAX_MARKS:
		var age := _ages[i]
		if age <= 0.0:
			continue
		age = maxf(age - delta, 0.0)
		_ages[i] = age
		_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, OPACITY * age / MARK_LIFE))

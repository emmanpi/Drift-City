extends Control

const PREVIEW_SIZE := Vector2i(640, 190)
const BOLD_FONT := "res://assets/fonts/Rajdhani-Bold.ttf"
const SEMIBOLD_FONT := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const CITY_SCENE := "res://scenes/city.tscn"

var _index := 0
var _viewport: SubViewport
var _holder: Node3D
var _preview_car: Node3D
var _name_label: Label
var _tagline_label: Label
var _price_label: Label
var _wallet_label: Label
var _loading: Label
var _notice: Label
var _start_button: Button
var _bars := {}
var _gen := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_index = CarCatalog.index_of_id(Game.selected_car_id)
	_build_background()
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	if _holder:
		_holder.rotation.y += delta * 0.55


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.062, 0.085)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.12, 0.14, 0.2, 0.5)
	glow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	glow.offset_left = -420
	glow.offset_top = 120
	glow.offset_right = 420
	glow.offset_bottom = 520
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var accent := ColorRect.new()
	accent.color = Color(0.76, 0.07, 0.1)
	accent.set_anchors_preset(Control.PRESET_CENTER_TOP)
	accent.offset_left = -52
	accent.offset_top = 0
	accent.offset_right = 52
	accent.offset_bottom = 7
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	_wallet_label = _label("$ %d" % Game.wallet, 22, Color(0.5, 1.0, 0.6))
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wallet_label.offset_left = -260
	_wallet_label.offset_top = 18
	_wallet_label.offset_right = -32
	_wallet_label.offset_bottom = 52
	add_child(_wallet_label)

	var saved := _label("Progress saved automatically", 12, Color(0.58, 0.64, 0.72))
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	saved.offset_left = -260
	saved.offset_top = 54
	saved.offset_right = -32
	saved.offset_bottom = 74
	add_child(saved)


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(700, 0)
	center.add_child(box)

	var title := _label("DRIFT CITY", 54, Color.WHITE)
	title.add_theme_font_override("font", load(BOLD_FONT))
	box.add_child(title)
	box.add_child(_label("Slide through the city. No goal.", 17, Color(0.72, 0.76, 0.84)))

	_build_preview(box)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	var prev := _arrow("<")
	prev.pressed.connect(func(): _select(-1))
	row.add_child(prev)

	_name_label = _label("", 34, Color.WHITE)
	_name_label.add_theme_font_override("font", load(SEMIBOLD_FONT))
	_name_label.custom_minimum_size = Vector2(430, 44)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_label)

	var next := _arrow(">")
	next.pressed.connect(func(): _select(1))
	row.add_child(next)

	_tagline_label = _label("", 17, Color(0.86, 0.55, 0.3))
	box.add_child(_tagline_label)

	_price_label = _label("", 20, Color(0.55, 1.0, 0.62))
	box.add_child(_price_label)

	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.07, 0.095, 0.7)
	csb.set_corner_radius_all(18)
	csb.set_border_width_all(1)
	csb.border_color = Color(1, 1, 1, 0.08)
	csb.anti_aliasing = true
	csb.content_margin_left = 26
	csb.content_margin_right = 26
	csb.content_margin_top = 14
	csb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", csb)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(card)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 6)
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(stats)
	_bars["speed"] = _stat_row(stats, "Speed", Color(0.95, 0.35, 0.35))
	_bars["accel"] = _stat_row(stats, "Acceleration", Color(0.95, 0.72, 0.25))
	_bars["drift"] = _stat_row(stats, "Drift", Color(0.35, 0.8, 1.0))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	box.add_child(spacer)

	_start_button = Button.new()
	_start_button.text = "START ENGINE"
	_start_button.custom_minimum_size = Vector2(300, 58)
	_start_button.add_theme_font_size_override("font_size", 26)
	_start_button.add_theme_stylebox_override("normal", _pill(Color(0.80, 0.10, 0.12), Color(1, 1, 1, 0.0), 29))
	_start_button.add_theme_stylebox_override("hover", _pill(Color(0.95, 0.17, 0.18), Color(1, 1, 1, 0.30), 29))
	_start_button.add_theme_stylebox_override("pressed", _pill(Color(0.60, 0.07, 0.09), Color(1, 1, 1, 0.0), 29))
	_start_button.add_theme_stylebox_override("focus", _pill(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 29))
	_start_button.add_theme_color_override("font_color", Color.WHITE)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.pressed.connect(_start)
	box.add_child(_start_button)

	_loading = _label("Loading model...", 15, Color(0.7, 0.75, 0.85))
	_loading.custom_minimum_size = Vector2(0, 20)
	box.add_child(_loading)

	_notice = _label("", 15, Color(0.55, 1.0, 0.62))
	_notice.custom_minimum_size = Vector2(0, 18)
	box.add_child(_notice)

	var hint := _label("← → choose    Enter start    WASD drive    Space handbrake\nShift nitro    Mouse camera    Wheel zoom    R reset    Esc quit", 14, Color(0.6, 0.65, 0.73))
	box.add_child(hint)


func _build_preview(box: VBoxContainer) -> void:
	_viewport = SubViewport.new()
	_viewport.size = PREVIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.075, 0.085, 0.115)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-36, 40, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	_viewport.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, -140, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.6, 0.74, 1.0)
	_viewport.add_child(rim)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.095, 0.105, 0.13)
	fm.roughness = 0.9
	floor_mi.material_override = fm
	_viewport.add_child(floor_mi)

	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.1
	cam.far = 80.0
	cam.look_at_from_position(Vector3(4.9, 2.05, -5.6), Vector3(0, 0.72, 0), Vector3.UP)
	_viewport.add_child(cam)
	cam.current = true

	_holder = Node3D.new()
	_holder.rotation.y = 0.5
	_viewport.add_child(_holder)

	var frame := TextureRect.new()
	frame.texture = _viewport.get_texture()
	frame.custom_minimum_size = Vector2(PREVIEW_SIZE)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)


func _stat_row(grid: GridContainer, title: String, color: Color) -> ProgressBar:
	var label := _label(title, 16, Color(0.78, 0.82, 0.88))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size = Vector2(130, 0)
	grid.add_child(label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.01
	bar.custom_minimum_size = Vector2(280, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	grid.add_child(bar)
	return bar


func _arrow(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(54, 54)
	btn.add_theme_font_size_override("font_size", 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _pill(Color(0.10, 0.115, 0.15), Color(1, 1, 1, 0.12), 27))
	btn.add_theme_stylebox_override("hover", _pill(Color(0.17, 0.19, 0.24), Color(0.95, 0.22, 0.2, 0.9), 27))
	btn.add_theme_stylebox_override("pressed", _pill(Color(0.07, 0.08, 0.11), Color(0.95, 0.22, 0.2, 1.0), 27))
	btn.add_theme_stylebox_override("focus", _pill(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 27))
	return btn


func _pill(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.anti_aliasing = true
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _select(delta: int) -> void:
	_index = posmod(_index + delta, CarCatalog.count())
	_refresh()


func _refresh() -> void:
	_gen += 1
	var gen := _gen
	var spec := CarCatalog.by_index(_index)
	var id := String(spec["id"])
	var owned := Game.owns(id)
	_name_label.text = spec["name"]
	_tagline_label.text = spec["tagline"]
	_wallet_label.text = "$ %d" % Game.wallet
	if owned:
		_price_label.text = "Owned" if id != "aveo" else "Included"
		_price_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
		_start_button.text = "START ENGINE"
	else:
		_price_label.text = "Price  $%d" % int(spec.get("price", 0))
		_price_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.25))
		_start_button.text = "BUY  $%d" % int(spec.get("price", 0))
	_notice.text = ""
	var ratings: Vector3 = spec.get("ratings", Vector3(0.5, 0.5, 0.5))
	_bars["speed"].value = ratings.x
	_bars["accel"].value = ratings.y
	_bars["drift"].value = ratings.z
	_loading.text = "Loading model..."

	if _preview_car:
		_preview_car.queue_free()
		_preview_car = null

	await get_tree().process_frame
	if gen != _gen:
		return

	var car := CarModel.build(_preview_spec(spec))
	_holder.add_child(car)
	_preview_car = car
	_holder.rotation.y = 0.5
	_loading.text = ""


## L'aperçu est statique : inutile de découper les roues (opération coûteuse),
## la carrosserie complète suffit.
func _preview_spec(spec: Dictionary) -> Dictionary:
	var copy := spec.duplicate()
	copy.erase("wheels")
	return copy


func _start() -> void:
	var spec := CarCatalog.by_index(_index)
	var id := String(spec["id"])
	if not Game.owns(id):
		var price := int(spec.get("price", 0))
		if not Game.buy_car(id):
			var missing := maxi(price - Game.wallet, 0)
			_notice.text = "You need $%d more." % missing
			_notice.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
			return
		# Purchase successful: refresh the card and let the player start.
		_refresh()
		_notice.text = "Car unlocked! Press Enter to drive."
		_notice.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
		return
	Game.selected_car_id = id
	Game.save_progress()
	Loading.show_message("Loading city...")
	get_tree().change_scene_to_file(CITY_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_tree().quit()
	elif event.is_action_pressed("ui_left"):
		_select(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_select(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_start()
		get_viewport().set_input_as_handled()

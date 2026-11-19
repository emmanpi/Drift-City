extends CanvasLayer

const DRIFT_STEPS := [0.0, 50.0, 100.0, 200.0, 500.0]
const ACCENT := Color(0.94, 0.24, 0.2)
const PANEL_BG := Color(0.04, 0.05, 0.07, 0.72)
const PANEL_BORDER := Color(1, 1, 1, 0.08)
const SpeedometerScript := preload("res://scripts/speedometer.gd")

var speedo: Control
var wallet_label: Label
var drift_label: Label
var mult_label: Label
var handbrake_label: Label
var feedback: Label
var car_label: Label
var nitro_label: Label
var drift_bar: ProgressBar
var nitro_bar: ProgressBar
var fps_label: Label

var _drift_panel: Panel
var _limit: Control
var _limit_t := 0.0
var _feedback_t := 0.0
var _fps_frames := 0
var _fps_time := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Argent (pilule en haut à gauche).
	_panel(root, Control.PRESET_TOP_LEFT, 20, 16, 240, 62, 16)
	wallet_label = _label(root, 26)
	_place(wallet_label, Control.PRESET_TOP_LEFT, 38, 16, 230, 62)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wallet_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))

	# --- FPS (pilule en haut à droite, discrète).
	_panel(root, Control.PRESET_TOP_RIGHT, -128, 16, -20, 50, 14)
	fps_label = _label(root, 18)
	_place(fps_label, Control.PRESET_TOP_RIGHT, -128, 16, -20, 50)
	fps_label.text = "FPS --"
	fps_label.add_theme_color_override("font_color", Color(0.75, 0.86, 1.0))

	# --- Drift (carte centrée en haut).
	_drift_panel = _panel(root, Control.PRESET_CENTER_TOP, -200, 12, 200, 122, 18)
	drift_label = _label(root, 36)
	_place(drift_label, Control.PRESET_CENTER_TOP, -200, 16, 200, 60)
	drift_bar = _bar(root, Color(1.0, 0.78, 0.25))
	_place(drift_bar, Control.PRESET_CENTER_TOP, -160, 66, 160, 78)
	mult_label = _label(root, 26)
	_place(mult_label, Control.PRESET_CENTER_TOP, -200, 82, 200, 116)
	mult_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))

	handbrake_label = _label(root, 18)
	handbrake_label.text = "HANDBRAKE"
	handbrake_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.22))
	_place(handbrake_label, Control.PRESET_CENTER_TOP, -200, 126, 200, 152)

	feedback = _label(root, 54)
	_place(feedback, Control.PRESET_CENTER, -500, -62, 500, 8)
	feedback.modulate.a = 0.0

	var hint := _label(root, 15)
	hint.text = "WASD / Arrows    Space handbrake    Shift nitro    Mouse camera    Wheel zoom    R reset    Esc menu"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	_place(hint, Control.PRESET_BOTTOM_LEFT, 24, -42, 960, -14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# --- Compteur de vitesse (en bas à droite).
	speedo = SpeedometerScript.new()
	_place(speedo, Control.PRESET_BOTTOM_RIGHT, -268, -268, -24, -24)
	root.add_child(speedo)

	car_label = _label(root, 19)
	_place(car_label, Control.PRESET_BOTTOM_RIGHT, -440, -304, -24, -276)
	car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	car_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))

	nitro_label = _label(root, 14)
	nitro_label.text = "NITRO"
	_place(nitro_label, Control.PRESET_BOTTOM_RIGHT, -560, -98, -300, -76)
	nitro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nitro_label.add_theme_color_override("font_color", Color(0.45, 0.86, 1.0))

	nitro_bar = _bar(root, Color(0.25, 0.8, 1.0))
	_place(nitro_bar, Control.PRESET_BOTTOM_RIGHT, -560, -74, -300, -64)

	# --- Petit message de limite du monde (retour sur la dernière terre ferme).
	_limit = PanelContainer.new()
	_limit.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_limit.offset_left = -190
	_limit.offset_top = 74
	_limit.offset_right = 190
	_limit.offset_bottom = 128
	_limit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_limit.visible = false
	var limit_style := StyleBoxFlat.new()
	limit_style.bg_color = Color(0.05, 0.06, 0.09, 0.86)
	limit_style.set_corner_radius_all(12)
	limit_style.set_border_width_all(1)
	limit_style.border_color = Color(0.96, 0.62, 0.24, 0.5)
	limit_style.content_margin_left = 18
	limit_style.content_margin_right = 18
	limit_style.content_margin_top = 7
	limit_style.content_margin_bottom = 7
	_limit.add_theme_stylebox_override("panel", limit_style)
	root.add_child(_limit)
	var limit_box := VBoxContainer.new()
	limit_box.alignment = BoxContainer.ALIGNMENT_CENTER
	limit_box.add_theme_constant_override("separation", 1)
	_limit.add_child(limit_box)
	var limit_title := _label(limit_box, 24)
	limit_title.text = "WORLD LIMIT"
	limit_title.add_theme_font_override("font", load("res://assets/fonts/Rajdhani-Bold.ttf"))
	limit_title.add_theme_color_override("font_color", Color(0.98, 0.68, 0.28))
	var limit_sub := _label(limit_box, 15)
	limit_sub.text = "You've reached the edge of the map."
	limit_sub.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96))

	_set_drift_visible(false)
	handbrake_label.visible = false


func _process(delta: float) -> void:
	if _feedback_t > 0.0:
		_feedback_t -= delta
		feedback.modulate.a = clampf(_feedback_t, 0.0, 1.0)
	else:
		feedback.modulate.a = 0.0

	if _limit_t > 0.0:
		_limit_t -= delta
		if _limit_t <= 0.0:
			_limit.visible = false

	# Moyenne glissante sur ~0,4 s : le chiffre reste lisible sans scintiller.
	_fps_frames += 1
	_fps_time += delta
	if _fps_time >= 0.4:
		var fps := float(_fps_frames) / _fps_time
		fps_label.text = "FPS %d" % roundi(fps)
		fps_label.add_theme_color_override("font_color", \
			Color(0.55, 1.0, 0.62) if fps >= 50.0 else \
			Color(1.0, 0.84, 0.35) if fps >= 30.0 else Color(1.0, 0.42, 0.38))
		_fps_frames = 0
		_fps_time = 0.0


func set_state(kmh: float, wallet: int, meters: float, mult: int, cash: int, drifting: bool, handbrake: bool, nitro: float, nitro_active: bool, car_name: String) -> void:
	speedo.set_speed(kmh)
	wallet_label.text = "$ %d" % wallet
	car_label.text = car_name
	handbrake_label.visible = handbrake
	nitro_bar.value = nitro
	nitro_bar.modulate = Color(1, 1, 1, 1) if nitro_active else Color(0.8, 0.8, 0.8, 0.7)
	nitro_label.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0) if nitro_active else Color(0.45, 0.86, 1.0, 0.75))
	_set_drift_visible(drifting)
	if drifting:
		drift_label.text = "Drift  %d m    $ %d" % [int(meters), cash]
		drift_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
		drift_bar.value = _bar_progress(meters)
		mult_label.text = "x%d" % mult


func show_bank(amount: int) -> void:
	feedback.text = "+%d $" % amount
	feedback.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	_feedback_t = 1.5


func show_crash() -> void:
	feedback.text = "Drift lost"
	feedback.add_theme_color_override("font_color", Color(1.0, 0.38, 0.32))
	_feedback_t = 1.3


func show_limit() -> void:
	_limit.visible = true
	_limit_t = 3.0
	feedback.modulate.a = 0.0
	_feedback_t = 0.0


func hide_limit() -> void:
	_limit.visible = false
	_limit_t = 0.0


func _set_drift_visible(on: bool) -> void:
	_drift_panel.visible = on
	drift_label.visible = on
	drift_bar.visible = on
	mult_label.visible = on


func _bar_progress(meters: float) -> float:
	var prev := 0.0
	for step in DRIFT_STEPS:
		if meters < step:
			return clampf((meters - prev) / maxf(step - prev, 0.001), 0.0, 1.0)
		prev = step
	return 1.0


func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	parent.add_child(label)
	return label


func _panel(parent: Node, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float, radius: int) -> Panel:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, preset, left, top, right, bottom)
	parent.add_child(panel)
	return panel


func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _place(control: Control, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

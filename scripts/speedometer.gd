extends Control

## Compteur de vitesse circulaire : le cadran fixe est dessiné par
## SpeedometerDial (une seule fois), cette classe ne redessine que l'aiguille,
## la progression et la vitesse numérique.

const DialScript := preload("res://scripts/speedometer_dial.gd")

const MAX_KMH := DialScript.MAX_KMH
const START_DEG := DialScript.START_DEG
const SWEEP_DEG := DialScript.SWEEP_DEG
const RED_ZONE := DialScript.RED_ZONE

const ACCENT := DialScript.ACCENT
const TEXT := DialScript.TEXT
const MUTED := DialScript.MUTED

var _target := 0.0
var _value := 0.0
var _drawn := -1.0
var _dial: Control
var _font: Font
var _font_bold: Font


func _ready() -> void:
	_font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	_font_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(244, 244)
	resized.connect(queue_redraw)

	# Cadran fixe : dessiné une fois pour toutes, derrière l'aiguille.
	_dial = DialScript.new()
	_dial.show_behind_parent = true
	_dial.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dial)


func set_speed(kmh: float) -> void:
	_target = clampf(kmh, 0.0, MAX_KMH)


func _process(delta: float) -> void:
	# L'aiguille rattrape la vitesse réelle avec un léger retard.
	_value = lerpf(_value, _target, 1.0 - exp(-11.0 * delta))
	if absf(_value - _target) < 0.05:
		_value = _target
	# Ne redessine que si l'affichage change vraiment : à l'arrêt, plus aucune
	# commande de dessin n'est envoyée au GPU.
	if absf(_value - _drawn) < 0.15:
		return
	_drawn = _value
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return

	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var a0 := deg_to_rad(START_DEG)
	var sweep := deg_to_rad(SWEEP_DEG)
	var rr := r - 13.0
	var ratio := _value / MAX_KMH

	# Progression.
	if ratio > 0.002:
		draw_arc(c, rr, a0, a0 + sweep * ratio, 96, ACCENT, 7.0, true)

	# Aiguille.
	var ang := a0 + sweep * ratio
	var dir := Vector2(cos(ang), sin(ang))
	var tip := c + dir * (rr - 27.0)
	var tail := c - dir * 15.0
	draw_line(tail, tip, Color(ACCENT, 0.16), 9.0, true)
	draw_line(tail, tip, ACCENT, 3.5, true)

	# Moyeu.
	draw_circle(c, 9.0, Color(0.06, 0.07, 0.10))
	draw_circle(c, 5.5, ACCENT)
	draw_circle(c, 2.0, Color(1, 1, 1, 0.85))

	# Vitesse numérique.
	draw_string(_font_bold, Vector2(c.x - 70.0, c.y + 58.0), str(int(round(_value))), HORIZONTAL_ALIGNMENT_CENTER, 140, 46, TEXT)
	draw_string(_font, Vector2(c.x - 70.0, c.y + 76.0), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 140, 15, MUTED)

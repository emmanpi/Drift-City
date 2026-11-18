class_name Speedometer
extends Control

## Compteur de vitesse circulaire dessiné à la main : arc gradué, zone rouge,
## aiguille lissée et vitesse numérique au centre.

const MAX_KMH := 240.0
const START_DEG := 140.0
const SWEEP_DEG := 260.0
const RED_ZONE := 200.0

const ACCENT := Color(0.94, 0.24, 0.2)
const TRACK := Color(1, 1, 1, 0.10)
const TEXT := Color(0.95, 0.97, 1.0)
const MUTED := Color(0.62, 0.68, 0.78)

var _target := 0.0
var _value := 0.0
var _font: Font
var _font_bold: Font


func _ready() -> void:
	_font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	_font_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(244, 244)
	resized.connect(queue_redraw)


func set_speed(kmh: float) -> void:
	_target = clampf(kmh, 0.0, MAX_KMH)


func _process(delta: float) -> void:
	# L'aiguille rattrape la vitesse réelle avec un léger retard.
	_value = lerpf(_value, _target, 1.0 - exp(-11.0 * delta))
	if absf(_value - _target) < 0.05:
		_value = _target
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return

	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var a0 := deg_to_rad(START_DEG)
	var sweep := deg_to_rad(SWEEP_DEG)
	var a1 := a0 + sweep
	var rr := r - 13.0
	var ratio := _value / MAX_KMH

	# Cadran.
	draw_circle(c, r, Color(0.035, 0.045, 0.065, 0.88))
	draw_arc(c, r - 0.5, 0.0, TAU, 72, Color(1, 1, 1, 0.09), 2.0, true)

	# Piste, zone rouge, progression.
	draw_arc(c, rr, a0, a1, 96, TRACK, 7.0, true)
	draw_arc(c, rr, a0 + sweep * (RED_ZONE / MAX_KMH), a1, 32, Color(1, 0.22, 0.18, 0.30), 7.0, true)
	if ratio > 0.002:
		draw_arc(c, rr, a0, a0 + sweep * ratio, 96, ACCENT, 7.0, true)

	# Graduations : petites tous les 10, grandes tous les 40 avec le nombre.
	for kmh in range(0, int(MAX_KMH) + 1, 10):
		var f := float(kmh) / MAX_KMH
		var ang := a0 + sweep * f
		var dir := Vector2(cos(ang), sin(ang))
		var major := kmh % 40 == 0
		var inner := rr - (15.0 if major else 8.0)
		var col := MUTED
		if kmh >= int(RED_ZONE):
			col = Color(1, 0.35, 0.3, 0.9)
		elif major:
			col = Color(1, 1, 1, 0.62)
		else:
			col = Color(1, 1, 1, 0.22)
		draw_line(c + dir * inner, c + dir * (rr - 3.0), col, 2.0 if major else 1.0, true)
		if major:
			var p := c + dir * (rr - 31.0)
			draw_string(_font, p + Vector2(-40, 6), str(kmh), HORIZONTAL_ALIGNMENT_CENTER, 80, 17, MUTED)

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

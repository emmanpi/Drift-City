extends Control

## Partie fixe du compteur (cadran, piste, graduations, chiffres). Elle n'est
## redessinée que lorsque la taille change : l'aiguille et la vitesse numérique
## restent, elles, redessinées à chaque image.

const MAX_KMH := 240.0
const START_DEG := 140.0
const SWEEP_DEG := 260.0
const RED_ZONE := 200.0

const ACCENT := Color(0.94, 0.24, 0.2)
const TRACK := Color(1, 1, 1, 0.10)
const TEXT := Color(0.95, 0.97, 1.0)
const MUTED := Color(0.62, 0.68, 0.78)

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	resized.connect(queue_redraw)


func _draw() -> void:
	if _font == null:
		return

	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var a0 := deg_to_rad(START_DEG)
	var sweep := deg_to_rad(SWEEP_DEG)
	var a1 := a0 + sweep
	var rr := r - 13.0

	# Cadran.
	draw_circle(c, r, Color(0.035, 0.045, 0.065, 0.88))
	draw_arc(c, r - 0.5, 0.0, TAU, 72, Color(1, 1, 1, 0.09), 2.0, true)

	# Piste et zone rouge.
	draw_arc(c, rr, a0, a1, 96, TRACK, 7.0, true)
	draw_arc(c, rr, a0 + sweep * (RED_ZONE / MAX_KMH), a1, 32, Color(1, 0.22, 0.18, 0.30), 7.0, true)

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

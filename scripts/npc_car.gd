extends CharacterBody3D

## Voiture de trafic — partie « conducteur » du port de slop-newyork.
##
## Le manager `npc_traffic.gd` construit les voies et appelle `step()` chaque
## frame physique ; toute la physique de conduite est ici :
##  - Intelligent Driver Model (accélération libre, freinage du véhicule devant,
##    limite de vitesse dans les virages) ;
##  - direction vers un point anticipé du chemin ;
##  - marche arrière + rotation pour se dégager quand la voiture est bloquée.
##
## `yaw` suit la convention du moteur JS : l'avant du véhicule pointe vers
## (sin yaw, cos yaw) dans le plan X/Z. `front_sign` convertit cela en rotation
## Godot selon le sens du modèle 3D.

const A := 2.0
const B := 3.0
const T_HEAD := 1.2
const S0 := 2.0
const A_LAT := 3.5
const B_MAX := 8.0
const LOOKAHEAD := 70.0
const HALF_L := 2.1
const AXLE := 1.4
const REVERSE_TIME := 0.55
const REVERSE_SPEED := 3.2

var manager: Node
## -1 : l'avant du modèle est en -Z ; +1 : l'avant est en +Z.
var front_sign := -1.0

## Position sur le graphe : arête orientée, mouvement choisi au carrefour,
## distance parcourue sur l'arête ou sur la courbe de carrefour.
var edge := -1
var move := -1
var conn_s := -1.0
var out_edge := -1
var s := 0.0
var v0 := 10.0

var speed := 0.0
var acc := 0.0
var yaw := 0.0
var yaw_rate := 0.0
var yaw_vel := 0.0
var knock := Vector2.ZERO
var dl := 0.0
var impact_time := 0.0
var gap := 1.0e9
var leader_speed := 0.0
## Écart entre le cap de la voiture et la tangente de sa voie (diagnostic).
var heading_error := 0.0
var stalled := 0.0
var reverse_left := 0.0
var reverse_spin := 1.0
var prev_pos := Vector2.ZERO


func setup(mgr: Node, e: int, start_s: float, desired: float, sign_front: float) -> void:
	manager = mgr
	edge = e
	s = start_s
	v0 = desired
	speed = desired * 0.6
	front_sign = sign_front
	var p: Array = manager.call("lane_point", edge, s)
	var pos: Vector2 = p[0]
	var d: Vector2 = p[1]
	yaw = atan2(d.x, d.y)
	prev_pos = pos
	global_position = Vector3(pos.x, 0.02, pos.y)
	_apply_rotation()


func step(delta: float) -> void:
	prev_pos = Vector2(global_position.x, global_position.z)
	impact_time = maxf(0.0, impact_time - delta)
	if edge < 0 or manager == null:
		return
	if move < 0:
		move = int(manager.call("choose_move", self))
		if move >= 0:
			out_edge = int(manager.call("get_move", edge, move)["to"])

	# --- Intelligent Driver Model ------------------------------------------
	var lead: Array = manager.call("leader", self)
	gap = float(lead[0])
	leader_speed = float(lead[1])
	var worst := 0.0
	if gap < LOOKAHEAD:
		worst = _brake(gap, leader_speed)

	var cap := 1.0e9
	var d_end: float = float(manager.call("edge_length", edge)) - s - HALF_L
	if move >= 0:
		var curve: Dictionary = manager.call("get_move", edge, move).get("curve", {})
		if not curve.is_empty() and float(curve["len"]) > 0.5 and float(curve["curv"]) > 0.001:
			var vt := sqrt(A_LAT / float(curve["curv"]))
			if conn_s >= 0.0:
				cap = vt
			else:
				cap = sqrt(vt * vt + 5.0 * maxf(0.0, d_end))
		# Le véhicule déjà sorti du carrefour sur la voie suivante.
		if conn_s < 0.0 and d_end < 6.0:
			var next_lead: Array = manager.call("leader_on", self, out_edge, 0.0)
			if float(next_lead[0]) < LOOKAHEAD:
				worst = minf(worst, _brake(float(next_lead[0]), float(next_lead[1])))

	var free := A * (1.0 - pow(speed / maxf(v0, 0.1), 4.0))
	acc = clampf(minf(free + worst, (cap - speed) * 2.0), -B_MAX, A)
	if impact_time > 0.0:
		acc = minf(acc, 0.0)

	# --- Intégration -------------------------------------------------------
	if reverse_left > 0.0:
		reverse_left -= delta
		speed = -REVERSE_SPEED
		yaw_vel += reverse_spin * 1.6 * delta
	else:
		speed = maxf(-2.0, speed + acc * delta)
	var ds := speed * delta
	if speed > 0.0 and gap < 1.0e8:
		var allowed := maxf(0.0, gap - 0.3)
		if ds > allowed:
			ds = allowed
			speed = minf(speed, maxf(0.0, leader_speed))
	manager.call("advance", self, ds)

	# --- Direction vers un point anticipé ----------------------------------
	var c: float = conn_s if conn_s >= 0.0 else s
	# Anticipation courte : notre modèle suit la tangente de la voie pour sa
	# position, un regard trop long ferait tourner le nez avant la trajectoire.
	var look := 0.6 * AXLE + 0.15 * maxf(speed, 0.0)
	var ahead: Array = manager.call("path_point", self, c + look)
	var d: Vector2 = ahead[1]
	var desired := atan2(d.x, d.y)
	var diff := wrapf(desired - yaw, -PI, PI)
	heading_error = diff
	# Un écart de cap important (demi-tour en impasse) se corrige à faible
	# vitesse : la voiture pivote sur place au lieu de reculer en biais.
	var rate := clampf(10.0 / maxf(absf(speed), 1.0), 2.0, 8.0)
	if absf(diff) > 2.0:
		speed = minf(speed, 1.2)
	var prev_yaw := yaw
	yaw = wrapf(yaw + clampf(diff, -rate * delta, rate * delta) + yaw_vel * delta, -PI, PI)
	yaw_vel *= exp(-4.0 * delta)
	if absf(yaw_vel) < 0.001:
		yaw_vel = 0.0
	yaw_rate = wrapf(yaw - prev_yaw, -PI, PI) / maxf(delta, 0.001)
	dl *= exp(-3.0 * delta)
	knock *= exp(-4.0 * delta)

	manager.call("locate", self, delta)

	# --- Déblocage : reculer en tournant -----------------------------------
	var moved := Vector2(global_position.x, global_position.z).distance_to(prev_pos)
	if moved < 0.012:
		stalled += delta
		if stalled > 0.9 and reverse_left <= 0.0 and impact_time <= 0.0:
			_begin_reverse()
	else:
		stalled = 0.0


func _begin_reverse() -> void:
	reverse_left = REVERSE_TIME
	reverse_spin = 1.0 if randf() < 0.5 else -1.0
	stalled = 0.0
	impact_time = 0.2


func _apply_rotation() -> void:
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	rotation.y = atan2(-dir.x, -dir.z)
	if front_sign > 0.0:
		rotation.y += PI


## Freinage IDM pour un obstacle à `g` mètres roulant à `other_speed`.
func _brake(g: float, other_speed: float, standstill: float = S0, headway: float = T_HEAD) -> float:
	var wanted: float = standstill + maxf(0.0,
		speed * headway + (speed * (speed - other_speed)) / (2.0 * sqrt(A * B)))
	return -A * pow(wanted / maxf(g, 0.1), 2.0)

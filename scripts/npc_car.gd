extends CharacterBody3D

## Voiture NPC : suit son segment de route, ralentit dans les virages et change
## de route aux carrefours. La logique du graphe est dans npc_traffic.gd.

var manager: Node
var target := Vector3.ZERO
var speed := 10.0
## Segment courant et extrémité visée.
var segment := -1
var side := 0
## -1 : avant du modèle en -Z ; +1 : avant en +Z.
var front_sign := -1.0

var _stalled := 0.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1


func _physics_process(delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 2.5:
		if manager:
			manager.call("retarget", self)
		return

	var dir := to.normalized()
	# Arrivée progressive à la vitesse de croisière : les changements de cap
	# sont souples au lieu d'être des à-coups instantanés.
	var approach := clampf(to.length() / 6.0, 0.75, 1.0)
	var wanted := dir * speed * approach
	velocity = velocity.lerp(wanted, 1.0 - exp(-2.5 * delta))

	var heading: Vector2 = Vector2(velocity.x, velocity.z)
	if heading.length() < 0.5:
		heading = Vector2(dir.x, dir.z)
	heading = heading.normalized()
	var yaw := atan2(-heading.x, -heading.y)
	if front_sign > 0.0:
		yaw += PI
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-4.0 * delta))

	var before := global_position
	move_and_slide()
	# Les NPC roulent sur les routes planes : on annule les poussées verticales
	# dues aux collisions entre voitures.
	global_position.y = target.y

	if before.distance_to(global_position) < 0.012:
		_stalled += delta
		if _stalled > 0.7:
			_stalled = 0.0
			if manager:
				manager.call("retarget", self)
	else:
		_stalled = 0.0

extends Node

func _ready() -> void:
	_action("accelerate", [KEY_W, KEY_UP])
	_action("brake", [KEY_S, KEY_DOWN])
	_action("steer_left", [KEY_A, KEY_LEFT])
	_action("steer_right", [KEY_D, KEY_RIGHT])
	_action("handbrake", [KEY_SPACE])
	_action("nitro", [KEY_SHIFT])
	_action("reset", [KEY_R])
	_action("menu", [KEY_ESCAPE])


func _action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)

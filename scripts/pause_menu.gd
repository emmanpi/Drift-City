extends CanvasLayer

## In-game pause menu (Esc). Offers Resume, Main menu, Quit and a live control
## for the number of NPC cars (0–100, 16 by default), a toggle for the
## reflective PBR materials on NPCs and music/sound toggles. Click the number
## to type a value with the keyboard, or use - / +. Settings are saved in
## `user://progress.cfg`.

signal npc_count_changed(count: int)
signal npc_reflections_changed(enabled: bool)

const BOLD_FONT := "res://assets/fonts/Rajdhani-Bold.ttf"
const SEMIBOLD_FONT := "res://assets/fonts/Rajdhani-SemiBold.ttf"

var _count_edit: LineEdit
var _minus: Button
var _plus: Button
var _reflections_button: Button
var _music_button: Button
var _sfx_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.055, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	box.custom_minimum_size = Vector2(380, 0)
	center.add_child(box)

	var title := _label("PAUSED", 52, Color.WHITE, BOLD_FONT)
	box.add_child(title)
	box.add_child(_label("Drift City", 17, Color(0.72, 0.78, 0.88)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var resume := _button("RESUME", Color(0.80, 0.10, 0.12))
	resume.pressed.connect(hide_menu)
	box.add_child(resume)

	var main_menu := _button("MAIN MENU", Color(0.16, 0.19, 0.26))
	main_menu.pressed.connect(_go_main_menu)
	box.add_child(main_menu)

	var quit := _button("QUIT GAME", Color(0.12, 0.14, 0.19))
	quit.pressed.connect(_quit_game)
	box.add_child(quit)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer2)

	box.add_child(_label("NPC CARS IN CITY", 16, Color(0.86, 0.55, 0.3)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	_minus = _small_button("-")
	_minus.pressed.connect(func(): _change_count(-1))
	row.add_child(_minus)
	_count_edit = _count_field()
	_count_edit.text_submitted.connect(func(_text: String):
		_commit_count()
		_count_edit.release_focus())
	_count_edit.focus_exited.connect(_commit_count)
	row.add_child(_count_edit)
	_plus = _small_button("+")
	_plus.pressed.connect(func(): _change_count(1))
	row.add_child(_plus)

	box.add_child(_label("Click the number to type a value (0–100)", 13, Color(0.72, 0.78, 0.88)))

	_reflections_button = _button("NPC REFLECTIONS: OFF", Color(0.16, 0.19, 0.26))
	_reflections_button.custom_minimum_size = Vector2(300, 44)
	_reflections_button.add_theme_font_size_override("font_size", 17)
	_reflections_button.pressed.connect(_toggle_reflections)
	box.add_child(_reflections_button)

	_music_button = _button("MUSIC: ON", Color(0.16, 0.19, 0.26))
	_music_button.custom_minimum_size = Vector2(300, 44)
	_music_button.add_theme_font_size_override("font_size", 17)
	_music_button.pressed.connect(_toggle_music)
	box.add_child(_music_button)

	_sfx_button = _button("SOUNDS: ON", Color(0.16, 0.19, 0.26))
	_sfx_button.custom_minimum_size = Vector2(300, 44)
	_sfx_button.add_theme_font_size_override("font_size", 17)
	_sfx_button.pressed.connect(_toggle_sfx)
	box.add_child(_sfx_button)

	box.add_child(_label("Progress is saved automatically", 13, Color(0.58, 0.64, 0.72)))
	box.add_child(_label("Esc resume    WASD drive    Space handbrake", 13, Color(0.58, 0.64, 0.72)))


func show_menu() -> void:
	if visible:
		return
	visible = true
	_refresh()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# The LineEdit consumes Esc before _unhandled_input sees it, so cancel a
	# number edit here, before GUI input handling.
	if not visible or not _count_edit.has_focus():
		return
	if event.is_action_pressed("menu"):
		_count_edit.text = "%d" % Game.npc_count
		_count_edit.release_focus()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Esc opens the menu when driving and closes it when paused. This node is
	# always processed, so it also receives the key while the tree is paused.
	if event.is_action_pressed("menu"):
		# An edit in progress is cancelled in _input(), before GUI handling.
		if visible:
			hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _count_edit.has_focus():
			_commit_count()
		else:
			hide_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not _count_edit.has_focus():
		_count_edit.text = "%d" % Game.npc_count
	_reflections_button.text = "NPC REFLECTIONS: %s" % ("ON" if Game.npc_reflections else "OFF")
	_music_button.text = "MUSIC: %s" % ("ON" if Game.music_enabled else "OFF")
	_sfx_button.text = "SOUNDS: %s" % ("ON" if Game.sfx_enabled else "OFF")
	_minus.disabled = Game.npc_count <= Game.MIN_NPC
	_plus.disabled = Game.npc_count >= Game.MAX_NPC
	_minus.modulate = Color(1, 1, 1, 1.0 if not _minus.disabled else 0.4)
	_plus.modulate = Color(1, 1, 1, 1.0 if not _plus.disabled else 0.4)


func _change_count(delta: int) -> void:
	Game.set_npc_count(Game.npc_count + delta)
	_refresh()
	npc_count_changed.emit(Game.npc_count)


func _commit_count() -> void:
	# Digits only, clamped to 0–100. An empty or invalid field restores the
	# previous value instead of changing the traffic.
	var raw := ""
	for c in _count_edit.text:
		if c >= "0" and c <= "9":
			raw += c
	var value := Game.npc_count
	if not raw.is_empty():
		value = clampi(int(raw), Game.MIN_NPC, Game.MAX_NPC)
	_count_edit.text = "%d" % value
	Game.set_npc_count(value)
	_refresh()
	npc_count_changed.emit(Game.npc_count)


func _count_field() -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(96, 50)
	edit.text = "%d" % Game.npc_count
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.max_length = 3
	edit.add_theme_font_size_override("font_size", 34)
	edit.add_theme_font_override("font", load(SEMIBOLD_FONT))
	edit.add_theme_color_override("font_color", Color.WHITE)
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_color_override("caret_color", Color.WHITE)
	edit.add_theme_stylebox_override("normal", _pill(Color(0.16, 0.19, 0.26), Color(1, 1, 1, 0.12), 14))
	edit.add_theme_stylebox_override("hover", _pill(Color(0.24, 0.28, 0.36), Color(1, 1, 1, 0.3), 14))
	edit.add_theme_stylebox_override("focus", _pill(Color(0.22, 0.26, 0.34), Color(0.90, 0.30, 0.20, 0.9), 14))
	return edit


func _toggle_reflections() -> void:
	Game.set_npc_reflections(not Game.npc_reflections)
	_refresh()
	npc_reflections_changed.emit(Game.npc_reflections)


func _toggle_music() -> void:
	Game.set_music_enabled(not Game.music_enabled)
	_refresh()


func _toggle_sfx() -> void:
	Game.set_sfx_enabled(not Game.sfx_enabled)
	_refresh()


func _go_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Loading.show_message("Loading menu...")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _quit_game() -> void:
	get_tree().quit()


func _label(text: String, size: int, color: Color, font_path: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if not font_path.is_empty():
		label.add_theme_font_override("font", load(font_path))
	return label


func _button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 52)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_font_override("font", load(SEMIBOLD_FONT))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _pill(color, Color(1, 1, 1, 0.06), 14))
	btn.add_theme_stylebox_override("hover", _pill(color.lightened(0.12), Color(1, 1, 1, 0.28), 14))
	btn.add_theme_stylebox_override("pressed", _pill(color.darkened(0.2), Color(1, 1, 1, 0.0), 14))
	btn.add_theme_stylebox_override("focus", _pill(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 14))
	btn.focus_mode = Control.FOCUS_NONE
	return btn


func _small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(56, 50)
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_font_override("font", load(BOLD_FONT))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _pill(Color(0.16, 0.19, 0.26), Color(1, 1, 1, 0.12), 14))
	btn.add_theme_stylebox_override("hover", _pill(Color(0.24, 0.28, 0.36), Color(1, 1, 1, 0.3), 14))
	btn.add_theme_stylebox_override("pressed", _pill(Color(0.1, 0.12, 0.17), Color(1, 1, 1, 0.0), 14))
	btn.add_theme_stylebox_override("disabled", _pill(Color(0.1, 0.12, 0.17), Color(1, 1, 1, 0.04), 14))
	btn.add_theme_stylebox_override("focus", _pill(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 14))
	btn.focus_mode = Control.FOCUS_NONE
	return btn


func _pill(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.anti_aliasing = true
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

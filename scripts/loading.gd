extends CanvasLayer

## Voile de chargement persistant (autoload) : il reste affiché pendant le
## changement de scène et la construction de la ville, puis la ville le referme.

var _root: Control
var _label: Label
var _bar: ProgressBar
var _t := 0.0


func _ready() -> void:
	layer = 128
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.055, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(460, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "DRIFT CITY"
	title.add_theme_font_override("font", load("res://assets/fonts/Rajdhani-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_label = Label.new()
	_label.text = "Loading..."
	_label.add_theme_font_override("font", load("res://assets/fonts/Rajdhani-SemiBold.ttf"))
	_label.add_theme_font_size_override("font_size", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	box.add_child(_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(460, 8)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.10)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.94, 0.24, 0.2)
	bar_fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	box.add_child(_bar)

	set_process(false)


func show_message(text: String) -> void:
	_label.text = text
	_root.visible = true
	_t = 0.0
	_bar.value = 0.5
	set_process(true)


func hide_loading() -> void:
	_root.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	_bar.value = 0.5 + 0.45 * sin(_t * 2.6)

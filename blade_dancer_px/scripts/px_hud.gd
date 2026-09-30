extends CanvasLayer
## PX HUD — the status readout and the CLOSE button.

signal close_requested()

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

const FONT_SIZE: int = 17

var label: Label


func _init() -> void:
	label = Label.new()
	label.position = Vector2(18.0, 14.0)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
	add_child(label)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -132.0
	close_button.offset_right = -18.0
	close_button.offset_top = 16.0
	close_button.offset_bottom = 56.0
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)


func set_lines(lines: Array[String]) -> void:
	label.text = "\n".join(lines)
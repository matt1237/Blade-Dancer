class_name PauseMenu extends Control

## Simple pause overlay. Bound to Escape via main.gd.
## Built programmatically — no .tscn needed.

signal resume_pressed
signal return_home_pressed

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Full-screen dark backdrop.
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Center panel.
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 260)
	add_child(panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.10, 0.92)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.75, 0.55, 0.25, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	# Title.
	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	# Spacer.
	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	# Resume button.
	var resume_btn: Button = _make_button("Resume")
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	# Return to Home button.
	var home_btn: Button = _make_button("Return to Home")
	home_btn.pressed.connect(_on_return_home)
	vbox.add_child(home_btn)

func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.add_theme_font_size_override("font_size", 18)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.18, 0.12, 1.0)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.65, 0.45, 0.2, 1.0)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.4, 0.28, 0.18, 1.0)
	hover_style.border_color = Color(0.9, 0.7, 0.35, 1.0)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.15, 0.10, 0.06, 1.0)
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	button.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.55))
	return button

func open() -> void:
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_resume() -> void:
	close()
	resume_pressed.emit()

func _on_return_home() -> void:
	visible = false
	return_home_pressed.emit()

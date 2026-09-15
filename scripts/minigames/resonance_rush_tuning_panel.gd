class_name ResonanceRushTuningPanel extends PanelContainer

## Live in-game physics & movement tuning panel for Resonance Rush.
## Allows live tweaking of Ground, Air, Grapple, Glide, and Visual tuning variables.
## Supports resetting to defaults and presets.

signal values_changed()

@export var land_sail: ResonanceRushLandSail = null

var _default_values: Dictionary = {}
var _sliders: Dictionary = {} # param_name -> { "slider": HSlider, "spinbox": SpinBox, "value_label": Label }
var _tab_container: TabContainer = null
var _panel_content: VBoxContainer = null

const PARAM_SECTIONS: Dictionary = {
	"Ground": [
		{"name": "acceleration", "label": "Acceleration", "min": 100.0, "max": 3000.0, "step": 10.0, "suffix": " px/s²"},
		{"name": "max_ground_speed", "label": "Max Ground Speed", "min": 200.0, "max": 2000.0, "step": 10.0, "suffix": " px/s"},
		{"name": "ground_friction", "label": "Friction (Coast)", "min": 0.0, "max": 1500.0, "step": 10.0, "suffix": " px/s²"},
		{"name": "reverse_brake_strength", "label": "Brake Strength", "min": 100.0, "max": 3000.0, "step": 10.0, "suffix": " px/s²"},
		{"name": "slope_gravity_scale", "label": "Slope Gravity Scale", "min": 0.0, "max": 3.0, "step": 0.05, "suffix": "x"},
		{"name": "initial_ground_speed", "label": "Initial Speed", "min": 0.0, "max": 1000.0, "step": 10.0, "suffix": " px/s"},
		{"name": "ground_clearance", "label": "Ground Clearance", "min": 0.0, "max": 60.0, "step": 1.0, "suffix": " px"}
	],
	"Air & Jump": [
		{"name": "manual_jump_impulse", "label": "Manual Jump", "min": 100.0, "max": 1500.0, "step": 10.0, "suffix": " px/s"},
		{"name": "jump_impulse", "label": "Ramp Launch Boost", "min": 0.0, "max": 1000.0, "step": 10.0, "suffix": " px/s"},
		{"name": "gravity", "label": "Gravity", "min": 200.0, "max": 3500.0, "step": 25.0, "suffix": " px/s²"},
		{"name": "air_control", "label": "Air Control", "min": 0.0, "max": 1000.0, "step": 10.0, "suffix": " px/s²"},
		{"name": "vehicle_weight", "label": "Vehicle Weight", "min": 0.1, "max": 5.0, "step": 0.05, "suffix": "x"},
		{"name": "momentum_retention", "label": "Landing Momentum", "min": 0.5, "max": 1.0, "step": 0.01, "suffix": "x"},
		{"name": "track_detach_ignore_seconds", "label": "Detach Window", "min": 0.02, "max": 0.5, "step": 0.01, "suffix": " s"}
	],
	"Grapple": [
		{"name": "grapple_max_range", "label": "Max Reach Range", "min": 100.0, "max": 1000.0, "step": 10.0, "suffix": " px"},
		{"name": "grapple_rope_length_max", "label": "Max Rope Length", "min": 100.0, "max": 1000.0, "step": 10.0, "suffix": " px"},
		{"name": "grapple_projectile_speed", "label": "Hook Flight Speed", "min": 500.0, "max": 4000.0, "step": 50.0, "suffix": " px/s"},
		{"name": "grapple_pump_acceleration", "label": "Pump Swing Accel", "min": 200.0, "max": 3000.0, "step": 20.0, "suffix": " px/s²"},
		{"name": "grapple_max_swing_speed", "label": "Max Swing Speed", "min": 400.0, "max": 3000.0, "step": 25.0, "suffix": " px/s"},
		{"name": "grapple_reel_speed", "label": "Reel Speed (W/S)", "min": 50.0, "max": 1000.0, "step": 10.0, "suffix": " px/s"},
		{"name": "release_momentum_multiplier", "label": "Launch Momentum", "min": 1.0, "max": 3.0, "step": 0.05, "suffix": "x"},
		{"name": "grapple_strength", "label": "Grapple Gravity", "min": 0.5, "max": 6.0, "step": 0.1, "suffix": "x"},
		{"name": "swing_damping", "label": "Swing Damping", "min": 0.98, "max": 1.0, "step": 0.0005, "suffix": ""},
		{"name": "grapple_aim_tolerance_degrees", "label": "Aim Cone Degrees", "min": 15.0, "max": 180.0, "step": 5.0, "suffix": "°"}
	],
	"Glider": [
		{"name": "glide_duration", "label": "Stamina Duration", "min": 1.0, "max": 20.0, "step": 0.5, "suffix": " s"},
		{"name": "glide_lift", "label": "Glide Lift", "min": 100.0, "max": 2000.0, "step": 20.0, "suffix": " px/s²"},
		{"name": "glide_drag", "label": "Glide Drag", "min": 0.0, "max": 300.0, "step": 5.0, "suffix": " px/s²"},
		{"name": "dive_acceleration", "label": "Dive Acceleration", "min": 100.0, "max": 2500.0, "step": 25.0, "suffix": " px/s²"},
		{"name": "upward_conversion", "label": "Upward Conversion", "min": 0.0, "max": 1.0, "step": 0.02, "suffix": "x"},
		{"name": "max_glide_speed", "label": "Max Glide Speed", "min": 200.0, "max": 2000.0, "step": 20.0, "suffix": " px/s"},
		{"name": "glide_recharge_rate", "label": "Recharge Rate", "min": 0.1, "max": 3.0, "step": 0.05, "suffix": "x/s"}
	],
	"Visual & Form": [
		{"name": "glider_deploy_seconds", "label": "Deploy Duration", "min": 0.05, "max": 1.0, "step": 0.01, "suffix": " s"},
		{"name": "glider_fold_seconds", "label": "Fold Duration", "min": 0.05, "max": 1.0, "step": 0.01, "suffix": " s"},
		{"name": "glider_deployed_scale", "label": "Deployed Scale", "min": 0.5, "max": 2.0, "step": 0.02, "suffix": "x"},
		{"name": "glider_flip_degrees", "label": "Hinge Tilt Degrees", "min": 0.0, "max": 90.0, "step": 1.0, "suffix": "°"},
		{"name": "glider_flutter_amount", "label": "Flutter Flex Amount", "min": 0.0, "max": 0.1, "step": 0.002, "suffix": ""},
		{"name": "glide_bank_smoothing", "label": "Bank Pitch Smoothing", "min": 1.0, "max": 30.0, "step": 0.5, "suffix": ""}
	]
}

func _ready() -> void:
	custom_minimum_size = Vector2(490, 520)
	size = Vector2(490, 560)
	_build_ui()
	if land_sail != null:
		setup_for_land_sail(land_sail)

func setup_for_land_sail(sail: ResonanceRushLandSail) -> void:
	land_sail = sail
	_record_defaults()
	_sync_all_from_target()

func _record_defaults() -> void:
	_default_values.clear()
	for section_name in PARAM_SECTIONS:
		var params: Array = PARAM_SECTIONS[section_name]
		for item in params:
			var param_name: String = item["name"]
			if land_sail != null and param_name in land_sail:
				_default_values[param_name] = land_sail.get(param_name)

func _build_ui() -> void:
	# Add a solid dark translucent stylebox
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.94)
	style.border_color = Color(0.2, 0.45, 0.65, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Header Bar
	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_label: Label = Label.new()
	title_label.text = "TUNING CONTROLS (LIVE)"
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	var reset_btn: Button = Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.pressed.connect(_on_reset_all_pressed)
	header_hbox.add_child(reset_btn)

	var minimize_btn: Button = Button.new()
	minimize_btn.text = "–"
	minimize_btn.custom_minimum_size = Vector2(28, 24)
	minimize_btn.pressed.connect(_toggle_panel_visibility)
	header_hbox.add_child(minimize_btn)

	_panel_content = VBoxContainer.new()
	_panel_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_content.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_panel_content)

	# Tab Container for categories
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_content.add_child(_tab_container)

	for section_name in PARAM_SECTIONS:
		var tab_scroll: ScrollContainer = ScrollContainer.new()
		tab_scroll.name = section_name
		tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(tab_scroll)

		var tab_margin: MarginContainer = MarginContainer.new()
		tab_margin.add_theme_constant_override("margin_left", 6)
		tab_margin.add_theme_constant_override("margin_right", 6)
		tab_margin.add_theme_constant_override("margin_top", 8)
		tab_margin.add_theme_constant_override("margin_bottom", 8)
		tab_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_scroll.add_child(tab_margin)

		var tab_vbox: VBoxContainer = VBoxContainer.new()
		tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_vbox.add_theme_constant_override("separation", 10)
		tab_margin.add_child(tab_vbox)

		var params: Array = PARAM_SECTIONS[section_name]
		for item in params:
			_create_param_row(tab_vbox, item)

	# Presets Row
	var presets_hbox: HBoxContainer = HBoxContainer.new()
	presets_hbox.add_theme_constant_override("separation", 6)
	_panel_content.add_child(presets_hbox)

	var preset_label: Label = Label.new()
	preset_label.text = "Presets:"
	preset_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	presets_hbox.add_child(preset_label)

	var default_preset_btn: Button = Button.new()
	default_preset_btn.text = "Standard"
	default_preset_btn.pressed.connect(_apply_preset_standard)
	presets_hbox.add_child(default_preset_btn)

	var floaty_preset_btn: Button = Button.new()
	floaty_preset_btn.text = "Floaty / Long Glide"
	floaty_preset_btn.pressed.connect(_apply_preset_floaty)
	presets_hbox.add_child(floaty_preset_btn)

	var speedy_preset_btn: Button = Button.new()
	speedy_preset_btn.text = "High Speed Rush"
	speedy_preset_btn.pressed.connect(_apply_preset_speedy)
	presets_hbox.add_child(speedy_preset_btn)

func _create_param_row(parent: VBoxContainer, info: Dictionary) -> void:
	var param_name: String = info["name"]
	var row_vbox: VBoxContainer = VBoxContainer.new()
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(row_vbox)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_child(top_hbox)

	var name_label: Label = Label.new()
	name_label.text = info["label"]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 1.0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(80, 0)
	top_hbox.add_child(value_label)

	var controls_hbox: HBoxContainer = HBoxContainer.new()
	controls_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_hbox.add_theme_constant_override("separation", 8)
	row_vbox.add_child(controls_hbox)

	var slider: HSlider = HSlider.new()
	slider.min_value = info["min"]
	slider.max_value = info["max"]
	slider.step = info["step"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float): _on_slider_changed(param_name, v, info))
	controls_hbox.add_child(slider)

	var spinbox: SpinBox = SpinBox.new()
	spinbox.min_value = info["min"]
	spinbox.max_value = info["max"]
	spinbox.step = info["step"]
	spinbox.custom_minimum_size = Vector2(90, 0)
	spinbox.value_changed.connect(func(v: float): _on_spinbox_changed(param_name, v, info))
	controls_hbox.add_child(spinbox)

	_sliders[param_name] = {
		"slider": slider,
		"spinbox": spinbox,
		"value_label": value_label,
		"info": info
	}

func _on_slider_changed(param_name: String, value: float, info: Dictionary) -> void:
	var entry: Dictionary = _sliders.get(param_name, {})
	var spinbox: SpinBox = entry.get("spinbox")
	if spinbox != null and not is_equal_approx(spinbox.value, value):
		spinbox.set_value_no_signal(value)
	_update_value_label(param_name, value, info)
	_apply_to_target(param_name, value)

func _on_spinbox_changed(param_name: String, value: float, info: Dictionary) -> void:
	var entry: Dictionary = _sliders.get(param_name, {})
	var slider: HSlider = entry.get("slider")
	if slider != null and not is_equal_approx(slider.value, value):
		slider.set_value_no_signal(value)
	_update_value_label(param_name, value, info)
	_apply_to_target(param_name, value)

func _update_value_label(param_name: String, value: float, info: Dictionary) -> void:
	var entry: Dictionary = _sliders.get(param_name, {})
	var label: Label = entry.get("value_label")
	if label == null:
		return
	var suffix: String = info.get("suffix", "")
	if info.get("step", 1.0) >= 1.0:
		label.text = "%d%s" % [roundi(value), suffix]
	elif info.get("step", 0.1) >= 0.01:
		label.text = "%.2f%s" % [value, suffix]
	else:
		label.text = "%.4f%s" % [value, suffix]

func _apply_to_target(param_name: String, value: float) -> void:
	if land_sail != null and param_name in land_sail:
		land_sail.set(param_name, value)
		values_changed.emit()

func _sync_all_from_target() -> void:
	if land_sail == null:
		return
	for param_name in _sliders:
		if param_name in land_sail:
			var val: float = float(land_sail.get(param_name))
			var entry: Dictionary = _sliders[param_name]
			var slider: HSlider = entry.get("slider")
			var spinbox: SpinBox = entry.get("spinbox")
			var info: Dictionary = entry.get("info")
			if slider != null:
				slider.set_value_no_signal(val)
			if spinbox != null:
				spinbox.set_value_no_signal(val)
			_update_value_label(param_name, val, info)

func _on_reset_all_pressed() -> void:
	if land_sail == null:
		return
	for param_name in _default_values:
		var val: float = float(_default_values[param_name])
		_apply_to_target(param_name, val)
	_sync_all_from_target()

func _toggle_panel_visibility() -> void:
	if _panel_content != null:
		_panel_content.visible = not _panel_content.visible
		custom_minimum_size = Vector2(490, 520) if _panel_content.visible else Vector2(490, 48)
		size = custom_minimum_size

func _apply_preset_standard() -> void:
	_on_reset_all_pressed()

func _apply_preset_floaty() -> void:
	if land_sail == null:
		return
	var overrides: Dictionary = {
		"gravity": 950.0,
		"manual_jump_impulse": 550.0,
		"glide_lift": 900.0,
		"glide_duration": 10.0,
		"glide_drag": 20.0,
		"grapple_max_range": 380.0,
		"grapple_rope_length_max": 380.0
	}
	for k in overrides:
		_apply_to_target(k, overrides[k])
	_sync_all_from_target()

func _apply_preset_speedy() -> void:
	if land_sail == null:
		return
	var overrides: Dictionary = {
		"acceleration": 1400.0,
		"max_ground_speed": 950.0,
		"ground_friction": 120.0,
		"manual_jump_impulse": 600.0,
		"grapple_projectile_speed": 2200.0,
		"grapple_pump_acceleration": 1400.0,
		"grapple_max_swing_speed": 1600.0,
		"release_momentum_multiplier": 1.5,
		"max_glide_speed": 1200.0,
		"dive_acceleration": 1400.0
	}
	for k in overrides:
		_apply_to_target(k, overrides[k])
	_sync_all_from_target()

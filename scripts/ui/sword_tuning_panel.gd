class_name SwordTuningPanel extends Control

## In-game Sword Tuner — dev tool, opened from the Pause Menu.
##
## Every parameter in combat_tuning_schema.gd gets its own row here (slider
## or checkbox + a hover "(?)" tooltip explaining what it does), grouped into
## tabs by mechanic. Values are saved per SWORD STYLE — switching the style
## dropdown edits an entirely independent preset, and every change is
## persisted immediately to user://sword_style_tuning.cfg so it survives
## between sessions. Never shown to players outside this dev-only panel.

signal closed()

@export var player: Player = null

var _rows: Dictionary = {} # param_key -> {control, value_label, info}
var _style_option: OptionButton = null
var _section_sidebar: VBoxContainer = null
var _section_pages: Array[Control] = [] # parallel to CombatTuningSchema.PARAM_SECTIONS
var _section_buttons: Array[Button] = []
var _active_section: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func open() -> void:
	visible = true
	_sync_style_option()
	_sync_all_rows()

func close() -> void:
	visible = false
	if player != null: player.save_style_tuning()
	closed.emit()

func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(820, 580)
	panel.size = Vector2(820, 580)
	add_child(panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.96)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.6, 0.2, 0.25, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# --- Header: title, style selector, reset, close ---
	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)

	var title_label: Label = Label.new()
	title_label.text = "SWORD TUNER"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	header_hbox.add_child(title_label)

	var style_label: Label = Label.new()
	style_label.text = "Editing:"
	style_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	header_hbox.add_child(style_label)

	_style_option = OptionButton.new()
	for style_index: int in Player.STYLE_CYCLE_ORDER:
		_style_option.add_item(_style_display_name(style_index), style_index)
	_style_option.item_selected.connect(_on_style_selected)
	header_hbox.add_child(_style_option)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var reset_btn: Button = Button.new()
	reset_btn.text = "Reset This Style"
	reset_btn.pressed.connect(_on_reset_pressed)
	header_hbox.add_child(reset_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)

	var hint_label: Label = Label.new()
	hint_label.text = "Dev tool — hover the (?) next to any setting for what it does. Changes save instantly to this style only."
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	main_vbox.add_child(hint_label)

	# --- Body: a left sidebar listing every section (always fully visible,
	# never hidden behind tab overflow arrows) + a page area on the right
	# showing only the selected section's params. ---
	var body_hbox: HBoxContainer = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 14)
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_hbox)

	var sidebar_scroll: ScrollContainer = ScrollContainer.new()
	sidebar_scroll.custom_minimum_size = Vector2(170, 0)
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(sidebar_scroll)

	_section_sidebar = VBoxContainer.new()
	_section_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_sidebar.add_theme_constant_override("separation", 4)
	sidebar_scroll.add_child(_section_sidebar)

	var page_holder: Control = Control.new()
	page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(page_holder)

	for section_index: int in range(CombatTuningSchema.PARAM_SECTIONS.size()):
		var section: Dictionary = CombatTuningSchema.PARAM_SECTIONS[section_index]

		var section_btn: Button = Button.new()
		section_btn.text = section["title"]
		section_btn.toggle_mode = true
		section_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		section_btn.focus_mode = Control.FOCUS_NONE
		section_btn.custom_minimum_size = Vector2(0, 36)
		section_btn.pressed.connect(_on_section_selected.bind(section_index))
		_section_sidebar.add_child(section_btn)
		_section_buttons.append(section_btn)

		var tab_scroll: ScrollContainer = ScrollContainer.new()
		tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tab_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		tab_scroll.visible = false
		page_holder.add_child(tab_scroll)
		_section_pages.append(tab_scroll)

		var tab_margin: MarginContainer = MarginContainer.new()
		tab_margin.add_theme_constant_override("margin_left", 8)
		tab_margin.add_theme_constant_override("margin_right", 8)
		tab_margin.add_theme_constant_override("margin_top", 10)
		tab_margin.add_theme_constant_override("margin_bottom", 10)
		tab_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_scroll.add_child(tab_margin)

		var tab_vbox: VBoxContainer = VBoxContainer.new()
		tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_vbox.add_theme_constant_override("separation", 12)
		tab_margin.add_child(tab_vbox)

		for param: Dictionary in section["params"]:
			_create_param_row(tab_vbox, param)

	_select_section(0)

func _on_section_selected(section_index: int) -> void:
	_select_section(section_index)

func _select_section(section_index: int) -> void:
	_active_section = section_index
	for i: int in range(_section_pages.size()):
		var is_active: bool = (i == section_index)
		_section_pages[i].visible = is_active
		_section_buttons[i].set_pressed_no_signal(is_active)

func _style_display_name(style_index: int) -> String:
	match style_index:
		Player.SwordStyle.METRONOME: return "Form I: Metronome V"
		Player.SwordStyle.METRONOME_WINDUP: return "Form II: Metronome Wind-up"
		Player.SwordStyle.METRONOME_BIND: return "Form III: Bind A"
		Player.SwordStyle.METRONOME_BIND_B: return "Form IV: Bind B (TEST)"
		Player.SwordStyle.THRUST: return "Form V: Thrusting A"
		Player.SwordStyle.MOULINET: return "Form VI: Moulinet 1 (Full 8)"
		Player.SwordStyle.MOULINET_2: return "Form VII: Moulinet 2 (Single Lobe)"
		Player.SwordStyle.MOULINET_3: return "Form VIII: Moulinet 3 (Aim-Driven)"
		Player.SwordStyle.MOULINET_4: return "Form IX: Flattened Infinity"
		Player.SwordStyle.THRUST_METRONOME: return "Form X: Metronome Thrusts"
		_: return "Unknown"

func _create_param_row(parent: VBoxContainer, param: Dictionary) -> void:
	var param_key: String = param["key"]
	var row_vbox: VBoxContainer = VBoxContainer.new()
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_theme_constant_override("separation", 3)
	parent.add_child(row_vbox)

	if param.get("is_toggle", false):
		# Toggle rows: the CheckBox itself carries the label text and fills
		# the row, so clicking anywhere on the label (not just the tiny
		# check icon) toggles it.
		var toggle_hbox: HBoxContainer = HBoxContainer.new()
		toggle_hbox.add_theme_constant_override("separation", 6)
		toggle_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_vbox.add_child(toggle_hbox)

		var toggle_help_btn: Button = Button.new()
		toggle_help_btn.text = "?"
		toggle_help_btn.custom_minimum_size = Vector2(22, 22)
		toggle_help_btn.focus_mode = Control.FOCUS_NONE
		toggle_help_btn.tooltip_text = param.get("tooltip", "")
		toggle_help_btn.mouse_default_cursor_shape = Control.CURSOR_HELP
		toggle_hbox.add_child(toggle_help_btn)

		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = param["label"]
		checkbox.add_theme_font_size_override("font_size", 13)
		checkbox.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
		checkbox.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
		checkbox.custom_minimum_size = Vector2(0, 32)
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.toggled.connect(func(pressed: bool) -> void: _on_value_changed(param_key, 1.0 if pressed else 0.0, param))
		toggle_hbox.add_child(checkbox)

		var toggle_value_label: Label = Label.new()
		toggle_value_label.text = "0"
		toggle_value_label.add_theme_font_size_override("font_size", 13)
		toggle_value_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		toggle_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		toggle_value_label.custom_minimum_size = Vector2(50, 0)
		toggle_hbox.add_child(toggle_value_label)

		_rows[param_key] = {"control": checkbox, "value_label": toggle_value_label, "info": param}
		return

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_child(top_hbox)

	var help_btn: Button = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.tooltip_text = param.get("tooltip", "")
	help_btn.mouse_default_cursor_shape = Control.CURSOR_HELP
	top_hbox.add_child(help_btn)

	var name_label: Label = Label.new()
	name_label.text = param["label"]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(70, 0)
	top_hbox.add_child(value_label)

	var controls_hbox: HBoxContainer = HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 8)
	controls_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_child(controls_hbox)

	var slider: HSlider = HSlider.new()
	slider.min_value = param["min"]
	slider.max_value = param["max"]
	slider.step = param["step"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void: _on_value_changed(param_key, v, param))
	controls_hbox.add_child(slider)

	var spinbox: SpinBox = SpinBox.new()
	spinbox.min_value = param["min"]
	spinbox.max_value = param["max"]
	spinbox.step = param["step"]
	spinbox.custom_minimum_size = Vector2(90, 0)
	spinbox.value_changed.connect(func(v: float) -> void: _on_value_changed(param_key, v, param))
	controls_hbox.add_child(spinbox)

	_rows[param_key] = {"control": slider, "spinbox": spinbox, "value_label": value_label, "info": param}


func _on_value_changed(param_key: String, value: float, param: Dictionary) -> void:
	if player == null: return
	player.set_tuned(param_key, value)
	player.save_style_tuning()
	_sync_row_controls(param_key, value)
	_update_value_label(param_key, value, param)

func _update_value_label(param_key: String, value: float, param: Dictionary) -> void:
	var row: Dictionary = _rows.get(param_key, {})
	var label: Label = row.get("value_label")
	if label == null: return
	if param.get("is_toggle", false):
		label.text = "ON" if value > 0.5 else "OFF"
		return
	var suffix: String = param.get("suffix", "")
	var step: float = param.get("step", 1.0)
	if step >= 1.0:
		label.text = "%d%s" % [roundi(value), suffix]
	elif step >= 0.01:
		label.text = "%.2f%s" % [value, suffix]
	else:
		label.text = "%.4f%s" % [value, suffix]

## Keeps slider/spinbox pairs (or a checkbox) mutually in sync without
## re-triggering each other's signals.
func _sync_row_controls(param_key: String, value: float) -> void:
	var row: Dictionary = _rows.get(param_key, {})
	if row.is_empty(): return
	var control: Control = row.get("control")
	if control is CheckBox:
		(control as CheckBox).set_pressed_no_signal(value > 0.5)
		return
	if control is HSlider and not is_equal_approx((control as HSlider).value, value):
		(control as HSlider).set_value_no_signal(value)
	var spinbox: SpinBox = row.get("spinbox")
	if spinbox != null and not is_equal_approx(spinbox.value, value):
		spinbox.set_value_no_signal(value)

func _sync_all_rows() -> void:
	if player == null: return
	for param_key: String in _rows:
		var value: float = player.get_tuned(param_key)
		_sync_row_controls(param_key, value)
		_update_value_label(param_key, value, (_rows[param_key] as Dictionary)["info"])

func _sync_style_option() -> void:
	if player == null or _style_option == null: return
	_style_option.select(player.sword_style)

func _on_style_selected(index: int) -> void:
	if player == null: return
	player.sword_style = index as Player.SwordStyle
	if player.has_signal("style_changed"): player.style_changed.emit(player._style_name())
	_sync_all_rows()

func _on_reset_pressed() -> void:
	if player == null: return
	player.reset_style_tuning(player._style_key())
	player.save_style_tuning()
	_sync_all_rows()

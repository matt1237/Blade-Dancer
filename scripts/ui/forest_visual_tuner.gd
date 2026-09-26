class_name ForestVisualTuner extends VBoxContainer

const CATEGORY_NAMES: Array[String] = ["Profiles", "Ground", "Effects", "Details", "Border", "Arena"]
const DAY_PHASES: Array[String] = ["Noon", "Morning", "Dusk", "Night"]
var settings: ForestVisualSettings = null
var population: ArenaPopulation = null
## The active Global Preset's four day phases -- a live reference to the single
## dictionary main owns and saves. Editing a slider writes straight into it; the
## tuner never keeps a private shadow copy that could drift or overwrite it.
var day_phases: Dictionary = {}
## Phases edited since the last Global Save All. Cleared by mark_global_save_complete().
var dirty_phases: Dictionary = {}
var selected_phase: String = "Noon"
var phase_buttons: Array[Button] = []
## Base (undecorated) button labels, keyed by phase name, so dirty markers can be
## appended/removed without losing the original wording.
var phase_button_labels: Dictionary = {}
var phase_status_label: Label = null
## True while settings are being written from a stored phase (load) or by main
## (external world-clock application), so the resulting settings.changed is not
## mistaken for a fresh user edit and committed into the wrong phase.
var _suppress_commit: bool = false
var farmable_density_slider: HSlider = null
var big_things_density_slider: HSlider = null
var farmable_density_label: Label = null
var big_things_density_label: Label = null
var forest_tabs: TabContainer = null
var bypass_check: CheckBox = null
var feedback_label: Label = null
var comparison_label: Label = null
var controls: Dictionary = {}
var value_labels: Dictionary = {}
var category_buttons: Array[Button] = []
var _built: bool = false
var reset_button: Button = null

func configure(profile: ForestVisualSettings, arena_population: ArenaPopulation = null) -> void:
	if settings != profile:
		_disconnect_profile()
		settings = profile
	population = arena_population
	if is_inside_tree(): _connect_profile()
	_sync_controls()
	if _built:
		_sync_phase_buttons()

func _ready() -> void:
	if not _built:
		_build_ui()
		_built = true
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_connect_profile()
	_sync_controls()

func _exit_tree() -> void:
	_disconnect_profile()
	if settings != null: settings.set_bypass(false)

func _connect_profile() -> void:
	if settings == null: return
	if not settings.changed.is_connected(_sync_controls): settings.changed.connect(_sync_controls)
	if not settings.changed.is_connected(_on_settings_changed): settings.changed.connect(_on_settings_changed)
func _disconnect_profile() -> void:
	if settings == null: return
	if settings.changed.is_connected(_sync_controls): settings.changed.disconnect(_sync_controls)
	if settings.changed.is_connected(_on_settings_changed): settings.changed.disconnect(_on_settings_changed)

## Binds this tuner to the one day bundle main owns. `bundle` is stored by
## reference, so every edit lands in the dictionary Global Save All persists.
func attach_day_bundle(bundle: Dictionary, phase: String) -> void:
	day_phases = bundle
	selected_phase = phase if DAY_PHASES.has(phase) else "Noon"
	dirty_phases.clear()
	_load_selected_phase()
	_sync_phase_buttons()

func get_day_bundle() -> Dictionary:
	return day_phases

func get_selected_phase() -> String:
	return selected_phase

## Writes the live settings into the owned bundle's current phase. Main calls this
## before capturing a Global Preset so nothing tuned goes unsaved.
func commit_current_phase() -> void:
	if settings == null: return
	day_phases[selected_phase] = settings.values.duplicate(true)

## Lets main apply a phase to the live view without that apply being mistaken for
## a user edit (which would commit the applied values back into the wrong phase).
func set_suppress_commit(active: bool) -> void:
	_suppress_commit = active

## The world clock applied a new phase on its own; mirror the label only.
func sync_external_phase(phase: String) -> void:
	if not DAY_PHASES.has(phase):
		return
	selected_phase = phase
	_sync_phase_buttons()

func mark_global_save_complete() -> void:
	dirty_phases.clear()
	_sync_phase_buttons()

func end_comparison() -> void:
	if settings != null: settings.set_bypass(false)

## Leaving the panel (or the tools closing) ends any active A/B comparison.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): end_comparison()

## A genuine user edit: commit it into the owned bundle and flag the phase dirty.
func _on_settings_changed() -> void:
	if _suppress_commit: return
	commit_current_phase()
	dirty_phases[selected_phase] = true
	_sync_phase_buttons()

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_label(self, "Title", "FOREST VISUALS", 16)
	_add_label(self, "Introduction", "HD Forest + Backyard only. Noon preserves Hazey. Tune each of the four day phases here; Global Presets → SAVE ALL is the single save that owns them.")
	bypass_check = CheckBox.new(); bypass_check.name = "bypass_all"; bypass_check.text = "Bypass All Presentation Effects"; bypass_check.focus_mode = Control.FOCUS_NONE
	bypass_check.toggled.connect(_on_bypass_toggled); add_child(bypass_check)
	comparison_label = _add_label(self, "ComparisonStatus", "A/B bypass preserves values; ground stays tuned.")
	var actions: HBoxContainer = HBoxContainer.new(); actions.name = "ProfileActions"; add_child(actions)
	reset_button = _add_button(actions, "ResetDefaults", "Reset Defaults", _reset_defaults)
	feedback_label = _add_label(self, "Feedback", "")
	var categories: HBoxContainer = HBoxContainer.new(); categories.name = "Categories"; add_child(categories)
	for category: String in CATEGORY_NAMES:
		var button: Button = Button.new(); button.name = category; button.text = category; button.toggle_mode = true; button.focus_mode = Control.FOCUS_NONE; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.pressed.connect(_select_category.bind(category_buttons.size())); categories.add_child(button); category_buttons.append(button)
	forest_tabs = TabContainer.new(); forest_tabs.name = "ForestTabs"; forest_tabs.tabs_visible = false; forest_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; forest_tabs.use_hidden_tabs_for_min_size = false; add_child(forest_tabs)
	for category: String in CATEGORY_NAMES:
		var scroll: ScrollContainer = ScrollContainer.new(); scroll.name = category; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; forest_tabs.add_child(scroll)
		var content: VBoxContainer = VBoxContainer.new(); content.name = "Content"; content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)
		_add_label(content, "Help", _category_help(category))
		if category == "Profiles":
			_build_day_phase_controls(content)
		elif category == "Arena":
			_build_arena_controls(content)
		else:
			for spec: Dictionary in ForestVisualSettings.SPECS:
				if str(spec["group"]) == category: _add_setting(content, spec)
	forest_tabs.tab_changed.connect(_on_category_changed)
	_on_category_changed(0)

func _build_day_phase_controls(parent: VBoxContainer) -> void:
	_add_label(parent, "DayPhaseHint", "Click a phase to view and tune it. Switching a phase never moves the running day cycle.")
	var phase_row: HBoxContainer = HBoxContainer.new()
	phase_row.name = "DayPhaseTabs"
	parent.add_child(phase_row)
	for phase: String in DAY_PHASES:
		var phase_label: String = "HAZEY NOON" if phase == "Noon" else phase.to_upper()
		phase_button_labels[phase] = phase_label
		var button: Button = _add_button(phase_row, phase, phase_label, _select_day_phase.bind(phase))
		button.toggle_mode = true
		phase_buttons.append(button)
	phase_status_label = _add_label(parent, "PhaseStatus", "")
	_add_label(parent, "DirtyHint", "Edit a phase here, then use Global Presets → SAVE ALL to save the complete package.")
	_sync_phase_buttons()

func _build_arena_controls(parent: VBoxContainer) -> void:
	_add_label(parent, "ArenaHelp", "Live population tuning. Objects remain in authored sockets; density never adds random scatter.")
	farmable_density_label = _add_label(parent, "FarmableDensityLabel", "Farmable density")
	farmable_density_slider = HSlider.new()
	farmable_density_slider.name = "FarmableDensity"
	farmable_density_slider.min_value = 0.0
	farmable_density_slider.max_value = 1.0
	farmable_density_slider.step = 0.05
	farmable_density_slider.value_changed.connect(_on_farmable_density_changed)
	parent.add_child(farmable_density_slider)
	big_things_density_label = _add_label(parent, "BigThingsDensityLabel", "Big things density")
	big_things_density_slider = HSlider.new()
	big_things_density_slider.name = "BigThingsDensity"
	big_things_density_slider.min_value = 0.0
	big_things_density_slider.max_value = 1.0
	big_things_density_slider.step = 0.05
	big_things_density_slider.value_changed.connect(_on_big_things_density_changed)
	parent.add_child(big_things_density_slider)

## Loads the selected phase into the live view for preview/tuning. Never touches
## the running world clock.
func _load_selected_phase() -> void:
	if settings == null: return
	var values: Variant = day_phases.get(selected_phase, null)
	if values is Dictionary:
		_suppress_commit = true
		settings.apply_snapshot_values(values as Dictionary)
		_suppress_commit = false
		if is_instance_valid(population): population.set_time_phase(selected_phase)
		_set_phase_status("Viewing %s." % selected_phase)

func _select_day_phase(phase: String) -> void:
	commit_current_phase()
	selected_phase = phase if DAY_PHASES.has(phase) else "Noon"
	_load_selected_phase()
	_sync_phase_buttons()

func _sync_phase_buttons() -> void:
	for index: int in range(phase_buttons.size()):
		var phase_name: String = str(phase_buttons[index].name)
		var base_label: String = str(phase_button_labels.get(phase_name, phase_name.to_upper()))
		var marker: String = " *" if bool(dirty_phases.get(phase_name, false)) else ""
		phase_buttons[index].text = base_label + marker
		phase_buttons[index].set_pressed_no_signal(phase_name == selected_phase)

func _set_phase_status(text: String, success: bool = true) -> void:
	if phase_status_label != null:
		phase_status_label.text = text
		phase_status_label.modulate = Color(0.55, 1.0, 0.65) if success else Color(1.0, 0.5, 0.4)

func _on_farmable_density_changed(value: float) -> void:
	if is_instance_valid(population):
		population.set_farmable_density(value)
		var main_scene: Node = get_tree().current_scene
		if main_scene != null and main_scene.has_method("refresh_population_navigation"): main_scene.refresh_population_navigation()
	if farmable_density_label != null: farmable_density_label.text = "Farmable density: %d%%" % roundi(value * 100.0)

func _on_big_things_density_changed(value: float) -> void:
	if is_instance_valid(population):
		population.set_big_things_density(value)
		var main_scene: Node = get_tree().current_scene
		if main_scene != null and main_scene.has_method("refresh_population_navigation"): main_scene.refresh_population_navigation()
	if big_things_density_label != null: big_things_density_label.text = "Big things density: %d%%" % roundi(value * 100.0)

func _add_label(parent: Node, node_name: String, text: String, font_size: int = 13) -> Label:
	var label: Label = Label.new(); label.name = node_name; label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.add_theme_font_size_override("font_size", font_size); parent.add_child(label); return label
func _add_button(parent: Node, node_name: String, text: String, callback: Callable) -> Button:
	var button: Button = Button.new(); button.name = node_name; button.text = text; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(callback); parent.add_child(button); return button
func _category_help(category: String) -> String:
	match category:
		"Profiles": return "Each of the four day phases is owned by the active Global Preset. Noon is a Hazey copy. Click a phase to view and tune it; switching phases here never changes the running day cycle."
		"Ground": return "Ground materials: tune the clear, east-west dirt/grass composition."
		"Effects": return "Optional effects are OFF by default. Bloom may soften detail."
		"Details": return "Readable leaves and border accents; these never change collision."
		"Border": return "Increase ruins, stones, logs, boulders and trees without changing their gameplay footprints."
		"Arena": return "Tune the authored gameplay population without creating procedural clutter."
	return ""
func _add_setting(parent: VBoxContainer, spec: Dictionary) -> void:
	var key: String = str(spec["key"]); var title: String = str(spec["label"])
	if spec["default"] is bool:
		var check: CheckBox = CheckBox.new(); check.name = key; check.text = title; check.focus_mode = Control.FOCUS_NONE; check.toggled.connect(_on_check_toggled.bind(key)); parent.add_child(check); controls[key] = check; return
	var row: VBoxContainer = VBoxContainer.new(); row.name = key + "_row"; parent.add_child(row)
	var heading: HBoxContainer = HBoxContainer.new(); heading.name = "Heading"; row.add_child(heading); _add_label(heading, "Caption", title); var value_label: Label = _add_label(heading, "Value", ""); value_label.name = "Value"; value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; value_label.custom_minimum_size.x = 52.0; value_labels[key] = value_label
	var slider: HSlider = HSlider.new(); slider.name = key; slider.min_value = float(spec["min"]); slider.max_value = float(spec["max"]); slider.step = float(spec["step"]); slider.focus_mode = Control.FOCUS_NONE; slider.scrollable = false; slider.value_changed.connect(_on_slider_changed.bind(key)); row.add_child(slider); controls[key] = slider
func _select_category(index: int) -> void:
	forest_tabs.current_tab = index
func _on_category_changed(index: int) -> void:
	for i: int in range(category_buttons.size()): category_buttons[i].set_pressed_no_signal(i == index)
func _sync_controls() -> void:
	if not _built: return
	for spec: Dictionary in ForestVisualSettings.SPECS:
		var key: String = str(spec["key"]); var value: Variant = spec["default"] if settings == null else settings.get_value(key)
		if spec["default"] is bool: (controls[key] as CheckBox).disabled = settings == null; (controls[key] as CheckBox).set_pressed_no_signal(bool(value))
		else: (controls[key] as HSlider).editable = settings != null; (controls[key] as HSlider).set_value_no_signal(float(value)); (value_labels[key] as Label).text = ("%.0f" if float(spec["step"]) >= 1.0 else "%.2f") % float(value)
	if bypass_check != null: bypass_check.disabled = settings == null; bypass_check.set_pressed_no_signal(settings != null and settings.bypass_all)
	if reset_button != null: reset_button.disabled = settings == null
	if is_instance_valid(population):
		if farmable_density_slider != null: farmable_density_slider.set_value_no_signal(population.farmable_density)
		if big_things_density_slider != null: big_things_density_slider.set_value_no_signal(population.big_things_density)
		if farmable_density_label != null: farmable_density_label.text = "Farmable density: %d%%" % roundi(population.farmable_density * 100.0)
		if big_things_density_label != null: big_things_density_label.text = "Big things density: %d%%" % roundi(population.big_things_density * 100.0)
	if comparison_label != null: comparison_label.text = "CLEAN A/B ACTIVE — effects and particles bypassed." if settings != null and settings.bypass_all else "A/B bypass preserves values; ground stays tuned."
func _on_slider_changed(value: float, key: String) -> void:
	if settings != null: settings.set_value(key, value)
func _on_check_toggled(value: bool, key: String) -> void:
	if settings != null: settings.set_value(key, value)
func _on_bypass_toggled(value: bool) -> void:
	if settings != null: settings.set_bypass(value)
func _reset_defaults() -> void:
	if settings != null:
		settings.reset_defaults()
		_set_feedback("Defaults restored. Global Presets are unchanged until you save.", true)

func _set_feedback(text: String, success: bool) -> void:
	if feedback_label != null: feedback_label.text = text; feedback_label.modulate = Color(0.55, 1.0, 0.65) if success else Color(1.0, 0.5, 0.4)

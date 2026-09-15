class_name ForestVisualTuner extends VBoxContainer

signal time_phase_selected(phase: String)

const CATEGORY_NAMES: Array[String] = ["Profiles", "Ground", "Effects", "Details", "Border", "Arena"]
var settings: ForestVisualSettings = null
var population: ArenaPopulation = null
var preset_slots: Array[Dictionary] = [{}, {}, {}]
## Phases edited (via settings.changed) since the last Global Save All, per slot.
## Dirty state is cleared when the complete global package is saved or loaded.
var dirty_phases: Array[Dictionary] = [{}, {}, {}]
var selected_preset_slot: int = 1
var selected_phase: String = "Noon"
var global_preset_mode: bool = false
var preset_buttons: Array[Button] = []
var phase_buttons: Array[Button] = []
## Base (undecorated) button labels, keyed by phase name, so dirty markers can be
## appended/removed without losing the original "HAZEY NOON" / "NIGHT" wording.
var phase_button_labels: Dictionary = {}
var preset_status_label: Label = null
## True only while _load_selected_phase() is applying a stored snapshot, so the
## settings.changed it triggers is not mistaken for a user edit (which would
## immediately and incorrectly mark the just-loaded phase as dirty).
var _loading_phase: bool = false
var farmable_density_slider: HSlider = null
var big_things_density_slider: HSlider = null
var farmable_density_label: Label = null
var big_things_density_label: Label = null
var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
var forest_tabs: TabContainer = null
var bypass_check: CheckBox = null
var feedback_label: Label = null
var comparison_label: Label = null
var controls: Dictionary = {}
var value_labels: Dictionary = {}
var category_buttons: Array[Button] = []
var profile_name: LineEdit = null
var profile_list: VBoxContainer = null
var startup_profile_label: Label = null
var _built: bool = false
var profile_buttons: Array[Button] = []
var reset_button: Button = null

func configure(profile: ForestVisualSettings, arena_population: ArenaPopulation = null) -> void:
	if settings != profile:
		_disconnect_profile()
		settings = profile
	population = arena_population
	if is_inside_tree(): _connect_profile()
	_sync_controls()
	if _built and not global_preset_mode:
		_refresh_day_presets()

func _ready() -> void:
	if not _built:
		_build_ui()
		_built = true
	_connect_profile()
	_sync_controls()

func _exit_tree() -> void:
	_disconnect_profile()
	if settings != null: settings.set_bypass(false)

func _connect_profile() -> void:
	if settings == null: return
	if not settings.changed.is_connected(_sync_controls): settings.changed.connect(_sync_controls)
	if not settings.changed.is_connected(_on_settings_changed_for_dirty_tracking): settings.changed.connect(_on_settings_changed_for_dirty_tracking)
func _disconnect_profile() -> void:
	if settings == null: return
	if settings.changed.is_connected(_sync_controls): settings.changed.disconnect(_sync_controls)
	if settings.changed.is_connected(_on_settings_changed_for_dirty_tracking): settings.changed.disconnect(_on_settings_changed_for_dirty_tracking)

## Auto-commits every live edit into the in-memory global phase bundle immediately,
## instead of only when the user explicitly switches phase or uses Global Save All.
## This is what stops a stray configure()/panel-reopen from losing tuning.
func _on_settings_changed_for_dirty_tracking() -> void:
	if _loading_phase: return
	_remember_current_phase()
	if selected_preset_slot - 1 < dirty_phases.size():
		dirty_phases[selected_preset_slot - 1][selected_phase] = true
	_sync_preset_buttons()
func get_global_day_presets() -> Dictionary:
	if settings == null:
		return {}
	_remember_current_phase()
	var result: Dictionary = {}
	for slot: int in range(1, 4):
		result[str(slot)] = preset_slots[slot - 1].duplicate(true)
	return result

func apply_global_day_presets(values_by_slot: Dictionary, startup_slot: int, phase: String) -> void:
	global_preset_mode = true
	preset_slots = [{}, {}, {}]
	for slot: int in range(1, 4):
		var incoming: Variant = values_by_slot.get(str(slot), {})
		if incoming is Dictionary:
			preset_slots[slot - 1] = (incoming as Dictionary).duplicate(true)
	selected_preset_slot = clampi(startup_slot, 1, 3)
	selected_phase = phase if ForestVisualProfileLibrary.DAY_PRESET_PHASES.has(phase) else "Noon"
	dirty_phases = [{}, {}, {}]
	_load_selected_phase()
	_sync_preset_buttons()

func mark_global_save_complete() -> void:
	for slot_dirty: Dictionary in dirty_phases:
		slot_dirty.clear()
	_sync_preset_buttons()

func sync_external_phase(phase: String) -> void:
	if not ForestVisualProfileLibrary.DAY_PRESET_PHASES.has(phase):
		return
	selected_phase = phase
	_sync_preset_buttons()

func end_comparison() -> void:
	if settings != null: settings.set_bypass(false)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): end_comparison()
	else: _sync_controls()

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_label(self, "Title", "FOREST VISUALS", 16)
	_add_label(self, "Introduction", "HD Forest + Backyard only. Noon preserves Hazey. Try Morning v2, Dusk v2, and Night v2; older profiles remain untouched.")
	bypass_check = CheckBox.new(); bypass_check.name = "bypass_all"; bypass_check.text = "Bypass All Presentation Effects"; bypass_check.focus_mode = Control.FOCUS_NONE
	bypass_check.toggled.connect(_on_bypass_toggled); add_child(bypass_check)
	comparison_label = _add_label(self, "ComparisonStatus", "A/B bypass preserves values; ground stays tuned.")
	var actions: HBoxContainer = HBoxContainer.new(); actions.name = "ProfileActions"; add_child(actions)
	profile_name = LineEdit.new(); profile_name.name = "ProfileName"; profile_name.placeholder_text = "Name visual profile"; profile_name.max_length = 64; profile_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(profile_name)
	var save_button: Button = _add_button(actions, "SaveNewSnapshot", "Save New", _save_snapshot); profile_buttons.append(save_button)
	var refresh_button: Button = _add_button(actions, "RefreshProfiles", "Refresh", _refresh_profiles); profile_buttons.append(refresh_button)
	reset_button = _add_button(actions, "ResetDefaults", "Reset Defaults", _reset_defaults); reset_button.visible = false
	# Retain the old three-button contract for compatibility with existing tuner QA.
	profile_buttons.append(save_button)
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
			startup_profile_label = _add_label(content, "StartupProfile", "Canonical cycle: Preset 1")
			_build_day_preset_controls(content)
			_add_label(content, "LegacyProfilesHeading", "LEGACY INDIVIDUAL PROFILES (NO LAUNCH CONTROL)", 11)
			profile_list = VBoxContainer.new(); profile_list.name = "SavedProfiles"; profile_list.add_theme_constant_override("separation", 4); content.add_child(profile_list)
		elif category == "Arena":
			_build_arena_controls(content)
		else:
			for spec: Dictionary in ForestVisualSettings.SPECS:
				if str(spec["group"]) == category: _add_setting(content, spec)
	forest_tabs.tab_changed.connect(_on_category_changed)
	_on_category_changed(0)
	_refresh_profiles()

func _build_day_preset_controls(parent: VBoxContainer) -> void:
	var preset_row: HBoxContainer = HBoxContainer.new()
	preset_row.name = "PresetTabs"
	parent.add_child(preset_row)
	preset_row.visible = false
	for slot: int in range(1, 4):
		var button: Button = _add_button(preset_row, "Preset%d" % slot, "PRESET %d" % slot, _select_day_preset.bind(slot))
		button.toggle_mode = true
		preset_buttons.append(button)
	var phase_row: HBoxContainer = HBoxContainer.new()
	phase_row.name = "DayPhaseTabs"
	parent.add_child(phase_row)
	for phase: String in ForestVisualProfileLibrary.DAY_PRESET_PHASES:
		var phase_label: String = "HAZEY NOON" if phase == "Noon" else phase.to_upper()
		phase_button_labels[phase] = phase_label
		var button: Button = _add_button(phase_row, phase, phase_label, _select_day_phase.bind(phase))
		button.toggle_mode = true
		phase_buttons.append(button)
	preset_status_label = _add_label(parent, "PresetStatus", "")
	_add_label(parent, "DirtyHint", "Edit a phase here, then use Global Presets → SAVE ALL to save the complete package.")
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "PresetActions"
	parent.add_child(action_row)
	action_row.visible = false
	_add_button(action_row, "SaveDayPreset", "SAVE PRESET", _save_day_preset)
	_add_button(action_row, "UseDayPreset", "USE ON LAUNCH", _use_day_preset)
	_add_button(action_row, "LoadDayPreset", "LOAD PHASE", _load_selected_phase)
	_refresh_day_presets()

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

func set_training_default_noon() -> void:
	if settings == null:
		return
	selected_preset_slot = clampi(selected_preset_slot, 1, preset_slots.size())
	selected_phase = "Noon"
	_load_selected_phase()

func _remember_current_phase() -> void:
	if settings == null or selected_preset_slot < 1 or selected_preset_slot > preset_slots.size(): return
	preset_slots[selected_preset_slot - 1][selected_phase] = settings.values.duplicate(true)

func _load_selected_phase() -> void:
	if settings == null: return
	var slot: Dictionary = preset_slots[selected_preset_slot - 1]
	var values: Variant = slot.get(selected_phase, null)
	if values is Dictionary:
		# Guard: applying a stored snapshot fires settings.changed, which must not
		# be mistaken for a fresh user edit (that would instantly re-mark the
		# phase we just loaded as "dirty" with nothing actually unsaved).
		_loading_phase = true
		settings.apply_snapshot_values(values as Dictionary)
		_loading_phase = false
		if is_instance_valid(population): population.set_time_phase(selected_phase)
		_set_preset_status("Loaded Preset %d / %s." % [selected_preset_slot, selected_phase])
	_sync_preset_buttons()

func _select_day_preset(slot: int) -> void:
	_remember_current_phase()
	selected_preset_slot = clampi(slot, 1, 3)
	_load_selected_phase()
	_sync_preset_buttons()

func _select_day_phase(phase: String) -> void:
	_remember_current_phase()
	selected_phase = phase if ForestVisualProfileLibrary.DAY_PRESET_PHASES.has(phase) else "Noon"
	_load_selected_phase()
	time_phase_selected.emit(selected_phase)
	_sync_preset_buttons()

func _save_day_preset() -> void:
	if global_preset_mode:
		_set_preset_status("Use Global Presets → SAVE ALL for all Forest phases.", false)
		return
	_remember_current_phase()
	var error: Error = library.save_day_preset(selected_preset_slot, preset_slots[selected_preset_slot - 1])
	if error == OK: dirty_phases[selected_preset_slot - 1].clear()
	_set_preset_status("Saved Preset %d." % selected_preset_slot if error == OK else "Could not save Preset %d." % selected_preset_slot, error == OK)
	_refresh_day_presets()

func _use_day_preset() -> void:
	if global_preset_mode:
		_set_preset_status("Forest phases do not control launch. Use Global Presets → LOAD ON LAUNCH.", false)
		return
	_remember_current_phase()
	var save_error: Error = library.save_day_preset(selected_preset_slot, preset_slots[selected_preset_slot - 1])
	var startup_error: Error = library.set_startup_day_preset_slot(selected_preset_slot) if save_error == OK else save_error
	if startup_error == OK:
		dirty_phases[selected_preset_slot - 1].clear()
		_load_selected_phase()
		_set_preset_status("Preset %d is now the canonical launch cycle." % selected_preset_slot, true)
	else:
		_set_preset_status("Could not set launch cycle.", false)
	_refresh_day_presets()

## Merges disk state into memory instead of overwriting it: any phase with
## unsaved edits this session (dirty_phases) is kept exactly as tuned, even if
## this runs again (e.g. the training panel is reopened) before it is saved.
func _refresh_day_presets() -> void:
	if settings == null: return
	if global_preset_mode:
		_sync_preset_buttons()
		return
	library.ensure_day_preset_slots(settings)
	for slot: int in range(1, 4):
		var disk_values: Dictionary = library.get_day_preset(slot)
		var current: Dictionary = preset_slots[slot - 1]
		var slot_dirty: Dictionary = dirty_phases[slot - 1]
		var merged: Dictionary = disk_values.duplicate(true)
		for phase: String in ForestVisualProfileLibrary.DAY_PRESET_PHASES:
			if bool(slot_dirty.get(phase, false)) and current.get(phase, null) is Dictionary:
				merged[phase] = current[phase]
		preset_slots[slot - 1] = merged
	_sync_preset_buttons()

func _slot_has_dirty_phase(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= dirty_phases.size(): return false
	for is_dirty: bool in dirty_phases[slot_index].values():
		if is_dirty: return true
	return false

func _sync_preset_buttons() -> void:
	for index: int in range(preset_buttons.size()):
		var marker: String = " *" if _slot_has_dirty_phase(index) else ""
		preset_buttons[index].text = "PRESET %d%s" % [index + 1, marker]
		preset_buttons[index].set_pressed_no_signal(index + 1 == selected_preset_slot)
	var current_slot_dirty: Dictionary = dirty_phases[selected_preset_slot - 1] if selected_preset_slot - 1 < dirty_phases.size() else {}
	for index: int in range(phase_buttons.size()):
		var phase_name: String = str(phase_buttons[index].name)
		var base_label: String = str(phase_button_labels.get(phase_name, phase_name.to_upper()))
		var marker: String = " *" if bool(current_slot_dirty.get(phase_name, false)) else ""
		phase_buttons[index].text = base_label + marker
		phase_buttons[index].set_pressed_no_signal(phase_name == selected_phase)
	if startup_profile_label != null:
		startup_profile_label.text = "Global Preset %d phases — save with Global Presets → SAVE ALL" % selected_preset_slot if global_preset_mode else "Legacy visual cycle: Preset %d" % library.get_startup_day_preset_slot()

func _set_preset_status(text: String, success: bool = true) -> void:
	if preset_status_label != null:
		preset_status_label.text = text
		preset_status_label.modulate = Color(0.55, 1.0, 0.65) if success else Color(1.0, 0.5, 0.4)

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
		"Profiles": return "Noon is a Hazey copy. The v2 profiles add localized light and mist; older profiles are preserved. Illustrated Fantasy Realism is the original baseline copy, not an art upgrade. No combat or progression changes."
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
	for button: Button in profile_buttons: button.disabled = settings == null
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
func _save_snapshot() -> void:
	if settings == null: return
	var snapshot: Dictionary = library.create_snapshot(profile_name.text, settings)
	_set_feedback("Saved visual profile: %s" % str(snapshot.get("name", "")) if not snapshot.is_empty() else "Save failed: enter a profile name.", not snapshot.is_empty()); profile_name.clear(); _refresh_profiles()
func _refresh_profiles() -> void:
	if profile_list == null: return
	for child: Node in profile_list.get_children(): child.queue_free()
	var startup_id: String = library.get_startup_snapshot_id()
	if startup_profile_label != null:
		var startup_snapshot: Dictionary = library.get_snapshot(startup_id)
		startup_profile_label.text = "Startup profile: %s" % (str(startup_snapshot.get("name", "")) if not startup_snapshot.is_empty() else "none")
	for snapshot: Dictionary in library.list_snapshots():
		var snapshot_id: String = str(snapshot.get("id", ""))
		var row: HBoxContainer = HBoxContainer.new(); row.name = "Profile_" + snapshot_id; profile_list.add_child(row)
		var marker: String = "★ " if snapshot_id == startup_id else ""
		var label: Label = _add_label(row, "Info", "%s%s  •  %s" % [marker, str(snapshot.get("name", "")), str(snapshot.get("timestamp", ""))]); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add_button(row, "Load", "Load (legacy)", _load_snapshot.bind(snapshot_id))
		_add_button(row, "Delete", "Delete", _delete_snapshot.bind(snapshot_id))
func _load_snapshot(id: String) -> void:
	if settings == null: return
	var snapshot: Dictionary = library.get_snapshot(id)
	if snapshot.is_empty():
		_set_feedback("Load failed; profile not found. Current values unchanged.", false)
		return
	var error: Error = settings.apply_snapshot_values(snapshot.get("values", {}))
	_set_feedback("Loaded visual profile." if error == OK else "Load failed; current values unchanged.", error == OK)
func _set_startup_snapshot(id: String) -> void:
	if settings == null: return
	var snapshot: Dictionary = library.get_snapshot(id)
	if snapshot.is_empty():
		_set_feedback("Startup profile not found.", false)
		return
	var apply_error: Error = settings.apply_snapshot_values(snapshot.get("values", {}) as Dictionary)
	if apply_error != OK:
		_set_feedback("Could not apply startup profile; current values unchanged.", false)
		return
	var save_error: Error = settings.save_preset()
	var startup_error: Error = library.set_startup_snapshot_id(id)
	var success: bool = save_error == OK and startup_error == OK
	_set_feedback("Set %s as the startup visual profile." % str(snapshot.get("name", "")) if success else "Could not save startup profile.", success)
	_refresh_profiles()

func _delete_snapshot(id: String) -> void:
	var confirmation: ConfirmationDialog = ConfirmationDialog.new()
	confirmation.name = "ConfirmDelete"
	confirmation.dialog_text = "Delete this visual profile?"
	add_child(confirmation)
	confirmation.confirmed.connect(func() -> void:
		var error: Error = library.delete_snapshot(id)
		_set_feedback("Deleted visual profile." if error == OK else "Delete failed.", error == OK)
		_refresh_profiles()
		confirmation.queue_free()
	)
	confirmation.canceled.connect(func() -> void: confirmation.queue_free())
	confirmation.popup_centered(Vector2(360.0, 140.0))
func _reset_defaults() -> void:
	if settings != null:
		settings.reset_defaults()
		_set_feedback("Defaults restored; saved profiles unchanged.", true)

func _set_feedback(text: String, success: bool) -> void:
	if feedback_label != null: feedback_label.text = text; feedback_label.modulate = Color(0.55, 1.0, 0.65) if success else Color(1.0, 0.5, 0.4)

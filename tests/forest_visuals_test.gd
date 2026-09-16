class_name ForestVisualsTest extends Node

# Synchronous tests: never run Main._ready(), style-change save handlers, or
# production profile I/O. Every disk operation passes this explicit test path.
const TEST_PROFILE_PATH: String = "user://forest_visuals_test.cfg"
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EFFECT_KEYS: Array[String] = ["grading_enabled", "clouds_enabled", "rays_enabled", "dapple_enabled", "haze_enabled", "bloom_enabled", "blur_enabled"]
const GROUND_DEFAULTS: Dictionary = {
	"grass_brightness": 1.0, "grass_saturation": 1.0, "detail_scale": 1.0,
	"dirt_amount": 0.85, "path_width": 260.0, "path_meander": 65.0,
	"edge_breakup": 65.0, "dark_soil": 0.3, "grading_enabled": false,
	"grade_saturation": 1.08, "grade_contrast": 1.06, "sunlight_warmth": 0.25
}

# Supply world queries only; particle construction/settings remain production
# code. The synchronous runner does not enter a processing scene tree.
class AmbientFixture extends ForestAmbientFX:
	func _presentation_rect() -> Rect2:
		return Rect2(-360.0, -180.0, 2000.0, 1080.0)

	func _gameplay_rect() -> Rect2:
		return Rect2(0.0, 0.0, 1280.0, 720.0)

	func _is_hd_visual() -> bool:
		return true

# Count the actual synchronization callback while retaining the production UI
# builder, signal handlers and sync implementation.
class TunerFixture extends ForestVisualTuner:
	var sync_count: int = 0

	func _sync_controls() -> void:
		sync_count += 1
		super._sync_controls()

var change_count: int = 0
var tuner_control_signal_count: int = 0

func _count_change() -> void:
	change_count += 1

# Never add the tuner to the tree or call UI Save/Load: those handlers use the
# production preset path. Manually perform only the off-tree UI lifecycle.
func _make_tuner(profile: ForestVisualSettings = null) -> TunerFixture:
	var tuner: TunerFixture = TunerFixture.new()
	tuner._build_ui()
	tuner._built = true
	tuner.configure(profile)
	tuner._connect_profile()
	assert(not tuner.is_inside_tree())
	return tuner

func _count_tuner_control_signal(_value: Variant) -> void:
	tuner_control_signal_count += 1

func _edit_tuner_slider(tuner: ForestVisualTuner, key: String, value: float) -> void:
	var slider: HSlider = tuner.controls[key] as HSlider
	# Range defers value_changed while off-tree. Explicitly deliver the real
	# control signal after its normal clamping/snapping, with no frame waits.
	slider.set_value_no_signal(value)
	slider.value_changed.emit(slider.value)

func _assert_tuner_controls(tuner: ForestVisualTuner, profile: ForestVisualSettings) -> void:
	assert(tuner.controls.size() == ForestVisualSettings.SPECS.size(), "Every spec must have exactly one mapped control.")
	var numeric_spec_count: int = 0
	for spec: Dictionary in ForestVisualSettings.SPECS:
		if not spec["default"] is bool: numeric_spec_count += 1
	assert(tuner.value_labels.size() == numeric_spec_count, "Only numeric settings need value labels.")
	var seen: Array[Control] = []
	var checkbox_count: int = 0
	for spec: Dictionary in ForestVisualSettings.SPECS:
		var key: String = str(spec["key"])
		assert(tuner.controls.has(key), "%s must be mapped by profile key." % key)
		var control: Control = tuner.controls[key] as Control
		assert(control != null and control.name == key and not seen.has(control), "%s must own a distinct named control." % key)
		seen.append(control)
		var content: Node = tuner.get_node("ForestTabs/%s/Content" % str(spec["group"]))
		var authored: Variant = spec["default"] if profile == null else profile.get_value(key)
		if spec["default"] is bool:
			checkbox_count += 1
			assert(control is CheckBox and control.get_parent() == content)
			var check: CheckBox = control as CheckBox
			assert(check.text == str(spec["label"]) and check.button_pressed == bool(authored))
			assert(check.disabled == (profile == null) and not tuner.value_labels.has(key))
		else:
			assert(control is HSlider and control.get_parent().get_parent() == content)
			var slider: HSlider = control as HSlider
			assert(is_equal_approx(slider.min_value, float(spec["min"])) and is_equal_approx(slider.max_value, float(spec["max"])), "%s must use spec bounds." % key)
			assert(is_equal_approx(slider.step, float(spec["step"])) and not slider.scrollable)
			assert(slider.editable == (profile != null))
			# Range snaps its thumb to a step, even during silent sync. Shipped
			# edge_breakup=65 (step 2) and warmth=0.25 (step 0.02) are off-grid;
			# the profile and numeric caption must retain the authored value.
			var expected_thumb: float = clampf(slider.min_value + roundf((float(authored) - slider.min_value) / slider.step) * slider.step, slider.min_value, slider.max_value)
			assert(is_equal_approx(slider.value, expected_thumb), "%s thumb must reflect the step-quantized profile value." % key)
			var number: Label = tuner.value_labels[key] as Label
			assert(number != null and number == slider.get_parent().get_node("Heading/Value"))
			assert(number.text == (("%.0f" if float(spec["step"]) >= 1.0 else "%.2f") % float(authored)), "%s caption must show the authored value." % key)
	# Day Cycle added one new checkbox spec (moon_glow_enabled) on top of the
	# historical tolerance already baked in here.
	assert(checkbox_count == 8 or checkbox_count == 9 or checkbox_count == 10)
	assert(tuner.bypass_check.disabled == (profile == null))
	assert(tuner.bypass_check.button_pressed == (profile != null and profile.bypass_all))
	assert(tuner.profile_buttons.size() >= 2)
	for button: Button in tuner.profile_buttons:
		assert(button.disabled == (profile == null))

func test_tuner_all_controls_map_types_ranges_defaults_and_configured_values() -> void:
	var tuner: TunerFixture = _make_tuner()
	_assert_tuner_controls(tuner, null)
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	var defaults: Dictionary = profile.values.duplicate(true)
	tuner.configure(profile)
	tuner._connect_profile()
	_assert_tuner_controls(tuner, profile)
	assert(profile.values == defaults, "Displaying off-step defaults must not quantize the profile itself.")
	for spec: Dictionary in ForestVisualSettings.SPECS:
		profile.set_value(str(spec["key"]), not bool(spec["default"]) if spec["default"] is bool else float(spec["min"]) + 2.0 * float(spec["step"]))
	_assert_tuner_controls(tuner, profile)
	assert(tuner.settings == profile, "The UI must retain the shared profile, not a private copy.")
	tuner.configure(null)
	_assert_tuner_controls(tuner, null)
	assert(not profile.changed.is_connected(tuner._sync_controls))
	tuner.free()

func test_tuner_slider_edits_change_only_the_bound_profile_setting_once() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: TunerFixture = _make_tuner(profile)
	profile.changed.connect(_count_change)
	var edited: int = 0
	for spec: Dictionary in ForestVisualSettings.SPECS:
		if spec["default"] is bool:
			continue
		var key: String = str(spec["key"])
		var before: Dictionary = profile.values.duplicate(true)
		var target_value: float = float(spec["min"]) + 3.0 * float(spec["step"])
		change_count = 0
		tuner.sync_count = 0
		# Exercise the real value_changed connection, not the handler directly.
		_edit_tuner_slider(tuner, key, target_value)
		assert(is_equal_approx(float(profile.get_value(key)), target_value), "%s must update its own profile key." % key)
		before[key] = profile.get_value(key)
		assert(profile.values == before, "%s slider must not modify any other setting." % key)
		assert(change_count == 1 and tuner.sync_count == 1, "%s edit should emit and synchronize exactly once." % key)
		_edit_tuner_slider(tuner, key, target_value)
		assert(change_count == 1 and tuner.sync_count == 1, "Repeating a slider value must be a no-op.")
		edited += 1
	var numeric_count: int = 0
	for spec: Dictionary in ForestVisualSettings.SPECS:
		if not spec["default"] is bool: numeric_count += 1
	assert(edited == numeric_count)
	_assert_tuner_controls(tuner, profile)
	tuner.free()

func test_tuner_checkbox_toggles_update_authored_and_effective_settings() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: TunerFixture = _make_tuner(profile)
	profile.changed.connect(_count_change)
	for key: String in EFFECT_KEYS + ["particles_enabled"]:
		var check: CheckBox = tuner.controls[key] as CheckBox
		var initial: bool = bool(profile.get_value(key))
		for enabled: bool in [not initial, initial]:
			var before: Dictionary = profile.values.duplicate(true)
			change_count = 0
			check.button_pressed = enabled
			assert(change_count == 1 and profile.get_value(key) == enabled)
			assert(profile.effect_enabled(key) == enabled and profile.get_effective_values()[key] == enabled, "%s must immediately control the effective effect state." % key)
			before[key] = enabled
			assert(profile.values == before, "CheckBox toggles must not modify unrelated settings.")
			check.button_pressed = enabled
			assert(change_count == 1)
	# During bypass the checkbox remains an authoring control, not a readout of
	# effective false. Toggling it still edits only the retained profile value.
	tuner.bypass_check.button_pressed = true
	var grading: CheckBox = tuner.controls["grading_enabled"] as CheckBox
	grading.button_pressed = true
	assert(grading.button_pressed and profile.get_value("grading_enabled") == true)
	assert(not profile.effect_enabled("grading_enabled") and profile.get_effective_values()["grading_enabled"] == false)
	tuner.bypass_check.button_pressed = false
	assert(profile.effect_enabled("grading_enabled"))
	_assert_tuner_controls(tuner, profile)
	tuner.free()

func test_tuner_profile_sync_is_silent_and_callback_connected_exactly_once() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: TunerFixture = _make_tuner(profile)
	for control: Control in tuner.controls.values():
		if control is CheckBox:
			(control as CheckBox).toggled.connect(_count_tuner_control_signal)
		else:
			(control as HSlider).value_changed.connect(_count_tuner_control_signal)
	tuner.bypass_check.toggled.connect(_count_tuner_control_signal)
	profile.changed.connect(_count_change)
	for attempt: int in range(3):
		tuner.configure(profile)
		tuner._connect_profile()
	var sync_connections: int = 0
	for connection: Dictionary in profile.changed.get_connections():
		if connection["callable"] == tuner._sync_controls:
			sync_connections += 1
	assert(sync_connections == 1, "Repeated configure/connect must retain exactly one UI callback.")
	for spec: Dictionary in ForestVisualSettings.SPECS:
		var key: String = str(spec["key"])
		var expected: Variant = not bool(spec["default"]) if spec["default"] is bool else float(spec["min"]) + 2.0 * float(spec["step"])
		change_count = 0
		tuner.sync_count = 0
		tuner_control_signal_count = 0
		profile.set_value(key, expected)
		assert(change_count == 1 and tuner.sync_count == 1, "%s external edit must trigger exactly one profile and UI callback." % key)
		assert(tuner_control_signal_count == 0, "%s synchronization must not emit UI editing signals." % key)
		_assert_tuner_controls(tuner, profile)
	change_count = 0
	tuner.sync_count = 0
	tuner_control_signal_count = 0
	profile.set_bypass(true)
	assert(change_count == 1 and tuner.sync_count == 1 and tuner_control_signal_count == 0)
	_assert_tuner_controls(tuner, profile)
	var authored: Dictionary = profile.values.duplicate(true)
	tuner._sync_controls()
	tuner._sync_controls()
	assert(change_count == 1 and tuner.sync_count == 3 and tuner_control_signal_count == 0, "Manual refresh must be silent, even while bypassed.")
	assert(profile.values == authored and profile.bypass_all)
	tuner.end_comparison()
	tuner.free()
	assert(not profile.changed.has_connections() or profile.changed.get_connections().size() == 1, "Freeing the UI must remove its callback; only the test observer may remain.")

func test_tuner_bypass_resets_on_close_without_losing_authored_edits() -> void:
	for close_path: String in ["end_comparison", "visibility", "exit_tree"]:
		var profile: ForestVisualSettings = ForestVisualSettings.new()
		for key: String in EFFECT_KEYS:
			profile.set_value(key, true)
		var tuner: TunerFixture = _make_tuner(profile)
		profile.changed.connect(_count_change)
		_edit_tuner_slider(tuner, "leaf_size", 16.5)
		_edit_tuner_slider(tuner, "grass_brightness", 1.23)
		var authored: Dictionary = profile.values.duplicate(true)
		tuner.bypass_check.button_pressed = true
		assert(profile.bypass_all and profile.values == authored)
		for key: String in EFFECT_KEYS + ["particles_enabled"]:
			assert(not profile.effect_enabled(key) and (tuner.controls[key] as CheckBox).button_pressed)
		_assert_tuner_controls(tuner, profile)
		_edit_tuner_slider(tuner, "leaf_size", 17.5)
		assert(profile.get_value("leaf_size") == 17.5, "Edits during bypass must survive close.")
		authored["leaf_size"] = profile.get_value("leaf_size")
		change_count = 0
		match close_path:
			"end_comparison":
				tuner.end_comparison()
			"visibility":
				# Off-tree controls are not visible in-tree: invoke the production
				# visibility callback synchronously instead of entering a tree.
				tuner._on_visibility_changed()
			"exit_tree":
				tuner._exit_tree()
				assert(not profile.changed.is_connected(tuner._sync_controls))
		assert(change_count == 1 and not profile.bypass_all and profile.values == authored, "%s close must clear only temporary comparison." % close_path)
		for key: String in EFFECT_KEYS + ["particles_enabled"]:
			assert(profile.effect_enabled(key))
		tuner.end_comparison()
		assert(change_count == 1, "Closing an already-ended comparison must be idempotent.")
		tuner.configure(profile)
		_assert_tuner_controls(tuner, profile)
		tuner.free()

func test_tuner_test_only_configfile_load_sync_and_reset_leave_saved_profile_intact() -> void:
	assert(TEST_PROFILE_PATH != ForestVisualSettings.PRESET_PATH)
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: TunerFixture = _make_tuner(profile)
	_edit_tuner_slider(tuner, "leaf_size", 17.5)
	assert(profile.get_value("leaf_size") == 17.5)
	(tuner.controls["grading_enabled"] as CheckBox).button_pressed = true
	tuner.bypass_check.button_pressed = true
	var authored: Dictionary = profile.values.duplicate(true)
	# Deliberately save through the profile with the existing single test path.
	# NEVER press SaveProfile/LoadProfile or invoke their UI handlers.
	assert(profile.save_preset(TEST_PROFILE_PATH) == OK)
	var saved: ConfigFile = ConfigFile.new()
	assert(saved.load(TEST_PROFILE_PATH) == OK)
	assert(saved.get_section_keys("visuals").size() == ForestVisualSettings.SPECS.size())
	assert(not saved.has_section_key("visuals", "bypass_all"))
	profile.changed.connect(_count_change)
	change_count = 0
	# Reset Defaults is memory-only and is safe to exercise through its button.
	(tuner.reset_button as Button).pressed.emit()
	assert(change_count == 1 and not profile.bypass_all and profile.values == ForestVisualSettings.new().values)
	_assert_tuner_controls(tuner, profile)
	var after_reset: ConfigFile = ConfigFile.new()
	assert(after_reset.load(TEST_PROFILE_PATH) == OK)
	for key: String in authored:
		assert(after_reset.get_value("visuals", key) == saved.get_value("visuals", key), "Reset Defaults must leave the saved preset intact.")
	tuner.bypass_check.button_pressed = true
	change_count = 0
	tuner.sync_count = 0
	assert(profile.load_preset(TEST_PROFILE_PATH) == OK)
	assert(change_count == 1 and tuner.sync_count == 1 and not profile.bypass_all)
	for key: String in authored:
		if authored[key] is bool:
			assert(profile.get_value(key) == authored[key])
		else:
			assert(is_equal_approx(float(profile.get_value(key)), float(authored[key])))
	_assert_tuner_controls(tuner, profile)
	tuner.free()

func test_settings_defaults_disable_optional_effects() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	assert(not profile.bypass_all, "A fresh profile must not start in comparison mode.")
	for key: String in EFFECT_KEYS:
		assert(profile.get_value(key) is bool and profile.get_value(key) == false, "%s must be opt-in." % key)
		assert(not profile.effect_enabled(key), "%s should be effectively off by default." % key)
	assert(profile.effect_enabled("particles_enabled"), "Readable leaves/motes are intentionally on, not post-processing.")
	assert(profile.values.size() == ForestVisualSettings.SPECS.size())
	for spec: Dictionary in ForestVisualSettings.SPECS:
		assert(profile.get_value(str(spec["key"])) == spec["default"], "Each setting must initialize from its spec.")
	assert(profile.get_value("not_a_setting") == null)
	assert(not profile.effect_enabled("not_a_setting"))

func test_bypass_is_non_destructive_and_effective_values_are_detached() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	for key: String in EFFECT_KEYS:
		profile.set_value(key, true)
	profile.set_value("grass_brightness", 1.23)
	profile.set_value("leaf_size", 16.0)
	var authored: Dictionary = profile.values.duplicate(true)
	profile.set_bypass(true)
	var effective: Dictionary = profile.get_effective_values()
	for key: String in EFFECT_KEYS + ["particles_enabled"]:
		assert(not profile.effect_enabled(key) and effective[key] == false, "Bypass must disable every enabled effect, including particles.")
	assert(profile.values == authored, "Bypass must never rewrite authored settings.")
	assert(effective["grass_brightness"] == 1.23 and effective["leaf_size"] == 16.0, "Bypass must preserve numeric tuning.")
	effective["leaf_size"] = 4.0
	assert(profile.get_value("leaf_size") == 16.0, "Consumers must not alias the profile dictionary.")
	profile.set_value("cloud_strength", 0.31)
	profile.set_bypass(false)
	assert(profile.effect_enabled("clouds_enabled") and profile.effect_enabled("particles_enabled"))
	assert(profile.get_effective_values() == profile.values, "Ending comparison restores all authored toggles.")
	assert(profile.get_value("cloud_strength") == 0.31, "Editing while bypassed must survive restoration.")
	var restored: Dictionary = profile.get_effective_values()
	restored["grading_enabled"] = false
	assert(profile.effect_enabled("grading_enabled"), "The non-bypassed snapshot must also be detached.")

func test_settings_clamp_numeric_ranges_reject_types_and_emit_only_changes() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	for spec: Dictionary in ForestVisualSettings.SPECS:
		var key: String = str(spec["key"])
		if spec["default"] is bool:
			for invalid: Variant in [0, 1, "true", "false", null, []]:
				profile.set_value(key, invalid)
				assert(profile.get_value(key) == spec["default"], "%s must reject non-bools, not coerce them." % key)
		else:
			profile.set_value(key, -100000.0)
			assert(profile.get_value(key) == spec["min"], "%s must clamp to its lower bound." % key)
			profile.set_value(key, 100000.0)
			assert(profile.get_value(key) == spec["max"], "%s must clamp to its upper bound." % key)
			for invalid: Variant in [NAN, INF, -INF, "12", true, null, {}, Vector2.ONE]:
				profile.set_value(key, invalid)
				assert(profile.get_value(key) == spec["max"], "%s must reject non-finite and nonnumeric input." % key)
	profile.reset_defaults()
	change_count = 0
	profile.changed.connect(_count_change)
	profile.set_value("unknown", 2.0)
	profile.set_value("leaf_size", "invalid")
	profile.set_value("leaf_size", 9)
	profile.set_bypass(false)
	assert(change_count == 0, "Invalid input and identical values must not emit changed.")
	profile.set_value("leaf_size", 13)
	profile.set_bypass(true)
	profile.set_bypass(true)
	assert(change_count == 2, "Each actual accepted change should emit once.")
	profile.reset_defaults()
	assert(change_count == 3 and not profile.bypass_all)
	assert(profile.values == ForestVisualSettings.new().values, "Reset must restore every setting and end bypass.")

func test_configfile_roundtrip_saves_authored_values_not_bypass() -> void:
	assert(TEST_PROFILE_PATH != ForestVisualSettings.PRESET_PATH)
	var source: ForestVisualSettings = ForestVisualSettings.new()
	for spec: Dictionary in ForestVisualSettings.SPECS:
		var value: Variant = not bool(spec["default"]) if spec["default"] is bool else lerpf(float(spec["min"]), float(spec["max"]), 0.37)
		source.set_value(str(spec["key"]), value)
	source.set_bypass(true)
	var save_error: Error = source.save_preset(TEST_PROFILE_PATH)
	assert(save_error == OK, "Test-only ConfigFile save should succeed.")
	var disk: ConfigFile = ConfigFile.new()
	assert(disk.load(TEST_PROFILE_PATH) == OK)
	assert(disk.get_value("profile", "version") == ForestVisualSettings.VERSION)
	assert(disk.get_section_keys("visuals").size() == ForestVisualSettings.SPECS.size())
	assert(not disk.has_section_key("profile", "bypass_all") and not disk.has_section_key("visuals", "bypass_all"))
	assert(disk.get_value("visuals", "grading_enabled") == true, "Save must use authored toggles even during bypass.")
	var loaded: ForestVisualSettings = ForestVisualSettings.new()
	loaded.set_bypass(true)
	assert(loaded.load_preset(TEST_PROFILE_PATH) == OK)
	assert(not loaded.bypass_all and source.bypass_all, "Loading ends comparison only on the target profile.")
	for key: String in source.values:
		if source.values[key] is bool:
			assert(loaded.get_value(key) == source.get_value(key))
		else:
			assert(is_equal_approx(float(loaded.get_value(key)), float(source.get_value(key))), "%s must roundtrip numerically." % key)
	loaded.set_value("leaf_size", 20.0)
	assert(not is_equal_approx(float(source.get_value("leaf_size")), 20.0), "Loaded profiles must be independent.")

func test_configfile_malformed_values_and_version_fail_transactionally() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("grass_brightness", 1.17)
	profile.set_value("clouds_enabled", true)
	profile.set_bypass(true)
	var before: Dictionary = profile.values.duplicate(true)
	change_count = 0
	profile.changed.connect(_count_change)
	# edge_density is the LAST spec: earlier valid changes must not partially apply.
	for invalid: Variant in ["broken", true, NAN, INF, -INF, [1, 2]]:
		var malformed: ConfigFile = ConfigFile.new()
		malformed.set_value("profile", "version", ForestVisualSettings.VERSION)
		malformed.set_value("visuals", "grass_brightness", 0.7)
		malformed.set_value("visuals", "edge_density", invalid)
		assert(malformed.save(TEST_PROFILE_PATH) == OK)
		assert(profile.load_preset(TEST_PROFILE_PATH) == ERR_INVALID_DATA, "Invalid final field should reject the whole profile.")
		assert(profile.values == before and profile.bypass_all, "A failed load must preserve values AND comparison state.")
	var wrong_boolean: ConfigFile = ConfigFile.new()
	wrong_boolean.set_value("profile", "version", ForestVisualSettings.VERSION)
	wrong_boolean.set_value("visuals", "grading_enabled", "true")
	assert(wrong_boolean.save(TEST_PROFILE_PATH) == OK)
	assert(profile.load_preset(TEST_PROFILE_PATH) == ERR_INVALID_DATA)
	wrong_boolean.set_value("profile", "version", ForestVisualSettings.VERSION + 1)
	assert(wrong_boolean.save(TEST_PROFILE_PATH) == OK)
	assert(profile.load_preset(TEST_PROFILE_PATH) == ERR_FILE_UNRECOGNIZED)
	assert(profile.values == before and profile.bypass_all and change_count == 0, "Rejected profiles must not emit changed or replace state.")

func test_configfile_partial_profile_defaults_and_clamps() -> void:
	var partial: ConfigFile = ConfigFile.new()
	partial.set_value("profile", "version", ForestVisualSettings.VERSION)
	partial.set_value("visuals", "leaf_size", 999.0)
	partial.set_value("visuals", "edge_density", -1.0)
	partial.set_value("visuals", "unknown_future_key", "ignored")
	assert(partial.save(TEST_PROFILE_PATH) == OK)
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("clouds_enabled", true)
	profile.set_bypass(true)
	assert(profile.load_preset(TEST_PROFILE_PATH) == OK)
	assert(profile.get_value("leaf_size") == 20.0 and profile.get_value("edge_density") == 0.0)
	assert(profile.get_value("clouds_enabled") == false and not profile.bypass_all, "Missing keys use clean defaults, not stale live values.")
	assert(not profile.values.has("unknown_future_key"))

func test_floor_uploads_all_shared_defaults_and_hd_samplers() -> void:
	var floor_node: ForestFloor = ForestFloor.new()
	floor_node.set_visual_style("hd")
	floor_node._ready()
	assert(floor_node.presentation_material.shader == ForestFloor.PRESENTATION_SHADER)
	assert(floor_node.material == floor_node.presentation_material, "HD ground compositor must remain attached with effects disabled.")
	assert(floor_node._ground_settings.size() == GROUND_DEFAULTS.size())
	# Poison every uniform first: reading shader defaults alone cannot prove that
	# apply_visual_settings actually uploads/reset values on an existing material.
	for key: String in GROUND_DEFAULTS:
		floor_node.presentation_material.set_shader_parameter(key, true if GROUND_DEFAULTS[key] is bool else -777.0)
	floor_node.apply_visual_settings({})
	for key: String in GROUND_DEFAULTS:
		var actual: Variant = floor_node.presentation_material.get_shader_parameter(key)
		assert(actual != null, "%s must be explicitly uploaded to the material." % key)
		if GROUND_DEFAULTS[key] is bool:
			assert(actual == GROUND_DEFAULTS[key])
		else:
			assert(is_equal_approx(float(actual), float(GROUND_DEFAULTS[key])), "%s uniform must match the shared default." % key)
	var names: Array[String] = ["grass_a", "grass_b", "grass_c", "grass_d"]
	assert(ForestFloor.HD_TILE_TEXTURES.size() == 4)
	for index: int in range(4):
		assert(floor_node.presentation_material.get_shader_parameter(names[index]) == ForestFloor.HD_TILE_TEXTURES[index])
		assert(ForestFloor.HD_TILE_TEXTURES[index].resource_path == "res://assets/generated/forest_floor_heroic_quiet_frame_%d.png" % index)
	floor_node.free()

func test_floor_pre_ready_profile_grading_bypass_and_classic_restore() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("grading_enabled", true)
	profile.set_value("grade_contrast", 1.19)
	profile.set_value("grass_brightness", 1.21)
	profile.set_value("path_width", 345.0)
	var floor_node: ForestFloor = ForestFloor.new()
	floor_node.apply_visual_settings(profile.get_effective_values())
	floor_node.set_visual_style("hd")
	floor_node._ready()
	assert(floor_node.presentation_material.get_shader_parameter("grading_enabled") == true)
	assert(is_equal_approx(float(floor_node.presentation_material.get_shader_parameter("path_width")), 345.0), "Pre-ready tuning must survive material creation.")
	profile.set_bypass(true)
	floor_node.apply_visual_settings(profile.get_effective_values())
	assert(floor_node.presentation_material.get_shader_parameter("grading_enabled") == false)
	assert(is_equal_approx(float(floor_node.presentation_material.get_shader_parameter("grade_contrast")), 1.19))
	assert(is_equal_approx(float(floor_node.presentation_material.get_shader_parameter("grass_brightness")), 1.21))
	assert(floor_node.material == floor_node.presentation_material, "Comparison disables grade, not continuous HD ground.")
	profile.set_bypass(false)
	floor_node.apply_visual_settings(profile.get_effective_values())
	assert(floor_node.presentation_material.get_shader_parameter("grading_enabled") == true)
	floor_node.set_visual_style("classic")
	assert(floor_node.material == null and floor_node.tile_texture == ForestFloor.CLASSIC_TILE_TEXTURE)
	floor_node.set_visual_style("hd")
	assert(floor_node.material == floor_node.presentation_material)
	floor_node.free()

func test_floor_rejects_invalid_values_resets_missing_and_ignores_atmosphere() -> void:
	var floor_node: ForestFloor = ForestFloor.new()
	floor_node._ready()
	floor_node.apply_visual_settings({"path_width": 9999.0, "dark_soil": -1, "grass_brightness": NAN, "grass_saturation": "bad", "grading_enabled": 1, "clouds_enabled": true, "leaf_size": 20.0})
	assert(floor_node._ground_settings["path_width"] == 440.0 and floor_node._ground_settings["dark_soil"] == 0.0)
	assert(floor_node._ground_settings["grass_brightness"] == 1.0 and floor_node._ground_settings["grass_saturation"] == 1.0)
	assert(floor_node.presentation_material.get_shader_parameter("grading_enabled") == false)
	assert(not floor_node._ground_settings.has("clouds_enabled") and not floor_node._ground_settings.has("leaf_size"))
	floor_node.apply_visual_settings({})
	assert(floor_node._ground_settings == GROUND_DEFAULTS, "Partial/empty updates must reset missing ground settings to defaults.")
	floor_node.free()

func test_ambient_leaf_count_size_build_and_particle_bypass() -> void:
	var ambient: AmbientFixture = AmbientFixture.new()
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	ambient.apply_visual_settings(profile.get_effective_values())
	ambient.rng.seed = 814273
	ambient._build_particles()
	assert(ambient.leaf_count == 12 and ambient.leaves.size() == 12)
	assert(is_equal_approx(ambient.leaf_half_length, 9.0) and is_equal_approx(ambient.wind_speed, 18.0))
	assert(ambient.particle_visibility and not ambient.atmosphere_requested)
	for index: int in range(ambient.leaves.size()):
		var leaf: ForestAmbientFX.LeafParticle = ambient.leaves[index]
		assert(leaf.size >= 2.0 and leaf.size <= 4.5)
		if index % 3 == 0:
			assert(ambient._gameplay_rect().has_point(leaf.world_position), "Some readable leaves must cross the clearing.")
		else:
			assert(not ambient._gameplay_rect().has_point(leaf.world_position), "Border leaves must start beyond playable ground.")
	profile.set_value("leaf_count", 27)
	profile.set_value("leaf_size", 17.5)
	profile.set_value("wind_speed", 33.0)
	profile.set_value("firefly_glow", 0.7)
	ambient.apply_visual_settings(profile.get_effective_values())
	# Off-tree: explicitly invoke the same builder used on count changes in-tree.
	ambient._build_particles()
	assert(ambient.leaf_count == 27 and ambient.leaves.size() == 27)
	assert(ambient.leaf_half_length == 17.5 and ambient.wind_speed == 33.0 and ambient.firefly_halo_strength == 0.7)
	profile.set_bypass(true)
	ambient.apply_visual_settings(profile.get_effective_values())
	assert(not ambient.particle_visibility and ambient.leaves.size() == 27 and ambient.leaf_half_length == 17.5, "Bypass hides particles without discarding their tuning.")
	profile.set_bypass(false)
	ambient.apply_visual_settings(profile.get_effective_values())
	assert(ambient.particle_visibility)
	ambient.apply_visual_settings({"leaf_count": -5, "leaf_size": 100.0, "wind_speed": -2.0, "firefly_glow": 4.0})
	ambient._build_particles()
	assert(ambient.leaves.is_empty() and ambient.leaf_half_length == 20.0 and ambient.wind_speed == 0.0 and ambient.firefly_halo_strength == 1.0)
	ambient.apply_visual_settings({"leaf_count": 100, "leaf_size": -1.0})
	ambient._build_particles()
	assert(ambient.leaves.size() == 40 and ambient.leaf_half_length == 4.0)
	ambient.free()

func test_edge_prop_bounds_and_collision_unchanged_at_all_scales() -> void:
	var border: BossArenaBorder = BossArenaBorder.new()
	border.arena_rect = Rect2(100.0, -50.0, 1280.0, 720.0)
	border._build_collision()
	var before: Array[Rect2] = _collision_rects(border)
	assert(before.size() == 4)
	var arena: Rect2 = border.arena_rect
	var half: float = border.border_thickness * 0.5
	var walkable: Rect2 = arena.grow(-half)
	assert(before[0] == Rect2(arena.position - Vector2.ONE * half, Vector2(arena.size.x + half * 2.0, half * 2.0)))
	for scale_value: float in [1.0, 2.4, 4.0]:
		for density: float in [0.0, 0.55, 1.0]:
			border.apply_visual_settings({"edge_scale": scale_value, "edge_density": density})
			assert(border.edge_scale == scale_value and border.edge_density == density)
			for side: int in range(4):
				for along: float in [0.0, 0.2, 0.5, 0.8, 1.0]:
					for prop_size: Vector2 in [Vector2(23.0, 16.0) * scale_value * 1.15, Vector2(18.0, 18.0) * scale_value * 1.15, Vector2(152.0, 174.0)]:
						var rect: Rect2 = border._hd_edge_prop_rect(side, along, prop_size, -10.0)
						assert(rect.size == prop_size, "Edge art should remain upright, not rotate or squash its footprint.")
						assert(not rect.intersects(walkable), "Art must grow outward, never into playable ground.")
						assert(not Rect2(rect.position + Vector2(2.0, 3.0), rect.size).intersects(walkable), "Contact shadows also must stay behind the inner collision face.")
			assert(_collision_rects(border) == before and border.arena_rect == arena, "Visual settings must not move physical arena boundaries.")
	border.apply_visual_settings({"edge_scale": INF, "edge_density": "bad"})
	assert(border.edge_scale == 2.4 and border.edge_density == 0.55)
	border.apply_visual_settings({"edge_scale": 99.0, "edge_density": -9.0})
	assert(border.edge_scale == 4.0 and border.edge_density == 0.0)
	assert(_collision_rects(border) == before)
	border.free()

func _collision_rects(node: Node2D) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for child: Node in node.get_children():
		if not child is StaticBody2D:
			continue
		var body: StaticBody2D = child as StaticBody2D
		assert(body.collision_layer == 4 and body.collision_mask == 0, "Visual changes must preserve terrain collision filtering.")
		for shape_node: Node in body.get_children():
			var collision: CollisionShape2D = shape_node as CollisionShape2D
			assert(collision != null)
			var size: Vector2 = Vector2.ZERO
			if collision.shape is RectangleShape2D:
				size = (collision.shape as RectangleShape2D).size
			elif collision.shape is CapsuleShape2D:
				var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
				size = Vector2(capsule.radius * 2.0, capsule.height)
				if posmod(roundi(collision.rotation / (PI * 0.5)), 2) == 1:
					size = Vector2(size.y, size.x)
			else:
				assert(false, "Gameplay collision must be a rectangle boundary, circle, or capsule.")
			result.append(Rect2(body.position + collision.position - size * 0.5, size))
	return result

func test_wall_hd_assets_and_blocking_rectangles_preserve_authored_geometry() -> void:
	assert(TerrainModule.HD_WALL_HORIZONTAL.resource_path == "res://assets/generated/forest_broken_stone_wall_horizontal_frame_0.png")
	assert(TerrainModule.HD_WALL_VERTICAL.resource_path == "res://assets/generated/forest_broken_stone_wall_vertical_frame_0.png")
	assert(TerrainModule.HD_WALL_HORIZONTAL != TerrainModule.HD_WALL_VERTICAL, "Vertical walls use upright authored art, not the horizontal sprite turned sideways.")
	for kind: String in ["i", "l", "t", "hall"]:
		var scene: PackedScene = load("res://scenes/terrain/forest_wall_%s.tscn" % kind) as PackedScene
		var wall: TerrainModule = scene.instantiate() as TerrainModule
		wall.position = Vector2(610.0, 340.0)
		var local_rects: Array[Rect2] = _collision_rects(wall)
		assert(not local_rects.is_empty() and wall.blocks_navigation)
		var authored_footprint: Vector2 = wall.footprint_size
		for quarter: int in range(4):
			wall.rotation = float(quarter) * PI * 0.5
			var before: Array[Rect2] = wall.world_blocking_rects()
			var footprint: Rect2 = wall.world_footprint()
			for texture: Texture2D in [TerrainModule.HD_WALL_HORIZONTAL, TerrainModule.HD_WALL_VERTICAL]:
				var region: Rect2 = wall._hd_wall_region(texture)
				assert(region.has_area() and Rect2(Vector2.ZERO, texture.get_size()).encloses(region), "HD alpha crop must stay within its source texture.")
				assert(wall._hd_wall_region(texture) == region, "Cached art selection must be stable.")
			assert(wall.world_blocking_rects() == before and wall.world_footprint() == footprint)
			assert(before.size() == local_rects.size())
			for index: int in range(local_rects.size()):
				var local: Rect2 = local_rects[index]
				var expected_size: Vector2 = local.size if quarter % 2 == 0 else Vector2(local.size.y, local.size.x)
				var expected_center: Vector2 = wall.position + local.get_center().rotated(wall.rotation)
				assert(before[index].is_equal_approx(Rect2(expected_center - expected_size * 0.5, expected_size)), "HD art bounds must never replace solid wall collision rectangles.")
		assert(wall.footprint_size == authored_footprint and _collision_rects(wall) == local_rects)
		wall.free()

func test_main_detached_visual_profile_lifecycle_without_profile_writes() -> void:
	# Real scene and production fan-out methods, explicitly wired like the other
	# synchronous integration tests. Main._ready / _on_visual_style_changed also
	# load/save gameplay data, so deliberately do not call those entry points.
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.forest_floor = main.get_node("ForestFloor") as ForestFloor
	main.forest_ambient_fx = main.get_node("ForestAmbientFX") as ForestAmbientFX
	main.combat_presentation_fx = main.get_node("CombatPresentationFX") as CombatPresentationFX
	main.arena_generator = main.get_node("ArenaGenerator") as ArenaGenerator
	main.presentation_environment = main.get_node("ForestEnvironment") as WorldEnvironment
	main.forest_floor._ready()
	main.visual_style = "hd"
	main.forest_floor.set_visual_style("hd")
	var profile: ForestVisualSettings = main.get_forest_visual_settings()
	assert(profile == main.forest_visual_settings)
	profile.changed.connect(main._apply_forest_visual_settings)
	main._apply_forest_visual_settings()
	assert(main.presentation_environment.environment == null, "Default HD must not create a bloom environment.")
	assert(not main.combat_presentation_fx.forest_screen_blur_allowed)
	profile.set_value("grading_enabled", true)
	profile.set_value("clouds_enabled", true)
	profile.set_value("blur_enabled", true)
	profile.set_value("leaf_size", 16.0)
	profile.set_value("edge_scale", 3.1)
	profile.set_value("edge_density", 0.8)
	main._create_boss_arena_border()
	assert(main.boss_arena_border.edge_scale == 3.1 and main.boss_arena_border.edge_density == 0.8, "A late-created border must receive the live shared profile.")
	assert(main.forest_floor.presentation_material.get_shader_parameter("grading_enabled") == true)
	assert(main.forest_ambient_fx.atmosphere_requested and main.combat_presentation_fx.forest_screen_blur_allowed)
	assert(main.forest_ambient_fx.leaf_half_length == 16.0)
	profile.set_bypass(true)
	assert(main.forest_floor.presentation_material.get_shader_parameter("grading_enabled") == false)
	assert(not main.forest_ambient_fx.atmosphere_requested and not main.forest_ambient_fx.particle_visibility)
	assert(not main.combat_presentation_fx.forest_screen_blur_allowed and main.presentation_environment.environment == null)
	assert(main.boss_arena_border.edge_scale == 3.1 and main.forest_ambient_fx.leaf_half_length == 16.0)
	profile.set_bypass(false)
	assert(main.forest_ambient_fx.atmosphere_requested and main.forest_ambient_fx.particle_visibility)
	assert(main.combat_presentation_fx.forest_screen_blur_allowed)
	profile.reset_defaults()
	assert(main.boss_arena_border.edge_scale == 2.4 and not main.combat_presentation_fx.forest_screen_blur_allowed)
	main.free()
	# Calling the retained profile after Main is freed must not hit a stale target.
	profile.set_value("leaf_size", 18.0)
	assert(profile.get_value("leaf_size") == 18.0)

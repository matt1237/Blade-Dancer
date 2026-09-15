class_name ForestDayPresetTest extends Node

const TEST_DAY_PRESET_PATH: String = "user://forest_day_preset_test.cfg"
const TEST_LIBRARY_PATH: String = "user://forest_day_preset_test_snapshots.cfg"

func _clear_test_files() -> void:
	for path: String in [TEST_DAY_PRESET_PATH, TEST_LIBRARY_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)

func _make_library() -> ForestVisualProfileLibrary:
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	library.storage_path = TEST_LIBRARY_PATH
	library.day_preset_path = TEST_DAY_PRESET_PATH
	return library

## A save for one phase must never wipe or require the other three phases.
func test_partial_phase_save_does_not_require_all_four_phases() -> void:
	_clear_test_files()
	var library: ForestVisualProfileLibrary = _make_library()
	var noon_only: Dictionary = {"Noon": {"grass_brightness": 1.2}}
	assert(library.save_day_preset(1, noon_only) == OK, "Saving a single phase should succeed.")
	var stored: Dictionary = library.get_day_preset(1)
	assert(stored.size() == 1 and stored.has("Noon"), "get_day_preset should return the one phase saved, not an empty dict.")
	assert(float((stored["Noon"] as Dictionary)["grass_brightness"]) == 1.2)
	_clear_test_files()

## Saving Morning later must preserve the already-saved Noon phase untouched.
func test_saving_a_second_phase_preserves_the_first() -> void:
	_clear_test_files()
	var library: ForestVisualProfileLibrary = _make_library()
	library.save_day_preset(1, {"Noon": {"grass_brightness": 1.2}})
	library.save_day_preset(1, {"Morning": {"grass_brightness": 0.9}})
	var stored: Dictionary = library.get_day_preset(1)
	assert(stored.has("Noon") and stored.has("Morning"), "Both phases should be present after two separate partial saves.")
	assert(float((stored["Noon"] as Dictionary)["grass_brightness"]) == 1.2, "Noon must survive a later Morning-only save.")
	assert(float((stored["Morning"] as Dictionary)["grass_brightness"]) == 0.9)
	_clear_test_files()

## ensure_day_preset_slots must only fill in missing phases, never overwrite existing ones.
func test_ensure_day_preset_slots_is_additive_not_destructive() -> void:
	_clear_test_files()
	var library: ForestVisualProfileLibrary = _make_library()
	library.save_day_preset(1, {"Noon": {"grass_brightness": 1.35}})
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	library.ensure_day_preset_slots(profile)
	var stored: Dictionary = library.get_day_preset(1)
	assert(stored.size() == ForestVisualProfileLibrary.DAY_PRESET_PHASES.size(), "Missing phases should be seeded.")
	assert(float((stored["Noon"] as Dictionary)["grass_brightness"]) == 1.35, "ensure_day_preset_slots must not touch a phase that already exists.")
	_clear_test_files()

## Simulates the tuner: tune phase A, switch to B, tune B, switch back to A —
## A's edits must still be there (this is the exact bug the user reported).
func test_tuner_phase_switch_preserves_untouched_phase_edits() -> void:
	_clear_test_files()
	var settings: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	tuner.library = _make_library()
	tuner.settings = settings
	tuner.preset_slots = [{}, {}, {}]
	tuner.dirty_phases = [{}, {}, {}]
	tuner.selected_preset_slot = 1
	tuner.selected_phase = "Noon"
	tuner._refresh_day_presets()

	settings.set_value("grass_brightness", 1.3)
	tuner._on_settings_changed_for_dirty_tracking()
	tuner._select_day_phase("Morning")
	assert(is_equal_approx(float(settings.get_value("grass_brightness")), float((tuner.preset_slots[0]["Morning"] as Dictionary).get("grass_brightness", -1.0))), "Morning should now be the live profile.")

	settings.set_value("grass_brightness", 0.7)
	tuner._on_settings_changed_for_dirty_tracking()
	# Simulate a stray reconfigure/panel-reopen while Morning still has unsaved edits.
	tuner._refresh_day_presets()
	assert(is_equal_approx(float((tuner.preset_slots[0]["Morning"] as Dictionary).get("grass_brightness", -1.0)), 0.7), "Unsaved Morning edit must survive a refresh.")

	tuner._select_day_phase("Noon")
	assert(is_equal_approx(float(settings.get_value("grass_brightness")), 1.3), "Switching back to Noon must restore Noon's own tuned value, not Morning's.")
	tuner.free()
	_clear_test_files()

## Save/reload round trip through the full tuner save path.
func test_save_and_reload_round_trip() -> void:
	_clear_test_files()
	var settings: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	tuner.library = _make_library()
	tuner.settings = settings
	tuner.preset_slots = [{}, {}, {}]
	tuner.dirty_phases = [{}, {}, {}]
	tuner.selected_preset_slot = 1
	tuner.selected_phase = "Noon"
	tuner._refresh_day_presets()
	settings.set_value("sunlight_warmth", 0.55)
	tuner._on_settings_changed_for_dirty_tracking()
	tuner._save_day_preset()
	assert(not tuner._slot_has_dirty_phase(0), "Saving should clear the dirty marker for the whole slot.")

	var reloaded: ForestVisualProfileLibrary = _make_library()
	var stored: Dictionary = reloaded.get_day_preset(1)
	assert(is_equal_approx(float((stored["Noon"] as Dictionary)["sunlight_warmth"]), 0.55), "Saved value should round-trip from disk.")
	tuner.free()
	_clear_test_files()

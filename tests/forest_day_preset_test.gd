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

## The tuner edits the one bundle main owns: tune phase A, switch to B, tune B,
## switch back to A -- A's edits must still be there and B's must be committed.
func test_tuner_phase_switch_preserves_untouched_phase_edits() -> void:
	var settings: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	tuner.settings = settings
	var bundle: Dictionary = {
		"Noon": {"grass_brightness": 1.0},
		"Morning": {"grass_brightness": 0.8},
		"Dusk": {},
		"Night": {}
	}
	tuner.attach_day_bundle(bundle, "Noon")

	settings.set_value("grass_brightness", 1.3)
	tuner._on_settings_changed()
	tuner._select_day_phase("Morning")
	assert(is_equal_approx(float(settings.get_value("grass_brightness")), 0.8), "Morning should now be the live profile.")

	settings.set_value("grass_brightness", 0.7)
	tuner._on_settings_changed()
	tuner._select_day_phase("Noon")
	assert(is_equal_approx(float(settings.get_value("grass_brightness")), 1.3), "Switching back to Noon must restore Noon's own tuned value.")
	assert(is_equal_approx(float((bundle["Morning"] as Dictionary).get("grass_brightness", -1.0)), 0.7), "Morning edit must be committed into the shared bundle.")
	assert(tuner.dirty_phases.has("Noon") and tuner.dirty_phases.has("Morning"), "Both edited phases should be flagged dirty.")
	tuner.mark_global_save_complete()
	assert(tuner.dirty_phases.is_empty(), "Global Save All must clear every dirty marker.")
	tuner.free()

## The tuner writes straight into the bundle main persists; commit must land there.
func test_tuner_commit_writes_into_the_owned_bundle() -> void:
	var settings: ForestVisualSettings = ForestVisualSettings.new()
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	tuner.settings = settings
	var bundle: Dictionary = {"Noon": {}, "Morning": {}, "Dusk": {}, "Night": {}}
	tuner.attach_day_bundle(bundle, "Noon")
	settings.set_value("sunlight_warmth", 0.55)
	tuner._on_settings_changed()
	assert(is_equal_approx(float((tuner.get_day_bundle()["Noon"] as Dictionary).get("sunlight_warmth", -1.0)), 0.55), "A tuned value must land in the owned bundle.")
	tuner.free()

class_name ForestVisualProfileStartupTest extends Node

const TEST_LIBRARY_PATH: String = "user://forest_visual_profile_startup_test.cfg"

func _clear_test_library() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_LIBRARY_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func test_startup_snapshot_roundtrip_and_latest_name_lookup() -> void:
	_clear_test_library()
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	library.storage_path = TEST_LIBRARY_PATH
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("edge_scale", 3.2)
	profile.set_value("border_ruins", 2.0)
	var snapshot: Dictionary = library.create_snapshot("Hazey", profile)
	assert(not snapshot.is_empty(), "Named visual snapshot should be created.")
	var latest: Dictionary = library.find_latest_named_snapshot("hazey")
	assert(str(latest.get("id", "")) == str(snapshot.get("id", "")), "Named lookup should be case-insensitive.")
	assert(library.set_startup_snapshot_id(str(snapshot.get("id", ""))) == OK, "Startup profile selection should persist.")
	assert(library.get_startup_snapshot_id() == str(snapshot.get("id", "")), "Startup profile id should round-trip.")
	var loaded_snapshot: Dictionary = library.get_snapshot(library.get_startup_snapshot_id())
	assert(float((loaded_snapshot.get("values", {}) as Dictionary).get("edge_scale", 0.0)) == 3.2, "Startup snapshot should retain border values.")
	_clear_test_library()

func test_border_hydrates_all_saved_visual_values() -> void:
	var border: BossArenaBorder = BossArenaBorder.new()
	border.apply_visual_settings({
		"edge_scale": 3.1,
		"edge_density": 0.8,
		"border_rocks": 2.0,
		"border_logs": 3.0,
		"border_stones": 1.0,
		"border_ruins": 2.0,
		"border_trees": 3.0,
		"landmark_scale": 1.4,
		"landmark_depth": 55.0,
		"landmark_prominence": 0.7,
	})
	assert(is_equal_approx(border.edge_scale, 3.1), "Border scale should hydrate from the active visual profile.")
	assert(is_equal_approx(border.edge_density, 0.8), "Border density should hydrate from the active visual profile.")
	assert(is_equal_approx(float(border.landmark_settings["border_ruins"]), 2.0), "Border ruin count should hydrate from the active visual profile.")
	assert(is_equal_approx(float(border.landmark_settings["landmark_depth"]), 55.0), "Landmark depth should hydrate from the active visual profile.")
	border.free()

func test_automatic_time_of_day_profiles_are_hazey_derived() -> void:
	_clear_test_library()
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	library.storage_path = TEST_LIBRARY_PATH
	var hazey: ForestVisualSettings = ForestVisualSettings.new()
	hazey.set_value("border_ruins", 2.0)
	hazey.set_value("world_brightness", 1.0)
	var hazey_snapshot: Dictionary = library.create_snapshot("Hazey", hazey)
	assert(not hazey_snapshot.is_empty(), "Hazey baseline should be created for the variant family.")
	var ensured: Array[Dictionary] = library.ensure_time_of_day_profiles(hazey)
	assert(ensured.size() == 4, "Illustrated base plus Morning, Dusk, and Night should be created.")
	var illustrated: Dictionary = library.find_latest_named_snapshot("Illustrated Fantasy Realism")
	var morning: Dictionary = library.find_latest_named_snapshot("Morning")
	var dusk: Dictionary = library.find_latest_named_snapshot("Dusk")
	var night: Dictionary = library.find_latest_named_snapshot("Night")
	assert(not illustrated.is_empty() and not morning.is_empty() and not dusk.is_empty() and not night.is_empty())
	var hazey_values: Dictionary = hazey_snapshot.get("values", {}) as Dictionary
	var illustrated_values: Dictionary = illustrated.get("values", {}) as Dictionary
	assert(illustrated_values == hazey_values, "Illustrated Fantasy Realism must preserve the Hazey baseline.")
	assert(float((morning.get("values", {}) as Dictionary).get("world_brightness", 0.0)) > 1.0)
	assert(float((dusk.get("values", {}) as Dictionary).get("sunlight_warmth", 0.0)) > float(hazey_values.get("sunlight_warmth", 0.0)))
	assert(float((night.get("values", {}) as Dictionary).get("world_brightness", 1.0)) < 1.0)
	assert(float((night.get("values", {}) as Dictionary).get("firefly_glow", 0.0)) > float(hazey_values.get("firefly_glow", 0.0)))
	assert(float((night.get("values", {}) as Dictionary).get("border_ruins", 0.0)) == 2.0, "Variants must retain Hazey border geometry settings.")
	_clear_test_library()

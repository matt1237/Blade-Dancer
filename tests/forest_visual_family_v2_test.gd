class_name ForestVisualFamilyV2Test extends Node

const TEST_PATH: String = "user://forest_visual_family_v2_test.cfg"

func _library() -> ForestVisualProfileLibrary:
	# Write only an isolated test fixture, never the user's real profile library.
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("library", "version", 1)
	cfg.set_value("snapshots", "fixture", {})
	assert(cfg.save(TEST_PATH) == OK)
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	library.storage_path = TEST_PATH
	return library

func test_new_mood_defaults_and_clamps() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	assert(profile.get_value("night_strength") == 0.0)
	assert(profile.get_value("light_radius") == 240.0)
	assert(profile.get_value("mood_temperature") == 0.0)
	assert(profile.get_value("mist_strength") == 0.0)
	profile.set_value("light_radius", 9999.0)
	profile.set_value("night_strength", 2.0)
	profile.set_value("mood_temperature", -2.0)
	profile.set_value("mist_strength", 2.0)
	assert(profile.get_value("light_radius") == 640.0)
	assert(profile.get_value("night_strength") == 1.0)
	assert(profile.get_value("mood_temperature") == -1.0)
	assert(profile.get_value("mist_strength") == 1.0)
	profile.set_bypass(true)
	assert(profile.get_effective_values()["night_strength"] == 0.0)
	assert(profile.get_effective_values()["mist_strength"] == 0.0)
	assert(profile.get_value("night_strength") == 1.0)
	assert(profile.apply_snapshot_values({"border_ruins":2.0}) == OK)
	assert(profile.get_value("night_strength") == 0.0, "Older profiles default to no night overlay")

func test_additive_family_is_idempotent_and_preserves_old_profiles_and_startup() -> void:
	var library: ForestVisualProfileLibrary = _library()
	var hazey: ForestVisualSettings = ForestVisualSettings.new()
	hazey.set_value("border_ruins", 2.0)
	hazey.set_value("world_brightness", 1.13)
	var baseline: Dictionary = library.create_snapshot("Hazey", hazey)
	var preserved: Array[Dictionary] = [baseline]
	for old_name: String in ["Morning", "Dusk", "Night", "Illustrated Fantasy Realism", "Custom"]:
		preserved.append(library.create_snapshot(old_name, hazey))
	var startup: String = str(preserved[2]["id"])
	assert(library.set_startup_snapshot_id(startup) == OK)
	assert(library.ensure_time_of_day_profiles(hazey).size() == 4)
	var count: int = library.list_snapshots().size()
	assert(count == preserved.size() + 4)
	var revised: Array[Dictionary] = library.ensure_revised_time_of_day_profiles(hazey)
	assert(revised.size() == 4)
	assert(library.ensure_time_of_day_profiles(hazey).size() == 4)
	assert(library.list_snapshots().size() == count)
	assert(library.get_startup_snapshot_id() == startup)
	for snapshot: Dictionary in preserved + revised:
		assert(library.get_snapshot(str(snapshot["id"])) == snapshot, "Never rewrite existing snapshots")
	var noon: Dictionary = library.find_latest_named_snapshot("Noon")["values"]
	assert(noon == baseline["values"], "Noon must exactly clone normalized Hazey")
	var night: Dictionary = library.find_latest_named_snapshot("Night v2")["values"]
	assert(night["night_strength"] > 0.0 and night["light_radius"] >= 320.0)
	assert(night["world_brightness"] == 1.0 and night["world_contrast"] == 1.0 and night["world_saturation"] == 1.0)
	assert(not night["bloom_enabled"] and not night["grading_enabled"])
	assert(night["border_ruins"] == 2.0)
	var morning: Dictionary = library.find_latest_named_snapshot("Morning v2")["values"]
	var dusk: Dictionary = library.find_latest_named_snapshot("Dusk v2")["values"]
	assert(morning["mist_strength"] > dusk["mist_strength"])
	assert(morning["mood_temperature"] < 0.0 and dusk["mood_temperature"] < 0.0)
	assert(morning["sunlight_warmth"] < dusk["sunlight_warmth"])

func test_noon_normalizes_legacy_hazey_without_rewriting_it() -> void:
	var library: ForestVisualProfileLibrary = _library()
	var hazey: ForestVisualSettings = ForestVisualSettings.new()
	var original: Dictionary = library.create_snapshot("Hazey", hazey)
	var cfg: ConfigFile = ConfigFile.new()
	assert(cfg.load(TEST_PATH) == OK)
	original["values"] = {"border_ruins":2.0, "world_brightness":1.07}
	cfg.set_value("snapshots", str(original["id"]), original)
	assert(cfg.save(TEST_PATH) == OK)
	assert(library.ensure_revised_time_of_day_profiles(hazey).size() == 4)
	var normalized: ForestVisualSettings = ForestVisualSettings.new()
	assert(normalized.apply_snapshot_values(original["values"]) == OK)
	assert(library.find_latest_named_snapshot("Noon")["values"] == normalized.values)
	assert(library.get_snapshot(str(original["id"])) == original)

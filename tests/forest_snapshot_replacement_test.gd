extends Node
## Memory-only regressions: never read or write production visual profiles.
class MemoryLibrary extends ForestVisualProfileLibrary:
	var snapshots: Dictionary = {}
	func get_snapshot(snapshot_id: String) -> Dictionary:
		return snapshots.get(snapshot_id, {})

var change_count: int = 0

func _count_change() -> void:
	change_count += 1

func test_night_then_old_hazey_resets_missing_world_settings() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	var old_hazey: Dictionary = {}
	var expected: Dictionary = {}
	for spec: Dictionary in ForestVisualSettings.SPECS:
		var key: String = str(spec["key"])
		expected[key] = spec["default"]
		if not key.begins_with("world_"):
			old_hazey[key] = spec["default"]
	old_hazey["haze_enabled"] = true
	old_hazey["haze_strength"] = 0.19
	expected["haze_enabled"] = true
	expected["haze_strength"] = 0.19
	var library: MemoryLibrary = MemoryLibrary.new()
	library.snapshots["hazey"] = {"name": "Hazey", "values": old_hazey}
	var night_values: Dictionary = old_hazey.duplicate(true)
	for variant: Dictionary in ForestVisualProfileLibrary.TIME_OF_DAY_VARIANTS:
		if variant["name"] == "Night":
			for key: String in variant["overrides"]:
				night_values[key] = variant["overrides"][key]
	library.snapshots["night"] = {"name": "Night", "values": night_values}
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	tuner.library = library
	tuner.settings = profile
	tuner._load_snapshot("night")
	assert(profile.get_value("world_brightness") < 1.0)
	profile.set_bypass(true)
	change_count = 0
	profile.changed.connect(_count_change)
	tuner._load_snapshot("hazey")
	assert(profile.values == expected, "Old Hazey must fully replace Night, defaulting every missing world_* key.")
	assert(not profile.bypass_all and change_count == 1)
	assert(not old_hazey.has("world_brightness"), "Loading must not mutate the source snapshot.")
	tuner.free()

func test_invalid_snapshot_is_transactional() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("world_brightness", 0.72)
	profile.set_value("haze_enabled", true)
	profile.set_bypass(true)
	var before: Dictionary = profile.values.duplicate(true)
	change_count = 0
	profile.changed.connect(_count_change)
	# Invalid last spec follows earlier staged changes and default resets.
	for invalid: Variant in [null, true, "bad", NAN, INF, -INF, [], {}]:
		assert(profile.apply_snapshot_values({"grass_brightness": 1.3, "landmark_prominence": invalid}) == ERR_INVALID_DATA)
		assert(profile.values == before and profile.bypass_all and change_count == 0)
	assert(profile.apply_snapshot_values({"grass_brightness": 1.3, "particles_enabled": 1}) == ERR_INVALID_DATA)
	assert(profile.values == before and profile.bypass_all and change_count == 0)

func test_empty_snapshot_resets_defaults_and_partial_snapshot_clamps() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("world_brightness", 0.72)
	profile.set_bypass(true)
	change_count = 0
	profile.changed.connect(_count_change)
	assert(profile.apply_snapshot_values({}) == OK)
	assert(profile.values == ForestVisualSettings.new().values and not profile.bypass_all and change_count == 1)
	assert(profile.apply_snapshot_values({"leaf_size": 999.0, "edge_density": -1.0, "unknown_future_key": "ignored"}) == OK)
	assert(profile.get_value("leaf_size") == 20.0 and profile.get_value("edge_density") == 0.0)
	assert(profile.values.size() == ForestVisualSettings.SPECS.size() and change_count == 2)

func test_missing_tuner_snapshot_reports_failure_without_applying_defaults() -> void:
	var profile: ForestVisualSettings = ForestVisualSettings.new()
	profile.set_value("world_brightness", 0.72)
	profile.set_bypass(true)
	var before: Dictionary = profile.values.duplicate(true)
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	tuner.library = MemoryLibrary.new()
	tuner.settings = profile
	tuner.feedback_label = Label.new()
	tuner.add_child(tuner.feedback_label)
	change_count = 0
	profile.changed.connect(_count_change)
	tuner._load_snapshot("missing")
	assert(profile.values == before and profile.bypass_all and change_count == 0)
	assert(tuner.feedback_label.text.begins_with("Load failed"))
	tuner.free()

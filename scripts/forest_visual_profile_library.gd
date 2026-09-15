class_name ForestVisualProfileLibrary extends RefCounted
## Named visual-only snapshots. Combat/progression files are never touched.
const LIBRARY_PATH: String = "user://forest_visual_profiles.cfg"
const VERSION: int = 1
const ILLUSTRATED_BASE_NAME: String = "Illustrated Fantasy Realism"
const TIME_OF_DAY_VARIANTS: Array[Dictionary] = [
	{
		"name": "Morning",
		"overrides": {
			"grass_brightness": 1.1,
			"grass_saturation": 1.08,
			"grading_enabled": true,
			"grade_saturation": 1.12,
			"grade_contrast": 1.04,
			"sunlight_warmth": 0.42,
			"world_brightness": 1.06,
			"world_contrast": 1.02,
			"world_saturation": 1.04,
			"clouds_enabled": true,
			"cloud_strength": 0.16,
			"cloud_scale": 420.0,
			"cloud_speed": 10.0,
			"cloud_coverage": 0.38,
			"cloud_softness": 0.52,
			"rays_enabled": true,
			"ray_strength": 0.12,
			"ray_width": 125.0,
			"dapple_enabled": true,
			"dapple_strength": 0.16,
			"haze_enabled": true,
			"haze_strength": 0.06,
			"bloom_enabled": false,
			"firefly_glow": 0.2
		}
	},
	{
		"name": "Dusk",
		"overrides": {
			"grass_brightness": 0.92,
			"grass_saturation": 1.02,
			"grading_enabled": true,
			"grade_saturation": 1.04,
			"grade_contrast": 1.1,
			"sunlight_warmth": 0.68,
			"world_brightness": 0.92,
			"world_contrast": 1.07,
			"world_saturation": 1.0,
			"clouds_enabled": true,
			"cloud_strength": 0.2,
			"cloud_scale": 390.0,
			"cloud_speed": 8.0,
			"cloud_coverage": 0.56,
			"cloud_softness": 0.4,
			"rays_enabled": true,
			"ray_strength": 0.09,
			"ray_width": 145.0,
			"dapple_enabled": true,
			"dapple_strength": 0.11,
			"haze_enabled": true,
			"haze_strength": 0.12,
			"bloom_enabled": false,
			"firefly_glow": 0.62
		}
	},
	{
		"name": "Night",
		"overrides": {
			"grass_brightness": 0.76,
			"grass_saturation": 0.86,
			"grading_enabled": true,
			"grade_saturation": 0.9,
			"grade_contrast": 1.14,
			"sunlight_warmth": 0.04,
			"world_brightness": 0.76,
			"world_contrast": 1.1,
			"world_saturation": 0.82,
			"clouds_enabled": false,
			"rays_enabled": false,
			"dapple_enabled": false,
			"haze_enabled": true,
			"haze_strength": 0.18,
			"bloom_enabled": true,
			"bloom_strength": 0.12,
			"particles_enabled": true,
			"firefly_glow": 0.95,
			"leaf_count": 14.0
		}
	}
]
## Revised family is additive: never rename or replace a user's old snapshots.
const REVISED_VARIANTS: Array[Dictionary] = [
	{"name":"Noon", "overrides":{}},
	{"name":"Morning v2", "overrides":{
		"night_strength":0.0, "mood_temperature":-0.65, "mist_strength":0.48,
		"world_brightness":1.0, "world_contrast":1.0, "world_saturation":1.0,
		"grading_enabled":true, "grass_brightness":1.04, "grass_saturation":0.98,
		"grade_saturation":1.02, "grade_contrast":1.02, "sunlight_warmth":0.18,
		"clouds_enabled":true, "cloud_strength":0.10, "cloud_softness":0.65,
		"cloud_coverage":0.36, "cloud_speed":6.0,
		"rays_enabled":true, "ray_strength":0.13, "ray_width":150.0,
		"dapple_enabled":true, "dapple_strength":0.08,
		"haze_enabled":true, "haze_strength":0.13, "bloom_enabled":false, "blur_enabled":false,
		"firefly_glow":0.2}},
	{"name":"Dusk v2", "overrides":{
		"night_strength":0.0, "mood_temperature":-0.4, "mist_strength":0.25,
		"world_brightness":1.0, "world_contrast":1.0, "world_saturation":1.0,
		"grading_enabled":true, "grass_brightness":0.98, "grass_saturation":0.98,
		"grade_saturation":1.04, "grade_contrast":1.04, "sunlight_warmth":0.78,
		"clouds_enabled":true, "cloud_strength":0.18, "cloud_softness":0.58,
		"cloud_coverage":0.55, "cloud_speed":5.0,
		"rays_enabled":true, "ray_strength":0.19, "ray_width":180.0,
		"dapple_enabled":true, "dapple_strength":0.12,
		"haze_enabled":true, "haze_strength":0.15, "bloom_enabled":false, "blur_enabled":false,
		"firefly_glow":0.65}},
	{"name":"Night v2", "overrides":{
		"night_strength":0.94, "light_radius":330.0, "mood_temperature":-0.8, "mist_strength":0.32,
		"world_brightness":1.0, "world_contrast":1.0, "world_saturation":1.0,
		"grass_brightness":1.0, "grass_saturation":1.0, "grading_enabled":false,
		"sunlight_warmth":0.0, "clouds_enabled":false, "rays_enabled":false,
		"dapple_enabled":false, "haze_enabled":false,
		"bloom_enabled":false, "blur_enabled":false,
		"particles_enabled":true, "firefly_glow":0.95}}
]
const DAY_PRESET_PATH: String = "user://forest_day_presets.cfg"
const DAY_PRESET_VERSION: int = 1
const DAY_PRESET_PHASES: Array[String] = ["Noon", "Morning", "Dusk", "Night"]
const DAY_PRESET_SLOTS: int = 3
var storage_path: String = LIBRARY_PATH
var day_preset_path: String = DAY_PRESET_PATH
var last_error: Error = OK

## Additive, per-phase seeding. Never wipes phases that already exist on disk —
## only fills in whichever phases of a slot are still missing.
func ensure_day_preset_slots(profile: ForestVisualSettings) -> void:
	if profile == null: return
	for slot: int in range(1, DAY_PRESET_SLOTS + 1):
		var existing: Dictionary = get_day_preset(slot)
		var missing_phases: Array[String] = []
		for phase: String in DAY_PRESET_PHASES:
			if not (existing.get(phase, null) is Dictionary): missing_phases.append(phase)
		if missing_phases.is_empty(): continue
		var values_by_phase: Dictionary = {}
		for phase: String in missing_phases:
			var source_name: String = "Hazey" if phase == "Noon" else (phase + " v2")
			var source: Dictionary = find_latest_named_snapshot(source_name)
			values_by_phase[phase] = (source.get("values", profile.values) as Dictionary).duplicate(true) if not source.is_empty() else profile.values.duplicate(true)
		save_day_preset(slot, values_by_phase)

## Returns whichever phases exist for this slot. May be a partial dict (0-4 keys) —
## callers must not assume all four phases are present.
func get_day_preset(slot: int) -> Dictionary:
	var checked_slot: int = clampi(slot, 1, DAY_PRESET_SLOTS)
	var config: ConfigFile = ConfigFile.new()
	if config.load(day_preset_path) != OK or int(config.get_value("library", "version", -1)) != DAY_PRESET_VERSION:
		return {}
	var result: Dictionary = {}
	var section_name: String = "preset_%d" % checked_slot
	for phase: String in DAY_PRESET_PHASES:
		if not config.has_section_key(section_name, phase): continue
		var values: Variant = config.get_value(section_name, phase)
		if values is Dictionary: result[phase] = (values as Dictionary).duplicate(true)
	return result

## Merges into whatever is already on disk. Only the phases present in
## values_by_phase are written; any other phase already saved for this slot
## is left untouched. Partial input (1-4 phases) is valid.
func save_day_preset(slot: int, values_by_phase: Dictionary) -> Error:
	var checked_slot: int = clampi(slot, 1, DAY_PRESET_SLOTS)
	var config: ConfigFile = ConfigFile.new()
	config.load(day_preset_path)
	config.set_value("library", "version", DAY_PRESET_VERSION)
	var section_name: String = "preset_%d" % checked_slot
	var wrote_any: bool = false
	for phase: String in DAY_PRESET_PHASES:
		var values: Variant = values_by_phase.get(phase, null)
		if values is Dictionary:
			config.set_value(section_name, phase, values)
			wrote_any = true
	if not wrote_any: return ERR_INVALID_DATA
	return config.save(day_preset_path)

const RAY_ANGLE_BY_PHASE: Dictionary = {"Morning": -55.0, "Noon": 0.0, "Dusk": 55.0, "Night": 0.0}
const MOON_GLOW_ENABLED_BY_PHASE: Dictionary = {"Morning": false, "Noon": false, "Dusk": false, "Night": true}
const MOON_GLOW_STRENGTH_BY_PHASE: Dictionary = {"Night": 0.16}
const MOON_BEAMS_ENABLED_BY_PHASE: Dictionary = {"Night": true}
const MOON_BEAM_STRENGTH_BY_PHASE: Dictionary = {"Night": 0.12}
const MOON_BEAM_WIDTH_BY_PHASE: Dictionary = {"Night": 150.0}
const MOON_BEAM_ANGLE_BY_PHASE: Dictionary = {"Night": -18.0}

## Additive per-phase migration for the two Day Cycle visual keys introduced
## alongside runtime phase advancement (ray_angle_degrees, moon_glow_*):
## Morning/Dusk lean the sun-ray shafts to opposite sides, Noon stays
## vertical, Night gets rays off (untouched) and a soft moon glow on. Only
## fills a phase's dict when a key is entirely absent -- never overwrites a
## value the user has already tuned, even away from these defaults.
func ensure_time_of_day_visual_upgrades() -> void:
	for slot: int in range(1, DAY_PRESET_SLOTS + 1):
		var existing: Dictionary = get_day_preset(slot)
		if existing.is_empty(): continue
		var patched_phases: Dictionary = {}
		for phase: String in DAY_PRESET_PHASES:
			var phase_values: Variant = existing.get(phase, null)
			if not (phase_values is Dictionary): continue
			var values: Dictionary = phase_values as Dictionary
			var changed: bool = false
			if not values.has("ray_angle_degrees"):
				values["ray_angle_degrees"] = float(RAY_ANGLE_BY_PHASE.get(phase, 25.64))
				changed = true
			if not values.has("moon_glow_enabled"):
				values["moon_glow_enabled"] = bool(MOON_GLOW_ENABLED_BY_PHASE.get(phase, false))
				changed = true
			if not values.has("moon_glow_strength"):
				values["moon_glow_strength"] = float(MOON_GLOW_STRENGTH_BY_PHASE.get(phase, 0.16))
				changed = true
			if not values.has("moon_beams_enabled"):
				values["moon_beams_enabled"] = bool(MOON_BEAMS_ENABLED_BY_PHASE.get(phase, true))
				changed = true
			if not values.has("moon_beam_strength"):
				values["moon_beam_strength"] = float(MOON_BEAM_STRENGTH_BY_PHASE.get(phase, 0.12))
				changed = true
			if not values.has("moon_beam_width"):
				values["moon_beam_width"] = float(MOON_BEAM_WIDTH_BY_PHASE.get(phase, 150.0))
				changed = true
			if not values.has("moon_beam_angle_degrees"):
				values["moon_beam_angle_degrees"] = float(MOON_BEAM_ANGLE_BY_PHASE.get(phase, -18.0))
				changed = true
			if changed: patched_phases[phase] = values
		if not patched_phases.is_empty():
			save_day_preset(slot, patched_phases)

func get_startup_day_preset_slot() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(day_preset_path) != OK or int(config.get_value("library", "version", -1)) != DAY_PRESET_VERSION: return 1
	return clampi(int(config.get_value("library", "startup_slot", 1)), 1, DAY_PRESET_SLOTS)

## The live day-cycle "world clock" phase, persisted here (not in the
## progression save) since it's purely visual/atmospheric -- same file as
## the startup slot it advances through. Empty string means "not yet set,"
## which callers should treat as a fresh install (starts at Morning).
func get_current_time_phase() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(day_preset_path) != OK or int(config.get_value("library", "version", -1)) != DAY_PRESET_VERSION: return ""
	var phase: String = str(config.get_value("library", "current_time_phase", ""))
	return phase if phase in DAY_PRESET_PHASES else ""

func set_current_time_phase(phase: String) -> Error:
	if not (phase in DAY_PRESET_PHASES): return ERR_INVALID_PARAMETER
	var config: ConfigFile = ConfigFile.new()
	config.load(day_preset_path)
	config.set_value("library", "version", DAY_PRESET_VERSION)
	config.set_value("library", "current_time_phase", phase)
	return config.save(day_preset_path)

func set_startup_day_preset_slot(slot: int) -> Error:
	var values: Dictionary = get_day_preset(slot)
	if values.is_empty(): return ERR_DOES_NOT_EXIST
	var config: ConfigFile = ConfigFile.new()
	config.load(day_preset_path)
	config.set_value("library", "version", DAY_PRESET_VERSION)
	config.set_value("library", "startup_slot", clampi(slot, 1, DAY_PRESET_SLOTS))
	return config.save(day_preset_path)

func create_snapshot(snapshot_name: String, profile: ForestVisualSettings) -> Dictionary:
	last_error = OK
	if profile == null:
		last_error = ERR_INVALID_PARAMETER
		return {}
	var name: String = snapshot_name.strip_edges()
	if name.is_empty():
		last_error = ERR_INVALID_PARAMETER
		return {}
	var unix_time: int = int(Time.get_unix_time_from_system())
	var saved_usec: int = Time.get_ticks_usec()
	var snapshot: Dictionary = {
		"id": "%d_%d" % [unix_time, saved_usec],
		"name": name,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"unix_time": unix_time,
		"saved_usec": saved_usec,
		"version": VERSION,
		"values": profile.values.duplicate(true)
	}
	var snapshots: Array[Dictionary] = list_snapshots()
	snapshots.push_front(snapshot)
	last_error = _write_snapshots(snapshots)
	return snapshot if last_error == OK else {}

func list_snapshots() -> Array[Dictionary]:
	last_error = OK
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(storage_path)
	if error == ERR_FILE_NOT_FOUND:
		return []
	if error != OK:
		last_error = error
		return []
	if int(config.get_value("library", "version", -1)) != VERSION:
		last_error = ERR_FILE_UNRECOGNIZED
		return []
	var result: Array[Dictionary] = []
	for id: String in config.get_section_keys("snapshots"):
		var encoded: Variant = config.get_value("snapshots", id, null)
		if encoded is Dictionary:
			var snapshot: Dictionary = (encoded as Dictionary).duplicate(true)
			snapshot["id"] = id
			if _valid_metadata(snapshot):
				result.append(snapshot)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unix_time", 0)) > int(b.get("unix_time", 0)) or (int(a.get("unix_time", 0)) == int(b.get("unix_time", 0)) and int(a.get("saved_usec", 0)) > int(b.get("saved_usec", 0)))
	)
	return result

func get_snapshot(snapshot_id: String) -> Dictionary:
	for snapshot: Dictionary in list_snapshots():
		if str(snapshot.get("id", "")) == snapshot_id:
			return snapshot
	return {}

func find_latest_named_snapshot(snapshot_name: String) -> Dictionary:
	var wanted_name: String = snapshot_name.strip_edges().to_lower()
	if wanted_name.is_empty():
		return {}
	for snapshot: Dictionary in list_snapshots():
		if str(snapshot.get("name", "")).strip_edges().to_lower() == wanted_name:
			return snapshot
	return {}

func get_startup_snapshot_id() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(storage_path) != OK:
		return ""
	if int(config.get_value("library", "version", -1)) != VERSION:
		return ""
	return str(config.get_value("library", "startup_snapshot_id", ""))

func set_startup_snapshot_id(snapshot_id: String) -> Error:
	var snapshot: Dictionary = get_snapshot(snapshot_id)
	if snapshot.is_empty():
		return ERR_DOES_NOT_EXIST
	var snapshots: Array[Dictionary] = list_snapshots()
	last_error = _write_snapshots(snapshots, snapshot_id)
	return last_error

func delete_snapshot(snapshot_id: String) -> Error:
	var snapshots: Array[Dictionary] = list_snapshots()
	var found: bool = false
	for index: int in range(snapshots.size() - 1, -1, -1):
		if str(snapshots[index].get("id", "")) == snapshot_id:
			snapshots.remove_at(index)
			found = true
	if not found:
		return ERR_DOES_NOT_EXIST
	var startup_snapshot_id: String = get_startup_snapshot_id()
	if startup_snapshot_id == snapshot_id:
		startup_snapshot_id = ""
	last_error = _write_snapshots(snapshots, startup_snapshot_id)
	return last_error

func _valid_metadata(snapshot: Dictionary) -> bool:
	return not str(snapshot.get("name", "")).strip_edges().is_empty() and snapshot.get("values", null) is Dictionary and int(snapshot.get("version", -1)) == VERSION

func _write_snapshots(snapshots: Array[Dictionary], startup_snapshot_id: Variant = null) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("library", "version", VERSION)
	var selected_startup_id: String = get_startup_snapshot_id() if startup_snapshot_id == null else str(startup_snapshot_id)
	if not selected_startup_id.is_empty():
		config.set_value("library", "startup_snapshot_id", selected_startup_id)
	for snapshot: Dictionary in snapshots:
		var id: String = str(snapshot.get("id", ""))
		if not id.is_empty():
			config.set_value("snapshots", id, snapshot)
	return config.save(storage_path)

## Creates the authored presentation family once, always derived from Hazey.
## Existing snapshots are treated as intentional art direction and preserved.
func ensure_time_of_day_profiles(hazey_profile: ForestVisualSettings) -> Array[Dictionary]:
	var ensured: Array[Dictionary] = []
	if hazey_profile == null:
		return ensured
	var hazey_snapshot: Dictionary = find_latest_named_snapshot("Hazey")
	if hazey_snapshot.is_empty():
		hazey_snapshot = create_snapshot("Hazey", hazey_profile)
	if hazey_snapshot.is_empty():
		return ensured
	var hazey_values: Dictionary = hazey_snapshot.get("values", {}) as Dictionary
	var base_snapshot: Dictionary = find_latest_named_snapshot(ILLUSTRATED_BASE_NAME)
	if base_snapshot.is_empty():
		var base_profile: ForestVisualSettings = ForestVisualSettings.new()
		if base_profile.apply_snapshot_values(hazey_values) == OK:
			base_snapshot = create_snapshot(ILLUSTRATED_BASE_NAME, base_profile)
	if not base_snapshot.is_empty():
		ensured.append(base_snapshot)
	for variant: Dictionary in TIME_OF_DAY_VARIANTS:
		var variant_name: String = str(variant.get("name", ""))
		var snapshot: Dictionary = find_latest_named_snapshot(variant_name)
		if snapshot.is_empty():
			var variant_profile: ForestVisualSettings = ForestVisualSettings.new()
			if variant_profile.apply_snapshot_values(hazey_values) != OK:
				continue
			var overrides: Dictionary = variant.get("overrides", {}) as Dictionary
			for key: String in overrides:
				variant_profile.set_value(key, overrides[key])
			snapshot = create_snapshot(variant_name, variant_profile)
		if not snapshot.is_empty():
			ensured.append(snapshot)
	# Startup already calls this entry point. Keep its legacy four-result contract.
	ensure_revised_time_of_day_profiles(hazey_profile)
	return ensured

## Noon is an exact normalized Hazey clone; v2 moods inherit its geometry.
## Only missing names are created. Startup selection and all existing values stay intact.
func ensure_revised_time_of_day_profiles(hazey_profile: ForestVisualSettings) -> Array[Dictionary]:
	var ensured: Array[Dictionary] = []
	if hazey_profile == null:
		return ensured
	var hazey_snapshot: Dictionary = find_latest_named_snapshot("Hazey")
	if last_error != OK:
		return ensured
	if hazey_snapshot.is_empty():
		hazey_snapshot = create_snapshot("Hazey", hazey_profile)
	if hazey_snapshot.is_empty():
		return ensured
	for variant: Dictionary in REVISED_VARIANTS:
		var variant_name: String = str(variant["name"])
		var snapshot: Dictionary = find_latest_named_snapshot(variant_name)
		if last_error != OK:
			return ensured
		if snapshot.is_empty():
			var profile: ForestVisualSettings = ForestVisualSettings.new()
			if profile.apply_snapshot_values(hazey_snapshot["values"]) != OK:
				continue
			for key: String in variant["overrides"]:
				profile.set_value(key, variant["overrides"][key])
			snapshot = create_snapshot(variant_name, profile)
		if not snapshot.is_empty():
			ensured.append(snapshot)
	return ensured

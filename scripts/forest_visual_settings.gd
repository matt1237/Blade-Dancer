class_name ForestVisualSettings extends Resource
## Visual-only profile. Does not share or overwrite progression/combat saves.
const PRESET_PATH = "user://forest_visuals.cfg"
const VERSION = 1
const SPECS: Array[Dictionary] = [
	{"key":"grass_brightness", "label":"Grass brightness", "group":"Ground", "default":1.0, "min":0.65, "max":1.4, "step":0.01},
	{"key":"grass_saturation", "label":"Grass saturation", "group":"Ground", "default":1.0, "min":0.3, "max":1.5, "step":0.01},
	{"key":"detail_scale", "label":"Ground detail size", "group":"Ground", "default":1.0, "min":0.7, "max":1.8, "step":0.05},
	{"key":"dirt_amount", "label":"Dirt coverage", "group":"Ground", "default":0.85, "min":0.0, "max":1.0, "step":0.01},
	{"key":"path_width", "label":"Path width (world px)", "group":"Ground", "default":260.0, "min":80.0, "max":440.0, "step":5.0},
	{"key":"path_meander", "label":"Path meander", "group":"Ground", "default":65.0, "min":0.0, "max":160.0, "step":5.0},
	{"key":"edge_breakup", "label":"Grass / soil edge breakup", "group":"Ground", "default":65.0, "min":0.0, "max":130.0, "step":2.0},
	{"key":"dark_soil", "label":"Dark soil variation", "group":"Ground", "default":0.3, "min":0.0, "max":1.0, "step":0.02},
	{"key":"night_strength", "label":"Localized night darkness", "group":"Effects", "default":0.0, "min":0.0, "max":1.0, "step":0.01},
	{"key":"light_radius", "label":"Player light radius (world px)", "group":"Effects", "default":240.0, "min":160.0, "max":640.0, "step":10.0},
	{"key":"mood_temperature", "label":"Mood temperature (cool / warm)", "group":"Effects", "default":0.0, "min":-1.0, "max":1.0, "step":0.02},
	{"key":"mist_strength", "label":"Mist strength (enable edge haze for daytime)", "group":"Effects", "default":0.0, "min":0.0, "max":1.0, "step":0.01},
	{"key":"grading_enabled", "label":"Ground color grading", "group":"Effects", "default":false},
	{"key":"grade_saturation", "label":"Grade saturation", "group":"Effects", "default":1.08, "min":0.4, "max":1.5, "step":0.02},
	{"key":"grade_contrast", "label":"Grade contrast", "group":"Effects", "default":1.06, "min":0.8, "max":1.25, "step":0.01},
	{"key":"sunlight_warmth", "label":"Sunlight warmth", "group":"Effects", "default":0.25, "min":0.0, "max":0.8, "step":0.02},
	{"key":"world_brightness", "label":"World brightness", "group":"Effects", "default":1.0, "min":0.65, "max":1.2, "step":0.01},
	{"key":"world_contrast", "label":"World contrast", "group":"Effects", "default":1.0, "min":0.85, "max":1.2, "step":0.01},
	{"key":"world_saturation", "label":"World saturation", "group":"Effects", "default":1.0, "min":0.65, "max":1.25, "step":0.01},
	{"key":"clouds_enabled", "label":"Moving cloud / canopy shadows", "group":"Effects", "default":false},
	{"key":"cloud_strength", "label":"Shadow strength", "group":"Effects", "default":0.22, "min":0.0, "max":0.45, "step":0.01},
	{"key":"cloud_scale", "label":"Shadow size", "group":"Effects", "default":360.0, "min":160.0, "max":700.0, "step":10.0},
	{"key":"cloud_speed", "label":"Shadow drift speed", "group":"Effects", "default":12.0, "min":0.0, "max":40.0, "step":1.0},
	{"key":"cloud_coverage", "label":"Cloud coverage", "group":"Effects", "default":0.5, "min":0.1, "max":0.9, "step":0.01},
	{"key":"cloud_softness", "label":"Cloud edge softness", "group":"Effects", "default":0.35, "min":0.05, "max":0.85, "step":0.01},
	{"key":"rays_enabled", "label":"Soft sun rays", "group":"Effects", "default":false},
	{"key":"ray_strength", "label":"Ray strength", "group":"Effects", "default":0.14, "min":0.0, "max":0.35, "step":0.01},
	{"key":"ray_width", "label":"Ray width", "group":"Effects", "default":100.0, "min":30.0, "max":220.0, "step":5.0},
	{"key":"ray_angle_degrees", "label":"Ray angle (0=vertical, - lean east, + lean west)", "group":"Effects", "default":25.64, "min":-85.0, "max":85.0, "step":1.0},
	{"key":"moon_glow_enabled", "label":"Moon glow (night)", "group":"Effects", "default":false},
	{"key":"moon_glow_strength", "label":"Moon glow strength", "group":"Effects", "default":0.16, "min":0.0, "max":0.4, "step":0.01},
	{"key":"moon_beams_enabled", "label":"Directional moon beams", "group":"Effects", "default":true},
	{"key":"moon_beam_strength", "label":"Moon beam strength", "group":"Effects", "default":0.12, "min":0.0, "max":0.35, "step":0.01},
	{"key":"moon_beam_width", "label":"Moon beam width", "group":"Effects", "default":150.0, "min":40.0, "max":300.0, "step":5.0},
	{"key":"moon_beam_angle_degrees", "label":"Moon beam angle", "group":"Effects", "default":-18.0, "min":-85.0, "max":85.0, "step":1.0},
	{"key":"dapple_enabled", "label":"Dappled sunlight", "group":"Effects", "default":false},
	{"key":"dapple_strength", "label":"Dapple strength", "group":"Effects", "default":0.12, "min":0.0, "max":0.3, "step":0.01},
	{"key":"haze_enabled", "label":"Edge haze", "group":"Effects", "default":false},
	{"key":"haze_strength", "label":"Haze strength", "group":"Effects", "default":0.1, "min":0.0, "max":0.25, "step":0.01},
	{"key":"bloom_enabled", "label":"Bloom (experimental, may soften detail)", "group":"Effects", "default":false},
	{"key":"bloom_strength", "label":"Bloom strength", "group":"Effects", "default":0.24, "min":0.0, "max":0.65, "step":0.01},
	{"key":"blur_enabled", "label":"Special-event screen blur", "group":"Effects", "default":false},
	{"key":"particles_enabled", "label":"Leaves, motes and fireflies", "group":"Details", "default":true},
	{"key":"leaf_size", "label":"Leaf half-length (world px)", "group":"Details", "default":9.0, "min":4.0, "max":20.0, "step":0.5},
	{"key":"leaf_count", "label":"Leaf count", "group":"Details", "default":12.0, "min":0.0, "max":40.0, "step":1.0},
	{"key":"wind_speed", "label":"Leaf drift speed", "group":"Details", "default":18.0, "min":0.0, "max":55.0, "step":1.0},
	{"key":"firefly_count", "label":"Night firefly count", "group":"Details", "default":8.0, "min":0.0, "max":20.0, "step":1.0},
	{"key":"firefly_glow", "label":"Firefly halo strength", "group":"Details", "default":0.45, "min":0.0, "max":1.0, "step":0.05},
	{"key":"edge_scale", "label":"Small edge foliage size", "group":"Details", "default":2.4, "min":1.0, "max":4.0, "step":0.1},
	{"key":"edge_density", "label":"Small edge foliage density", "group":"Details", "default":0.55, "min":0.0, "max":1.0, "step":0.05},
	{"key":"border_rocks", "label":"Border boulders", "group":"Border", "default":1.0, "min":0.0, "max":3.0, "step":1.0},
	{"key":"border_logs", "label":"Border fallen logs", "group":"Border", "default":1.0, "min":0.0, "max":3.0, "step":1.0},
	{"key":"border_stones", "label":"Border standing stones", "group":"Border", "default":1.0, "min":0.0, "max":3.0, "step":1.0},
	{"key":"border_ruins", "label":"Border ruin walls", "group":"Border", "default":0.0, "min":0.0, "max":3.0, "step":1.0},
	{"key":"border_trees", "label":"Border anchor trees", "group":"Border", "default":1.0, "min":0.0, "max":3.0, "step":1.0},
	{"key":"landmark_scale", "label":"Landmark scale", "group":"Border", "default":1.0, "min":0.65, "max":1.8, "step":0.05},
	{"key":"landmark_depth", "label":"Landmark depth", "group":"Border", "default":0.0, "min":0.0, "max":140.0, "step":5.0},
	{"key":"landmark_prominence", "label":"Landmark prominence", "group":"Border", "default":0.0, "min":0.0, "max":1.0, "step":0.05}
]
var values: Dictionary = {}
var bypass_all: bool = false

func _init() -> void:
	for spec: Dictionary in SPECS:
		values[spec["key"]] = spec["default"]

func get_value(key: String) -> Variant:
	return values.get(key)

func effect_enabled(key: String) -> bool:
	return not bypass_all and bool(values.get(key, false))

func set_value(key: String, value: Variant) -> void:
	for spec: Dictionary in SPECS:
		if str(spec["key"]) != key:
			continue
		var checked: Variant = _validate_value(spec, value)
		if checked != null and values[key] != checked:
			values[key] = checked
			emit_changed()
		return

func _validate_value(spec: Dictionary, value: Variant) -> Variant:
	if spec["default"] is bool:
		return value if value is bool else null
	if not (value is float or value is int) or not is_finite(float(value)):
		return null
	return clampf(float(value), float(spec["min"]), float(spec["max"]))

func set_bypass(enabled: bool) -> void:
	if bypass_all == enabled:
		return
	bypass_all = enabled
	emit_changed()

func reset_defaults() -> void:
	for spec: Dictionary in SPECS:
		values[spec["key"]] = spec["default"]
	bypass_all = false
	emit_changed()

func get_effective_values() -> Dictionary:
	var result: Dictionary = values.duplicate(true)
	if bypass_all:
		result["night_strength"] = 0.0
		result["mist_strength"] = 0.0
		result["mood_temperature"] = 0.0
		for key: String in result:
			if key.ends_with("_enabled"):
				result[key] = false
	return result

func save_preset(path: String = PRESET_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("profile", "version", VERSION)
	for key: String in values:
		config.set_value("visuals", key, values[key])
	# Comparison bypass is temporary and is deliberately not saved.
	return config.save(path)

func apply_snapshot_values(incoming: Dictionary) -> Error:
	# Snapshots replace the whole profile, including defaults for older schemas.
	# Stage every value before committing so invalid input leaves live state intact.
	var next_values: Dictionary = {}
	for spec: Dictionary in SPECS:
		var key: String = str(spec["key"])
		var checked: Variant = _validate_value(spec, incoming.get(key, spec["default"]))
		if checked == null:
			return ERR_INVALID_DATA
		next_values[key] = checked
	values = next_values
	bypass_all = false
	emit_changed()
	return OK

func load_preset(path: String = PRESET_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(path)
	if error != OK:
		return error
	if config.get_value("profile", "version", 0) != VERSION:
		return ERR_FILE_UNRECOGNIZED
	var loaded: Dictionary = {}
	for spec: Dictionary in SPECS:
		var key: String = str(spec["key"])
		var checked: Variant = _validate_value(spec, config.get_value("visuals", key, spec["default"]))
		if checked == null:
			return ERR_INVALID_DATA
		loaded[key] = checked
	values = loaded
	bypass_all = false
	emit_changed()
	return OK

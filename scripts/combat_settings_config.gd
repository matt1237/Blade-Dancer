class_name CombatSettingsConfig extends RefCounted

const SAVE_PATH: String = "user://combat_presets_config.json"
const SNAPSHOT_LIBRARY_PATH: String = "user://combat_preset_snapshots.json"
const SNAPSHOT_VERSION: String = "v0.1"

static func save_all(active_preset: int, hand_settings: Dictionary, contact_settings: Dictionary, blade_settings: Dictionary = {}, weapon_hand_settings: Dictionary = {}) -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	var payload: Dictionary = {
		"active_preset": clampi(active_preset, 1, 4),
		"hand_settings": hand_settings,
		"contact_settings": contact_settings,
		"blade_settings": blade_settings,
		"weapon_hand_settings": weapon_hand_settings,
		"version": "v0.1"
	}
	file.store_string(JSON.stringify(payload, "\t"))
	return true

static func load_all() -> Dictionary:
	return _read_dictionary(SAVE_PATH)

static func create_snapshot(snapshot_name: String, main_game_preset: int, selected_preset: int, hand_settings: Dictionary, contact_settings: Dictionary, blade_settings: Dictionary = {}, weapon_hand_settings: Dictionary = {}) -> Dictionary:
	var clean_name: String = snapshot_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Combat Backup"
	var unix_time: int = int(Time.get_unix_time_from_system())
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	var snapshot: Dictionary = {
		"id": "%d_%d" % [unix_time, Time.get_ticks_msec()],
		"name": clean_name,
		"timestamp": timestamp,
		"unix_time": unix_time,
		"active_preset": clampi(main_game_preset, 1, 4),
		"selected_preset": clampi(selected_preset, 1, 4),
		"hand_settings": hand_settings.duplicate(true),
		"contact_settings": contact_settings.duplicate(true),
		"blade_settings": blade_settings.duplicate(true),
		"weapon_hand_settings": weapon_hand_settings.duplicate(true),
		"version": SNAPSHOT_VERSION
	}
	var library: Dictionary = _read_dictionary(SNAPSHOT_LIBRARY_PATH)
	var raw_snapshots: Variant = library.get("snapshots", [])
	var snapshots: Array = raw_snapshots as Array if raw_snapshots is Array else []
	snapshots.push_front(snapshot)
	if not _write_dictionary(SNAPSHOT_LIBRARY_PATH, {"snapshots": snapshots, "version": SNAPSHOT_VERSION}):
		return {}
	return snapshot

static func list_snapshots() -> Array[Dictionary]:
	var library: Dictionary = _read_dictionary(SNAPSHOT_LIBRARY_PATH)
	var snapshots: Array[Dictionary] = []
	var raw_snapshots: Variant = library.get("snapshots", [])
	if not raw_snapshots is Array:
		return snapshots
	for value: Variant in raw_snapshots as Array:
		if value is Dictionary:
			snapshots.append((value as Dictionary).duplicate(true))
	snapshots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("unix_time", 0)) > int(b.get("unix_time", 0)))
	return snapshots

static func load_snapshot(snapshot_id: String) -> Dictionary:
	for snapshot: Dictionary in list_snapshots():
		if str(snapshot.get("id", "")) == snapshot_id:
			return snapshot
	return {}

static func delete_snapshot(snapshot_id: String) -> bool:
	var library: Dictionary = _read_dictionary(SNAPSHOT_LIBRARY_PATH)
	var raw_snapshots: Variant = library.get("snapshots", [])
	if not raw_snapshots is Array:
		return false
	var initial_count: int = (raw_snapshots as Array).size()
	var filtered_snapshots: Array = []
	for value: Variant in raw_snapshots as Array:
		if value is Dictionary and str((value as Dictionary).get("id", "")) != snapshot_id:
			filtered_snapshots.append(value)
	if filtered_snapshots.size() == initial_count:
		return false
	return _write_dictionary(SNAPSHOT_LIBRARY_PATH, {"snapshots": filtered_snapshots, "version": SNAPSHOT_VERSION})

## Built-in launch profile copied from the latest saved snapshot "Nasty".
## User files still override this profile when present.
static func built_in_hand_settings() -> Dictionary:
	return {
		"2:0": {"arc": 100.0, "frequency": 0.55, "max": 60.0, "max_turn_speed": 0.0, "mouse_drag": 35.0, "radial_response": 1.0, "rotation": 10.5, "scale": 3.0},
		"2:1": {"arc": 90.0, "frequency": 0.25, "max": 40.0, "max_turn_speed": 0.0, "min": 5.0, "moulinet_aim_smoothing": 0.5, "mouse_drag": 29.0, "radial_response": 1.0, "scale": 3.2, "thrusts_per_cycle": 5.0},
		"2:2": {"arc": 60.0, "frequency": 0.4, "max": 15.0, "max_turn_speed": 360.0, "min": 5.0, "mouse_drag": 20.0, "radial_response": 0.5, "scale": 4.0},
		"2:3": {"arc": 5.0, "frequency": 0.45, "max": 25.0, "max_turn_speed": 0.0, "min": 5.0, "moulinet_aim_smoothing": 1.0, "mouse_drag": 35.0, "radial_response": 0.5, "rotation": 9.0, "scale": 1.0, "strike_commitment": 0.0},
		"2:4": {"arc": 45.0, "frequency": 0.6, "max": 50.0, "max_turn_speed": 360.0, "min": 5.0, "moulinet_aim_smoothing": 30.0, "mouse_drag": 30.0, "radial_response": 1.0, "rotation": 11.0, "scale": 4.0},
		"2:5": {"arc": 5.0, "frequency": 0.55, "min": 5.0, "mouse_drag": 35.0}
	}

static func built_in_contact_settings() -> Dictionary:
	return {
		"2": {"apex_hang_time": 0.0, "bite_duration": 0.0, "bite_target_drag": 0.0, "bite_velocity_transfer": 0.0, "blade_recoil_degrees": 5.0, "blade_recoil_return": 150.0, "clash_shake_duration": 0.1, "clash_shake_strength": 4.5, "clash_zoom": 0.01, "flesh_shake_strength": 0.0, "flesh_zoom": 0.005, "grip_authority_duration": 0.15, "grip_turn_speed_mult": 1.0, "parry_focus_duration": 0.1, "parry_shake_duration": 0.1, "parry_shake_strength": 2.0, "parry_zoom": 0.02, "parry_zoom_duration": 0.1, "rebound_flow_boost": 1.0}
	}

## Empty by default -- absence of a sword's key means "use its BLADE_PROFILES
## hardcoded default," resolved live by Player.get_blade_shape_setting().
static func built_in_blade_settings() -> Dictionary:
	return {}

static func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary

static func _write_dictionary(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

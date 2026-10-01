class_name BDPXGlobal extends RefCounted
## BDPX Global — the standalone prototype's OWN persistent settings store.
##
## It lives in its own user:// file, deliberately NOT the game's
## blade_dancer_global_presets.json, so the prototype can never read or clobber
## the live game save. Same idea as the game's saves (JSON, versioned, defaults
## filled in), just walled off.
##
## The settings are a flat Dictionary. Missing keys fall back to defaults, and a
## save whose VERSION does not match is ignored, so adding a tunable later never
## breaks an older file.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

const SAVE_PATH: String = "user://bdpx_global.json"
const VERSION: int = 1

## The canonical shape of a BDPX settings save. Every value you can tune in the
## Tuning Tools panel appears here, so one call records the whole setup.
static func default_settings() -> Dictionary:
	return {
		"stiffness": Cfg.DEFAULT_MOTOR_STIFFNESS,
		"damping": Cfg.DEFAULT_MOTOR_DAMPING,
		"max_torque": Cfg.DEFAULT_MAX_TORQUE,
		# The sword BODY's own physical properties (what the object is), separate
		# from the motor above (how strongly you control it).
		"sword_mass": Cfg.SWORD_MASS_DEFAULT,
		"sword_angular_damp": Cfg.SWORD_ANGULAR_DAMP_DEFAULT,
		"sword_linear_damp": Cfg.SWORD_LINEAR_DAMP_DEFAULT,
		"com_offset": Cfg.SWORD_COM_OFFSET_DEFAULT,
		"metronome_on": false,
		"arc_degrees": Cfg.METRONOME_ARC_DEGREES,
		"frequency": Cfg.METRONOME_FREQUENCY,
		"lead_degrees": Cfg.METRONOME_MAX_LEAD_DEGREES,
		"windup_on": Cfg.WINDUP_ENABLED,
		"windup_profile": Cfg.DEFAULT_WINDUP_PROFILE,
		"windup_fraction": Cfg.WINDUP_FRACTION,
		"recovery_fraction": Cfg.RECOVERY_FRACTION,
		"windup_speed": Cfg.WINDUP_SPEED,
		"strike_speed": Cfg.STRIKE_SPEED,
		"recovery_speed": Cfg.RECOVERY_SPEED,
		"action_commitment_strength": Cfg.ACTION_COMMITMENT_STRENGTH_DEFAULT,
		"action_commitment_start": Cfg.ACTION_COMMITMENT_START_DEFAULT,
		"action_commitment_end": Cfg.ACTION_COMMITMENT_END_DEFAULT,
		"arc_energy_on": Cfg.ARC_ENERGY_ENABLED,
		"arc_wake_speed": Cfg.ARC_WAKE_SPEED_DEFAULT,
		"arc_energy_build": Cfg.ARC_ENERGY_BUILD_DEFAULT,
		"arc_energy_fade": Cfg.ARC_ENERGY_FADE_DEFAULT,
		"arc_idle_grace": Cfg.ARC_IDLE_GRACE_DEFAULT,
		"apex_hang_time": Cfg.APEX_HANG_ENABLED,
		"apex_hang_duration": Cfg.APEX_HANG_DURATION_DEFAULT,
		"aim_inertia_on": Cfg.AIM_INERTIA_ENABLED,
		"mouse_drag": Cfg.DEFAULT_MOUSE_DRAG,
		"rotation_speed": Cfg.DEFAULT_ROTATION_SPEED,
		"max_turn_speed_deg": Cfg.DEFAULT_MAX_TURN_SPEED_DEG,
		"hand_min": Cfg.DEFAULT_HAND_MIN,
		"hand_max": Cfg.DEFAULT_HAND_MAX,
		"servo_feedforward_on": Cfg.SERVO_FEEDFORWARD_ENABLED,
		"hilt_spring_on": Cfg.HILT_SPRING_ENABLED,
		"show_ghost": Cfg.SHOW_GHOST_ENABLED,
		"ghost_opacity": Cfg.GHOST_OPACITY_PERCENT,
		"px_mode": false,
		"chaser_wanted": false,
		"sword_enemy_wanted": false,
		"test_dummy_wanted": false,
		"flesh_radius": Cfg.FLESH_RADIUS_DEFAULT,
		"core_radius": Cfg.BONE_CORE_RADIUS_DEFAULT,
		"flesh_drag": Cfg.FLESH_DRAG_DEFAULT,
		"bone_friction": Cfg.BONE_FRICTION_DEFAULT,
		"enemy_mass": Cfg.ENEMY_MASS,
		"helicopter_limit": Cfg.HELICOPTER_LIMIT_DEFAULT,
	}


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Returns defaults merged with whatever was stored. Safe to call with no save
## present — you just get the defaults back.
static func load_settings() -> Dictionary:
	var settings: Dictionary = default_settings()
	if not has_save():
		return settings
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return settings
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return settings
	var stored: Dictionary = parsed as Dictionary
	if int(stored.get("version", 0)) != VERSION:
		return settings
	var values: Variant = stored.get("settings", {})
	if values is Dictionary:
		for key: String in settings.keys():
			if (values as Dictionary).has(key):
				settings[key] = (values as Dictionary)[key]
	return settings


## Clamps the given settings onto the canonical shape, stamps them, and writes.
## Returns true on a successful write.
static func save_settings(next: Dictionary) -> bool:
	var settings: Dictionary = default_settings()
	for key: String in settings.keys():
		if next.has(key):
			settings[key] = next[key]
	var payload: Dictionary = {
		"version": VERSION,
		"settings": settings,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## When the save was last written, for display. Empty string if none.
static func saved_at() -> String:
	if not has_save():
		return ""
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("saved_at", ""))
	return ""


static func clear_save() -> bool:
	if not has_save():
		return false
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	return dir.remove("bdpx_global.json") == OK
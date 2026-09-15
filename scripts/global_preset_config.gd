class_name GlobalPresetConfig extends RefCounted

const SAVE_PATH: String = "user://blade_dancer_global_presets.json"
const VERSION: int = 4
const LEGACY_VERSION: int = 3
const SLOT_COUNT: int = 3

static func load_raw_library() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

static func load_library() -> Dictionary:
	var library: Dictionary = load_raw_library()
	return library if int(library.get("version", 0)) == VERSION else {}

static func has_library() -> bool:
	return not load_library().is_empty()

static func get_slot(slot: int) -> Dictionary:
	var library: Dictionary = load_library()
	var slots: Dictionary = library.get("slots", {}) as Dictionary
	var value: Variant = slots.get(str(clampi(slot, 1, SLOT_COUNT)), {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

static func list_slots() -> Array[Dictionary]:
	var library: Dictionary = load_library()
	var slots: Dictionary = library.get("slots", {}) as Dictionary
	var result: Array[Dictionary] = []
	for slot: int in range(1, SLOT_COUNT + 1):
		var value: Variant = slots.get(str(slot), {})
		result.append((value as Dictionary).duplicate(true) if value is Dictionary else {})
	return result

static func save_slot(slot: int, state: Dictionary, selected_active_slot: int) -> bool:
	var library: Dictionary = load_library()
	if library.is_empty():
		library = {"version": VERSION, "active_slot": 2, "launch_slot": 2, "slots": {}}
	if not library.has("launch_slot"):
		library["launch_slot"] = clampi(int(library.get("active_slot", 2)), 1, SLOT_COUNT)
	var slots: Dictionary = library.get("slots", {}) as Dictionary
	var clean_slot: int = clampi(slot, 1, SLOT_COUNT)
	var stored: Dictionary = state.duplicate(true)
	stored["saved_at_unix"] = int(Time.get_unix_time_from_system())
	stored["saved_at"] = Time.get_datetime_string_from_system(false, true)
	slots[str(clean_slot)] = stored
	library["version"] = VERSION
	library["active_slot"] = clampi(selected_active_slot, 1, SLOT_COUNT)
	library["slots"] = slots
	return _write_library(library)

static func delete_slot(slot: int) -> bool:
	var library: Dictionary = load_library()
	if library.is_empty():
		return false
	var slots: Dictionary = library.get("slots", {}) as Dictionary
	var key: String = str(clampi(slot, 1, SLOT_COUNT))
	if not slots.has(key):
		return false
	slots.erase(key)
	library["slots"] = slots
	if int(library.get("active_slot", 2)) == int(key):
		library["active_slot"] = 2
	if int(library.get("launch_slot", 2)) == int(key):
		library["launch_slot"] = 2
	return _write_library(library)

static func active_slot() -> int:
	var library: Dictionary = load_library()
	return clampi(int(library.get("active_slot", 2)), 1, SLOT_COUNT)

static func set_active_slot(slot: int) -> bool:
	var library: Dictionary = load_library()
	if library.is_empty():
		return false
	library["active_slot"] = clampi(slot, 1, SLOT_COUNT)
	return _write_library(library)

static func launch_slot() -> int:
	var library: Dictionary = load_library()
	var fallback: int = clampi(int(library.get("active_slot", 2)), 1, SLOT_COUNT)
	return clampi(int(library.get("launch_slot", fallback)), 1, SLOT_COUNT)

static func set_launch_slot(slot: int) -> bool:
	var library: Dictionary = load_library()
	if library.is_empty():
		return false
	var clean_slot: int = clampi(slot, 1, SLOT_COUNT)
	var slots: Dictionary = library.get("slots", {}) as Dictionary
	if not slots.has(str(clean_slot)):
		return false
	library["launch_slot"] = clean_slot
	return _write_library(library)

static func _write_library(library: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(library, "\t"))
	return true

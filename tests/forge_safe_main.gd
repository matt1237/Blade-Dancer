extends Main
## Used unparented: no Main startup, onready evaluation, tick, or player saves.
## Production launch/close handlers remain unchanged; phase is in-memory only.
func set_forest_time_phase(phase: String) -> void:
	active_forest_time_phase = phase

func save_game(_path: String = SAVE_PATH) -> bool:
	assert(false, "Opening/closing Forge must not save")
	return false

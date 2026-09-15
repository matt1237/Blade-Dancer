class_name ResonanceRushGame extends Node2D

## Small lifecycle contract shared by every Resonance Rush world that Main can
## launch. Main owns instancing/freeing; the world only requests closure.

signal closed()

var _close_requested: bool = false

func request_close() -> void:
	if _close_requested:
		return
	_close_requested = true
	closed.emit()

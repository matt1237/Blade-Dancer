extends "res://tests/chasm_test_2_preview.gd"
## Compatibility doorway now uses the pretree save-safe real Player/Main bench.
func _ready() -> void:
	super._ready()
	_on_adventure_zone_requested("chasm_test")
	print("[SAFE TEST 1] WASD; E center/corners/sides/top/bottom; C collision; Esc/Home. No persistence.")


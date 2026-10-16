extends Player
## Test-only persistence seam. All controls, collision and startup remain Player's.
func _load_saved_combat_settings() -> void:
	ensure_experimental_form_initialized()

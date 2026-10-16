class_name ForestRestoreSafeMain
extends "res://tests/ability_bar_safe_main.gd"
## Read-only forest preview. Never use normal Main startup for recovery QA.

func _ready() -> void:
	super._ready()
	var library: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GlobalPresetConfig.SAVE_PATH)) as Dictionary
	var state: Dictionary = library["slots"]["2"]
	global_preset_slot = 2
	active_global_forest_day_presets = state["forest_day_presets"].duplicate(true)
	active_global_day_phases = active_global_forest_day_presets["2"]
	visual_style = str(state.get("visual_style", "hd"))
	player.set_visual_style(visual_style)
	forest_floor.set_visual_style(visual_style)
	_start_forest_run()
	spawner.normal_spawning_suspended = true
	spawner.set_process(false)
	forest_visual_settings.changed.connect(_apply_forest_visual_settings)
	_apply_time_phase_values(str(library.get("current_time_phase", "Night")))
	forest_visual_settings.set_bypass(bool(state.get("forest_bypass_all", false)))
	_apply_forest_visual_settings()
	print("[FOREST RESTORE PREVIEW] phase=", active_forest_time_phase, " N toggles Noon/Night; persistence disabled; writes=", write_attempts)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_N:
			_apply_time_phase_values("Noon" if active_forest_time_phase == "Night" else "Night")
			print("[FOREST RESTORE PREVIEW] phase=",active_forest_time_phase," writes=",write_attempts)
			get_viewport().set_input_as_handled()

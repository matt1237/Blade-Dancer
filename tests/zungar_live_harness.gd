class_name ZungarLiveHarness extends Node

func _ready() -> void:
	var main: Main = get_parent() as Main
	if main == null:
		push_error("Zungar live harness must be a child of Main.")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	main._set_dev_start_wave(ZungarConfig.BOSS_WAVE)
	main._start_forest_run()

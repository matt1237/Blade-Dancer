extends Node

## BDPX Global suite. Bound through PRELOADED PATHS (const GlobalStore) so a
## moved or renamed module fails loudly here. Each test stashes and restores the
## real user://bdpx_global.json, so running tests never destroys a live setup.

const PX_SCENE: PackedScene = preload("res://blade_dancer_px/scenes/px_game.tscn")
const PXGame = preload("res://blade_dancer_px/scripts/px_game.gd")
const GlobalStore = preload("res://blade_dancer_px/scripts/bdpx_global.gd")


func _stash_save() -> Variant:
	return GlobalStore.load_settings() if GlobalStore.has_save() else null


func _restore_save(backup: Variant) -> void:
	if backup == null:
		GlobalStore.clear_save()
	else:
		GlobalStore.save_settings(backup as Dictionary)


func test_bdpx_save_is_its_own_file_not_the_game_save() -> void:
	assert(GlobalStore.SAVE_PATH == "user://bdpx_global.json", "BDPX must own its file.")
	assert(GlobalStore.SAVE_PATH != "user://blade_dancer_global_presets.json",
		"BDPX must never write the game's live save.")


func test_bdpx_settings_round_trip() -> void:
	var backup: Variant = _stash_save()
	var custom: Dictionary = GlobalStore.default_settings()
	custom["stiffness"] = 12345.0
	custom["metronome_on"] = true
	custom["chaser_wanted"] = true
	assert(GlobalStore.save_settings(custom), "save_settings must report success.")
	assert(GlobalStore.has_save(), "a save must exist after writing.")
	var loaded: Dictionary = GlobalStore.load_settings()
	assert(is_equal_approx(float(loaded["stiffness"]), 12345.0), "stiffness must survive a round trip.")
	assert(bool(loaded["metronome_on"]), "metronome flag must survive.")
	assert(bool(loaded["chaser_wanted"]), "spawn flags must survive.")
	_restore_save(backup)


func test_bdpx_missing_keys_fall_back_to_defaults() -> void:
	var backup: Variant = _stash_save()
	GlobalStore.save_settings({"stiffness": 777.0})
	var loaded: Dictionary = GlobalStore.load_settings()
	assert(is_equal_approx(float(loaded["stiffness"]), 777.0), "stored value must win.")
	assert(is_equal_approx(float(loaded["max_torque"]), GlobalStore.default_settings()["max_torque"]),
		"an absent key must fall back to its default.")
	_restore_save(backup)


func test_loaded_settings_reach_the_tunables_and_spawns() -> void:
	var backup: Variant = _stash_save()
	GlobalStore.clear_save()
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	# Sliders step in 1000s, so the values here sit on the grid (a load is only
	# as precise as the control it lands on).
	var state: Dictionary = proto.current_settings()
	state["stiffness"] = 55000.0
	state["max_torque"] = 110000.0
	state["chaser_wanted"] = true
	proto.apply_settings(state)
	assert(is_equal_approx(proto.tuner.stiffness, 55000.0), "load must reach the stiffness tunable.")
	assert(is_equal_approx(proto.tuner.max_torque, 110000.0), "load must reach the torque tunable.")
	assert(proto.chaser_wanted, "a saved ON toggle must fire through the panel.")
	assert(proto._has_enemy(false), "loading a chaser ON must spawn one.")
	proto.queue_free()
	await get_tree().process_frame
	_restore_save(backup)
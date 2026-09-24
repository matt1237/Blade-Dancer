class_name AuthoredMetronomeTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _new_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME
	return player

func test_disabled_mode_preserves_existing_metronome_transform() -> void:
	var player: Player = _new_player()
	player.sword_phase = 1.17
	player.aim_angle = 0.62
	var before: Dictionary = player._sword_transform()
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	player._update_authored_metronome_state(1.0 / 60.0)
	var after: Dictionary = player._sword_transform()
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.INACTIVE, "Disabled Authored Metronome must remain inert.")
	assert(is_equal_approx(float(before["angle"]), float(after["angle"])), "With the switch off, the existing metronome angle must be unchanged.")
	assert((before["start"] as Vector2).is_equal_approx(after["start"] as Vector2), "With the switch off, the existing hand position must be unchanged.")
	player.free()

func test_ready_pose_uses_aim_and_existing_hand_radius_then_wakes_at_threshold() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("authored_metronome_enabled", 1.0)
	player.set_combat_contact_setting("authored_metronome_wake_speed", 350.0)
	player.aim_angle = 0.7
	player.combat_hand_radius = 46.0
	player.sword_phase = 1.1
	player.charged_guard_authored_aim_velocity = Vector2(349.0, 0.0)
	player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.READY, "Below-threshold movement must only reposition the ready blade.")
	assert(player._authored_metronome_pauses_phase(), "Ready state must pause the existing metronome phase.")
	var ready_pose: Dictionary = player._sword_transform()
	assert(is_equal_approx(float(ready_pose["angle"]), player.aim_angle), "The ready blade should point directly along current aim.")
	var expected_hilt: Vector2 = player.global_position + Vector2.RIGHT.rotated(player.aim_angle) * player.combat_hand_radius
	assert((ready_pose["start"] as Vector2).is_equal_approx(expected_hilt), "Ready hand position should keep the existing aim/reach radius.")
	player.charged_guard_authored_aim_velocity = Vector2(350.0, 0.0)
	player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.ACTIVE, "Crossing the authored movement threshold should wake the existing metronome.")
	assert(not player._authored_metronome_pauses_phase(), "Active state must resume the existing metronome phase.")
	player.free()

func test_active_idle_grace_returns_to_ready_before_ready_only_sheathe_timer() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("authored_metronome_enabled", 1.0)
	player.set_combat_contact_setting("authored_metronome_idle_grace", 3.0)
	player.set_combat_contact_setting("authored_metronome_sheathe_time", 0.2)
	player.charged_guard_authored_aim_velocity = Vector2.RIGHT * 500.0
	player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.ACTIVE, "Intentional aim movement should wake the metronome.")
	player.charged_guard_authored_aim_velocity = Vector2.ZERO
	for _frame: int in range(179):
		player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.ACTIVE, "Ready's shorter sheathe timer must never override active idle grace.")
	for _frame: int in range(10):
		player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.READY, "After its idle grace and smooth return, the metronome should become pointed/ready.")
	assert(player.authored_metronome_swing_blend <= 0.01, "Returning to Ready should blend the metronome offset smoothly to zero.")
	assert(player.authored_metronome_state != Player.AuthoredMetronomeState.SHEATHED, "The Ready-only timer must begin after the return to Ready.")
	for _frame: int in range(15):
		player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.SHEATHED, "An idle Ready blade should sheath after its separate delay.")
	assert(player.authored_metronome_sheathe_alpha < 1.0, "Sheathing should fade the existing blade art instead of popping it away.")
	player.charged_guard_authored_aim_velocity = Vector2.RIGHT * 26.0
	player._update_authored_metronome_state(1.0 / 60.0)
	assert(player.authored_metronome_state == Player.AuthoredMetronomeState.READY, "Meaningful aim movement should immediately restore the pointed Ready state.")
	player.free()

func test_new_tuners_are_adjacent_to_charged_guard_and_persisted() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	add_child(menu)
	var tabs: TabContainer = menu.get_node("Panel/TrainingTabs") as TabContainer
	var charged_index: int = -1
	var authored_index: int = -1
	for index: int in range(tabs.get_child_count()):
		var tab: Node = tabs.get_child(index)
		if tab.name == "Charged Guard":
			charged_index = index
		if tab.name == "Authored Metronome":
			authored_index = index
	assert(charged_index >= 0 and authored_index == charged_index + 1, "Authored Metronome must sit immediately beside Charged Guard.")
	assert(CombatSettingsConfig.AUTHORED_METRONOME_TUNING_KEYS.size() == 4, "The canonical tuner list should own the switch and all three feel controls.")
	var defaults: Dictionary = CombatSettingsConfig.built_in_contact_settings()["2"] as Dictionary
	assert(is_zero_approx(float(defaults["authored_metronome_enabled"])), "Authored Metronome must default off.")
	assert(is_equal_approx(float(defaults["authored_metronome_wake_speed"]), 350.0), "Wake speed should have a reachable testing baseline.")
	assert(is_equal_approx(float(defaults["authored_metronome_idle_grace"]), 3.0), "Active idle grace should default to three seconds.")
	assert(is_equal_approx(float(defaults["authored_metronome_sheathe_time"]), 1.0), "Ready should sheath after one quiet second by default.")
	for tuning_key: String in CombatSettingsConfig.AUTHORED_METRONOME_TUNING_KEYS:
		assert(menu.contact_controls.has(tuning_key), "Canonical Authored Metronome key %s must have a visible control." % tuning_key)
		var tooltip: String = (menu.contact_controls[tuning_key]["slider"] as HSlider).tooltip_text
		assert(tooltip.contains("← LEFT:") and tooltip.contains("→ RIGHT:") and tooltip.contains("TIP:"), "Authored Metronome control %s needs the complete tuner guidance." % tuning_key)
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_source.contains("contact_keys.append_array(CombatSettingsConfig.AUTHORED_METRONOME_TUNING_KEYS)"), "Global preset materialization must include the canonical Authored Metronome keys.")
	menu.free()

class_name ChargedGuardTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _new_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME
	return player

func test_guard_is_inert_when_disabled() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 0.0)
	player.charged_guard_charge = 0.2
	player.player_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	player.sword_phase = 1.4
	player._update_charged_guard(0.1)
	assert(is_zero_approx(player.charged_guard_charge), "Disabled Charged Guard must clear acquisition state.")
	assert(not player.charged_guard_locked, "Disabled Charged Guard must not lock or alter the sword.")
	player.free()

func test_pommel_alignment_requires_strong_axis_drive() -> void:
	var blade_direction: Vector2 = Vector2.RIGHT
	var direct_pommel_pull: float = Player.charged_guard_pommel_alignment(blade_direction, Vector2.LEFT * 200.0)
	var diagonal_pull: float = Player.charged_guard_pommel_alignment(blade_direction, Vector2(-1.0, 1.0).normalized() * 200.0)
	var tipward_push: float = Player.charged_guard_pommel_alignment(blade_direction, Vector2.RIGHT * 200.0)
	assert(is_equal_approx(direct_pommel_pull, 1.0), "Driving directly opposite the blade axis should strongly qualify.")
	assert(diagonal_pull < 0.82, "A diagonal gesture should not qualify from a partial backward component.")
	assert(tipward_push < 0.0, "Pushing toward the tip must not qualify as a pommel pull.")
	assert(Player.charged_guard_charge_multiplier(true, true) > Player.charged_guard_charge_multiplier(false, false), "Metronome counter-phase and near-body position should only speed completion.")

func test_pommel_gesture_latches_candidate_then_locks_after_guard_hold() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.sword_phase = 1.2
	player.player_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	var initial_transform: Dictionary = player._sword_transform()
	var blade_direction: Vector2 = Vector2.RIGHT.rotated(float(initial_transform["angle"]))
	player.authored_virtual_aim_velocity = -blade_direction * 200.0
	for _frame: int in range(8):
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_candidate_active, "Sustained pommel-directed counter-drive in the reversal window should latch a guard candidate.")
	assert(player.charged_guard_candidate_latch_left > 0.0, "A qualified gesture should grant a forgiving stabilization window.")
	player.authored_virtual_aim_velocity = Vector2.ZERO
	for _frame: int in range(20):
		if player.charged_guard_locked:
			break
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_locked, "A latched and maintained folded guard should lock after the short hold.")
	player.authored_angular_travel_radians = deg_to_rad(4.0)
	player.authored_sword_engagement = 0.6
	player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_locked, "Deliberate authored motion should release the lock.")
	player.free()

func test_countersteering_without_pommel_drive_does_not_acquire() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.sword_phase = 1.2
	player.player_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	player.authored_virtual_aim_velocity = Vector2.RIGHT * 200.0
	for _frame: int in range(12):
		player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_candidate_active, "Angular counter-steering without a blade-axis pommel pull must not activate Guard.")
	player.free()

func test_stroke_drive_rewards_fast_travel_more_than_slow_travel() -> void:
	var slow: float = Player.authored_stroke_drive_increment(deg_to_rad(30.0), 60.0, 0.20)
	var fast: float = Player.authored_stroke_drive_increment(deg_to_rad(30.0), 60.0, 0.90)
	var longer: float = Player.authored_stroke_drive_increment(deg_to_rad(60.0), 60.0, 0.90)
	assert(slow < fast, "At equal travel, deliberate faster authored movement should earn more Stroke Drive.")
	assert(fast < longer, "More aligned travel at the same pace should earn more Stroke Drive.")
	assert(is_zero_approx(Player.authored_stroke_drive_increment(deg_to_rad(30.0), 60.0, 0.0)), "No authored motion must earn no drive.")

func test_apex_duration_has_preset_default_and_persistence_key() -> void:
	var player: Player = _new_player()
	assert(is_equal_approx(player.get_combat_contact_setting("apex_hang_duration"), 0.14), "Shipped apex hang duration should remain 0.14 seconds.")
	player.set_combat_contact_setting("apex_hang_duration", 0.27)
	assert(is_equal_approx(player.get_combat_contact_setting("apex_hang_duration"), 0.27), "Apex hang duration should persist through the contact preset authority.")
	player.free()

func test_training_ui_has_guard_tab_and_collapsed_core_section() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	add_child(menu)
	var tabs: TabContainer = menu.get_node("Panel/TrainingTabs") as TabContainer
	var guard_tab_found: bool = false
	for tab: Node in tabs.get_children():
		if tab.name == "Charged Guard":
			guard_tab_found = true
	assert(guard_tab_found, "The opt-in guard and apex tuners need their dedicated tab.")
	var combat_scroll: ScrollContainer = tabs.get_child(4) as ScrollContainer
	var combat_box: VBoxContainer = combat_scroll.get_child(0) as VBoxContainer
	var core_collapsed: bool = false
	for child: Node in combat_box.get_children():
		if child is VBoxContainer and child.get_child_count() >= 2:
			var header: Button = child.get_child(0) as Button
			if header != null and header.text.contains("CORE SWORD & REACH"):
				core_collapsed = not (child.get_child(1) as Control).visible
	assert(core_collapsed, "Core Sword & Reach should start collapsed to reduce tuner clutter.")
	var blade_shape_collapsed: bool = false
	for child: Node in combat_box.get_children():
		if child is VBoxContainer and child.get_child_count() >= 2:
			var header: Button = child.get_child(0) as Button
			if header != null and header.text.contains("BLADE SHAPE"):
				blade_shape_collapsed = not (child.get_child(1) as Control).visible
	assert(blade_shape_collapsed, "Blade Shape should start collapsed to reduce tuner clutter.")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_source.contains("swing_gesture_gearing_degrees"), "Swing Gesture Gearing must be included in global-preset persistence.")
	assert(main_source.contains("apex_hang_duration") and main_source.contains("charged_guard_enabled"), "Apex duration and Charged Guard opt-in must be included in global-preset persistence.")
	menu.free()

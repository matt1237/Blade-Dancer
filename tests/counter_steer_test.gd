class_name CounterSteerTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const COUNTER_KEYS: Array[String] = ["counter_steer_arc_enabled", "counter_steer_arc_compression"]

func test_counter_steer_defaults_off_and_only_responds_to_engaged_opposition() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_hand_settings = {}
	player.combat_weapon_hand_settings = {}
	assert(is_zero_approx(player.get_combat_hand_setting("counter_steer_arc_enabled")), "Counter-steer must default off so the existing sword feel is unchanged until explicitly enabled.")
	assert(is_equal_approx(player.get_combat_hand_setting("counter_steer_arc_compression"), Player.COUNTER_STEER_ARC_COMPRESSION_DEFAULT), "The tunable effect strength should retain its 0.22 baseline.")
	player.authored_sword_engagement = 1.0
	assert(is_zero_approx(player._counter_steer_compression_target(-1.0, 1.0)), "Disabled counter-steer must have no effect.")
	player.set_combat_hand_setting("counter_steer_arc_enabled", 1.0)
	player.set_combat_hand_setting("counter_steer_arc_compression", 0.30)
	assert(is_equal_approx(player._counter_steer_compression_target(-1.0, 1.0), 0.30), "Engaged input against blade travel should earn the configured compression.")
	assert(is_zero_approx(player._counter_steer_compression_target(1.0, 1.0)), "Input aligned with blade travel must not counter-steer.")
	player.authored_sword_engagement = 0.0
	assert(is_zero_approx(player._counter_steer_compression_target(-1.0, 1.0)), "Unintentional jitter below the engagement threshold must not compress the arc.")
	player.free()

func test_counter_steer_settings_copy_with_hand_presets() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_hand_settings = {}
	player.combat_weapon_hand_settings = {}
	player.set_combat_hand_setting("counter_steer_arc_enabled", 1.0)
	player.set_combat_hand_setting("counter_steer_arc_compression", 0.31)
	player.copy_preset_settings(2, 3)
	player.combat_contact_preset = 3
	assert(is_equal_approx(player.get_combat_hand_setting("counter_steer_arc_enabled"), 1.0), "Preset copying must carry the counter-steer enable state.")
	assert(is_equal_approx(player.get_combat_hand_setting("counter_steer_arc_compression"), 0.31), "Preset copying must carry the counter-steer strength.")
	player.free()

func test_counter_steer_compresses_only_the_active_side_geometry_without_advancing_phase() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.sword_phase = PI * 0.5
	var phase_before: float = player.sword_phase
	var baseline: Dictionary = player._calculate_form_metronome(0.0, 40.0, 60.0, 1.0)
	player.counter_steer_compression = 0.25
	var compressed: Dictionary = player._calculate_form_metronome(0.0, 40.0, 60.0, 1.0)
	var angle_change: float = angle_difference(float(baseline["angle"]), float(compressed["angle"]))
	assert(is_equal_approx(angle_change, -deg_to_rad(15.0)), "A 25% counter-steer strength should remove 15 degrees from the destination-side apex of a 60-degree arc.")
	assert(is_equal_approx(player.sword_phase, phase_before), "Counter-steer changes geometry only and must not advance or alter the metronome clock.")
	player.counter_steer_compression = 0.0
	var opposite_side: Dictionary = player._calculate_form_metronome(0.0, 40.0, 60.0, -1.0)
	player.counter_steer_compression = 0.25
	var compressed_opposite: Dictionary = player._calculate_form_metronome(0.0, 40.0, 60.0, -1.0)
	assert(angle_difference(float(opposite_side["angle"]), float(compressed_opposite["angle"])) > 0.0, "The opposite half-stroke must compress toward its own side, never across the aim axis.")
	player.free()

func test_earned_arc_geometry_remains_continuous_at_reversal_for_both_swords() -> void:
	var tree: SceneTree = get_tree()
	var previous_scene: Node = tree.current_scene
	var stub: Node = Node.new()
	tree.root.add_child(stub)
	tree.current_scene = stub
	for sword_id: String in ["Basic Longsword", "Basic Curved Sword"]:
		for case_name: String in ["directional", "counter", "counter_idle", "both", "both_idle", "neither"]:
			var player: Player = PLAYER_SCENE.instantiate() as Player
			stub.add_child(player)
			player.set_physics_process(false)
			player.combat_contact_preset = 2
			player.sword_style = Player.SwordStyle.METRONOME_BIND_B
			player.combat_hand_settings = {}
			player.combat_weapon_hand_settings = {}
			player.set_equipped_sword(sword_id)
			player.set_combat_hand_setting_for_sword(sword_id, "counter_steer_arc_enabled", 1.0 if case_name in ["counter", "counter_idle", "both", "both_idle"] else 0.0)
			player.set_combat_hand_setting_for_sword(sword_id, "counter_steer_arc_compression", 0.4)
			player.set_combat_hand_setting_for_sword(sword_id, "directional_arc_opening_enabled", 1.0 if case_name in ["directional", "both", "both_idle"] else 0.0)
			player.authored_sword_engagement = 1.0
			player.player_aim_turn_sign = 0.0 if case_name.ends_with("idle") else -1.0
			player.sword_phase = PI * 0.5 - 0.001
			player.authored_stroke_drive = 1.0 if case_name in ["directional", "both", "both_idle"] else 0.0
			player.directional_arc_extension_degrees = 10.0 if case_name in ["directional", "both", "both_idle"] else 0.0
			player.counter_steer_compression = 0.4 if case_name in ["counter", "counter_idle", "both", "both_idle"] else 0.0
			var angle_before: float = float(player._sword_transform()["angle"])
			player._update_sword(1.0 / 60.0)
			var angle_after: float = float(player._sword_transform()["angle"])
			assert(player.swing_count == 1, "The test stroke must cross a metronome reversal.")
			assert(absf(angle_difference(angle_before, angle_after)) < deg_to_rad(1.0), "%s %s must not snap at reversal." % [sword_id, case_name])
			player.sword_phase = PI * 0.5 + PI * 0.35
			var settled_angle: float = float(player._sword_transform()["angle"])
			player.reversal_arc_carry_degrees = 0.0
			assert(is_equal_approx(settled_angle, float(player._sword_transform()["angle"])), "The carried angle must have faded out by early return travel.")
			player.free()
	tree.current_scene = previous_scene
	stub.queue_free()

func test_negative_side_reversal_keeps_its_earned_endpoint_angle() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.sword_phase = PI * 1.5 - 0.001
	player.directional_arc_extension_degrees = 10.0
	var before: float = float(player._calculate_form_metronome(0.0, 40.0, 105.0, sin(player.sword_phase))["angle"])
	player.sword_phase = PI * 1.5 + 0.001
	player.directional_arc_extension_degrees = 0.0
	player.reversal_arc_carry_degrees = -10.0
	var after: float = float(player._calculate_form_metronome(0.0, 40.0, 105.0, sin(player.sword_phase))["angle"])
	assert(absf(angle_difference(before, after)) < deg_to_rad(0.1), "Negative-side return must keep its previous endpoint instead of snapping toward center.")
	player.free()

func test_counter_steer_controls_follow_directional_arc_and_use_canonical_keys() -> void:
	assert(CombatSettingsConfig.COUNTER_STEER_HAND_TUNING_KEYS == COUNTER_KEYS, "Counter-steer's two saved tuners must use one canonical key list.")
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	add_child(menu)
	for key: String in COUNTER_KEYS:
		assert(menu.hand_controls.has(key), "Counter-steer setting %s must have a visible control." % key)
		var slider: HSlider = (menu.hand_controls[key] as Dictionary)["slider"] as HSlider
		assert(slider.tooltip_text.contains("← LEFT:") and slider.tooltip_text.contains("→ RIGHT:") and slider.tooltip_text.contains("TIP:"), "Counter-steer control %s must use the full feel-tip layout." % key)
	var toggle: HSlider = (menu.hand_controls[COUNTER_KEYS[0]] as Dictionary)["slider"] as HSlider
	var strength: HSlider = (menu.hand_controls[COUNTER_KEYS[1]] as Dictionary)["slider"] as HSlider
	assert(is_zero_approx(toggle.min_value) and is_equal_approx(toggle.max_value, 1.0) and is_equal_approx(toggle.step, 1.0), "The enable tuner must be binary 0/1.")
	assert(is_zero_approx(strength.min_value) and is_equal_approx(strength.max_value, Player.COUNTER_STEER_ARC_COMPRESSION_MAX), "Effect strength must be adjustable from zero through the supported maximum.")
	var directional: HSlider = (menu.hand_controls["directional_arc_opening_enabled"] as Dictionary)["slider"] as HSlider
	var directional_row: Node = directional.get_parent()
	var core_section: Control = directional_row.get_parent() as Control
	var rows: Array[Node] = core_section.get_children()
	var toggle_row: Node = toggle.get_parent()
	var strength_row: Node = strength.get_parent()
	var opening_strength: HSlider = (menu.hand_controls[CombatSettingsConfig.STROKE_ASSIST_HAND_TUNING_KEYS[1]] as Dictionary)["slider"] as HSlider
	assert(rows.find(toggle_row) == rows.find(opening_strength.get_parent()) + 1 and rows.find(strength_row) == rows.find(toggle_row) + 1, "Counter-steer tuners must sit directly after Directional Arc Opening's strength slider.")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_source.contains("hand_keys.append_array(CombatSettingsConfig.COUNTER_STEER_HAND_TUNING_KEYS)"), "Global preset save/load materialization must include the canonical counter-steer keys.")
	menu.free()

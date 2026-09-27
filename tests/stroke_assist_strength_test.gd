class_name StrokeAssistStrengthTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const STRENGTH_KEYS: Array[String] = ["tempo_assist_strength", "directional_arc_opening_strength"]

func test_new_strengths_preserve_old_full_strength_and_copy_to_other_presets() -> void:
	assert(CombatSettingsConfig.STROKE_ASSIST_HAND_TUNING_KEYS == STRENGTH_KEYS)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_hand_settings = {}
	player.combat_weapon_hand_settings = {}
	assert(is_equal_approx(player.get_combat_hand_setting(STRENGTH_KEYS[0]), 0.4), "Old saved profiles retain the previous +40% maximum.")
	assert(is_equal_approx(player.get_combat_hand_setting(STRENGTH_KEYS[1]), 10.0), "Old saved profiles retain the previous 10-degree maximum.")
	player.set_combat_hand_setting(STRENGTH_KEYS[0], 0.19)
	player.set_combat_hand_setting(STRENGTH_KEYS[1], 4.5)
	player.copy_preset_settings(2, 3)
	player.combat_contact_preset = 3
	assert(is_equal_approx(player.get_combat_hand_setting(STRENGTH_KEYS[0]), 0.19))
	assert(is_equal_approx(player.get_combat_hand_setting(STRENGTH_KEYS[1]), 4.5))
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	main.player = player
	var serialized: Dictionary = main._materialize_combat_settings()
	var saved_hand: Dictionary = (serialized["hand"] as Dictionary)["3:9"] as Dictionary
	assert(is_equal_approx(float(saved_hand[STRENGTH_KEYS[0]]), 0.19) and is_equal_approx(float(saved_hand[STRENGTH_KEYS[1]]), 4.5), "The actual GP2 serialization path must capture both tuned strengths.")
	player.set_combat_hand_setting_for_sword("Basic Curved Sword", STRENGTH_KEYS[0], 0.08)
	player.set_combat_hand_setting_for_sword("Basic Curved Sword", STRENGTH_KEYS[1], 2.0)
	assert(is_equal_approx(player.get_combat_hand_setting_for_sword("Basic Curved Sword", STRENGTH_KEYS[0]), 0.08) and is_equal_approx(player.get_combat_hand_setting_for_sword("Basic Longsword", STRENGTH_KEYS[0]), 0.19), "Tempo strength must remain per weapon.")
	assert(is_equal_approx(player.get_combat_hand_setting_for_sword("Basic Curved Sword", STRENGTH_KEYS[1]), 2.0) and is_equal_approx(player.get_combat_hand_setting_for_sword("Basic Longsword", STRENGTH_KEYS[1]), 4.5), "Opening strength must remain per weapon.")
	main.free()
	player.free()

func test_strength_sliders_follow_their_own_switches_with_feel_tips() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	add_child(menu)
	var core: Control = (menu.hand_controls["tempo_assist_enabled"] as Dictionary)["slider"].get_parent().get_parent() as Control
	var rows: Array[Node] = core.get_children()
	for pair: Array in [["tempo_assist_enabled", STRENGTH_KEYS[0]], ["directional_arc_opening_enabled", STRENGTH_KEYS[1]]]:
		var switch: HSlider = (menu.hand_controls[pair[0]] as Dictionary)["slider"] as HSlider
		var strength: HSlider = (menu.hand_controls[pair[1]] as Dictionary)["slider"] as HSlider
		assert(rows.find(strength.get_parent()) == rows.find(switch.get_parent()) + 1, "%s should sit directly below its switch." % pair[1])
		assert(is_zero_approx(strength.min_value))
		assert(strength.tooltip_text.contains("← LEFT:") and strength.tooltip_text.contains("→ RIGHT:") and strength.tooltip_text.contains("TIP:"))
	assert(is_equal_approx(((menu.hand_controls[STRENGTH_KEYS[0]] as Dictionary)["slider"] as HSlider).max_value, 1.0))
	assert(is_equal_approx(((menu.hand_controls[STRENGTH_KEYS[1]] as Dictionary)["slider"] as HSlider).max_value, 40.0))
	menu.free()

func test_maximum_opening_and_tempo_keep_the_turnaround_continuous() -> void:
	var tree: SceneTree = get_tree()
	var old_scene: Node = tree.current_scene
	var stub: Node = Node.new()
	tree.root.add_child(stub)
	tree.current_scene = stub
	for sword_id: String in ["Basic Longsword", "Basic Curved Sword"]:
		var player: Player = PLAYER_SCENE.instantiate() as Player
		stub.add_child(player)
		player.set_physics_process(false)
		player.combat_contact_preset = 2
		player.sword_style = Player.SwordStyle.METRONOME_BIND_B
		player.combat_hand_settings = {}
		player.combat_weapon_hand_settings = {}
		player.combat_contact_settings = {}
		player.set_equipped_sword(sword_id)
		player.set_combat_hand_setting("windup_profile", 0.0)
		player.set_combat_hand_setting("tempo_assist_enabled", 1.0)
		player.set_combat_hand_setting(STRENGTH_KEYS[0], 1.0)
		player.set_combat_hand_setting("directional_arc_opening_enabled", 1.0)
		player.set_combat_hand_setting(STRENGTH_KEYS[1], 40.0)
		player.sword_phase = PI * 0.5 - 0.001
		player.authored_stroke_drive = 1.0
		player.directional_arc_extension_degrees = 40.0
		var before: float = float(player._sword_transform()["angle"])
		player._update_sword(1.0 / 60.0)
		var after: float = float(player._sword_transform()["angle"])
		assert(player.swing_count == 1, "The frame must cross a metronome reversal.")
		assert(absf(angle_difference(before, after)) < deg_to_rad(3.0), "%s must not drop 40 degrees at the turnaround." % sword_id)
		player.free()
	tree.current_scene = old_scene
	stub.queue_free()

func test_strengths_change_only_their_existing_phase_or_geometry_effect() -> void:
	var tree: SceneTree = get_tree()
	var old_scene: Node = tree.current_scene
	var stub: Node = Node.new()
	tree.root.add_child(stub)
	tree.current_scene = stub
	var player: Player = PLAYER_SCENE.instantiate() as Player
	stub.add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_hand_settings = {}
	player.combat_weapon_hand_settings = {}
	player.combat_contact_settings = {}
	player.set_combat_hand_setting("windup_profile", 0.0)
	player.set_combat_hand_setting("tempo_assist_enabled", 1.0)
	player.set_combat_hand_setting("directional_arc_opening_enabled", 0.0)
	player.set_combat_hand_setting(STRENGTH_KEYS[0], 0.0)
	player.sword_phase = 0.2
	player.authored_stroke_drive = 1.0
	player._update_sword(1.0 / 60.0)
	var neutral_advance: float = player.sword_phase - 0.2
	assert(is_equal_approx(player.tempo_assist_multiplier, 1.0))
	player.set_combat_hand_setting(STRENGTH_KEYS[0], 0.4)
	player.sword_phase = 0.2
	player.authored_stroke_drive = 1.0
	player._update_sword(1.0 / 60.0)
	assert(is_equal_approx(player.tempo_assist_multiplier, 1.4))
	assert(is_equal_approx(player.sword_phase - 0.2, neutral_advance * 1.4))
	player.set_combat_hand_setting(STRENGTH_KEYS[0], 1.0)
	player.sword_phase = 0.2
	player.authored_stroke_drive = 1.0
	player._update_sword(1.0 / 60.0)
	assert(is_equal_approx(player.tempo_assist_multiplier, 2.0), "Full tempo strength doubles driven phase speed.")
	assert(is_equal_approx(player.sword_phase - 0.2, neutral_advance * 2.0))
	player.set_combat_hand_setting("tempo_assist_enabled", 0.0)
	player.set_combat_hand_setting("directional_arc_opening_enabled", 1.0)
	player.set_combat_hand_setting(STRENGTH_KEYS[1], 0.0)
	player.sword_phase = 0.2
	player.authored_stroke_drive = 1.0
	player._update_sword(0.0)
	assert(is_zero_approx(player.directional_arc_extension_degrees))
	player.set_combat_hand_setting(STRENGTH_KEYS[1], 10.0)
	player._update_sword(0.0)
	assert(is_equal_approx(player.directional_arc_extension_degrees, 10.0))
	player.set_combat_hand_setting(STRENGTH_KEYS[1], 40.0)
	player._update_sword(0.0)
	assert(is_equal_approx(player.directional_arc_extension_degrees, 40.0), "Full opening strength earns 40 degrees without altering stroke time.")
	assert(is_equal_approx(player.tempo_assist_multiplier, 1.0))
	player.free()
	tree.current_scene = old_scene
	stub.queue_free()

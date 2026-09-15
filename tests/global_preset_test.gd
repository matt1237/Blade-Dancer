class_name GlobalPresetTest extends Node

func test_global_library_has_three_complete_slots() -> void:
	var library: Dictionary = GlobalPresetConfig.load_library()
	assert(int(library.get("version", 0)) == GlobalPresetConfig.VERSION, "global preset schema should be current")
	assert(GlobalPresetConfig.launch_slot() == 2, "Global Preset 2 is the restored source-of-truth launch package")
	for slot: int in range(1, GlobalPresetConfig.SLOT_COUNT + 1):
		var state: Dictionary = GlobalPresetConfig.get_slot(slot)
		assert(not state.is_empty(), "global preset %d should exist" % slot)
		assert(int(state.get("schema", 0)) == GlobalPresetConfig.VERSION, "global preset %d should use the current schema" % slot)
		# Retired Bind A remains a save-safe enum value; the canonical Bind Form is
		# consolidated in memory when a package is loaded.
		assert((state.get("combat_hand_settings", {}) as Dictionary).size() >= (Player.SwordStyle.size() - 1) * 4, "global preset %d should retain complete save-compatible sword/style data" % slot)
		assert((state.get("combat_contact_settings", {}) as Dictionary).size() >= 4, "global preset %d should include every combat preset" % slot)
		assert(state.has("combat_weapon_hand_settings"), "global preset %d should include the weapon tuning section" % slot)
		assert((state.get("grapple", {}) as Dictionary).size() >= 18, "global preset %d must preserve legacy Grapple data; newly saved slots use every canonical tuner" % slot)
		assert((state.get("forest_values", {}) as Dictionary).size() == ForestVisualSettings.SPECS.size(), "global preset %d should include every forest slider" % slot)
		assert(state.has("forest_bypass_all"), "global preset %d should include the forest bypass setting" % slot)
		assert(not state.has("bonus_ranks"), "bonus ranks must remain outside global presets")
	var preset_two: Dictionary = GlobalPresetConfig.get_slot(2)
	var preset_two_grapple: Dictionary = preset_two.get("grapple", {}) as Dictionary
	assert(preset_two_grapple.size() == GrappleController.TUNING_KEYS.size(), "Source-of-truth Global Preset 2 must persist every visible Grapple and Yo-yo tuner.")
	for key: String in GrappleController.TUNING_KEYS:
		assert(preset_two_grapple.has(key), "Global Preset 2 is missing canonical Grapple tuner: %s" % key)
	var preset_two_weapons: Dictionary = preset_two.get("combat_weapon_hand_settings", {}) as Dictionary
	assert(preset_two_weapons.has("Basic Longsword") and preset_two_weapons.has("Basic Curved Sword"), "Global Preset 2 should retain both weapon tuning profiles")

func test_moonlight_phases_are_complete_and_isolated() -> void:
	var preset_two: Dictionary = GlobalPresetConfig.get_slot(2)
	var day_presets: Dictionary = preset_two.get("forest_day_presets", {}) as Dictionary
	var moonlight: Dictionary = day_presets.get("2", {}) as Dictionary
	var noon: Dictionary = moonlight.get("Noon", {}) as Dictionary
	var night: Dictionary = moonlight.get("Night", {}) as Dictionary
	assert(noon.size() == ForestVisualSettings.SPECS.size(), "Moonlight Noon should contain every forest setting")
	assert(night.size() == ForestVisualSettings.SPECS.size(), "Moonlight Night should contain every forest setting")
	assert(float(noon.get("night_strength", 1.0)) == 0.0, "Moonlight Noon must not inherit Night darkness")
	assert(float(night.get("night_strength", 0.0)) > 0.0, "Moonlight Night must retain Night darkness")
	assert(not bool(noon.get("moon_glow_enabled", true)), "Moonlight Noon must not inherit moon glow")
	assert(bool(night.get("moon_glow_enabled", false)), "Moonlight Night must retain moon glow")

func test_forest_phase_ui_has_no_launch_authority() -> void:
	var tuner: ForestVisualTuner = ForestVisualTuner.new()
	add_child(tuner)
	await get_tree().process_frame
	var phase_actions: Control = tuner.get_node("ForestTabs/Profiles/Content/PresetActions") as Control
	assert(not phase_actions.visible, "Forest phases must not expose a launch control")
	for row: Node in tuner.profile_list.get_children():
		assert(row.get_node_or_null("UseOnLaunch") == null, "legacy visual profiles must not expose launch controls")
	tuner.queue_free()

func test_weapon_hand_overrides_are_independent() -> void:
	var player_scene: PackedScene = preload("res://scenes/player.tscn")
	var player: Player = player_scene.instantiate() as Player
	add_child(player)
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME
	player.combat_weapon_hand_settings = {
		"Basic Longsword": {"2:0": {"arc": 105.0, "max": 70.0}},
		"Basic Curved Sword": {"2:0": {"arc": 90.0, "max": 30.0}}
	}
	player.set_equipped_sword("Basic Longsword")
	assert(is_equal_approx(player.get_combat_hand_setting("arc"), 105.0), "longsword arc should use its own override")
	assert(is_equal_approx(player.get_combat_hand_setting("max"), 70.0), "longsword reach should use its own override")
	player.set_equipped_sword("Basic Curved Sword")
	assert(is_equal_approx(player.get_combat_hand_setting("arc"), 90.0), "curved sword arc should use its own override")
	assert(is_equal_approx(player.get_combat_hand_setting("max"), 30.0), "curved sword reach should use its own override")
	player.free()

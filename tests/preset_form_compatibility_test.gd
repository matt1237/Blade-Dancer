class_name PresetFormCompatibilityTest
extends Node

func _authored() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/default_global_preset.json")) as Dictionary

func test_pre_thrust_package_is_valid_without_touching_its_data() -> void:
	var main: Main = Main.new() # Never enter the tree: no startup/save writers.
	var state: Dictionary = _authored()
	var before: Dictionary = state.duplicate(true)
	assert(main._global_state_complete(state), "Missing new form entries must not invalidate the forest/world package")
	assert(not main._load_baked_global_preset().is_empty(), "Authored first-run fallback must remain available")
	assert(state == before, "Validation must not mutate saved data")
	main.free()

func test_missing_optional_form_profiles_never_rebuild_the_world() -> void:
	var main: Main = Main.new()
	var state: Dictionary = _authored()
	var bind: Dictionary = state["combat_hand_settings"]["2:9"].duplicate(true)
	state["combat_hand_settings"] = {"2:9": bind}
	assert(main._global_state_complete(state), "Form count is not a world schema version")
	state["combat_hand_settings"] = {}
	assert(not main._global_state_complete(state), "Absent combat section is still invalid")
	state = _authored()
	state["schema"] = -1
	assert(not main._global_state_complete(state), "Actual schema incompatibilities must still be rejected")
	main.free()

func test_thrust_reads_shared_longsword_bind_without_changing_profiles() -> void:
	var player: Player = Player.new() # No _ready/persistence.
	var state: Dictionary = _authored()
	player.combat_hand_settings = state["combat_hand_settings"].duplicate(true)
	player.combat_weapon_hand_settings = state["combat_weapon_hand_settings"].duplicate(true)
	player.combat_contact_preset = 2
	var before: Dictionary = player.combat_weapon_hand_settings.duplicate(true)
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.set_equipped_sword("Basic Longsword")
	var bind_frequency: float = player.get_combat_hand_setting("frequency")
	var bind_arc: float = player.get_combat_hand_setting("arc")
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.sword_style == Player.SwordStyle.WINDUP_THRUST)
	assert(is_equal_approx(player.get_combat_hand_setting("frequency"), bind_frequency))
	assert(is_equal_approx(player.get_combat_hand_setting("arc"), bind_arc))
	assert(player.combat_weapon_hand_settings == before, "Thrust must use existing tuning, not rewrite profiles")
	player.free()

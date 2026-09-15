class_name BonusConfigTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BONUS_IDS: Array[String] = ["health", "chakram", "pierce", "explosion", "nova", "regen", "magnetic", "defense", "dash", "voltage", "burning", "deflect", "moon", "flash", "disarm", "void", "chain", "vampirism", "adrenaline"]

func test_every_bonus_has_seven_ranks_and_generated_text() -> void:
	for bonus_id: String in BONUS_IDS:
		var player: Player = PLAYER_SCENE.instantiate() as Player
		add_child(player)
		player.health_bar = player.get_node("HealthBar") as ProgressBar
		assert(BonusConfig.rank(player, bonus_id) == 0, "%s should begin at Rank 0." % bonus_id)
		var initial_title: String = BonusConfig.choice_title(bonus_id, player)
		assert(initial_title.contains("Rank 1 / 7"), "%s choice title should consistently state its next rank." % bonus_id)
		var comparison: String = BonusConfig.comparison_bbcode(bonus_id, player)
		assert(comparison.contains("[i][u]"), "%s comparison values should be italicized and underlined." % bonus_id)
		var tooltip: String = BonusConfig.tooltip_bbcode(bonus_id, player)
		assert(tooltip.contains("RANK PROGRESSION") and tooltip.contains("R7:"), "%s tooltip should contain generated Rank 1-7 progression." % bonus_id)
		for expected_rank: int in range(1, BonusConfig.MAX_RANK + 1):
			BonusConfig.apply_to_player(player, bonus_id)
			assert(BonusConfig.rank(player, bonus_id) == expected_rank, "%s should advance exactly one rank per selection." % bonus_id)
		assert(not BonusConfig.can_upgrade(player, bonus_id), "%s should stop appearing after Rank 7." % bonus_id)
		BonusConfig.apply_to_player(player, bonus_id)
		assert(BonusConfig.rank(player, bonus_id) == BonusConfig.MAX_RANK, "%s must remain capped at Rank 7." % bonus_id)
		player.free()

func test_bonus_screen_cards_and_help_popup_use_generated_text() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	main.player = main.get_node("Player") as Player
	main.bonus_panel = main.get_node("CanvasLayer/BonusPanel") as Panel
	main.bonus_title = main.get_node("CanvasLayer/BonusPanel/BonusTitle") as Label
	main.bonus_buttons = [main.get_node("CanvasLayer/BonusPanel/Bonus1") as Button, main.get_node("CanvasLayer/BonusPanel/Bonus2") as Button, main.get_node("CanvasLayer/BonusPanel/Bonus3") as Button]
	main.bonus_help_buttons = [main.get_node("CanvasLayer/BonusPanel/Bonus1Help") as Button, main.get_node("CanvasLayer/BonusPanel/Bonus2Help") as Button, main.get_node("CanvasLayer/BonusPanel/Bonus3Help") as Button]
	main.bonus_detail_labels = [main.get_node("CanvasLayer/BonusPanel/Bonus1Details") as RichTextLabel, main.get_node("CanvasLayer/BonusPanel/Bonus2Details") as RichTextLabel, main.get_node("CanvasLayer/BonusPanel/Bonus3Details") as RichTextLabel]
	main.bonus_tooltip_panel = main.get_node("CanvasLayer/BonusPanel/BonusTooltipPanel") as Panel
	main.bonus_tooltip_text = main.get_node("CanvasLayer/BonusPanel/BonusTooltipPanel/TooltipText") as RichTextLabel
	main.next_wave_button = main.get_node("CanvasLayer/BonusPanel/StartNextWave") as Button
	main._show_bonus_screen(3)
	assert(main.visible_bonus_choices.size() == 3, "Bonus screen should present three uncapped ranked choices.")
	for index: int in range(3):
		assert(main.bonus_buttons[index].text.contains("Rank 1 / 7"), "Every choice card should state its rank consistently.")
		assert(main.bonus_detail_labels[index].text.contains("[i][u]"), "Each card should show underlined italic current/next values.")
	main._show_bonus_tooltip(0)
	assert(main.bonus_tooltip_panel.visible, "Hover help should display the popup panel.")
	assert(main.bonus_tooltip_text.text.contains("RANK PROGRESSION"), "Help popup must use generated rank progression text.")
	main.free()

func test_voltage_and_burn_behavior_are_tuned_and_explained() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	var voltage_text: String = BonusConfig.tooltip_bbcode("voltage", player)
	var burn_text: String = BonusConfig.tooltip_bbcode("burning", player)
	assert(voltage_text.contains("stun roll") and voltage_text.contains("status"), "Voltage tooltip should explain its duration, tick, and stun behavior.")
	assert(burn_text.contains("damage every") and burn_text.contains("first tick"), "Burn tooltip should explain its damage-over-time behavior.")
	var enemy_scene: PackedScene = load("res://scenes/enemies/turkey.tscn") as PackedScene
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	enemy.apply_voltage(7)
	assert(is_equal_approx(enemy.electrified_left, BonusConfig.voltage_duration(7)))
	assert(is_equal_approx(enemy.electrified_stun_chance, BonusConfig.voltage_stun_chance(7)))
	assert(is_equal_approx(enemy.electrified_stun_duration, BonusConfig.voltage_stun_duration(7)))
	enemy.apply_burn(7)
	assert(is_equal_approx(enemy.burning_left, BonusConfig.burn_duration(7)))
	assert(is_equal_approx(enemy.burning_damage_per_tick, BonusConfig.burn_damage_per_tick(7)))
	assert(is_equal_approx(enemy.burning_tick_interval, BonusConfig.burn_tick_interval(7)))
	enemy.free()
	player.free()

func test_rank_zero_disables_all_optional_bonus_effects() -> void:
	assert(is_zero_approx(BonusConfig.explosion_radius(0)))
	assert(is_zero_approx(BonusConfig.explosion_damage_multiplier(0)))
	assert(is_zero_approx(BonusConfig.magnetic_turn_rate(0)))
	assert(is_zero_approx(BonusConfig.frost_nova_radius(0)))
	assert(is_zero_approx(BonusConfig.frost_nova_stun(0)))
	assert(is_zero_approx(BonusConfig.regeneration_per_second(0)))
	assert(is_zero_approx(BonusConfig.defense_reduction(0)))
	assert(is_zero_approx(BonusConfig.vampirism_heal(0)))
	assert(is_zero_approx(BonusConfig.void_dash_radius(0)))
	assert(is_zero_approx(BonusConfig.voltage_chance(0)))
	assert(is_zero_approx(BonusConfig.burn_chance(0)))
	assert(is_zero_approx(BonusConfig.disarm_chance(0)))
	assert(BonusConfig.deflect_max_charges(0) == 0)
	assert(is_zero_approx(BonusConfig.moon_slash_damage(0)))
	assert(is_zero_approx(BonusConfig.chain_lightning_damage(0)))
	assert(is_zero_approx(BonusConfig.adrenaline_slow(0, 100.0)))
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.deflect_rank = 0
	player.deflect_charges = 3
	player._synchronize_rank_zero_bonus_state()
	assert(player.deflect_charges == 0 and not player.can_deflect_projectile(), "Rank 0 must disable Deflect even if stale charges exist.")
	assert(not player.frost_nova_enabled and not player.regeneration_enabled and not player.voltage_enabled and not player.flash_step_enabled, "Rank 0 must disable boolean compatibility flags.")
	player.free()

func test_rank_tables_drive_applied_player_values() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.health_bar = player.get_node("HealthBar") as ProgressBar
	for rank_value: int in range(1, BonusConfig.MAX_RANK + 1):
		BonusConfig.apply_to_player(player, "health")
		assert(is_equal_approx(player.max_health, BonusConfig.health_maximum(rank_value)))
		BonusConfig.apply_to_player(player, "chakram")
		assert(player.max_chakram_charges == BonusConfig.chakram_max_charges(rank_value))
		BonusConfig.apply_to_player(player, "dash")
		assert(player.max_dash_charges == BonusConfig.dash_max_charges(rank_value))
	player.free()

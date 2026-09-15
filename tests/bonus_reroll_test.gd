class_name BonusRerollTest extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func _configured_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.player = main.get_node("Player") as Player
	main.bonus_panel = main.get_node("CanvasLayer/BonusPanel") as Panel
	main.bonus_title = main.get_node("CanvasLayer/BonusPanel/BonusTitle") as Label
	main.bonus_buttons = [
		main.get_node("CanvasLayer/BonusPanel/Bonus1") as Button,
		main.get_node("CanvasLayer/BonusPanel/Bonus2") as Button,
		main.get_node("CanvasLayer/BonusPanel/Bonus3") as Button,
	]
	main.bonus_help_buttons = [
		main.get_node("CanvasLayer/BonusPanel/Bonus1Help") as Button,
		main.get_node("CanvasLayer/BonusPanel/Bonus2Help") as Button,
		main.get_node("CanvasLayer/BonusPanel/Bonus3Help") as Button,
	]
	main.bonus_detail_labels = [
		main.get_node("CanvasLayer/BonusPanel/Bonus1Details") as RichTextLabel,
		main.get_node("CanvasLayer/BonusPanel/Bonus2Details") as RichTextLabel,
		main.get_node("CanvasLayer/BonusPanel/Bonus3Details") as RichTextLabel,
	]
	main.bonus_tooltip_panel = main.get_node("CanvasLayer/BonusPanel/BonusTooltipPanel") as Panel
	main.reroll_bonuses_button = main.get_node("CanvasLayer/BonusPanel/RerollBonuses") as Button
	main.next_wave_button = main.get_node("CanvasLayer/BonusPanel/StartNextWave") as Button
	return main

func test_wave_rewards_accumulate_run_only_reroll_charges() -> void:
	var main: Main = _configured_main()
	main._grant_bonus_reroll_charge()
	main._grant_bonus_reroll_charge()
	assert(main.bonus_reroll_charges == 2, "Unused wave rerolls should accumulate.")
	main.free()

func test_reroll_replaces_every_visible_bonus_without_repeats() -> void:
	var main: Main = _configured_main()
	main.bonus_reroll_charges = 1
	main._show_bonus_screen(1)
	var original_choices: Array[String] = main.visible_bonus_choices.duplicate()
	assert(original_choices.size() == 3, "The bonus panel should initially offer three choices.")
	main._on_reroll_bonuses()
	assert(main.bonus_reroll_charges == 0, "A full reroll should consume exactly one charge.")
	assert(main.visible_bonus_choices.size() == original_choices.size(), "A full reroll should replace every choice.")
	for bonus_id: String in main.visible_bonus_choices:
		assert(not original_choices.has(bonus_id), "A discarded bonus must not return in the reroll.")
	main.free()

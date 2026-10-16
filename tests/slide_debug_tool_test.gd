class_name SlideDebugToolTest extends Node

func test_slide_debug_defaults_off_and_follows_active_preset() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	player.combat_contact_settings = {}
	player.combat_contact_preset = 2
	assert(not player.debug_show_slide_counter)
	player.set_combat_contact_setting("slide_debug_enabled", 1.0)
	assert(player.debug_show_slide_counter)
	player.combat_contact_preset = 1
	assert(not player.debug_show_slide_counter)
	player.combat_contact_preset = 2
	player.set_combat_contact_setting("slide_debug_enabled", 0.0)
	assert(not player.debug_show_slide_counter)
	player.free()

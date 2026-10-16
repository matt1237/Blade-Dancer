class_name AbilityBarTest
extends Node
const Fixture = preload("res://tests/dualblade_test.gd")

class BarProbe extends AbilityBar:
	var forced_hover: int = -1
	func hovered_slot() -> int:
		return forced_hover

func _make_bar() -> BarProbe:
	var fixture: Node = Fixture.new()
	add_child(fixture)
	var player: Player = fixture.make_player()
	player.set_equipped_sword("Basic Longsword")
	player.set_physics_process(true)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CanvasLayer"
	fixture.add_child(layer)
	var bar: BarProbe = BarProbe.new()
	bar.name = "AbilityBar"
	layer.add_child(bar)
	bar._process(0.0)
	assert(bar.player_ref == player)
	return bar

func _key(key: int, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key as Key
	event.pressed = true
	event.echo = echo
	return event

func test_twelve_slots_defaults_and_blue_top_right_keys() -> void:
	var bar: BarProbe = _make_bar()
	assert(bar.buttons.size() == 12)
	assert(bar.bindings == AbilityBar.DEFAULT_KEYS)
	assert(bar.abilities[0] == "rewind" and bar.abilities[1] == "slow")
	assert(bar.key_labels[0].text == "1" and bar.key_labels[11].text == "=")
	assert(bar.key_labels[0].horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(bar.key_labels[0].get_theme_color("font_color").is_equal_approx(AbilityBar.HOTKEY_BLUE))
	assert(bar.fills[0].fill_mode == ProgressBar.FILL_BOTTOM_TO_TOP)
	bar.get_parent().get_parent().free()

func test_hover_rebind_does_not_cast_and_duplicate_keys_swap() -> void:
	var bar: BarProbe = _make_bar()
	bar.forced_hover = 1
	bar._input(_key(KEY_Q))
	assert(bar.bindings[1] == KEY_Q and bar.key_labels[1].text == "Q")
	assert(not WorldTime.slow_active(), "Binding must never cast")
	assert(bar.rebind_slot(0, KEY_Q))
	assert(bar.bindings[0] == KEY_Q and bar.bindings[1] == KEY_1)
	assert(not bar.rebind_slot(1, KEY_W), "Protect core movement")
	assert(bar.rebind_slot(1, KEY_E))
	bar.get_parent().get_parent().free()

func test_key_and_click_share_activation_stop_and_recharge_ui() -> void:
	var bar: BarProbe = _make_bar()
	bar._input(_key(KEY_2))
	assert(WorldTime.slow_active())
	assert(bar.cooldown_labels[1].text == "30")
	assert(is_zero_approx(bar.fills[1].value))
	bar._input(_key(KEY_2, true))
	assert(WorldTime.slow_active(), "Held key must not immediately cancel")
	bar.forced_hover = 1
	bar._input(_key(KEY_2))
	assert(not WorldTime.slow_active(), "Current hotkey still stops while hovered")
	# A separate activation checks the same cancellation through the click path.
	bar.player_ref.ability_cooldowns.start("slow", 0.0)
	bar.buttons[1].pressed.emit()
	assert(WorldTime.slow_active())
	bar.buttons[1].pressed.emit()
	assert(not WorldTime.slow_active(), "Click cancels active ability")
	bar.player_ref._tick_ability_cooldowns(15.0)
	bar._refresh()
	assert(bar.cooldown_labels[1].text == "15")
	assert(is_equal_approx(bar.fills[1].value, 0.5))
	bar.get_parent().get_parent().free()

func test_compact_bar_spacing_bottom_margin_and_fixed_metronome_anchor() -> void:
	var bar: BarProbe = _make_bar()
	assert(is_equal_approx(bar.scale.x, 0.85))
	var first: Rect2 = bar.buttons[0].get_global_rect()
	var second: Rect2 = bar.buttons[1].get_global_rect()
	assert(is_equal_approx(first.size.x, 60.0 * 0.85))
	assert(is_equal_approx(second.position.x - first.end.x, 2.0 * 0.85))
	assert(is_equal_approx(bar.get_viewport_rect().size.y - bar.get_global_rect().end.y, 5.0))
	var top: MetronomeTopBar = MetronomeTopBar.new()
	add_child(top)
	top.set_process(false)
	top.configure(bar.player_ref, "top_bar", 70.0, 2.5, 2)
	top._process(0.0)
	assert(is_equal_approx(top.visualizer.scale.x, 2.25), "Honor configured size, not a fixed preview scale")
	assert(is_equal_approx(top.visualizer.position.y, 104.0))
	top.set_beat_visualizer_size(0.5)
	top._process(0.0)
	assert(is_equal_approx(top.visualizer.position.y, 104.0), "Changing size must not push the anchor away")
	top.free()
	bar.get_parent().get_parent().free()

func test_menu_lock_and_hidden_bar_ignore_hotkeys() -> void:
	var bar: BarProbe = _make_bar()
	bar.player_ref.set_training_menu_input_locked(true)
	bar._input(_key(KEY_2))
	assert(not WorldTime.slow_active())
	bar.player_ref.set_training_menu_input_locked(false)
	bar.hide()
	bar._input(_key(KEY_2))
	assert(not WorldTime.slow_active())
	bar.get_parent().get_parent().free()

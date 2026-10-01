class_name BladeRollCooldownTest extends Node
## Covers the Blade Roll Cooldown slider (O.S. strike tuner, under Blade Roll Speed): a minimum
## time between edge-flip rollovers, so a jittery reversal cannot spin the blade back and forth.
## It must ship OFF (0) and leave the flip exactly as it is today, and a flip blocked by the timer
## is only deferred, never lost.

func _make(cooldown: float) -> Player:
	var player: Player = Player.new()
	player.set_combat_contact_setting("blade_roll_cooldown", cooldown)
	return player

## A reversal is confirmed over BLADE_TRAVEL_SIGN_CONFIRM_TIME, so two calls clear the confirm.
func _reverse_and_confirm(player: Player, relative_velocity: Vector2) -> void:
	player._update_blade_roll_target(relative_velocity, Vector2.RIGHT, 0.03)
	player._update_blade_roll_target(relative_velocity, Vector2.RIGHT, 0.03)

func test_blade_roll_cooldown_ships_off() -> void:
	var player: Player = Player.new()
	assert(is_equal_approx(player.get_combat_contact_setting("blade_roll_cooldown"), 0.0), "Blade Roll Cooldown must default to 0 so the blade flips exactly as it does today.")
	player.free()

func test_the_timer_only_defers_the_next_flip_and_never_the_first() -> void:
	var to_negative: Vector2 = Vector2(0.0, -50.0)
	var to_positive: Vector2 = Vector2(0.0, 50.0)
	# With no cooldown, a confirmed reversal flips the blade at once.
	var free_player: Player = _make(0.0)
	var flipped: float = Player.blade_roll_target_for_travel(free_player._blade_edge_side(), -1.0)
	_reverse_and_confirm(free_player, to_negative)
	assert(is_equal_approx(free_player.blade_roll_target, flipped), "With no cooldown a reversal flips the blade as it does today.")
	free_player.free()
	# With a cooldown, the first flip still fires immediately -- it only spaces flips out.
	var timed: Player = _make(0.5)
	_reverse_and_confirm(timed, to_negative)
	assert(is_equal_approx(timed.blade_roll_target, flipped), "The first flip must still fire; the cooldown only spaces flips out.")
	# Flipping straight back before the timer clears must be refused, not fired.
	var back: float = Player.blade_roll_target_for_travel(timed._blade_edge_side(), 1.0)
	_reverse_and_confirm(timed, to_positive)
	assert(not is_equal_approx(timed.blade_roll_target, back), "A flip inside the cooldown window must be refused, not fired.")
	# Once the timer clears, the deferred flip fires.
	for i: int in range(40):
		timed._update_blade_roll_target(to_positive, Vector2.RIGHT, 0.03)
	assert(is_equal_approx(timed.blade_roll_target, back), "Once the cooldown clears the deferred flip must fire.")
	timed.free()
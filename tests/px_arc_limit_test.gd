class_name PXArcLimitTest extends Node

## Aim Arc Limit ("Swing Envelope"). With the metronome OFF the target is the raw
## aim direction and there is no leash, so a whip can hand the motor a runaway
## error and fling the blade. This bounds that error: the target may never lead the
## blade by more than the arc. These pin the pure contract — the metronome's own
## leash and normal mode's arc-limit now share one implementation, so this covers
## both.
##
## Runs against PXInWorld's PURE helper, so it needs no live physics world.

func test_the_leash_bounds_how_far_the_target_may_lead_the_blade() -> void:
	var sword: PXInWorld = PXInWorld.new()
	var body: RigidBody2D = RigidBody2D.new()
	sword.blade = body
	body.rotation = 0.0
	# An aim INSIDE the arc is handed to the motor unchanged — no artificial lag.
	assert(is_equal_approx(sword._leash_aim(deg_to_rad(40.0), 90.0), deg_to_rad(40.0)), "An aim within the arc must be handed on unchanged.")
	# An aim BEYOND the arc parks the target exactly the arc's width ahead of the
	# blade, so the motor is never handed a runaway error to fling it with.
	var parked_pos: float = sword._leash_aim(deg_to_rad(170.0), 90.0)
	assert(is_equal_approx(absf(angle_difference(0.0, parked_pos)), deg_to_rad(90.0)), "An aim beyond the arc must park the target exactly arc-degrees ahead of the blade.")
	assert(signf(angle_difference(0.0, parked_pos)) > 0.0, "The target must park on the aim's own side (positive).")
	# Symmetric the other way around.
	var parked_neg: float = sword._leash_aim(deg_to_rad(-170.0), 90.0)
	assert(is_equal_approx(absf(angle_difference(0.0, parked_neg)), deg_to_rad(90.0)), "The bound must be symmetric.")
	assert(signf(angle_difference(0.0, parked_neg)) < 0.0, "The target must park on the aim's own side (negative).")
	# A limit of 0 parks the target ON the blade: it holds wherever it is.
	body.rotation = 1.0
	assert(is_equal_approx(sword._leash_aim(0.0, 0.0), 1.0), "A zero arc must hold the blade where it is.")
	body.free()
	sword.free()

func test_the_arc_limit_ships_off_with_its_knob() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	for key: String in ["arc_limit_on", "arc_limit_degrees"]:
		assert(defaults.has(key), "The BDPX save defaults must carry the arc-limit key %s." % key)
	assert(bool(defaults["arc_limit_on"]) == false, "The Aim Arc Limit must ship OFF — normal mode is untouched until it is switched on.")
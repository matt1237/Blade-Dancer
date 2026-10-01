class_name PXAimReachTest extends Node

## Core Sword & Reach ("PX owns its aim"): the aim-feel filter belongs to PX. Aim
## Inertia OFF = the cursor is the aim; ON = a two-stage filter (point drag, then
## angle drag, capped at Max Turn Speed). Pure INPUT shaping — it only decides where
## the motor is ASKED to point, never the blade's pose.

func test_turn_step_is_a_fraction_of_the_error() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.rotation_speed = 10.0
	sword.max_turn_speed_deg = 0.0  # unlimited
	# 10/s over 0.05 s = 0.5, so half the error is walked down in one frame.
	var step: float = sword._aim_turn_step(0.0, PI * 0.5, 0.05)
	assert(is_equal_approx(step, PI * 0.25), "The step must be Rotation Speed x delta of the error.")
	sword.free()

func test_max_turn_speed_caps_the_step() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.rotation_speed = 40.0
	sword.max_turn_speed_deg = 180.0
	# 40/s over 0.05 s would want a full PI/2 rad, but 180 deg/s caps it at 0.157 rad.
	var step: float = sword._aim_turn_step(0.0, PI * 0.5, 0.05)
	assert(is_equal_approx(step, deg_to_rad(180.0) * 0.05), "Max Turn Speed must cap the step.")
	sword.free()

func test_aim_feel_defaults_carry_the_playstyle() -> void:
	var sword: PXInWorld = PXInWorld.new()
	assert(sword.aim_inertia_on, "Aim Inertia defaults ON, matching the game's feel.")
	sword.free()
	var defaults: Dictionary = BDPXGlobal.default_settings()
	for key: String in ["aim_inertia_on", "mouse_drag", "rotation_speed", "max_turn_speed_deg"]:
		assert(defaults.has(key), "The PX save defaults must carry '%s'." % key)
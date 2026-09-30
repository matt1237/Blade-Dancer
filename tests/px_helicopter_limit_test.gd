class_name PXHelicopterLimitTest extends Node

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## The "Helicopter Limit" knob caps how fast the blade may TURN (deg/s). Above the
## cap a brake torque opposes the spin — a pure torque, so the blade's pose is still
## never written. These checks pin the brake's contract: silent under the cap, opposing
## the sign of the spin over it, growing with the excess, and OFF at 0.

func test_brake_is_off_below_cap_and_opposes_spin_above_it() -> void:
	var sword: PXInWorld = PXInWorld.new()
	# At the wide default cap, a brisk-but-normal swing produces no brake.
	sword.helicopter_limit = Cfg.HELICOPTER_LIMIT_DEFAULT
	assert(sword._helicopter_brake_torque(deg_to_rad(300.0)) == 0.0, "Below the cap the brake must be zero.")
	# A tight cap catches a helicoptering spin, pushing opposite to its direction.
	sword.helicopter_limit = 360.0
	assert(sword._helicopter_brake_torque(deg_to_rad(600.0)) < 0.0, "A forward spin past the cap must be braked.")
	assert(sword._helicopter_brake_torque(deg_to_rad(-600.0)) > 0.0, "A reverse spin past the cap must be braked the other way.")
	assert(sword._helicopter_brake_torque(deg_to_rad(359.0)) == 0.0, "Just under the cap must not brake.")
	# The brake grows with how far past the cap the spin is.
	var near: float = sword._helicopter_brake_torque(deg_to_rad(400.0))
	var far: float = sword._helicopter_brake_torque(deg_to_rad(900.0))
	assert(absf(far) > absf(near), "The brake must scale with the excess spin.")
	# A limit of 0 disables the brake entirely.
	sword.helicopter_limit = 0.0
	assert(sword._helicopter_brake_torque(deg_to_rad(5000.0)) == 0.0, "A limit of 0 must mean no brake at all.")
	sword.free()

func test_default_settings_carry_the_helicopter_limit() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	assert(defaults.has("helicopter_limit"), "The PX save defaults must carry the helicopter limit.")
	assert(float(defaults["helicopter_limit"]) == Cfg.HELICOPTER_LIMIT_DEFAULT, "The default limit must come from the config.")
class_name PXLmbChargeTest extends Node

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## LMB Charge ("Coil & Whip"). Hold the primary fire button and the blade banks
## speed IN THE DIRECTION IT IS ALREADY MOVING; release and that stored speed is
## spent. Two styles ride on one flag (A = Hold & Release, B = Spin-Up). These pin
## the contract: the reservoir only fills faster when the blade was really moving,
## the hold brake opposes spin and cannot exceed the motor cap, the whip scales
## with the reservoir, and the whole thing ships OFF in Style A.
##
## All checks run against PXInWorld's PURE helpers, so they need no live physics
## world — exactly the way the helicopter-limit brake is tested.

func test_the_reservoir_fills_faster_when_the_blade_was_already_moving() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.charge_time = 1.0
	sword.charge_existing_speed_gain = 1.0
	sword._charge_seed = 0.0
	var base: float = sword._charge_fill_rate()
	assert(is_equal_approx(base, 1.0), "With no head-start the reservoir must fill at the base rate 1/Charge Time.")
	var nominal_omega: float = deg_to_rad(Cfg.METRONOME_ARC_DEGREES) * Cfg.METRONOME_FREQUENCY * TAU
	sword._charge_seed = nominal_omega
	assert(is_equal_approx(sword._charge_fill_rate(), base * 2.0), "A blade already moving at nominal speed must double the fill rate at gain 1.0.")
	sword._charge_seed = nominal_omega * 4.0
	assert(sword._charge_fill_rate() > base * 2.0, "A faster-moving blade must charge even faster.")
	# Gain 0 ignores the head-start entirely — a flat, predictable charge.
	sword.charge_existing_speed_gain = 0.0
	assert(is_equal_approx(sword._charge_fill_rate(), base), "With Existing Speed Gain at 0, how you were moving must not matter.")
	# A longer Charge Time slows the base fill.
	sword.charge_existing_speed_gain = 1.0
	sword._charge_seed = 0.0
	sword.charge_time = 2.0
	assert(sword._charge_fill_rate() < base, "A longer Charge Time must slow the base fill.")
	sword.free()

func test_the_hold_brake_opposes_spin_and_clamps_to_the_motor_cap() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.damping = 1000.0
	sword.max_torque = 5000.0
	assert(sword._charge_hold_torque(3.0) < 0.0, "The hold brake must oppose a positive spin.")
	assert(sword._charge_hold_torque(-3.0) > 0.0, "The hold brake must oppose a negative spin.")
	assert(sword._charge_hold_torque(0.0) == 0.0, "A still blade must earn no brake.")
	assert(absf(sword._charge_hold_torque(1000.0)) <= sword.max_torque, "The hold brake must never exceed the motor cap.")
	sword.free()

func test_the_whip_impulse_scales_with_the_reservoir() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.fling_impulse = 40000.0
	sword._charge = 0.0
	assert(sword._fling_impulse_magnitude() == 0.0, "An empty reservoir must mean no whip.")
	sword._charge = 0.5
	var half: float = sword._fling_impulse_magnitude()
	sword._charge = 1.0
	assert(is_equal_approx(sword._fling_impulse_magnitude(), half * 2.0), "The whip must scale linearly with the reservoir.")
	sword._charge = 2.0
	assert(is_equal_approx(sword._fling_impulse_magnitude(), 40000.0), "The whip must clamp at a full reservoir.")
	sword.free()

func test_the_sense_falls_back_when_the_blade_is_still() -> void:
	var sword: PXInWorld = PXInWorld.new()
	# No blade at all: the sense must default to +1 rather than crash.
	assert(sword._capture_charge_sense() == 1.0, "With no blade the captured sense must default to +1.")
	sword.free()

func test_the_charge_ships_off_with_the_new_knobs() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	for key: String in ["lmb_charge_on", "lmb_charge_style", "lmb_charge_time", "lmb_charge_existing_speed_gain", "lmb_charge_spin_lead_degrees", "lmb_charge_fling_impulse"]:
		assert(defaults.has(key), "The BDPX save defaults must carry the LMB charge key %s." % key)
	assert(float(defaults["lmb_charge_on"]) == 0.0, "The LMB charge must ship OFF — the chakram stays the button until it is switched on.")
	assert(float(defaults["lmb_charge_style"]) == 0.0, "The charge must ship in Style A (Hold & Release).")
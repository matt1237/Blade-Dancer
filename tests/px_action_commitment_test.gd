class_name PXActionCommitmentTest extends Node

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## Late-stroke Action Commitment ("no-cancel"): inside a fraction of each stroke
## [start, end) the aim's authority over the swing is removed by `strength`
## (1 = fully no-cancel). It shapes the TARGET only — the blade still earns every
## degree from the motor. These checks pin that contract.

func test_scale_is_one_outside_the_window_and_reduced_inside() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.action_commitment_strength = 1.0
	sword.action_commitment_start = 0.60
	sword.action_commitment_end = 0.90
	assert(sword._action_commitment_scale(0.10) == 1.0, "Before the window, aim authority is untouched.")
	assert(sword._action_commitment_scale(0.75) == 0.0, "At full strength the window removes aim authority entirely.")
	assert(sword._action_commitment_scale(0.95) == 1.0, "After the window, aim authority returns.")
	sword.action_commitment_strength = 0.5
	assert(is_equal_approx(sword._action_commitment_scale(0.75), 0.5), "Half strength leaves half the aim authority.")
	sword.free()

func test_zero_strength_disables_the_lock_entirely() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.action_commitment_strength = 0.0
	assert(sword._action_commitment_scale(0.75) == 1.0, "Strength 0 must mean freely redirectable everywhere.")
	sword.free()

func test_default_settings_carry_the_commitment() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	for key: String in ["action_commitment_strength", "action_commitment_start", "action_commitment_end"]:
		assert(defaults.has(key), "The PX save defaults must carry '%s'." % key)
	assert(float(defaults["action_commitment_strength"]) == Cfg.ACTION_COMMITMENT_STRENGTH_DEFAULT, "The default strength must come from the config.")
class_name PXWindupTest extends Node

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## The Metronome Wind-up ("Form II") redistributes a stroke's angular SPEED so it
## opens slowly, strikes fast, then recovers slowly. A time-normalizer keeps the
## stroke's AVERAGE rate at the Frequency tempo, so wind-up changes the SHAPE of the
## stroke, not its length. It shapes the TARGET only — the blade still earns every
## degree from the motor. These checks pin that contract.

func test_windup_is_inert_when_off_and_shapes_when_on() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.windup_on = false
	assert(sword._metronome_step_scale(PI * 0.5) == 1.0, "With wind-up OFF the stroke must run at a constant rate.")
	sword.windup_on = true
	sword.windup_profile = 1.0
	var at_open: float = sword._metronome_step_scale(PI * 0.5)     # start of the stroke
	var at_strike: float = sword._metronome_step_scale(PI)          # middle of the stroke
	var at_recover: float = sword._metronome_step_scale(PI * 1.4)   # late in the stroke
	assert(at_strike > at_open, "The strike window must run faster than the slow open.")
	assert(at_recover < at_strike, "The recovery must run slower than the strike.")
	sword.free()

func test_windup_preserves_the_average_tempo() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.windup_on = true
	sword.windup_profile = 1.0
	# Time per stroke is the integral of 1/speed. The normalizer must keep the mean
	# of 1/step_scale across one stroke (PI of phase) at 1.0, so the stroke's total
	# duration — the tempo — is unchanged.
	var samples: int = 512
	var inverse_sum: float = 0.0
	for i: int in range(samples):
		var phase: float = PI * float(i) / float(samples)
		inverse_sum += 1.0 / sword._metronome_step_scale(phase)
	var mean_inverse: float = inverse_sum / float(samples)
	assert(absf(mean_inverse - 1.0) < 0.06, "Wind-up must preserve the average stroke tempo (got %.4f)." % mean_inverse)
	sword.free()

func test_raw_speed_profile_matches_the_game_table() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.windup_fraction = Cfg.WINDUP_FRACTION
	sword.recovery_fraction = Cfg.RECOVERY_FRACTION
	sword.windup_speed = Cfg.WINDUP_SPEED
	sword.strike_speed = Cfg.STRIKE_SPEED
	sword.recovery_speed = Cfg.RECOVERY_SPEED
	assert(is_equal_approx(sword._windup_raw_speed(0.0), Cfg.WINDUP_SPEED), "A stroke must open at the wind-up speed.")
	assert(is_equal_approx(sword._windup_raw_speed(0.5), Cfg.STRIKE_SPEED), "Mid-stroke must run at the strike speed.")
	assert(is_equal_approx(sword._windup_raw_speed(1.0), Cfg.RECOVERY_SPEED), "A stroke must close at the recovery speed.")
	sword.free()

func test_default_settings_carry_the_windup() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	for key: String in ["windup_on", "windup_profile", "windup_fraction", "recovery_fraction", "windup_speed", "strike_speed", "recovery_speed"]:
		assert(defaults.has(key), "The PX save defaults must carry '%s'." % key)
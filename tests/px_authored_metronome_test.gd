class_name PXAuthoredMetronomeTest extends Node

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## Arc Energy ("Authored Metronome"): the metronome arc widens while the aim moves
## above the wake speed, and closes once the idle grace passes with no movement.
## Apex Hang dwells at the top of each stroke. Both shape the TARGET only — the
## blade still earns every degree from the motor.

func test_arc_energy_builds_when_moving_and_fades_only_after_grace() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.arc_wake_speed = 300.0
	sword.arc_energy_build = 1.0
	sword.arc_energy_fade = 1.0
	sword.arc_idle_grace = 1.0
	# Moving above the wake speed fills the energy.
	sword._advance_arc_energy(400.0, 0.5)
	assert(sword._arc_energy > 0.0, "Moving above the wake speed must build arc energy.")
	assert(is_equal_approx(sword._arc_energy, 0.5), "Energy must build at the configured rate.")
	# Idle inside the grace holds the energy (no fade yet).
	sword._advance_arc_energy(0.0, 0.5)
	assert(is_equal_approx(sword._arc_energy, 0.5), "Idle inside the grace must not fade the arc.")
	# Past the grace it begins to bleed.
	sword._advance_arc_energy(0.0, 1.0)
	assert(sword._arc_energy < 0.5, "Past the idle grace the energy must fade.")
	sword.free()

func test_arc_energy_clamps_between_zero_and_one() -> void:
	var sword: PXInWorld = PXInWorld.new()
	sword.arc_energy_build = 3.0
	sword._advance_arc_energy(5000.0, 5.0)
	assert(sword._arc_energy == 1.0, "Energy must cap at 1.")
	sword.free()

func test_authored_metronome_is_inert_by_default() -> void:
	var sword: PXInWorld = PXInWorld.new()
	assert(not sword.arc_energy_on, "Arc Energy must be OFF by default (bench-first).")
	assert(not sword.apex_hang_on, "Apex Hang must be OFF by default (bench-first).")
	sword.free()

func test_default_settings_carry_the_authored_metronome() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	for key: String in ["arc_energy_on", "arc_wake_speed", "arc_energy_build", "arc_energy_fade", "arc_idle_grace", "apex_hang_time", "apex_hang_duration"]:
		assert(defaults.has(key), "The PX save defaults must carry '%s'." % key)
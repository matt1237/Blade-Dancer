extends Node

## PX sword-feel suite: Aim Inertia ("Core Sword & Reach") and the metronome
## wind-up ("Form II"). Both are COMMAND shaping, so both are pure enough to
## test directly — and both sit behind a kill-switch toggle.

const PX_SCENE: PackedScene = preload("res://blade_dancer_px/scenes/px_game.tscn")
const PXGame = preload("res://blade_dancer_px/scripts/px_game.gd")


func _spawn() -> PXGame:
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	return proto


func test_aim_inertia_walks_the_aim_instead_of_snapping() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	var quarter: float = PI * 0.5
	# A 90-degree cursor jump must NOT be taken in one frame.
	var step: float = proto._aim_turn_step(0.0, quarter, 1.0 / 60.0)
	assert(step > 0.001, "The aim must actually move toward the target.")
	assert(step < quarter * 0.9, "The aim must not snap a whole 90 degrees in one frame (%.3f)." % step)
	# It is a fixed fraction of the remaining error: rotation_speed per second.
	assert(is_equal_approx(step, quarter * (proto.tuner.rotation_speed / 60.0)), "One frame must advance by rotation_speed*dt of the error.")
	# Max Turn Speed clamps the per-frame step.
	proto.tuner.max_turn_speed_deg = 90.0
	var capped: float = proto._aim_turn_step(0.0, quarter, 1.0 / 60.0)
	assert(is_equal_approx(capped, deg_to_rad(90.0) / 60.0), "Max Turn Speed must cap the per-frame turn.")
	# 0 = unlimited.
	proto.tuner.max_turn_speed_deg = 0.0
	proto.tuner.rotation_speed = 40.0
	var unlimited: float = proto._aim_turn_step(0.0, quarter, 1.0 / 60.0)
	assert(is_equal_approx(unlimited, quarter * (40.0 / 60.0)), "Max Turn Speed 0 must mean unlimited.")
	proto.queue_free()
	await get_tree().process_frame


func test_windup_makes_the_strike_faster_than_the_opening() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	# One stroke spans PI; its start sits at phase PI/2.
	var opening: float = proto._metronome_step_scale(PI * 0.5)      # progress 0
	var strike: float = proto._metronome_step_scale(PI)            # progress 0.5
	assert(strike > opening, "The strike must be faster than the opening (open %.2f, strike %.2f)." % [opening, strike])
	proto.queue_free()
	await get_tree().process_frame


func test_windup_preserves_the_stroke_tempo() -> void:
	# The time-normalizer keeps the AVERAGE traversal time at the Frequency
	# slider's rate, so wind-up reshapes the stroke but does not change its tempo.
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	var sample_count: int = 200
	var inverse_sum: float = 0.0
	for index: int in range(sample_count):
		var progress: float = (float(index) + 0.5) / float(sample_count)
		var phase: float = PI * 0.5 + progress * PI
		inverse_sum += 1.0 / proto._metronome_step_scale(phase)
	var mean_inverse: float = inverse_sum / float(sample_count)
	# The normalizer samples 16 points, so a couple of percent is the intended
	# approximation, not a bug.
	assert(absf(mean_inverse - 1.0) < 0.05, "Wind-up must preserve average tempo (mean 1/scale %.3f)." % mean_inverse)
	proto.queue_free()
	await get_tree().process_frame


func test_the_toggles_kill_both_features() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	# Aim Inertia: OFF restores an instant aim.
	var aim_toggle: Button = proto.tuner._toggle_buttons["aim_inertia_on"] as Button
	aim_toggle.button_pressed = false
	assert(not proto.aim_inertia_on, "The Aim Inertia toggle must switch the feature off.")
	# Wind-up: OFF makes every step scale 1.0 (a plain sine).
	var windup_toggle: Button = proto.tuner._toggle_buttons["windup_on"] as Button
	windup_toggle.button_pressed = false
	assert(not proto.windup_on, "The Wind-up toggle must switch the feature off.")
	assert(proto._metronome_step_scale(PI) == 1.0, "With wind-up off the stroke must be a plain sine.")
	proto.queue_free()
	await get_tree().process_frame
class_name GrindstoneGame extends Control

## Grindstone — procedural tracing + rhythm prototype.
## The mouse sets a target X for the pressure point, but the point eases toward
## it rather than snapping instantly — this is what gives the pressure real
## weight instead of feeling twitchy. Beats require a click near the hit line;
## Grind sections require holding through the pulsing segment.

signal closed()

enum EventKind { BEAT, GRIND }

const GRINDSTONE_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/Grindstone/Forgewheel Pulse.mp3"),
	preload("res://assets/audio/Grindstone/Grindstone Waltz.mp3"),
]
const METAL_SLIDE_LOOP: AudioStreamMP3 = preload("res://assets/audio/Grindstone/Metal Scraping Along Metal - Like The Sound Of Rubbbing Two Metal Knives Alon....mp3")
const BALANCE_SWORD: Texture2D = preload("res://assets/Blade Dancer Sword.png")

@export_category("Session")
@export var run_duration: float = 40.0
## Linear music volume: 0.7 = 70%. Converted to decibels internally.
@export_range(0.0, 1.0, 0.05) var music_volume: float = 0.70
@export var scroll_speed: float = 140.0
@export var hit_y: float = 520.0
@export var guide_top_y: float = 150.0

@export_category("Pressure Movement")
## Maximum speed the pressure point can physically travel toward the mouse.
@export var pressure_speed: float = 620.0
## Higher = snappier easing toward the mouse target; lower = heavier, laggier feel.
@export var pressure_ease_rate: float = 9.0
@export var pressure_min_x: float = 425.0
@export var pressure_max_x: float = 775.0
@export var tracing_tolerance: float = 92.0
@export var rhythm_x_tolerance: float = 76.0

@export_category("Rail Balance")
## Balance position controlled by W/S throughout the entire run.
@export var balance_control_acceleration: float = 3.8
@export var balance_force_strength: float = 0.42
@export var balance_tolerance: float = 0.78
@export var balance_force_change_min: float = 0.90
@export var balance_force_change_max: float = 1.60
@export var balance_start_delay: float = 1.25
@export var balance_radius: float = 32.0

@export_category("Procedural Guide")
@export var guide_center_x: float = 600.0
@export var guide_amplitude: float = 140.0
@export var primary_curve_frequency: float = 0.52
@export var secondary_curve_frequency: float = 1.17
@export var chart_seed: int = 74291
## When enabled, each retry gets a fresh procedural chart. Disable this to
## reproduce a run from chart_seed while tuning or debugging.
@export var randomize_runs: bool = true

@export_category("Rhythm — quantized to a music BPM")
## Set this to match whatever custom track is playing so every Beat/Grind
## lands exactly on a musical beat instead of drifting on arbitrary timing.
@export var track_bpm: float = 100.0
## Time signature numerator. Locked to 4 for a standard 4:4 track.
@export var beats_per_bar: int = 4
## Seconds before the first event, letting the player settle in after a
## count-in or intro measure in the track.
@export var lead_in_beats: float = 4.0
## Beats between one event's start and the next, chosen randomly from this
## list. Every value here MUST be even (in a 4:4 bar) so events only ever
## land on beat 1 or beat 3 — the strong beats — never drifting onto the
## weaker beat 2 / beat 4. Change this list, not the values inside it, if you
## want a different feel.
@export var event_gap_beats_choices: Array[int] = [2, 4]
## Grind hold lengths, in beats. Same even-only rule as the gaps above, so a
## grind always resolves back onto a strong beat.
@export var grind_duration_beats_choices: Array[int] = [2, 4]
@export var beat_timing_window: float = 0.18
@export var grind_start_window: float = 0.24
@export_range(0.0, 1.0, 0.05) var grind_event_chance: float = 0.38

@export_category("Grind Feedback")
## Seconds between spawned sparks while actively holding a grind.
@export var grind_spark_interval_min: float = 0.025
@export var grind_spark_interval_max: float = 0.055
@export var grind_sparks_per_burst: int = 2
@export var grind_spark_life: float = 0.22
@export_range(0.0, 1.0, 0.05) var trace_spark_accuracy_threshold: float = 0.82
@export var trace_spark_interval: float = 0.16
@export var trace_spark_life: float = 0.14
@export var grind_loop_volume: float = -6.0

@export_category("Final Score Weights")
@export_range(0.0, 1.0, 0.05) var tracing_weight: float = 0.50
@export_range(0.0, 1.0, 0.05) var beat_weight: float = 0.25
@export_range(0.0, 1.0, 0.05) var grind_weight: float = 0.20
@export_range(0.0, 1.0, 0.05) var balance_weight: float = 0.20
@export_range(0.0, 1.0, 0.05) var grind_audio_accuracy_threshold: float = 0.80
@export var grind_audio_volume_multiplier: float = 1.20
@export var maximum_score: int = 10000

var elapsed: float = 0.0
var pressure_x: float = 700.0
var target_pressure_x: float = 700.0
var is_playing: bool = false
var mouse_held: bool = false
var active_grind_index: int = -1
var trace_score_total: float = 0.0
var trace_sample_time: float = 0.0
var balance_position: float = 0.0
var balance_velocity: float = 0.0
var balance_force: float = 0.0
var balance_force_timer: float = 0.0
var balance_score_total: float = 0.0
var balance_sample_time: float = 0.0
var beat_hits: int = 0
var beat_total: int = 0
var grind_score_total: float = 0.0
var grind_total: int = 0
var bad_clicks: int = 0
var events: Array[Dictionary] = []
var feedback_time_left: float = 0.0
var feedback_position: Vector2 = Vector2.ZERO
var feedback_success: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var audio_manager: AudioManager = null
var track_shuffle_bag: Array[int] = []
var current_track_index: int = -1
var generated_run_seed: int = 0
var run_curve_center_x: float = 700.0
var run_curve_amplitude: float = 245.0
var run_primary_frequency: float = 0.52
var run_secondary_frequency: float = 1.17
var run_primary_phase: float = 0.35
var run_secondary_phase: float = 1.8
var run_slow_phase: float = 2.4
var grind_loop_player: AudioStreamPlayer = null
var grind_loop_active: bool = false
var grind_loop_time: float = 0.0
var grind_spark_timer: float = 0.0
var trace_spark_timer: float = 0.0
var active_sparks: Array[Dictionary] = []

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var timer_label: Label = $HUD/Timer
@onready var path_label: Label = $HUD/Path
@onready var rhythm_label: Label = $HUD/Rhythm
@onready var score_label: Label = $HUD/Score
@onready var status_label: Label = $HUD/Status
@onready var result_panel: Panel = $HUD/Result
@onready var result_text: Label = $HUD/Result/ResultText
@onready var reset_button: Button = $HUD/Reset
@onready var close_button: Button = $HUD/Close

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(start_game)
	close_button.pressed.connect(_close)
	audio_manager = AudioManager.new()
	audio_manager.name = "GrindstoneAudioManager"
	add_child(audio_manager)
	if music_player != null:
		music_player.bus = &"Music"
		music_player.volume_db = linear_to_db(maxf(0.0001, music_volume))
	_setup_grind_loop_player()
	start_game()

func _setup_grind_loop_player() -> void:
	grind_loop_player = AudioStreamPlayer.new()
	grind_loop_player.name = "GrindLoopPlayer"
	grind_loop_player.bus = &"SFX"
	var slide_stream: AudioStreamMP3 = METAL_SLIDE_LOOP
	slide_stream.loop = true
	grind_loop_player.stream = slide_stream
	grind_loop_player.volume_db = grind_loop_volume
	add_child(grind_loop_player)

func start_game() -> void:
	elapsed = 0.0
	pressure_x = guide_center_x
	target_pressure_x = guide_center_x
	is_playing = true
	mouse_held = false
	active_grind_index = -1
	trace_score_total = 0.0
	trace_sample_time = 0.0
	balance_position = 0.0
	balance_velocity = 0.0
	balance_force = 0.0
	balance_force_timer = balance_start_delay
	balance_score_total = 0.0
	balance_sample_time = 0.0
	beat_hits = 0
	beat_total = 0
	grind_score_total = 0.0
	grind_total = 0
	bad_clicks = 0
	feedback_time_left = 0.0
	active_sparks.clear()
	grind_spark_timer = 0.0
	trace_spark_timer = 0.0
	_stop_grind_loop(false)
	if result_panel != null: result_panel.visible = false
	_generate_chart()
	_play_next_track()
	_update_hud()
	queue_redraw()

func _play_next_track() -> void:
	if music_player == null: return
	music_player.stream = _next_track()
	# Playback requires true SceneTree membership, which a node freshly
	# added by a synchronous test harness may not yet have — skip playing
	# rather than error, the chart/scoring logic does not depend on audio.
	if not is_inside_tree() or not music_player.is_inside_tree(): return
	music_player.stop()
	music_player.play()

func _next_track() -> AudioStream:
	if track_shuffle_bag.is_empty(): _refill_track_shuffle_bag()
	current_track_index = track_shuffle_bag.pop_front()
	return GRINDSTONE_TRACKS[current_track_index]

func _refill_track_shuffle_bag() -> void:
	track_shuffle_bag.clear()
	for track_index: int in range(GRINDSTONE_TRACKS.size()): track_shuffle_bag.append(track_index)
	track_shuffle_bag.shuffle()
	if track_shuffle_bag.size() > 1 and track_shuffle_bag[0] == current_track_index:
		var swap_index: int = randi_range(1, track_shuffle_bag.size() - 1)
		var held_index: int = track_shuffle_bag[0]
		track_shuffle_bag[0] = track_shuffle_bag[swap_index]
		track_shuffle_bag[swap_index] = held_index

func beat_duration() -> float:
	return 60.0 / maxf(1.0, track_bpm)

## True if every configured gap/duration keeps events phase-locked to the
## strong beats (1 and 3) of a 4:4 bar. Every choice must be an even number
## of beats — an odd one would shift all following events onto beat 2 or 4.
func is_strong_beat_locked() -> bool:
	for beats_value: int in event_gap_beats_choices:
		if beats_value % 2 != 0: return false
	for beats_value: int in grind_duration_beats_choices:
		if beats_value % 2 != 0: return false
	return true

func _random_choice(choices: Array[int], fallback: int) -> int:
	if choices.is_empty(): return fallback
	return choices[rng.randi_range(0, choices.size() - 1)]

func _rng_curve_parameters() -> void:
	# Keep the guide inside the playable pressure range while changing its
	# personality each run: broad sweep, tighter S-curve, or gentle drift.
	run_curve_center_x = clampf(guide_center_x + rng.randf_range(-25.0, 25.0), pressure_min_x + 105.0, pressure_max_x - 105.0)
	run_curve_amplitude = clampf(guide_amplitude * rng.randf_range(0.78, 1.08), 95.0, 155.0)
	run_primary_frequency = rng.randf_range(0.38, 0.68)
	run_secondary_frequency = rng.randf_range(0.86, 1.48)
	run_primary_phase = rng.randf_range(0.0, TAU)
	run_secondary_phase = rng.randf_range(0.0, TAU)
	run_slow_phase = rng.randf_range(0.0, TAU)

func _generate_chart() -> void:
	events.clear()
	beat_total = 0
	grind_total = 0
	if randomize_runs:
		rng.randomize()
	else:
		rng.seed = chart_seed
	generated_run_seed = rng.randi()
	_rng_curve_parameters()
	var seconds_per_beat: float = beat_duration()
	var event_time: float = lead_in_beats * seconds_per_beat
	while event_time < run_duration - seconds_per_beat:
		var kind: EventKind = EventKind.GRIND if rng.randf() < grind_event_chance else EventKind.BEAT
		if kind == EventKind.BEAT:
			events.append({"kind": int(kind), "time": event_time, "duration": 0.0, "hit": false, "resolved": false, "held_score": 0.0})
			beat_total += 1
		else:
			var duration_beats: int = _random_choice(grind_duration_beats_choices, 2)
			var duration: float = float(duration_beats) * seconds_per_beat
			events.append({"kind": int(kind), "time": event_time, "duration": duration, "hit": false, "resolved": false, "held_score": 0.0})
			grind_total += 1
			event_time += duration
		var gap_beats: int = _random_choice(event_gap_beats_choices, 2)
		event_time += float(gap_beats) * seconds_per_beat
	# Keep the procedural run varied but never degenerate.
	if events.size() > 0 and beat_total == 0:
		events[0]["kind"] = int(EventKind.BEAT)
		events[0]["duration"] = 0.0
		beat_total = 1
		grind_total = maxi(0, grind_total - 1)
	if events.size() > 0 and grind_total == 0:
		var replacement: Dictionary = events[events.size() - 1]
		replacement["kind"] = int(EventKind.GRIND)
		replacement["duration"] = float(_random_choice(grind_duration_beats_choices, 2)) * seconds_per_beat
		grind_total = 1
		beat_total = maxi(0, beat_total - 1)

func _process(delta: float) -> void:
	feedback_time_left = maxf(0.0, feedback_time_left - delta)
	_update_sparks(delta)
	if not is_playing:
		queue_redraw()
		return
	_handle_pressure_input(delta)
	_update_balance(delta)
	balance_score_total += balance_accuracy() * delta
	balance_sample_time += delta
	elapsed = minf(run_duration, elapsed + delta)
	_update_tracing(delta)
	_update_rhythm_events(delta)
	_update_grind_audio()
	_update_hud()
	queue_redraw()
	if elapsed >= run_duration: _finish_game()

func _handle_pressure_input(delta: float) -> void:
	# The pressure point never snaps to the mouse: it eases toward the target
	# exponentially, and that ease is additionally capped by pressure_speed so
	# a sudden mouse jump across the screen still takes real time to catch up.
	var ease_fraction: float = clampf(1.0 - exp(-pressure_ease_rate * delta), 0.0, 1.0)
	var eased_target: float = lerpf(pressure_x, target_pressure_x, ease_fraction)
	pressure_x = move_toward(pressure_x, eased_target, pressure_speed * delta)
	pressure_x = clampf(pressure_x, pressure_min_x, pressure_max_x)

func _update_balance(delta: float) -> void:
	var down_pressed: bool = Input.is_physical_key_pressed(KEY_S)
	var up_pressed: bool = Input.is_physical_key_pressed(KEY_W)
	var input_axis: float = float(int(up_pressed) - int(down_pressed))
	# The player counters a gentle vertical shove with W/S. The ball has
	# inertia, so releasing the key lets the current force keep carrying it.
	balance_force_timer -= delta
	if balance_force_timer <= 0.0:
		balance_force = rng.randf_range(-balance_force_strength, balance_force_strength)
		balance_force_timer = rng.randf_range(balance_force_change_min, balance_force_change_max)
	balance_velocity += (balance_force + input_axis * balance_control_acceleration) * delta
	balance_velocity *= pow(0.18, delta)
	balance_position = clampf(balance_position + balance_velocity * delta, -1.0, 1.0)
	if absf(balance_position) >= 1.0: balance_velocity *= -0.25

func balance_accuracy() -> float:
	return 1.0 - clampf(absf(balance_position) / balance_tolerance, 0.0, 1.0)

func balance_accuracy_score() -> float:
	if balance_sample_time <= 0.0: return 0.0
	return clampf(balance_score_total / balance_sample_time, 0.0, 1.0)

func _update_grind_audio() -> void:
	if grind_loop_player == null or not grind_loop_player.is_inside_tree(): return
	var grinding: bool = mouse_held and active_grind_index >= 0
	var pressure_accuracy: float = 1.0 - clampf(absf(pressure_x - guide_x_at(elapsed)) / rhythm_x_tolerance, 0.0, 1.0)
	var rail_ready: bool = pressure_accuracy >= grind_audio_accuracy_threshold and balance_accuracy() >= grind_audio_accuracy_threshold
	if grinding:
		# A Grind always has audible metal contact, 20% louder than a normal
		# successful rail slide.
		var boosted_volume: float = db_to_linear(grind_loop_volume) * grind_audio_volume_multiplier
		grind_loop_player.volume_db = linear_to_db(maxf(0.0001, boosted_volume))
		return
	if rail_ready:
		# A normal rail slide is a live success cue: it starts and stops with
		# the current pressure/balance accuracy rather than run averages.
		grind_loop_player.volume_db = grind_loop_volume
		if not grind_loop_active:
			grind_loop_player.play()
			grind_loop_active = true
	else:
		if grind_loop_active:
			grind_loop_player.stop()
			grind_loop_active = false
		grind_loop_player.volume_db = -80.0

func guide_x_at(chart_time: float) -> float:
	var primary: float = sin(chart_time * run_primary_frequency + run_primary_phase) * run_curve_amplitude * 0.62
	var secondary: float = sin(chart_time * run_secondary_frequency + run_secondary_phase) * run_curve_amplitude * 0.28
	var slow_bend: float = sin(chart_time * 0.19 + run_slow_phase) * run_curve_amplitude * 0.18
	return clampf(run_curve_center_x + primary + secondary + slow_bend, pressure_min_x, pressure_max_x)

func tracing_accuracy() -> float:
	if trace_sample_time <= 0.0: return 0.0
	return clampf(trace_score_total / trace_sample_time, 0.0, 1.0)

func _update_tracing(delta: float) -> void:
	var distance: float = absf(pressure_x - guide_x_at(elapsed))
	var frame_accuracy: float = 1.0 - clampf(distance / tracing_tolerance, 0.0, 1.0)
	# Staying balanced matters during the complete run, not only during Grind
	# sections. Pressure and balance form the tracing score together.
	# Path Accuracy is pressure-on-rail only. Balance is tracked separately
	# and must never contaminate the path percentage.
	trace_score_total += frame_accuracy * delta
	trace_sample_time += delta

func _gui_input(event: InputEvent) -> void:
	if not is_playing: return
	if event is InputEventMouseMotion:
		target_pressure_x = clampf(event.position.x, pressure_min_x, pressure_max_x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed
		if event.pressed:
			_attempt_rhythm_press()
		elif active_grind_index >= 0:
			active_grind_index = -1
			_stop_grind_loop(true)
		accept_event()

func _attempt_rhythm_press() -> void:
	var nearest_index: int = -1
	var nearest_distance: float = INF
	for event_index: int in range(events.size()):
		var entry: Dictionary = events[event_index]
		if bool(entry["resolved"]): continue
		var timing_distance: float = absf(float(entry["time"]) - elapsed)
		if timing_distance < nearest_distance:
			nearest_distance = timing_distance
			nearest_index = event_index
	if nearest_index < 0:
		_bad_press()
		return
	var nearest: Dictionary = events[nearest_index]
	var event_x: float = guide_x_at(float(nearest["time"]))
	var spatially_aligned: bool = absf(pressure_x - event_x) <= rhythm_x_tolerance
	if int(nearest["kind"]) == int(EventKind.BEAT):
		if nearest_distance <= beat_timing_window and spatially_aligned:
			nearest["hit"] = true
			nearest["resolved"] = true
			beat_hits += 1
			_success_feedback(Vector2(event_x, hit_y), "")
		else:
			_bad_press()
	else:
		if nearest_distance <= grind_start_window and spatially_aligned:
			nearest["hit"] = true
			active_grind_index = nearest_index
			_success_feedback(Vector2(event_x, hit_y), "GRIND!")
			_start_grind_loop()
		else:
			_bad_press()

func _bad_press() -> void:
	bad_clicks += 1
	feedback_success = false
	feedback_position = Vector2(pressure_x, hit_y)
	feedback_time_left = 0.25
	if status_label != null: status_label.text = "Too early, late, or off the guide."
	if audio_manager != null: audio_manager.play_sfx("smith_donk", 0.35, 1.1)

func _success_feedback(feedback_world_position: Vector2, message: String) -> void:
	feedback_success = true
	feedback_position = feedback_world_position
	feedback_time_left = 0.28
	if status_label != null and not message.is_empty(): status_label.text = message
	if audio_manager != null: audio_manager.play_sfx("smith_ting", 0.45, 1.25)

func _update_rhythm_events(delta: float) -> void:
	for event_index: int in range(events.size()):
		var entry: Dictionary = events[event_index]
		if bool(entry["resolved"]): continue
		var event_time: float = float(entry["time"])
		if int(entry["kind"]) == int(EventKind.BEAT):
			if elapsed > event_time + beat_timing_window: entry["resolved"] = true
		else:
			var duration: float = float(entry["duration"])
			if event_index == active_grind_index and mouse_held and elapsed >= event_time and elapsed <= event_time + duration:
				var target_x: float = guide_x_at(elapsed)
				var pressure_alignment: float = 1.0 - clampf(absf(pressure_x - target_x) / rhythm_x_tolerance, 0.0, 1.0)
				var balance_alignment: float = balance_accuracy()
				entry["held_score"] = float(entry["held_score"]) + pressure_alignment * balance_alignment * delta
			if elapsed > event_time + duration:
				entry["resolved"] = true
				grind_score_total += clampf(float(entry["held_score"]) / duration, 0.0, 1.0)
				if active_grind_index == event_index:
					active_grind_index = -1
					_stop_grind_loop(true)

func _start_grind_loop() -> void:
	if grind_loop_player == null or not grind_loop_player.is_inside_tree(): return
	if audio_manager != null: audio_manager.play_sfx("grind_start", 0.55, 0.95)
	grind_loop_player.stop()
	grind_loop_player.play()
	grind_loop_active = true

func _stop_grind_loop(play_landing_hit: bool) -> void:
	if grind_loop_active and grind_loop_player != null and grind_loop_player.is_inside_tree():
		grind_loop_player.stop()
	grind_loop_active = false
	if play_landing_hit and audio_manager != null: audio_manager.play_sfx("grind_land", 0.75, 1.0)

func _update_sparks(delta: float) -> void:
	for spark_index: int in range(active_sparks.size() - 1, -1, -1):
		var spark: Dictionary = active_sparks[spark_index]
		spark["life_left"] = float(spark["life_left"]) - delta
		spark["position"] = Vector2(spark["position"]) + Vector2(spark["velocity"]) * delta
		if float(spark["life_left"]) <= 0.0: active_sparks.remove_at(spark_index)
	if not is_playing: return
	var grinding: bool = mouse_held and active_grind_index >= 0
	if grinding:
		grind_spark_timer -= delta
		if grind_spark_timer <= 0.0:
			grind_spark_timer = rng.randf_range(grind_spark_interval_min, grind_spark_interval_max)
			# Grinds always show the full increased spark burst. Accuracy cues
			# belong to the rail-slide sound, not to whether a Grind sparks.
			for _burst_index: int in range(maxi(1, grind_sparks_per_burst)):
				_spawn_grind_spark(true)
		return
	# Quiet tracer sparks reward holding pressure accurately on the guide,
	# even when no rhythm grind section is active.
	var distance: float = absf(pressure_x - guide_x_at(elapsed))
	var accuracy: float = 1.0 - clampf(distance / tracing_tolerance, 0.0, 1.0)
	if accuracy < trace_spark_accuracy_threshold: return
	trace_spark_timer -= delta
	if trace_spark_timer <= 0.0:
		trace_spark_timer = trace_spark_interval
		_spawn_grind_spark(false)

func _spawn_grind_spark(is_grinding: bool) -> void:
	var spark_color: Color = Color("ffd84f") if rng.randf() < 0.5 else Color("ff9a3c")
	var spark_life: float = grind_spark_life if is_grinding else trace_spark_life
	var spread: float = 10.0 if is_grinding else 5.0
	var speed_min: float = 60.0 if is_grinding else 24.0
	var speed_max: float = 150.0 if is_grinding else 58.0
	if not is_grinding: spark_color = Color("ffe99a")
	var spawn_position: Vector2 = Vector2(pressure_x, hit_y) + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.8, spread * 0.8))
	var travel_angle: float = rng.randf_range(0.0, TAU)
	active_sparks.append({
		"position": spawn_position,
		"velocity": Vector2(cos(travel_angle), sin(travel_angle)) * rng.randf_range(speed_min, speed_max),
		"life_left": spark_life,
		"life_total": spark_life,
		"color": spark_color,
		"thickness": 2.0 if is_grinding else 1.0,
	})

func beat_accuracy() -> float:
	return float(beat_hits) / float(maxi(1, beat_total))

func grind_accuracy() -> float:
	return grind_score_total / float(maxi(1, grind_total))

func overall_accuracy() -> float:
	var weight_total: float = maxf(0.001, tracing_weight + beat_weight + grind_weight + balance_weight)
	return clampf((tracing_accuracy() * tracing_weight + beat_accuracy() * beat_weight + grind_accuracy() * grind_weight + balance_accuracy_score() * balance_weight) / weight_total, 0.0, 1.0)

func final_score() -> int:
	# Positive/additive presentation: accuracy earns points from zero rather
	# than starting at a maximum and subtracting penalties.
	return roundi(float(maximum_score) * overall_accuracy())

func material_value_multiplier() -> float:
	# A perfect result doubles the base material value; a zero result keeps it
	# at base value. This is intentionally positive and easy for crafting to use.
	return 1.0 + overall_accuracy()

func _finish_game() -> void:
	is_playing = false
	mouse_held = false
	_stop_grind_loop(false)
	active_grind_index = -1
	if music_player != null and music_player.is_inside_tree(): music_player.stop()
	if result_panel != null: result_panel.visible = true
	if result_text != null: result_text.text = "GRIND COMPLETE\n\nPath Accuracy: %.1f%%\nBalance Accuracy: %.1f%%\nBeats: %d / %d\nGrind Accuracy: %.1f%%\nOverall Accuracy: %.1f%%\n\nEARNED SCORE: %d" % [tracing_accuracy() * 100.0, balance_accuracy_score() * 100.0, beat_hits, beat_total, grind_accuracy() * 100.0, overall_accuracy() * 100.0, final_score()]
	if status_label != null: status_label.text = "The blade leaves the stone with a fresh edge."

func _update_hud() -> void:
	if timer_label != null: timer_label.text = "TIME  %d" % ceili(run_duration - elapsed)
	if path_label != null: path_label.text = "PATH  %.1f%%" % (tracing_accuracy() * 100.0)
	if rhythm_label != null: rhythm_label.text = "BALANCE %.0f%%   BEATS %d/%d   GRIND %.0f%%" % [balance_accuracy_score() * 100.0, beat_hits, beat_total, grind_accuracy() * 100.0]
	if score_label != null: score_label.text = "EARNED  %d" % final_score()

func _chart_y(chart_time: float) -> float:
	return hit_y - (chart_time - elapsed) * scroll_speed

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("171d20"))
	draw_rect(Rect2(38.0, 34.0, size.x - 76.0, size.y - 68.0), Color("283238"), true)
	_draw_rhythm_events()
	_draw_guide()
	_draw_pressure_point()
	_draw_sparks()
	_draw_feedback()

func _draw_workshop_art() -> void:
	# Top-down grindstone wheel and a simple sword touching its upper edge.
	var stone_center: Vector2 = Vector2(205.0, 395.0)
	draw_circle(stone_center, 112.0, Color("20272b"))
	draw_circle(stone_center, 96.0, Color("69757a"))
	draw_circle(stone_center, 74.0, Color("899398"))
	draw_circle(stone_center, 18.0, Color("343c40"))
	for groove_index: int in range(5):
		draw_arc(stone_center, 34.0 + groove_index * 12.0, 0.0, TAU, 48, Color(0.18, 0.22, 0.24, 0.45), 2.0)
	var blade: PackedVector2Array = PackedVector2Array([Vector2(92.0, 208.0), Vector2(113.0, 200.0), Vector2(270.0, 310.0), Vector2(257.0, 326.0)])
	draw_colored_polygon(blade, Color("c8d1d2"))
	draw_polyline(blade, Color("f1d17a"), 3.0)
	draw_line(Vector2(88.0, 198.0), Vector2(122.0, 229.0), Color("9d7048"), 13.0)
	draw_string(ThemeDB.fallback_font, Vector2(85.0, 555.0), "MOUSE  MOVES PRESSURE", HORIZONTAL_ALIGNMENT_CENTER, 240.0, 18, Color("b8d4b2"))

func _draw_guide() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	_build_guide_points_and_colors(points, colors)
	if points.size() > 1:
		var glow_colors: PackedColorArray = PackedColorArray()
		glow_colors.resize(colors.size())
		for color_index: int in range(colors.size()):
			glow_colors[color_index] = Color(0.78, 0.86, 0.86, 0.32 * colors[color_index].a)
		draw_polyline_colors(points, glow_colors, 23.0, true)
		draw_polyline_colors(points, colors, 8.0, true)
	draw_line(Vector2(pressure_min_x, hit_y), Vector2(pressure_max_x, hit_y), Color(1.0, 0.8, 0.2, 0.35), 3.0)
	_draw_balance_meter()

func _is_grind_at_time(chart_time: float) -> bool:
	for entry: Dictionary in events:
		if int(entry["kind"]) != int(EventKind.GRIND): continue
		var event_time: float = float(entry["time"])
		var event_end: float = event_time + float(entry["duration"])
		if chart_time >= event_time and chart_time <= event_end: return true
	return false

func _guide_core_color(chart_time: float) -> Color:
	return Color("e76b57") if _is_grind_at_time(chart_time) else Color("d5dedf")

func _time_to_sample_y(chart_time: float) -> float:
	return hit_y - (chart_time - elapsed) * scroll_speed

## Sampling the guide on a fixed 8px grid makes a Grind's start/end boundary
## snap between whichever sample happens to land nearest it, so the visible
## edge hops discretely (and unevenly) from frame to frame as the guide
## scrolls. Instead, every fixed sample is emitted as before, but the exact
## Grind start/end times are also inserted as extra vertices at their true
## position — as two coincident points carrying the color on each side, for
## a hard cut rather than a gradient — so the boundary itself moves smoothly
## and precisely with elapsed instead of jittering between samples.
func _build_guide_points_and_colors(points: PackedVector2Array, colors: PackedColorArray) -> void:
	var boundary_times: Array[float] = []
	for entry: Dictionary in events:
		if int(entry["kind"]) != int(EventKind.GRIND): continue
		boundary_times.append(float(entry["time"]))
		boundary_times.append(float(entry["time"]) + float(entry["duration"]))
	var sample_y: float = guide_top_y
	var has_previous_time: bool = false
	var previous_time: float = 0.0
	# The track material itself is fully generated up front — this fade only
	# softens the point where new track scrolls into the visible window at
	# the top edge, so it eases in instead of appearing with a hard pop-in.
	var fade_zone: float = 60.0
	while sample_y <= hit_y + 2.0:
		var chart_time: float = elapsed + (hit_y - sample_y) / scroll_speed
		if has_previous_time:
			var lo: float = minf(previous_time, chart_time)
			var hi: float = maxf(previous_time, chart_time)
			var crossings: Array[float] = []
			for boundary_time: float in boundary_times:
				if boundary_time > lo and boundary_time < hi: crossings.append(boundary_time)
			crossings.sort()
			if previous_time < chart_time: crossings.reverse()
			for boundary_time: float in crossings:
				var boundary_position: Vector2 = Vector2(guide_x_at(boundary_time), _time_to_sample_y(boundary_time))
				var boundary_fade: float = clampf((boundary_position.y - guide_top_y) / fade_zone, 0.0, 1.0)
				# Tiny time nudges on either side of the exact boundary decide
				# which color applies right before vs. right after the cut.
				points.append(boundary_position)
				colors.append(Color(_guide_core_color(boundary_time + (0.001 if previous_time > chart_time else -0.001)), boundary_fade))
				points.append(boundary_position)
				colors.append(Color(_guide_core_color(boundary_time + (-0.001 if previous_time > chart_time else 0.001)), boundary_fade))
		var fade: float = clampf((sample_y - guide_top_y) / fade_zone, 0.0, 1.0)
		points.append(Vector2(guide_x_at(chart_time), sample_y))
		colors.append(Color(_guide_core_color(chart_time), fade))
		previous_time = chart_time
		has_previous_time = true
		sample_y += 8.0

func _draw_balance_meter() -> void:
	# Version 2: a compact vertical balance meter at the right side of the
	# playfield. Center is green; distance above/below center fades to yellow
	# and then red at the ends.
	var meter_center: Vector2 = Vector2(830.0, 390.0)
	var meter_height: float = 456.0
	var meter_half_height: float = meter_height * 0.5
	var meter_width: float = 54.0
	var meter_top: float = meter_center.y - meter_half_height
	draw_rect(Rect2(meter_center.x - meter_width * 0.5 - 6.0, meter_top - 6.0, meter_width + 12.0, meter_height + 12.0), Color(0.12, 0.16, 0.17, 0.82), true)
	for segment_index: int in range(24):
		var segment_position: float = float(segment_index) / 23.0
		var distance_from_center: float = absf(segment_position - 0.5) * 2.0
		var zone_color: Color = Color("62ce7b").lerp(Color("f1d34f"), distance_from_center * 2.0) if distance_from_center < 0.5 else Color("f1d34f").lerp(Color("df5148"), (distance_from_center - 0.5) * 2.0)
		var segment_y: float = meter_top + segment_position * meter_height
		draw_rect(Rect2(meter_center.x - meter_width * 0.5, segment_y, meter_width, meter_height / 23.0 + 1.0), zone_color, true)
	var balance_y: float = meter_center.y - balance_position * meter_half_height
	var sword_x: float = meter_center.x + meter_width * 0.5 + 30.0
	draw_line(Vector2(meter_center.x - 15.0, meter_center.y), Vector2(meter_center.x + 15.0, meter_center.y), Color("e7f0b0"), 3.0, true)
	# The sword is the balance line: rotate the source 90 degrees clockwise
	# and place its tip against the right edge of the vertical gauge.
	draw_set_transform(Vector2(sword_x, balance_y), PI * 0.5, Vector2.ONE)
	draw_texture_rect(BALANCE_SWORD, Rect2(-59.5, -38.0, 119.0, 76.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var alert_x: float = meter_center.x + meter_width * 0.5 + 150.0
	# If the sword is outside the 90% balance band, show a large warning
	# doodle to the right of the meter, never on top of the sword itself.
	if balance_accuracy() < 0.90:
		var alert_y: float = meter_top + 58.0 if balance_position > 0.0 else meter_top + meter_height - 58.0
		draw_set_transform(Vector2(alert_x, alert_y), deg_to_rad(15.0), Vector2.ONE)
		var alert_shadow: Color = Color(0.08, 0.05, 0.05, 0.9)
		draw_line(Vector2(3.0, -31.0), Vector2(3.0, 12.0), alert_shadow, 16.0, true)
		draw_circle(Vector2(3.0, 30.0), 9.0, alert_shadow)
		draw_line(Vector2.ZERO, Vector2(-1.0, 11.0), Color("e34b45"), 12.5, true)
		draw_circle(Vector2(-1.0, 30.0), 7.5, Color("e34b45"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Positive cue at 85%+ balance. It is deliberately farther right than
	# the warning position so the two doodles can never overlap.
	if balance_accuracy() >= 0.85:
		var thumb_center: Vector2 = Vector2(alert_x + 72.0, meter_center.y)
		var thumb: PackedVector2Array = PackedVector2Array([Vector2(-10.0, 12.0), Vector2(-10.0, -7.0), Vector2(-3.0, -7.0), Vector2(0.0, -21.0), Vector2(7.0, -25.0), Vector2(11.0, -20.0), Vector2(10.0, -8.0), Vector2(20.0, -8.0), Vector2(24.0, -3.0), Vector2(22.0, 15.0), Vector2(15.0, 20.0), Vector2(-10.0, 20.0)])
		draw_set_transform(thumb_center + Vector2(3.0, 3.0), 0.0, Vector2.ONE)
		draw_colored_polygon(thumb, Color(0.08, 0.05, 0.05, 0.9))
		draw_set_transform(thumb_center, 0.0, Vector2.ONE)
		draw_colored_polygon(thumb, Color("70d98a"))
		draw_polyline(thumb, Color("d8f0a0"), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2(meter_center.x - 30.0, meter_top - 12.0), "W / S", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 14, Color("c3b56d"))


func _draw_rhythm_events() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for event_index: int in range(events.size()):
		var entry: Dictionary = events[event_index]
		if bool(entry["resolved"]): continue
		var event_time: float = float(entry["time"])
		if int(entry["kind"]) == int(EventKind.BEAT):
			var beat_y: float = _chart_y(event_time)
			if beat_y < guide_top_y - 30.0 or beat_y > hit_y + 35.0: continue
			var beat_position: Vector2 = Vector2(guide_x_at(event_time), beat_y)
			draw_circle(beat_position, 15.0 + pulse * 3.0, Color("f4d74f"))
			draw_circle(beat_position, 7.0, Color("fff5b0"))
		else:
			var duration: float = float(entry["duration"])
			var grind_points: PackedVector2Array = PackedVector2Array()
			var sample_time: float = event_time
			while sample_time <= event_time + duration:
				var grind_y: float = _chart_y(sample_time)
				if grind_y >= guide_top_y - 20.0 and grind_y <= hit_y + 30.0:
					grind_points.append(Vector2(guide_x_at(sample_time), grind_y))
				sample_time += 0.06
			if grind_points.size() > 1:
				var grind_color: Color = Color("f2a33f").lerp(Color("ffe66a"), pulse)
				draw_polyline(grind_points, grind_color, 16.0, true)
				draw_circle(grind_points[0], 14.0, Color("ffe66a"))

func _draw_pressure_point() -> void:
	var pressure_world_position: Vector2 = Vector2(pressure_x, hit_y)
	draw_circle(pressure_world_position, 23.0, Color("ef514c"), false, 5.0, true)
	draw_circle(pressure_world_position, 5.0, Color("ef514c"))

func _draw_sparks() -> void:
	for spark: Dictionary in active_sparks:
		var fade: float = clampf(float(spark["life_left"]) / float(spark["life_total"]), 0.0, 1.0)
		var spark_color: Color = Color(spark["color"])
		spark_color.a = fade
		var spark_position: Vector2 = spark["position"]
		var velocity: Vector2 = spark["velocity"]
		draw_line(spark_position, spark_position - velocity.normalized() * (5.0 + fade * 6.0), spark_color, float(spark["thickness"]))

func _draw_feedback() -> void:
	if feedback_time_left <= 0.0: return
	var fade: float = feedback_time_left / 0.28
	var color: Color = Color(1.0, 0.88, 0.3, fade) if feedback_success else Color(1.0, 0.25, 0.2, fade)
	for ray_index: int in range(8):
		var angle: float = float(ray_index) * TAU / 8.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(feedback_position + direction * 18.0, feedback_position + direction * 42.0, color, 3.0)

func _close() -> void:
	if music_player != null and music_player.is_inside_tree(): music_player.stop()
	closed.emit()

class_name GemJamGame extends Control

## Jewel Jam V4 — timed 2D lap-wheel extraction, faceting, and resonance polish.
## One canonical 256x256 ROCK/GEM/EMPTY mask is shared by X-ray, grinding, and
## resonance. The grind station transforms that same mask against a fixed wheel;
## only exposed material physically overlapping the wheel can erode. Exposed gem
## receives procedural facet light, while Resonance finishes with a clean vector
## trophy whose quality is derived from the player's real canonical result.
##
## Performance note: every per-frame operation below is deliberately bounded.
## The mask is 65536 cells, so anything that walks the WHOLE mask every frame
## (a naive contact scan, a full texture rebuild, a per-cell exposure raycast)
## reliably stalls the game once grinding starts mutating cells continuously.
## Contact scanning is limited to a small AABB near the wheel, textures are
## updated only for the handful of cells that actually changed, and the
## aggregate exposure ratio is computed with linear row/column sweeps instead
## of a raycast per gem cell.

signal closed()

enum Cell { EMPTY, ROCK, GEM }
enum Station { XRAY, GRIND, RESONANCE }

const MASK_SIZE: int = 256
const MASK_HALF: float = MASK_SIZE * 0.5
const ROCK_COLOR: Color = Color("725846")
const ROCK_HIGHLIGHT: Color = Color("a68162")
const DUST_ROCK_COLOR: Color = Color("c8a97e")
const TARGET_COLOR: Color = Color("ffd56a")
## Curated gemstone palette (base, glow) — a curated random pick per attempt
## reads far more consistently as "a gemstone" than fully procedural/noise
## color generation, while still varying the result every time.
const GEM_PALETTE: Array[Array] = [
	[Color("54e5e0"), Color("b5fff2")], # aquamarine
	[Color("e5546e"), Color("ffb5c9")], # ruby
	[Color("59c96b"), Color("baffc4")], # emerald
	[Color("6f8bf2"), Color("c3d0ff")], # sapphire
	[Color("b25de8"), Color("ecc4ff")], # amethyst
	[Color("f2b23c"), Color("ffe4a8")], # topaz
	[Color("ffffffce"), Color("fff9ecff")], # Diamond
	[Color("141414ee"), Color("000000b5")], # Nightstone
]
const GEM_NAMES: Array[String] = ["AQUAMARINE", "RUBY", "EMERALD", "SAPPHIRE", "AMETHYST", "TOPAZ", "DIAMOND", "Nightstone"]
const GEM_JAM_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/Gem Jammer/Moonlight Gemforge.mp3"),
	preload("res://assets/audio/Gem Jammer/Moonlit Gemforge.mp3"),
	preload("res://assets/audio/Gem Jammer/Moonlit Gemforge (1).mp3"),
	preload("res://assets/audio/Gem Jammer/Moonlit Gemforge (2).mp3"),
	preload("res://assets/audio/Gem Jammer/Moonlit Gemforge (3).mp3"),
]
const XRAY_STATION_RECT: Rect2 = Rect2(60.0, 175.0, 350.0, 420.0)
const GRIND_STATION_RECT: Rect2 = Rect2(465.0, 175.0, 350.0, 420.0)
const RESONANCE_STATION_RECT: Rect2 = Rect2(870.0, 175.0, 350.0, 420.0)
const GRIND_WHEEL_CENTER: Vector2 = Vector2(640.0, 518.0)
const GRIND_WHEEL_RADIUS: float = 66.0
## Only this top fraction of the wheel's height pokes out of its housing — a
## small rounded grinding surface rather than a full spinning wheel — while the
## underlying circle math is kept so the player can still approach it from the
## side, not just straight down.
const GRIND_WHEEL_CAP_FRACTION: float = 0.25
const GRIND_REST_POSITION: Vector2 = Vector2(640.0, 298.0)
const CARDINAL_NEIGHBORS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const TARGET_SHAPES: Array[String] = ["OVAL", "CIRCLE", "DIAMOND", "EMERALD", "TEARDROP", "HEXAGON"]

@export_category("Generation")
## Negative uses a new random seed each attempt; non-negative is deterministic.
@export var generation_seed: int = -1
@export_range(0.15, 0.8, 0.05) var target_reveal_exposure: float = 0.35

@export_category("Audio")
## Linear dedicated-minigame music volume; converted to decibels internally.
@export_range(0.0, 1.0, 0.05) var music_volume: float = 0.70
@export_range(0.1, 2.0, 0.05) var resonance_music_fade_seconds: float = 0.45

@export_category("Challenge Timer")
@export_range(30.0, 180.0, 5.0) var run_time_limit_seconds: float =120.0
## Resonance is no longer a fixed countdown window scored on its average. It's
## a meter: it fills only while you're at least (1 - resonance_tolerance)
## aligned, holds steady (no decay) otherwise, and completing the whole
## refinement requires accumulating this many total "good" seconds. The
## overall run_time_limit_seconds clock keeps running the whole time, so a
## slow polish still costs you real time and can still time the run out.
@export_range(1.0, 15.0, 0.5) var resonance_hold_target_seconds: float = 5.0

@export_category("Grinding")
@export var object_rotation_speed_degrees: float = 105.0
## Boundary pixels per second at shallow contact and wheel_speed 1.0.
## Penetration depth and wheel_speed both further scale this up.
@export_range(1.0, 40.0, 0.5) var rock_grind_rate: float = 30.0
@export_range(0.5, 15.0, 0.25) var gem_grind_rate: float = 5.5
@export_range(1.0, 5.0, 0.1) var deep_contact_multiplier: float = 3.2
## Resonance is the polishing/final-cut phase. Requiring both substantial
## exposure and silhouette shaping prevents it from bypassing the lap wheel.
@export_range(0.0, 1.0, 0.05) var resonance_exposure_required: float = 0.6
@export_range(0.0, 1.0, 0.05) var resonance_match_required: float = 0.75
## W/S wheel-speed control: how fast the bar fills per second, and its range.
@export_range(0.2, 3.0, 0.05) var wheel_speed_change_rate: float = 0.9
@export_range(0.05, 1.0, 0.05) var wheel_speed_min: float = 0.2
@export_range(1.0, 4.0, 0.1) var wheel_speed_max: float = 2.5
@export var wheel_speed_default: float = 1.0

@export_category("Gem Stress & Precision")
## Stress is deterministic: fast/deep GEM contact raises it; releasing or
## touching only rock cools it. High stress accelerates GEM erosion, especially
## inside the intended target, so every chip follows from a readable choice.
@export_range(0.05, 1.0, 0.05) var gem_stress_warning_threshold: float = 0.55
@export_range(0.2, 1.0, 0.05) var gem_stress_critical_threshold: float = 0.82
@export_range(0.05, 1.0, 0.05) var gem_stress_gain_per_second: float = 0.10
@export_range(0.05, 1.0, 0.05) var gem_stress_cool_per_second: float = 0.30
@export_range(1.0, 4.0, 0.1) var max_stressed_gem_rate_multiplier: float = 2.4
@export_range(50.0, 1000.0, 50.0) var precision_points_per_multiplier_step: float = 400.0
@export_range(0.1, 2.0, 0.1) var precision_chain_decay_delay: float = 0.5
@export_range(1.0, 100.0, 1.0) var precision_chain_decay_per_second: float = 25.0

@export_category("Dust & Shine")
## New dust particles per second at 1 contacting cell and wheel_speed 1.0.
@export_range(1.0, 40.0, 1.0) var dust_rate_per_contact_cell: float = 6.0
@export var dust_max_particles: int = 140
@export var shine_burst_particles_per_reveal: int = 3
@export var shine_burst_max_per_frame: int = 8

@export_category("Resonance")
@export_range(0.01, 0.5, 0.01) var resonance_frequency_step: float = 0.04
@export_range(0.01, 0.5, 0.01) var resonance_amplitude_step: float = 0.04
@export_range(0.01, 0.5, 0.01) var resonance_tolerance: float = 0.10
@export_range(0.0, 0.2, 0.005) var resonance_gentle_frequency_motion: float = 0.04
@export_range(0.0, 0.2, 0.005) var resonance_gentle_amplitude_motion: float = 0.03
@export_range(0.0, 0.4, 0.01) var resonance_erratic_frequency_motion: float = 0.25
@export_range(0.0, 0.4, 0.01) var resonance_erratic_amplitude_motion: float = 0.24
@export_range(0.2, 0.8, 0.05) var resonance_full_exposure_motion_floor: float = 0.45

@export_category("Final Reveal")
@export_range(0.5, 4.0, 0.1) var final_reveal_duration: float = 2.2
@export_range(60.0, 180.0, 5.0) var final_gem_radius: float = 118.0
@export_range(0.0, 1.0, 0.05) var facet_strength: float = 0.82

var material_mask: Array[int] = []
var original_gem_mask: PackedByteArray = PackedByteArray()
var target_mask: PackedByteArray = PackedByteArray()
var grind_progress: Array[float] = []
var total_rock: int = 0
var total_gem_cells: int = 0
var removed_rock: int = 0
var removed_gem: int = 0
var target_shape_name: String = ""
var target_center: Vector2 = Vector2(MASK_HALF, MASK_HALF)
var target_half_size: Vector2 = Vector2(32.0, 38.0)
var rough_gem_center: Vector2 = Vector2(MASK_HALF, MASK_HALF)
## O(1) running counters for target_match_ratio(), kept in sync incrementally
## by _remove_material_index() instead of rescanning the whole mask.
var target_intersection_cache: int = 0
var target_union_cache: int = 0

var station: Station = Station.GRIND
var rock_station: Station = Station.GRIND
var rock_position: Vector2 = GRIND_REST_POSITION
var object_rotation: float = 0.0
var dragging_rock: bool = false
var pending_rock_drag: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var drag_origin_position: Vector2 = Vector2.ZERO
var drag_origin_station: Station = Station.GRIND
var grinding_active: bool = false
var grind_contact_cells: int = 0
var wheel_rotation: float = 0.0
var wheel_speed: float = 1.0
var gem_stress: float = 0.0
var gem_contact_intensity: float = 0.0
var target_contact_cells: int = 0
var target_damage_flash: float = 0.0
var danger_flash: float = 0.0
var target_chip_count: int = 0
var feedback_time: float = 0.0
var precision_chain_points: float = 0.0
var best_precision_chain: float = 0.0
var precision_score: float = 0.0
var precision_chain_idle_time: float = 0.0
var precision_activity_this_frame: bool = false
var last_contact_mask_position: Vector2 = Vector2(MASK_HALF, MASK_HALF)
## Per-attempt randomized gemstone color (see GEM_PALETTE), applied
## consistently everywhere the canonical gem is drawn: X-ray, grind reveal,
## resonance, dust, and shine.
var gem_color: Color = Color("54e5e0")
var gem_glow_color: Color = Color("b5fff2")
var gem_name: String = "AQUAMARINE"
var music_shuffle_bag: Array[int] = []
var current_music_index: int = -1
var music_normal_volume_db: float = 0.0
var music_target_volume_db: float = 0.0
var music_fade_tween: Tween = null
var resonance_music_mix_active: bool = false
var dust_particles: Array[Dictionary] = []
var shine_bursts: Array[Dictionary] = []
var shine_intensity: float = 0.0
var previous_exposed_gem_cells: int = 0

## Persistent CPU-side images backing the live textures. Only the small set of
## pixels that actually changed this frame are repainted into these (see
## dirty_pixels), then the GPU textures are updated once via ImageTexture.update
## rather than being recreated from a full pixel scan every frame.
var grind_pixels: Image
var xray_pixels: Image
var gem_pixels: Image
var target_pixels: Image
var grind_texture: ImageTexture
var xray_texture: ImageTexture
var gem_texture: ImageTexture
var target_texture: ImageTexture
var textures_dirty: bool = true
var dirty_pixels: Dictionary = {}
var exposure_dirty: bool = true
var exposed_mask_cache: PackedByteArray = PackedByteArray()
var exposed_gem_cells_cache: int = 0
var remaining_gem_cells_cache: int = 0

var completed: bool = false
var timed_out: bool = false
var run_elapsed: float = 0.0
var run_time_remaining: float = 90.0
var resonance_challenge_active: bool = false
## Accumulated "good" (>= 1-resonance_tolerance aligned) seconds this attempt.
## Only ever increases while aligned and holds steady otherwise — never
## decays — until it reaches resonance_hold_target_seconds, which completes
## the whole refinement.
var resonance_good_time: float = 0.0
var final_reveal_progress: float = 0.0
var final_quality_score: float = 0.0
var final_shape_score: float = 0.0
var final_preservation_score: float = 0.0
var final_exposure_score: float = 0.0
var final_cut_score: float = 0.0
var final_time_score: float = 0.0
var final_score: int = 0
var resonance_completion_accuracy: float = 0.0
var final_rank_name: String = ""
var final_limiting_stage: String = ""
var final_gem_name: String = ""
var final_glint_phase: float = 0.0
var resonance_time: float = 0.0
var resonance_frequency: float = 0.50
var resonance_amplitude: float = 0.50
var target_base_frequency: float = 0.60
var target_base_amplitude: float = 0.66
var target_frequency: float = 0.60
var target_amplitude: float = 0.66

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var gem_jam_audio: GemJamAudio = $GemJamAudio
@onready var station_label: Label = $HUD/StationLabel
@onready var view_label: Label = $HUD/ViewLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var metrics_label: Label = $HUD/MetricsLabel
@onready var progress_bar: ProgressBar = $HUD/ResonanceProgress
@onready var frequency_label: Label = $ResonancePanel/FrequencyLabel
@onready var amplitude_label: Label = $ResonancePanel/AmplitudeLabel
@onready var resonance_panel: Control = $ResonancePanel
@onready var grind_hint: Label = $HUD/GrindHint

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_normal_volume_db = linear_to_db(maxf(0.0001, music_volume))
	music_target_volume_db = music_normal_volume_db
	music_player.bus = &"Music"
	music_player.volume_db = music_normal_volume_db
	music_player.finished.connect(_on_music_finished)
	_play_next_music_track()
	_build_material_mask()
	$StationBar/XRayButton.pressed.connect(_select_xray)
	$StationBar/GrindButton.pressed.connect(_select_grind)
	$StationBar/ResonanceButton.pressed.connect(_select_resonance)
	$ResonancePanel/FrequencyDown.pressed.connect(_frequency_down)
	$ResonancePanel/FrequencyUp.pressed.connect(_frequency_up)
	$ResonancePanel/AmplitudeDown.pressed.connect(_amplitude_down)
	$ResonancePanel/AmplitudeUp.pressed.connect(_amplitude_up)
	$CloseButton.pressed.connect(_close)
	_open_on_xray_station()
	_update_ui()
	queue_redraw()

## Open on X-ray rather than Grind: with the gem now placed off-center,
## actually looking before committing is the point, not a formality.
## Extracted out of _ready() so test setup (whose synchronous harness defers
## the engine's automatic _ready() invocation by a frame) can deterministically
## reproduce a fresh attempt's starting state without waiting on that timing.
func _open_on_xray_station() -> void:
	_move_rock_to_station(Station.XRAY)
	status_label.text = "X-RAY: find the gem — it's not centered. Then drag down into the lap wheel."

func _play_next_music_track() -> void:
	if music_player == null or GEM_JAM_TRACKS.is_empty():
		return
	music_player.stream = _next_music_track()
	_set_music_stream_loop(music_player.stream, false)
	if not is_inside_tree() or not music_player.is_inside_tree():
		return
	music_player.stop()
	music_player.play()

func _next_music_track() -> AudioStream:
	if music_shuffle_bag.is_empty():
		_refill_music_shuffle_bag()
	current_music_index = music_shuffle_bag.pop_front()
	return GEM_JAM_TRACKS[current_music_index]

func _refill_music_shuffle_bag() -> void:
	music_shuffle_bag.clear()
	for track_index: int in range(GEM_JAM_TRACKS.size()):
		music_shuffle_bag.append(track_index)
	music_shuffle_bag.shuffle()
	# The final song of the previous cycle must not immediately repeat as the
	# first song of the new cycle.
	if music_shuffle_bag.size() > 1 and music_shuffle_bag[0] == current_music_index:
		var swap_index: int = randi_range(1, music_shuffle_bag.size() - 1)
		var held_index: int = music_shuffle_bag[0]
		music_shuffle_bag[0] = music_shuffle_bag[swap_index]
		music_shuffle_bag[swap_index] = held_index

func _on_music_finished() -> void:
	_play_next_music_track()

func _set_music_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled

func _set_resonance_music_mix(enabled: bool) -> void:
	if resonance_music_mix_active == enabled:
		return
	resonance_music_mix_active = enabled
	music_target_volume_db = GemJamAudio.SILENT_VOLUME_DB if enabled else music_normal_volume_db
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	if music_player != null and is_inside_tree():
		music_fade_tween = create_tween()
		music_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		music_fade_tween.tween_property(music_player, "volume_db", music_target_volume_db, resonance_music_fade_seconds).set_trans(Tween.TRANS_SINE)
	elif music_player != null:
		music_player.volume_db = music_target_volume_db
	if gem_jam_audio != null:
		if enabled:
			gem_jam_audio.set_resonance_cue_accuracy(_alignment_score())
			gem_jam_audio.start_resonance_cue()
		else:
			gem_jam_audio.stop_resonance_cue()

## Random outer rock -> random rough gem -> target generated strictly inside it.
func _build_material_mask() -> void:
	material_mask.resize(MASK_SIZE * MASK_SIZE)
	material_mask.fill(Cell.EMPTY)
	original_gem_mask.resize(MASK_SIZE * MASK_SIZE)
	original_gem_mask.fill(0)
	target_mask.resize(MASK_SIZE * MASK_SIZE)
	target_mask.fill(0)
	grind_progress.resize(MASK_SIZE * MASK_SIZE)
	grind_progress.fill(0.0)
	total_rock = 0
	total_gem_cells = 0
	removed_rock = 0
	removed_gem = 0
	wheel_speed = wheel_speed_default
	dust_particles.clear()
	shine_bursts.clear()
	shine_intensity = 0.0
	previous_exposed_gem_cells = 0
	completed = false
	timed_out = false
	run_elapsed = 0.0
	run_time_remaining = run_time_limit_seconds
	resonance_challenge_active = false
	resonance_good_time = 0.0
	gem_stress = 0.0
	gem_contact_intensity = 0.0
	target_contact_cells = 0
	target_damage_flash = 0.0
	danger_flash = 0.0
	target_chip_count = 0
	feedback_time = 0.0
	precision_chain_points = 0.0
	best_precision_chain = 0.0
	precision_score = 0.0
	precision_chain_idle_time = 0.0
	precision_activity_this_frame = false
	final_reveal_progress = 0.0
	final_quality_score = 0.0
	final_shape_score = 0.0
	final_preservation_score = 0.0
	final_exposure_score = 0.0
	final_cut_score = 0.0
	final_time_score = 0.0
	final_score = 0
	resonance_completion_accuracy = 0.0
	final_rank_name = ""
	final_limiting_stage = ""
	final_gem_name = ""
	final_glint_phase = 0.0
	exposed_mask_cache = PackedByteArray()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	if generation_seed >= 0:
		random.seed = generation_seed
	else:
		random.randomize()
	var palette_index: int = random.randi_range(0, GEM_PALETTE.size() - 1)
	var palette_entry: Array = GEM_PALETTE[palette_index]
	gem_color = palette_entry[0]
	gem_glow_color = palette_entry[1]
	gem_name = GEM_NAMES[palette_index]
	var rock_center: Vector2 = Vector2(128.0 + random.randf_range(-5.0, 5.0), 129.0 + random.randf_range(-4.0, 4.0))
	var rock_rx: float = random.randf_range(102.0, 112.0)
	var rock_ry: float = random.randf_range(96.0, 108.0)
	var rock_phase_a: float = random.randf_range(0.0, TAU)
	var rock_phase_b: float = random.randf_range(0.0, TAU)
	for y: int in range(MASK_SIZE):
		for x: int in range(MASK_SIZE):
			var offset: Vector2 = Vector2(x, y) - rock_center
			var angle: float = atan2(offset.y, offset.x)
			var rough_limit: float = 1.0 + 0.065 * sin(angle * 5.0 + rock_phase_a) + 0.038 * sin(angle * 9.0 + rock_phase_b)
			var normalized: float = sqrt(pow(offset.x / rock_rx, 2.0) + pow(offset.y / rock_ry, 2.0))
			if normalized <= rough_limit:
				_set_mask_cell_raw(x, y, Cell.ROCK)
				total_rock += 1
	var gem_rx: float = random.randf_range(43.0, 54.0)
	var gem_ry: float = random.randf_range(45.0, 59.0)
	## Deliberately off-center, not a small jitter: this is what makes X-ray
	## worth reading. "Grind the middle" is no longer a reliable default —
	## the player has to actually look at where the gem sits and commit to an
	## approach, with real risk of chewing into it from an unplanned side if
	## they don't. The offset is still bounded so the gem's own roughness
	## never pokes outside the rock's safe inner radius (0.80 rock / 1.15 gem
	## margins), so it's always fully enclosed, just not centered.
	var max_offset_x: float = maxf(8.0, rock_rx * 0.80 - gem_rx * 1.15)
	var max_offset_y: float = maxf(8.0, rock_ry * 0.80 - gem_ry * 1.15)
	var offset_angle: float = random.randf_range(0.0, TAU)
	var offset_fraction: float = random.randf_range(0.55, 1.0)
	rough_gem_center = rock_center + Vector2(cos(offset_angle) * max_offset_x, sin(offset_angle) * max_offset_y) * offset_fraction
	var gem_phase_a: float = random.randf_range(0.0, TAU)
	var gem_phase_b: float = random.randf_range(0.0, TAU)
	for y: int in range(MASK_SIZE):
		for x: int in range(MASK_SIZE):
			var offset: Vector2 = Vector2(x, y) - rough_gem_center
			var angle: float = atan2(offset.y, offset.x)
			var rough_limit: float = 1.0 + 0.10 * sin(angle * 5.0 + gem_phase_a) + 0.055 * sin(angle * 8.0 + gem_phase_b)
			var normalized: float = sqrt(pow(offset.x / gem_rx, 2.0) + pow(offset.y / gem_ry, 2.0))
			if normalized <= rough_limit and _mask_cell(x, y) == Cell.ROCK:
				_set_mask_cell_raw(x, y, Cell.GEM)
				original_gem_mask[_mask_index(x, y)] = 1
				total_rock -= 1
				total_gem_cells += 1
	_generate_achievable_target(random, gem_rx, gem_ry)
	_rebuild_all_textures_full()
	_recompute_target_cache()
	exposure_dirty = true

func _generate_achievable_target(random: RandomNumberGenerator, rough_rx: float, rough_ry: float) -> void:
	target_shape_name = TARGET_SHAPES[random.randi_range(0, TARGET_SHAPES.size() - 1)]
	var half_size: Vector2 = Vector2(rough_rx * random.randf_range(0.58, 0.72), rough_ry * random.randf_range(0.58, 0.72))
	if target_shape_name == "CIRCLE":
		var radius: float = minf(half_size.x, half_size.y)
		half_size = Vector2(radius, radius)
	target_center = rough_gem_center + Vector2(random.randf_range(-2.5, 2.5), random.randf_range(-2.5, 2.5))
	target_half_size = half_size
	for attempt: int in range(24):
		target_mask.fill(0)
		var fits: bool = true
		var cell_count: int = 0
		var bounds: Rect2i = _local_shape_bounds(target_center, half_size)
		for y: int in range(bounds.position.y, bounds.position.y + bounds.size.y):
			for x: int in range(bounds.position.x, bounds.position.x + bounds.size.x):
				var local: Vector2 = Vector2(x, y) - target_center
				if _target_shape_contains(target_shape_name, local, half_size):
					var index: int = _mask_index(x, y)
					target_mask[index] = 1
					cell_count += 1
					if original_gem_mask[index] == 0:
						fits = false
		if fits and cell_count > 80:
			target_half_size = half_size
			return
		half_size *= 0.93
	# The centered tiny fallback is guaranteed by shrinking inside the gem core.
	target_mask.fill(0)
	target_center = rough_gem_center
	half_size = Vector2(14.0, 14.0)
	target_half_size = half_size
	var fallback_bounds: Rect2i = _local_shape_bounds(rough_gem_center, half_size)
	for y: int in range(fallback_bounds.position.y, fallback_bounds.position.y + fallback_bounds.size.y):
		for x: int in range(fallback_bounds.position.x, fallback_bounds.position.x + fallback_bounds.size.x):
			var index: int = _mask_index(x, y)
			if original_gem_mask[index] != 0 and _target_shape_contains("CIRCLE", Vector2(x, y) - rough_gem_center, half_size):
				target_mask[index] = 1
	target_shape_name = "CIRCLE"

## A shape only ever occupies a small region near its center, so bounding
## every fit-check/paint to that region (instead of the full 65536-cell mask)
## is what keeps generation fast even across up to 24 shrink attempts.
func _local_shape_bounds(center: Vector2, half_size: Vector2) -> Rect2i:
	var margin: float = 3.0
	var min_x: int = clampi(floori(center.x - half_size.x - margin), 0, MASK_SIZE - 1)
	var min_y: int = clampi(floori(center.y - half_size.y - margin), 0, MASK_SIZE - 1)
	var max_x: int = clampi(ceili(center.x + half_size.x + margin), 0, MASK_SIZE - 1)
	var max_y: int = clampi(ceili(center.y + half_size.y + margin), 0, MASK_SIZE - 1)
	return Rect2i(min_x, min_y, maxi(1, max_x - min_x + 1), maxi(1, max_y - min_y + 1))

func _target_shape_contains(shape_name: String, local: Vector2, half_size: Vector2) -> bool:
	var width: float = maxf(1.0, half_size.x)
	var height: float = maxf(1.0, half_size.y)
	var nx: float = local.x / width
	var ny: float = local.y / height
	match shape_name:
		"OVAL", "CIRCLE":
			return nx * nx + ny * ny <= 1.0
		"DIAMOND":
			return absf(nx) + absf(ny) <= 1.0
		"EMERALD":
			return absf(nx) <= 1.0 and absf(ny) <= 1.0 and absf(nx) + absf(ny) <= 1.72
		"TEARDROP":
			var teardrop: PackedVector2Array = PackedVector2Array([Vector2(0.0, -height), Vector2(width * 0.82, -height * 0.10), Vector2(width * 0.62, height * 0.72), Vector2(0.0, height), Vector2(-width * 0.62, height * 0.72), Vector2(-width * 0.82, -height * 0.10)])
			return Geometry2D.is_point_in_polygon(local, teardrop)
		"HEXAGON":
			return absf(ny) <= 1.0 and absf(nx) <= 1.0 and absf(nx) + absf(ny) * 0.52 <= 1.15
	return false

func _process(delta: float) -> void:
	wheel_rotation += delta * 5.0 * wheel_speed
	feedback_time += delta
	precision_activity_this_frame = false
	if not completed:
		_update_run_timer(delta)
	if not completed and not resonance_challenge_active and station == Station.GRIND:
		if Input.is_physical_key_pressed(KEY_A):
			object_rotation -= deg_to_rad(object_rotation_speed_degrees) * delta
		if Input.is_physical_key_pressed(KEY_D):
			object_rotation += deg_to_rad(object_rotation_speed_degrees) * delta
		if Input.is_physical_key_pressed(KEY_W):
			wheel_speed = clampf(wheel_speed + wheel_speed_change_rate * delta, wheel_speed_min, wheel_speed_max)
		if Input.is_physical_key_pressed(KEY_S):
			wheel_speed = clampf(wheel_speed - wheel_speed_change_rate * delta, wheel_speed_min, wheel_speed_max)
		var exposed_before: int = exposed_gem_cells_cache
		_update_grinding(delta)
		_check_for_new_shine(exposed_before)
	else:
		grinding_active = false
		grind_contact_cells = 0
		target_contact_cells = 0
		gem_contact_intensity = 0.0
		_update_gem_stress(delta, 0, 0, 0.0)
	_update_precision_chain(delta)
	_update_feedback(delta)
	_update_dust_particles(delta)
	_update_shine_bursts(delta)
	if completed:
		final_reveal_progress = minf(1.0, final_reveal_progress + delta / maxf(0.01, final_reveal_duration))
		final_glint_phase += delta * 1.6
	elif resonance_challenge_active:
		_update_resonance(delta)
	_update_audio_state(delta)
	_update_ui()
	queue_redraw()

func _update_audio_state(delta: float) -> void:
	if gem_jam_audio == null:
		return
	var normalized_speed: float = (wheel_speed - wheel_speed_min) / maxf(0.001, wheel_speed_max - wheel_speed_min)
	var alignment: float = _alignment_score() if resonance_challenge_active else 0.0
	gem_jam_audio.update_state(delta, grinding_active and station == Station.GRIND, normalized_speed, gem_contact_intensity, resonance_challenge_active, alignment)

## The run's single clock keeps running through both cutting AND Resonance —
## there is no reserved end-of-run slice anymore. Entering Resonance is
## entirely the player's own choice once qualified (via the button or
## dragging onto the pad); nothing forces it. If the clock reaches zero while
## already polishing, the run still ends gracefully with whatever partial
## sync progress was made (see _finish_resonance_challenge) rather than being
## discarded as unfinished — polishing was legitimately underway.
func _update_run_timer(delta: float) -> void:
	run_elapsed = minf(run_time_limit_seconds, run_elapsed + delta)
	run_time_remaining = maxf(0.0, run_time_limit_seconds - run_elapsed)
	if resonance_challenge_active:
		if run_time_remaining <= 0.0:
			_finish_resonance_challenge()
		return
	if run_time_remaining <= 0.0:
		timed_out = true
		resonance_completion_accuracy = 0.0
		_complete_refinement(true)

func _update_feedback(delta: float) -> void:
	target_damage_flash = maxf(0.0, target_damage_flash - delta * 2.8)
	danger_flash = maxf(0.0, danger_flash - delta * 2.2)

func _update_precision_chain(delta: float) -> void:
	if precision_activity_this_frame:
		precision_chain_idle_time = 0.0
		return
	precision_chain_idle_time += delta
	if precision_chain_idle_time > precision_chain_decay_delay:
		precision_chain_points = maxf(0.0, precision_chain_points - precision_chain_decay_per_second * delta)

## Comparing the exposure cache before/after a grind step tells us how many
## gem cells were just newly revealed, without needing to diff all 65536
## cells — gem_exposure_ratio()'s dirty-flag recompute already refreshed the
## cache as a side effect of _update_grinding() marking exposure_dirty.
func _check_for_new_shine(exposed_before: int) -> void:
	gem_exposure_ratio() # ensures exposed_gem_cells_cache reflects this frame
	var newly_exposed: int = exposed_gem_cells_cache - exposed_before
	if newly_exposed <= 0:
		return
	shine_intensity = clampf(shine_intensity + 0.35 * clampf(float(newly_exposed) / 4.0, 0.2, 1.0), 0.0, 1.0)
	var burst_count: int = clampi(newly_exposed * shine_burst_particles_per_reveal, 1, shine_burst_max_per_frame)
	var burst_origin: Vector2 = _mask_to_screen(last_contact_mask_position)
	for i: int in range(burst_count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(30.0, 90.0)
		shine_bursts.append({
			"position": burst_origin,
			"velocity": Vector2.from_angle(angle) * speed,
			"life": 0.6,
			"max_life": 0.6,
			"size": randf_range(3.0, 6.0),
		})

## Jewel Jam deliberately uses one canonical presentation. The old SIDE mode
## merely squashed the same 2D mask and implied depth it did not simulate.
func _view_scale() -> Vector2:
	return Vector2.ONE

func _gui_input(event: InputEvent) -> void:
	if completed or resonance_challenge_active:
		return
	if event is InputEventMouseMotion:
		if pending_rock_drag and not dragging_rock and drag_start_position.distance_to(event.position) > 8.0:
			dragging_rock = true
		if dragging_rock:
			rock_position = event.position
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _rock_display_rect().grow(8.0).has_point(event.position):
				pending_rock_drag = true
				drag_start_position = event.position
				drag_origin_position = rock_position
				drag_origin_station = rock_station
			else:
				pending_rock_drag = false
		else:
			if dragging_rock:
				dragging_rock = false
				pending_rock_drag = false
				_place_rock_in_station()
			else:
				pending_rock_drag = false

## Continuous erosion of exposed boundary cells overlapping the fixed wheel.
## Bounded to a small mask-space AABB near the wheel — never walks all 65536
## cells — so cost stays tiny regardless of how far away the rock currently is.
func _update_grinding(delta: float) -> int:
	var bounds: Rect2i = _wheel_contact_mask_bounds()
	grind_contact_cells = 0
	target_contact_cells = 0
	var removed: int = 0
	var rock_contact_cells: int = 0
	var gem_contact_cells: int = 0
	var gem_penetration_total: float = 0.0
	var contact_centroid: Vector2 = Vector2.ZERO
	for y: int in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x: int in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cell: Cell = _mask_cell(x, y)
			if not _is_material(cell) or not _is_material_boundary(x, y):
				continue
			var screen_point: Vector2 = _mask_to_screen(Vector2(x, y))
			var penetration: float = _wheel_penetration(screen_point)
			if penetration <= 0.0:
				continue
			grind_contact_cells += 1
			contact_centroid += Vector2(x, y)
			var index: int = _mask_index(x, y)
			if cell == Cell.ROCK:
				rock_contact_cells += 1
			else:
				gem_contact_cells += 1
				gem_penetration_total += penetration
				if target_mask[index] != 0:
					target_contact_cells += 1
					danger_flash = maxf(danger_flash, penetration * maxf(0.35, gem_stress))
			var rate: float = rock_grind_rate if cell == Cell.ROCK else gem_grind_rate * _stressed_gem_rate_multiplier(index)
			var speed_scale: float = (0.20 + penetration * deep_contact_multiplier) * wheel_speed
			grind_progress[index] += delta * rate * speed_scale
			if grind_progress[index] >= 1.0 and _remove_material_index(index):
				removed += 1
	grinding_active = grind_contact_cells > 0
	var average_gem_penetration: float = gem_penetration_total / maxf(1.0, float(gem_contact_cells))
	_update_gem_stress(delta, gem_contact_cells, grind_contact_cells, average_gem_penetration)
	if grinding_active:
		last_contact_mask_position = contact_centroid / float(grind_contact_cells)
		_spawn_dust(delta, gem_contact_cells > rock_contact_cells)
	return removed

func _update_gem_stress(delta: float, gem_contacts: int, total_contacts: int, average_penetration: float) -> void:
	if gem_contacts <= 0 or total_contacts <= 0:
		gem_contact_intensity = 0.0
		gem_stress = maxf(0.0, gem_stress - gem_stress_cool_per_second * delta)
		return
	var gem_contact_ratio: float = float(gem_contacts) / float(total_contacts)
	gem_contact_intensity = clampf(gem_contact_ratio * (0.35 + average_penetration * 0.65), 0.0, 1.0)
	var pressure_factor: float = 0.35 + average_penetration * 1.65
	var gain: float = gem_stress_gain_per_second * wheel_speed * pressure_factor * gem_contact_ratio
	gem_stress = clampf(gem_stress + gain * delta, 0.0, 1.0)

func _stressed_gem_rate_multiplier(index: int) -> float:
	if gem_stress <= gem_stress_warning_threshold:
		return 1.0
	var stress_range: float = maxf(0.01, 1.0 - gem_stress_warning_threshold)
	var stressed_fraction: float = clampf((gem_stress - gem_stress_warning_threshold) / stress_range, 0.0, 1.0)
	var multiplier: float = lerpf(1.0, max_stressed_gem_rate_multiplier, stressed_fraction)
	if target_mask[index] != 0 and gem_stress >= gem_stress_critical_threshold:
		var critical_range: float = maxf(0.01, 1.0 - gem_stress_critical_threshold)
		var critical_fraction: float = clampf((gem_stress - gem_stress_critical_threshold) / critical_range, 0.0, 1.0)
		multiplier *= 1.0 + critical_fraction * 0.60
	return multiplier

func _last_contact_mask_position() -> Vector2:
	return last_contact_mask_position

## Dust volume scales with how much is actively being ground away (contact
## cells) and the player's chosen wheel speed — fast+deep grinding kicks up
## visibly more dust than a light, careful touch.
func _spawn_dust(delta: float, mostly_gem: bool) -> void:
	if dust_particles.size() >= dust_max_particles:
		return
	var rate: float = float(grind_contact_cells) * dust_rate_per_contact_cell * wheel_speed
	var count: int = floori(rate * delta)
	# Carry the fractional remainder as a probability so slow grinding still
	# produces occasional dust instead of none at all.
	if randf() < fmod(rate * delta, 1.0):
		count += 1
	var color: Color = gem_color if mostly_gem else DUST_ROCK_COLOR
	# Spawned in absolute SCREEN space (not mask space): once airborne, dust
	# flies in a straight, gravity-affected path rather than getting dragged
	# around if the object keeps rotating underneath it.
	var spawn_point: Vector2 = _mask_to_screen(last_contact_mask_position)
	for i: int in range(mini(count, dust_max_particles - dust_particles.size())):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(20.0, 70.0) * (0.6 + wheel_speed * 0.4)
		dust_particles.append({
			"position": spawn_point,
			"velocity": Vector2.from_angle(angle) * speed - Vector2(0.0, 30.0),
			"life": randf_range(0.35, 0.65),
			"max_life": 0.65,
			"size": randf_range(1.5, 3.5),
			"color": color,
		})

func _update_dust_particles(delta: float) -> void:
	for particle: Dictionary in dust_particles:
		var velocity: Vector2 = particle["velocity"]
		particle["position"] = (particle["position"] as Vector2) + velocity * delta
		particle["velocity"] = velocity + Vector2(0.0, 90.0) * delta
		particle["life"] = float(particle["life"]) - delta
	for i: int in range(dust_particles.size() - 1, -1, -1):
		if float(dust_particles[i]["life"]) <= 0.0:
			dust_particles.remove_at(i)

func _update_shine_bursts(delta: float) -> void:
	shine_intensity = maxf(0.0, shine_intensity - delta * 1.4)
	for particle: Dictionary in shine_bursts:
		var velocity: Vector2 = particle["velocity"]
		particle["position"] = (particle["position"] as Vector2) + velocity * delta
		particle["velocity"] = velocity * 0.94
		particle["life"] = float(particle["life"]) - delta
	for i: int in range(shine_bursts.size() - 1, -1, -1):
		if float(shine_bursts[i]["life"]) <= 0.0:
			shine_bursts.remove_at(i)

## Only the wheel's fixed screen bounding box, inverse-transformed through the
## object's CURRENT position/rotation/scale, can possibly be in contact right
## now. Affine maps send a box's corners to the image box's corners, so taking
## the AABB of the 4 transformed corners is an exact, cheap, rotation-safe
## bound — independent of where any actual material happens to be. Uses the
## FULL circle (collision is not limited to the visual cap — see
## _wheel_penetration) so the deepest, fastest-grinding point stays reachable.
func _wheel_contact_mask_bounds() -> Rect2i:
	var r: float = GRIND_WHEEL_RADIUS + 4.0
	var corners: Array[Vector2] = [
		Vector2(GRIND_WHEEL_CENTER.x - r, GRIND_WHEEL_CENTER.y - r),
		Vector2(GRIND_WHEEL_CENTER.x + r, GRIND_WHEEL_CENTER.y - r),
		Vector2(GRIND_WHEEL_CENTER.x - r, GRIND_WHEEL_CENTER.y + r),
		Vector2(GRIND_WHEEL_CENTER.x + r, GRIND_WHEEL_CENTER.y + r),
	]
	var min_point: Vector2 = Vector2(INF, INF)
	var max_point: Vector2 = Vector2(-INF, -INF)
	for corner: Vector2 in corners:
		var mask_point: Vector2 = _screen_to_mask(corner)
		min_point.x = minf(min_point.x, mask_point.x)
		min_point.y = minf(min_point.y, mask_point.y)
		max_point.x = maxf(max_point.x, mask_point.x)
		max_point.y = maxf(max_point.y, mask_point.y)
	var min_x: int = clampi(floori(min_point.x) - 1, 0, MASK_SIZE - 1)
	var min_y: int = clampi(floori(min_point.y) - 1, 0, MASK_SIZE - 1)
	var max_x: int = clampi(ceili(max_point.x) + 1, 0, MASK_SIZE - 1)
	var max_y: int = clampi(ceili(max_point.y) + 1, 0, MASK_SIZE - 1)
	return Rect2i(min_x, min_y, maxi(1, max_x - min_x + 1), maxi(1, max_y - min_y + 1))

func _grind_wheel_housing_top_y() -> float:
	return GRIND_WHEEL_CENTER.y - GRIND_WHEEL_RADIUS * (1.0 - 2.0 * GRIND_WHEEL_CAP_FRACTION)

## Collision deliberately uses the FULL circle, not just the visible cap: the
## housing drawn in _draw_grind_wheel() is a purely cosmetic "recessed wheel"
## look. Restricting contact to only the cap would bury the wheel's own
## center — its single deepest, fastest-grinding point — making full
## penetration (and full grind speed) permanently unreachable.
func _wheel_penetration(screen_point: Vector2) -> float:
	return clampf((GRIND_WHEEL_RADIUS - screen_point.distance_to(GRIND_WHEEL_CENTER)) / GRIND_WHEEL_RADIUS, 0.0, 1.0)

func _remove_material_index(index: int) -> bool:
	var cell: Cell = material_mask[index] as Cell
	if cell != Cell.ROCK and cell != Cell.GEM:
		return false
	material_mask[index] = Cell.EMPTY
	grind_progress[index] = 0.0
	if cell == Cell.ROCK:
		removed_rock += 1
		_register_precision_success(1.0)
	else:
		removed_gem += 1
		# Incremental target-match bookkeeping: only a GEM cell's removal can
		# change the intersection/union with the (fixed) target silhouette.
		if target_mask[index] != 0:
			target_intersection_cache -= 1
			_register_target_damage(index)
		else:
			target_union_cache -= 1
			_register_precision_success(3.0)
	textures_dirty = true
	exposure_dirty = true
	_mark_pixel_dirty(index)
	var x: int = index % MASK_SIZE
	var y: int = index >> 8
	for offset: Vector2i in CARDINAL_NEIGHBORS:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if _mask_in_bounds(nx, ny):
			_mark_pixel_dirty(_mask_index(nx, ny))
	return true

func precision_multiplier() -> float:
	var steps: int = floori(precision_chain_points / maxf(1.0, precision_points_per_multiplier_step))
	return 1.0 + minf(2.0, float(steps) * 0.25)

func _register_precision_success(points: float) -> void:
	precision_activity_this_frame = true
	precision_chain_idle_time = 0.0
	precision_chain_points += points
	best_precision_chain = maxf(best_precision_chain, precision_chain_points)
	precision_score += points * precision_multiplier()

func _register_target_damage(index: int) -> void:
	var emit_feedback_burst: bool = target_damage_flash <= 0.25
	precision_chain_points = 0.0
	precision_chain_idle_time = 0.0
	target_damage_flash = 1.0
	danger_flash = 1.0
	target_chip_count += 1
	if not emit_feedback_burst:
		return
	if status_label != null:
		status_label.text = "TARGET CHIPPED — ease pressure and let stress cool!"
	var chip_origin: Vector2 = _mask_to_screen(Vector2(index % MASK_SIZE, index >> 8))
	for particle_index: int in range(7):
		var angle: float = randf_range(0.0, TAU)
		shine_bursts.append({
			"position": chip_origin,
			"velocity": Vector2.from_angle(angle) * randf_range(55.0, 125.0),
			"life": 0.72,
			"max_life": 0.72,
			"size": randf_range(3.0, 6.0),
			"color": Color("ff554f"),
		})

func _mark_pixel_dirty(index: int) -> void:
	dirty_pixels[index] = true

func _mask_to_screen(mask_point: Vector2) -> Vector2:
	var local: Vector2 = (mask_point - Vector2(MASK_HALF, MASK_HALF)) * _view_scale()
	return rock_position + local.rotated(object_rotation)

func _screen_to_mask(screen_point: Vector2) -> Vector2:
	var unrotated: Vector2 = (screen_point - rock_position).rotated(-object_rotation)
	var view_transform_scale: Vector2 = _view_scale()
	return Vector2(unrotated.x / view_transform_scale.x, unrotated.y / view_transform_scale.y) + Vector2(MASK_HALF, MASK_HALF)

func _rock_display_rect() -> Rect2:
	# Rotation-safe grab bounds use the full diagonal radius.
	var radius: float = MASK_HALF * 1.42
	return Rect2(rock_position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))

func _mask_index(x: int, y: int) -> int:
	return x + y * MASK_SIZE

func _mask_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < MASK_SIZE and y >= 0 and y < MASK_SIZE

func _mask_cell(x: int, y: int) -> Cell:
	if not _mask_in_bounds(x, y):
		return Cell.EMPTY
	return material_mask[_mask_index(x, y)] as Cell

func _set_mask_cell_raw(x: int, y: int, cell: Cell) -> void:
	if _mask_in_bounds(x, y):
		material_mask[_mask_index(x, y)] = cell

func _is_material(cell: Cell) -> bool:
	return cell == Cell.ROCK or cell == Cell.GEM

func _is_material_boundary(x: int, y: int) -> bool:
	if not _is_material(_mask_cell(x, y)):
		return false
	for offset: Vector2i in CARDINAL_NEIGHBORS:
		if not _is_material(_mask_cell(x + offset.x, y + offset.y)):
			return true
	return false

func _count_mask_cells(cell: Cell) -> int:
	var count: int = 0
	for value: int in material_mask:
		if value == cell:
			count += 1
	return count

func _count_target_cells() -> int:
	var count: int = 0
	for value: int in target_mask:
		if value != 0:
			count += 1
	return count

func _target_is_subset_of_original_gem() -> bool:
	for index: int in range(target_mask.size()):
		if target_mask[index] != 0 and original_gem_mask[index] == 0:
			return false
	return true

## Single-cell exposure query (raycast in 4 cardinal directions until ROCK or
## the mask edge). Kept exact and simple — it is only ever called for a
## handful of cells per frame (dirty pixels being painted), never the whole
## mask; see _recompute_exposure_cache() for the whole-mask aggregate.
func _gem_cell_is_exposed(x: int, y: int) -> bool:
	if _mask_cell(x, y) != Cell.GEM:
		return false
	for direction: Vector2i in CARDINAL_NEIGHBORS:
		var cursor: Vector2i = Vector2i(x, y) + direction
		var blocked: bool = false
		while _mask_in_bounds(cursor.x, cursor.y):
			if _mask_cell(cursor.x, cursor.y) == Cell.ROCK:
				blocked = true
				break
			cursor += direction
		if not blocked:
			return true
	return false

func _visible_material_at(x: int, y: int, xray: bool) -> Cell:
	var cell: Cell = _mask_cell(x, y)
	if cell == Cell.GEM and not xray and not _gem_cell_is_exposed(x, y):
		return Cell.ROCK
	return cell

func gem_exposure_ratio() -> float:
	if exposure_dirty:
		_recompute_exposure_cache()
	if remaining_gem_cells_cache <= 0:
		return 0.0
	return clampf(float(exposed_gem_cells_cache) / float(remaining_gem_cells_cache), 0.0, 1.0)

## Whole-mask exposure aggregate via 4 linear sweeps (left/right/top/bottom
## "is there a clear, ROCK-free run to this edge") instead of a raycast per
## gem cell — same semantics as _gem_cell_is_exposed, ~65536*6 simple array
## reads instead of up to hundreds of thousands of bounds-checked steps (a gem
## cluster is tens of cells across, and GEM never blocks the raycast, so a
## per-cell raycast from deep inside it walks the whole cluster radius).
func _compute_exposed_mask() -> PackedByteArray:
	var clear_left: PackedByteArray = PackedByteArray()
	var clear_right: PackedByteArray = PackedByteArray()
	var clear_top: PackedByteArray = PackedByteArray()
	var clear_bottom: PackedByteArray = PackedByteArray()
	clear_left.resize(MASK_SIZE * MASK_SIZE)
	clear_right.resize(MASK_SIZE * MASK_SIZE)
	clear_top.resize(MASK_SIZE * MASK_SIZE)
	clear_bottom.resize(MASK_SIZE * MASK_SIZE)
	for y: int in range(MASK_SIZE):
		var row_base: int = y * MASK_SIZE
		var blocked: bool = false
		for x: int in range(MASK_SIZE):
			var index: int = row_base + x
			clear_left[index] = 0 if blocked else 1
			if material_mask[index] == Cell.ROCK:
				blocked = true
		blocked = false
		for x: int in range(MASK_SIZE - 1, -1, -1):
			var index: int = row_base + x
			clear_right[index] = 0 if blocked else 1
			if material_mask[index] == Cell.ROCK:
				blocked = true
	for x: int in range(MASK_SIZE):
		var blocked: bool = false
		for y: int in range(MASK_SIZE):
			var index: int = _mask_index(x, y)
			clear_top[index] = 0 if blocked else 1
			if material_mask[index] == Cell.ROCK:
				blocked = true
		blocked = false
		for y: int in range(MASK_SIZE - 1, -1, -1):
			var index: int = _mask_index(x, y)
			clear_bottom[index] = 0 if blocked else 1
			if material_mask[index] == Cell.ROCK:
				blocked = true
	var exposed: PackedByteArray = PackedByteArray()
	exposed.resize(MASK_SIZE * MASK_SIZE)
	for index: int in range(exposed.size()):
		exposed[index] = 1 if (clear_left[index] or clear_right[index] or clear_top[index] or clear_bottom[index]) else 0
	return exposed

func _recompute_exposure_cache() -> void:
	var exposed: PackedByteArray = _compute_exposed_mask()
	var had_previous: bool = exposed_mask_cache.size() == exposed.size()
	exposed_gem_cells_cache = 0
	remaining_gem_cells_cache = 0
	var exposure_changed: bool = false
	for index: int in range(material_mask.size()):
		if material_mask[index] == Cell.GEM:
			remaining_gem_cells_cache += 1
			if exposed[index] != 0:
				exposed_gem_cells_cache += 1
			if had_previous and exposed_mask_cache[index] != exposed[index]:
				# Opening one line through the outer rock can reveal many gem cells,
				# not just the cell adjacent to the removed pixel. Mark every changed
				# sightline pixel so the optimized texture cannot stay stale brown.
				_mark_pixel_dirty(index)
				exposure_changed = true
	exposed_mask_cache = exposed
	if exposure_changed:
		textures_dirty = true
	exposure_dirty = false

func gem_preserved_ratio() -> float:
	return clampf(float(total_gem_cells - removed_gem) / maxf(1.0, float(total_gem_cells)), 0.0, 1.0)

func rock_removal_ratio() -> float:
	return clampf(float(removed_rock) / maxf(1.0, float(total_rock)), 0.0, 1.0)

func target_match_ratio() -> float:
	if target_union_cache <= 0:
		return 0.0
	return float(target_intersection_cache) / float(target_union_cache)

## Unlike total gem preservation, this treats removing surplus rough gemstone
## as correct shaping and only penalizes cutting into the intended final jewel.
func target_preservation_ratio() -> float:
	return clampf(float(target_intersection_cache) / maxf(1.0, float(_count_target_cells())), 0.0, 1.0)

func _resonance_is_available() -> bool:
	return gem_exposure_ratio() >= resonance_exposure_required and target_match_ratio() >= resonance_match_required

func _recompute_target_cache() -> void:
	target_intersection_cache = 0
	target_union_cache = 0
	for index: int in range(material_mask.size()):
		var is_gem: bool = material_mask[index] == Cell.GEM
		var is_target: bool = target_mask[index] != 0
		if is_gem and is_target:
			target_intersection_cache += 1
		if is_gem or is_target:
			target_union_cache += 1

## Full O(mask) pixel paint — only run once per generated attempt (never per
## frame). Per-frame updates go through _refresh_textures()'s dirty-pixel path.
## Uses the fast whole-mask sweep for gem visibility (see _compute_exposed_mask)
## instead of a single-cell raycast per gem cell — with ~9000 gem cells whose
## raycasts don't stop at other GEM cells, the per-cell version alone can cost
## the better part of a second here.
func _rebuild_all_textures_full() -> void:
	grind_pixels = Image.create_empty(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	xray_pixels = Image.create_empty(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	gem_pixels = Image.create_empty(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	target_pixels = Image.create_empty(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	grind_pixels.fill(Color.TRANSPARENT)
	xray_pixels.fill(Color.TRANSPARENT)
	gem_pixels.fill(Color.TRANSPARENT)
	target_pixels.fill(Color.TRANSPARENT)
	var exposed_mask: PackedByteArray = _compute_exposed_mask()
	exposed_mask_cache = exposed_mask.duplicate()
	for y: int in range(MASK_SIZE):
		for x: int in range(MASK_SIZE):
			_paint_pixel(x, y, exposed_mask)
			var index: int = _mask_index(x, y)
			if target_mask[index] != 0 and _target_is_boundary(x, y):
				target_pixels.set_pixel(x, y, TARGET_COLOR)
	grind_texture = ImageTexture.create_from_image(grind_pixels)
	xray_texture = ImageTexture.create_from_image(xray_pixels)
	gem_texture = ImageTexture.create_from_image(gem_pixels)
	target_texture = ImageTexture.create_from_image(target_pixels)
	dirty_pixels.clear()
	textures_dirty = false

## Procedural facet light for the live rough gemstone. It is evaluated only for
## GEM pixels, then naturally clipped by the canonical mask/visibility rules.
## The clean final trophy uses vector facets, but sharing this angular/radial
## light language makes the gemstone visibly emerge during grinding instead of
## remaining a flat colored blob until the end.
func _live_facet_color(mask_point: Vector2) -> Color:
	var safe_half: Vector2 = Vector2(maxf(1.0, target_half_size.x), maxf(1.0, target_half_size.y))
	var local: Vector2 = mask_point - target_center
	var normalized: Vector2 = Vector2(local.x / safe_half.x, local.y / safe_half.y)
	var angle: float = atan2(normalized.y, normalized.x)
	var facet_count: int = _facet_count_for_shape(target_shape_name)
	var sector: int = floori((angle + PI) / TAU * float(facet_count))
	var radial: float = normalized.length()
	var alternating: float = 1.14 if sector % 2 == 0 else 0.76
	var directional: float = 0.16 * cos(angle + 0.75)
	var table_light: float = 0.18 if radial < 0.43 else 0.0
	var rim_darkening: float = -0.12 if radial > 0.82 else 0.0
	var multiplier: float = clampf(alternating + directional + table_light + rim_darkening, 0.48, 1.42)
	var shaded: Color = _multiply_color(gem_color, multiplier)
	return gem_color.lerp(shaded, facet_strength)

func _multiply_color(color: Color, multiplier: float) -> Color:
	var red: float = clampf(color.r * multiplier, 0.0, 1.0)
	var green: float = clampf(color.g * multiplier, 0.0, 1.0)
	var blue: float = clampf(color.b * multiplier, 0.0, 1.0)
	# Keep facet contrast visible on near-white custom gems. Without a little
	# headroom, every highlight clamps to pure white and becomes one flat blob.
	if color.r > 0.95 and color.g > 0.95 and color.b > 0.95 and multiplier > 1.0:
		var headroom: float = (multiplier - 1.0) * 0.12
		red = clampf(red - headroom, 0.0, 1.0)
		green = clampf(green - headroom, 0.0, 1.0)
		blue = clampf(blue - headroom, 0.0, 1.0)
	return Color(red, green, blue, color.a)

func _facet_count_for_shape(shape_name: String) -> int:
	match shape_name:
		"CIRCLE", "OVAL":
			return 12
		"EMERALD":
			return 8
		"HEXAGON":
			return 6
		"TEARDROP":
			return 10
		_:
			return 8

## Repaints ONE pixel across the 3 dynamic images (grind/xray/gem). The target
## image is static after generation and is never touched here. Pass a
## precomputed exposed_mask (see _compute_exposed_mask) when repainting many
## cells at once; per-cell incremental repaints reuse exposed_mask_cache.
func _paint_pixel(x: int, y: int, exposed_mask: PackedByteArray = PackedByteArray()) -> void:
	var canonical: Cell = _mask_cell(x, y)
	var visible_grind: Cell = canonical
	var index: int = _mask_index(x, y)
	if canonical == Cell.GEM:
		var visibility_mask: PackedByteArray = exposed_mask if exposed_mask.size() > 0 else exposed_mask_cache
		var is_exposed: bool = visibility_mask[index] != 0 if visibility_mask.size() == material_mask.size() else _gem_cell_is_exposed(x, y)
		if not is_exposed:
			visible_grind = Cell.ROCK
	var grind_color: Color = Color.TRANSPARENT
	if visible_grind == Cell.ROCK:
		grind_color = ROCK_HIGHLIGHT if _is_material_boundary(x, y) else ROCK_COLOR
	elif visible_grind == Cell.GEM:
		var faceted: Color = _live_facet_color(Vector2(x, y))
		grind_color = faceted.lerp(gem_glow_color, 0.42) if _is_material_boundary(x, y) else faceted
	grind_pixels.set_pixel(x, y, grind_color)
	var xray_color: Color = Color.TRANSPARENT
	if canonical == Cell.ROCK:
		xray_color = Color(ROCK_COLOR.r, ROCK_COLOR.g, ROCK_COLOR.b, 0.38)
	elif canonical == Cell.GEM:
		xray_color = gem_color
	xray_pixels.set_pixel(x, y, xray_color)
	gem_pixels.set_pixel(x, y, _live_facet_color(Vector2(x, y)) if canonical == Cell.GEM else Color.TRANSPARENT)

func _target_is_boundary(x: int, y: int) -> bool:
	var index: int = _mask_index(x, y)
	if target_mask[index] == 0:
		return false
	for offset: Vector2i in CARDINAL_NEIGHBORS:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if not _mask_in_bounds(nx, ny) or target_mask[_mask_index(nx, ny)] == 0:
			return true
	return false

## Per-frame texture sync: repaints only the cells marked dirty since the last
## call (the removed cell plus its 4 neighbors, whose boundary-highlight color
## can change), then uploads once via ImageTexture.update — never a full
## 65536-pixel rescan or texture recreation while grinding.
func _refresh_textures() -> void:
	if not textures_dirty:
		return
	if grind_pixels == null:
		_rebuild_all_textures_full()
		return
	for index: int in dirty_pixels.keys():
		var x: int = index % MASK_SIZE
		var y: int = index >> 8
		_paint_pixel(x, y)
	grind_texture.update(grind_pixels)
	xray_texture.update(xray_pixels)
	gem_texture.update(gem_pixels)
	dirty_pixels.clear()
	textures_dirty = false

func _station_center(target_station: Station) -> Vector2:
	match target_station:
		Station.XRAY:
			return XRAY_STATION_RECT.get_center()
		Station.RESONANCE:
			return RESONANCE_STATION_RECT.get_center()
		_:
			return GRIND_REST_POSITION

func _move_rock_to_station(target_station: Station) -> void:
	var previous_station: Station = station
	rock_station = target_station
	station = target_station
	rock_position = _station_center(target_station)
	if target_station == Station.XRAY and previous_station != Station.XRAY and gem_jam_audio != null:
		gem_jam_audio.play_xray_machine()
	if target_station == Station.RESONANCE:
		_update_resonance_target()

func _place_rock_in_station() -> void:
	if XRAY_STATION_RECT.grow(20.0).has_point(rock_position):
		_move_rock_to_station(Station.XRAY)
		status_label.text = "X-ray reveals the same canonical rough gem."
	elif GRIND_STATION_RECT.grow(20.0).has_point(rock_position):
		rock_station = Station.GRIND
		station = Station.GRIND
		rock_position.x = clampf(rock_position.x, GRIND_STATION_RECT.position.x + 35.0, GRIND_STATION_RECT.end.x - 35.0)
		rock_position.y = clampf(rock_position.y, GRIND_STATION_RECT.position.y + 35.0, GRIND_STATION_RECT.end.y - 35.0)
		status_label.text = "Lower into the wheel, rotate with A/D, adjust wheel speed with W/S."
	elif RESONANCE_STATION_RECT.grow(20.0).has_point(rock_position) and _resonance_is_available():
		_start_resonance_challenge()
	else:
		rock_position = drag_origin_position
		rock_station = drag_origin_station
		station = drag_origin_station
		status_label.text = "Keep the formation in a workstation."
	_update_ui()
	queue_redraw()

func _select_xray() -> void:
	if completed or resonance_challenge_active:
		return
	_move_rock_to_station(Station.XRAY)
	status_label.text = "X-ray reveals the canonical rough gemstone through rock."
	_update_ui()
	queue_redraw()

func _select_grind() -> void:
	if completed or resonance_challenge_active:
		return
	_move_rock_to_station(Station.GRIND)
	status_label.text = "Drag downward into the lap wheel. A/D rotates, W/S sets wheel speed."
	_update_ui()
	queue_redraw()

func _select_resonance() -> void:
	var exposure: float = gem_exposure_ratio()
	var shape_match: float = target_match_ratio()
	if not _resonance_is_available():
		status_label.text = "REFINE MORE — exposure %d/%d%%, cut match %d/%d%%." % [roundi(exposure * 100.0), roundi(resonance_exposure_required * 100.0), roundi(shape_match * 100.0), roundi(resonance_match_required * 100.0)]
		return
	_start_resonance_challenge()

func _start_resonance_challenge() -> void:
	if completed or resonance_challenge_active:
		return
	_move_rock_to_station(Station.RESONANCE)
	resonance_challenge_active = true
	resonance_time = 0.0
	resonance_good_time = 0.0
	_set_resonance_music_mix(true)
	status_label.text = "POLISH — hold %d%%+ sync for %.0f total seconds." % [roundi((1.0 - resonance_tolerance) * 100.0), resonance_hold_target_seconds]
	_update_ui()
	queue_redraw()

## The meter only ever moves toward completion: while aligned it fills, while
## not aligned it simply holds (no decay) — so total accumulated good time is
## what matters, not one unbroken streak. The run's own clock is what
## actually punishes struggling (see _update_run_timer), not this meter.
func _update_resonance(delta: float) -> void:
	resonance_time += delta
	_update_resonance_target()
	if Input.is_physical_key_pressed(KEY_A):
		resonance_frequency = clampf(resonance_frequency - resonance_frequency_step * delta * 4.0, 0.0, 1.0)
	if Input.is_physical_key_pressed(KEY_D):
		resonance_frequency = clampf(resonance_frequency + resonance_frequency_step * delta * 4.0, 0.0, 1.0)
	if Input.is_physical_key_pressed(KEY_S):
		resonance_amplitude = clampf(resonance_amplitude - resonance_amplitude_step * delta * 4.0, 0.0, 1.0)
	if Input.is_physical_key_pressed(KEY_W):
		resonance_amplitude = clampf(resonance_amplitude + resonance_amplitude_step * delta * 4.0, 0.0, 1.0)
	if _alignment_score() >= 1.0 - resonance_tolerance:
		resonance_good_time = minf(resonance_hold_target_seconds, resonance_good_time + delta)
	if resonance_good_time >= resonance_hold_target_seconds:
		resonance_completion_accuracy = 1.0
		_finish_resonance_challenge()

## Called both on a full, successful polish AND when the run's clock reaches
## zero mid-polish — either way the player is graded on however much of the
## hold target they actually accumulated, rather than being discarded.
func _finish_resonance_challenge() -> void:
	if completed:
		return
	resonance_challenge_active = false
	resonance_completion_accuracy = clampf(resonance_good_time / maxf(0.01, resonance_hold_target_seconds), 0.0, 1.0)
	_set_resonance_music_mix(false)
	_complete_refinement()

func _complete_refinement(unfinished: bool = false) -> void:
	if completed:
		return
	completed = true
	resonance_challenge_active = false
	final_reveal_progress = 0.0
	final_shape_score = target_match_ratio()
	final_preservation_score = target_preservation_ratio()
	final_exposure_score = gem_exposure_ratio()
	final_cut_score = clampf(final_shape_score * 0.65 + final_preservation_score * 0.35, 0.0, 1.0)
	final_time_score = clampf(run_time_remaining / maxf(1.0, run_time_limit_seconds), 0.0, 1.0)
	var resonance_score: float = clampf(resonance_completion_accuracy, 0.0, 1.0)
	# Quality is determined by the material result and resonance skill. Time and
	# heat management are gameplay pressures, not hidden quality grades.
	final_quality_score = clampf(final_exposure_score * 0.22 + final_cut_score * 0.40 + resonance_score * 0.38, 0.0, 1.0)
	final_rank_name = _rank_for_scores(final_exposure_score, final_cut_score, resonance_score, unfinished)
	final_limiting_stage = _limiting_stage(final_exposure_score, final_cut_score, resonance_score)
	final_score = _compute_final_score(unfinished)
	final_gem_name = "%s %s — %s CUT" % [final_rank_name, gem_name, target_shape_name]
	if status_label != null:
		status_label.text = "TIME EXPIRED — unfinished rough cut." if unfinished else "JEWEL REFINED — %s" % final_gem_name
	# A final shower is screen-space trophy feedback, separate from the smaller
	# contact sparkle used during grinding.
	var reveal_center: Vector2 = Vector2(640.0, 355.0)
	var burst_total: int = 14 if unfinished else 36
	for i: int in range(burst_total):
		var angle: float = TAU * float(i) / float(burst_total) + randf_range(-0.08, 0.08)
		var speed: float = randf_range(70.0, 175.0)
		shine_bursts.append({
			"position": reveal_center + Vector2.from_angle(angle) * randf_range(15.0, 55.0),
			"velocity": Vector2.from_angle(angle) * speed,
			"life": randf_range(0.9, 1.5),
			"max_life": 1.5,
			"size": randf_range(3.0, 7.0),
		})

## A concrete arcade-style number, on top of the 0-100% category scores:
## precision_score is earned live during grinding (rock/surplus-gem removal,
## multiplied by the precision chain), then extraction/cut/tune each contribute
## a flat point pool. Time contributes to the arcade score separately, but
## heat management and elapsed time never alter the quality/rank grade.
func _compute_final_score(unfinished: bool) -> int:
	if unfinished:
		return roundi(precision_score + final_exposure_score * 400.0)
	var score: float = precision_score
	score += final_exposure_score * 1000.0
	score += final_cut_score * 2000.0
	score += resonance_completion_accuracy * 2000.0
	score += final_time_score * 1000.0
	return roundi(score)

func _rank_for_scores(extraction: float, cut: float, tune: float, unfinished: bool) -> String:
	if unfinished:
		return "UNFINISHED"
	if extraction >= 0.90 and cut >= 0.90 and tune >= 0.85:
		return "MASTERWORK"
	if extraction >= 0.78 and cut >= 0.78 and tune >= 0.75:
		return "BRILLIANT"
	if extraction >= 0.60 and cut >= 0.60 and tune >= 0.60:
		return "POLISHED"
	return "ROUGH-CUT"

func _limiting_stage(extraction: float, cut: float, tune: float) -> String:
	if extraction <= cut and extraction <= tune:
		return "EXTRACTION"
	if cut <= tune:
		return "CUT"
	return "RESONANCE"

func _resonance_erratic_weight(exposure: float) -> float:
	var final_band: float = clampf((exposure - 0.80) / 0.20, 0.0, 1.0)
	var smoothed: float = final_band * final_band * (3.0 - 2.0 * final_band)
	return lerpf(1.0, resonance_full_exposure_motion_floor, smoothed)

func _resonance_target_at_time(exposure: float, time: float) -> Vector2:
	var erratic_weight: float = _resonance_erratic_weight(exposure)
	var gentle_frequency: float = resonance_gentle_frequency_motion * (0.72 * sin(time * 0.72) + 0.28 * sin(time * 1.19 + 1.1))
	var gentle_amplitude: float = resonance_gentle_amplitude_motion * (0.70 * sin(time * 0.61 + 0.8) + 0.30 * sin(time * 1.07 + 2.0))
	var erratic_frequency: float = resonance_erratic_frequency_motion * (0.56 * sin(time * 2.25 + 0.4) + 0.29 * sin(time * 5.15) + 0.15 * sin(time * 8.6 + 1.7))
	var erratic_amplitude: float = resonance_erratic_amplitude_motion * (0.55 * sin(time * 1.85 + 2.2) + 0.30 * sin(time * 4.65 + 0.3) + 0.15 * sin(time * 7.9))
	return Vector2(clampf(target_base_frequency + gentle_frequency + erratic_frequency * erratic_weight, 0.08, 0.92), clampf(target_base_amplitude + gentle_amplitude + erratic_amplitude * erratic_weight, 0.08, 0.92))

func _update_resonance_target() -> void:
	var live_target: Vector2 = _resonance_target_at_time(gem_exposure_ratio(), resonance_time)
	target_frequency = live_target.x
	target_amplitude = live_target.y

func _alignment_score() -> float:
	return 1.0 - clampf(absf(resonance_frequency - target_frequency) + absf(resonance_amplitude - target_amplitude), 0.0, 1.0)

func _frequency_down() -> void:
	resonance_frequency = clampf(resonance_frequency - resonance_frequency_step, 0.0, 1.0)

func _frequency_up() -> void:
	resonance_frequency = clampf(resonance_frequency + resonance_frequency_step, 0.0, 1.0)

func _amplitude_down() -> void:
	resonance_amplitude = clampf(resonance_amplitude - resonance_amplitude_step, 0.0, 1.0)

func _amplitude_up() -> void:
	resonance_amplitude = clampf(resonance_amplitude + resonance_amplitude_step, 0.0, 1.0)

func _update_ui() -> void:
	var station_name: String = ["X-RAY STATION", "GRIND WHEEL STATION", "RESONANCE STATION"][station]
	station_label.text = "FINISHED JEWEL" if completed else station_name
	view_label.text = "SPECIMEN: UNIDENTIFIED"
	metrics_label.text = "TARGET INTACT %d%%    TARGET MATCH %d%%    ROCK REMOVED %d%%    PRECISION ×%.2f" % [roundi(target_preservation_ratio() * 100.0), roundi(target_match_ratio() * 100.0), roundi(rock_removal_ratio() * 100.0), precision_multiplier()]
	progress_bar.value = (resonance_good_time / maxf(0.01, resonance_hold_target_seconds)) * 100.0
	progress_bar.visible = resonance_challenge_active and not completed
	frequency_label.text = "YOUR FREQUENCY  %.2f" % resonance_frequency
	amplitude_label.text = "YOUR AMPLITUDE  %.2f    SYNC METER %.1f / %.0fs" % [resonance_amplitude, resonance_good_time, resonance_hold_target_seconds]
	resonance_panel.visible = resonance_challenge_active and not completed
	grind_hint.visible = station == Station.GRIND and not completed and not resonance_challenge_active
	status_label.visible = not completed
	metrics_label.visible = not completed
	$StationBar.visible = not completed and not resonance_challenge_active

func _draw() -> void:
	_refresh_textures()
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color("100c16"))
	_draw_shop_background()
	_draw_station(XRAY_STATION_RECT, "X-RAY SCANNER", Color("4b8490"))
	_draw_station(GRIND_STATION_RECT, "LAP GRIND WHEEL", Color("8b684d"))
	_draw_station(RESONANCE_STATION_RECT, "RESONANCE PAD", Color("66518d"))
	if not completed:
		_draw_challenge_timer()
	if completed:
		_draw_final_reveal()
		_draw_shine_bursts()
		return
	_draw_material_body()
	if station == Station.GRIND:
		_draw_ambient_shine_glow()
		_draw_dust_particles()
		_draw_grind_wheel()
		_draw_target_guide()
		_draw_shine_bursts()
		_draw_wheel_speed_bar()
	elif station == Station.RESONANCE:
		_draw_waveforms()

func _draw_shop_background() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color("17121b"))
	draw_line(Vector2(0.0, 155.0), Vector2(size.x, 155.0), Color("4b3540"), 3.0)
	for x: int in range(0, 1280, 80):
		draw_line(Vector2(x, 0.0), Vector2(x + 180.0, 155.0), Color(0.18, 0.12, 0.18, 0.45), 2.0)

func _draw_challenge_timer() -> void:
	var timer_color: Color = Color("ff6b62") if run_time_remaining <= 10.0 else Color("ffe18a")
	var timer_text: String = "POLISH  %.1fs" % run_time_remaining if resonance_challenge_active else "TIME  %.1fs" % run_time_remaining
	draw_rect(Rect2(1000.0, 92.0, 185.0, 42.0), Color(0.08, 0.055, 0.10, 0.92), true)
	draw_rect(Rect2(1000.0, 92.0, 185.0, 42.0), timer_color, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(1010.0, 121.0), timer_text, HORIZONTAL_ALIGNMENT_CENTER, 165.0, 20, timer_color)

func _draw_station(rect: Rect2, title: String, color: Color) -> void:
	draw_rect(rect, Color("211a25"), true)
	draw_rect(rect, color, false, 4.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 32.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, 20, color)

func _draw_material_body() -> void:
	var texture: ImageTexture = grind_texture
	if station == Station.XRAY:
		texture = xray_texture
	elif station == Station.RESONANCE:
		texture = gem_texture
	var shake: Vector2 = Vector2(sin(feedback_time * 73.0), cos(feedback_time * 61.0)) * target_damage_flash * 5.0
	draw_set_transform(rock_position + shake, object_rotation, _view_scale())
	draw_texture(texture, Vector2(-MASK_HALF, -MASK_HALF))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A mostly-buried grinding wheel: the collision math is still a full circle
## (so the player can approach it from the side, not just straight down), but
## only the top ~25% pokes up out of its housing, reading as a small rounded
## grinding surface rather than a full spinning wheel.
func _draw_grind_wheel() -> void:
	draw_circle(GRIND_WHEEL_CENTER, GRIND_WHEEL_RADIUS, Color("777782"))
	for spoke: int in range(8):
		var angle: float = wheel_rotation + TAU * float(spoke) / 8.0
		draw_line(GRIND_WHEEL_CENTER + Vector2.from_angle(angle) * 18.0, GRIND_WHEEL_CENTER + Vector2.from_angle(angle) * (GRIND_WHEEL_RADIUS - 6.0), Color(0.82, 0.82, 0.86, 0.48), 3.0)
	var housing_top: float = _grind_wheel_housing_top_y()
	var housing_rect: Rect2 = Rect2(GRIND_STATION_RECT.position.x + 14.0, housing_top, GRIND_STATION_RECT.size.x - 28.0, GRIND_STATION_RECT.end.y - housing_top - 14.0)
	draw_rect(housing_rect, Color("342c38"), true)
	draw_rect(housing_rect, Color("1c1720"), false, 3.0)
	draw_line(Vector2(housing_rect.position.x, housing_top), Vector2(housing_rect.end.x, housing_top), Color("57505f"), 2.0)
	if grinding_active:
		draw_arc(GRIND_WHEEL_CENTER, GRIND_WHEEL_RADIUS + 5.0, PI * 1.1, PI * 1.9, 24, Color("ffd56a"), 5.0)
		draw_string(ThemeDB.fallback_font, Vector2(505.0, 583.0), "GRINDING — contact cells %d" % grind_contact_cells, HORIZONTAL_ALIGNMENT_CENTER, 270.0, 15, Color("ffd56a"))

func _draw_target_guide() -> void:
	if gem_exposure_ratio() < target_reveal_exposure:
		return
	var guide_color: Color = TARGET_COLOR
	if target_damage_flash > 0.0:
		guide_color = Color("ff3d42")
	elif danger_flash > 0.05 or (gem_stress >= gem_stress_warning_threshold and target_contact_cells > 0):
		guide_color = Color("ff8a3d")
	draw_set_transform(rock_position, object_rotation, _view_scale())
	draw_texture(target_texture, Vector2(-MASK_HALF, -MASK_HALF), Color(guide_color.r, guide_color.g, guide_color.b, 0.96))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var guide_text: String = _target_guide_text()
	draw_string(ThemeDB.fallback_font, Vector2(505.0, 245.0), guide_text, HORIZONTAL_ALIGNMENT_CENTER, 270.0, 14, guide_color)

func _target_guide_text() -> String:
	return "TARGET CHIPPED! BACK OFF" if target_damage_flash > 0.0 else "FOLLOW THE GOLD OUTLINE"

## A soft, breathing halo behind the object that grows with how much gem is
## exposed, plus a brighter temporary boost right after a breakthrough
## (shine_intensity) — the "dramatic reveal" cue requested, layered purely as
## a screen-space overlay so it never touches (or slows down) the pixel data.
func _draw_ambient_shine_glow() -> void:
	var exposure: float = gem_exposure_ratio()
	if exposure <= 0.01 and shine_intensity <= 0.01:
		return
	var breathing: float = 0.75 + 0.25 * sin(wheel_rotation * 0.6)
	var base_alpha: float = exposure * 0.35 * breathing
	var boosted_alpha: float = clampf(base_alpha + shine_intensity * 0.5, 0.0, 0.85)
	var radius: float = 60.0 + exposure * 40.0 + shine_intensity * 30.0
	for ring: int in range(3):
		var ring_scale: float = 1.0 - float(ring) * 0.28
		draw_circle(rock_position, radius * ring_scale, Color(gem_glow_color.r, gem_glow_color.g, gem_glow_color.b, boosted_alpha * (0.4 - float(ring) * 0.1)))

func _draw_dust_particles() -> void:
	for particle: Dictionary in dust_particles:
		var color: Color = particle["color"]
		var alpha: float = clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		draw_circle(particle["position"], float(particle["size"]), Color(color.r, color.g, color.b, alpha * 0.85))

func _draw_shine_bursts() -> void:
	for particle: Dictionary in shine_bursts:
		var alpha: float = clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		var burst_position: Vector2 = particle["position"]
		var burst_size: float = float(particle["size"])
		var burst_color: Color = gem_glow_color
		if particle.has("color"):
			burst_color = particle["color"] as Color
		draw_circle(burst_position, burst_size * alpha, Color(burst_color.r, burst_color.g, burst_color.b, alpha))
		draw_circle(burst_position, burst_size * 0.4 * alpha, Color(1.0, 1.0, 1.0, alpha * 0.9))

func _draw_wheel_speed_bar() -> void:
	var speed_rect: Rect2 = Rect2(505.0, 545.0, 270.0, 18.0)
	var speed_fraction: float = (wheel_speed - wheel_speed_min) / maxf(0.001, wheel_speed_max - wheel_speed_min)
	draw_rect(speed_rect, Color("120e18"), true)
	draw_rect(Rect2(speed_rect.position, Vector2(speed_rect.size.x * clampf(speed_fraction, 0.0, 1.0), speed_rect.size.y)), Color("6fd1e6"), true)
	draw_rect(speed_rect, Color("bfeaf2"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(505.0, 540.0), "WHEEL SPEED  %.0f%%  — W/S to adjust" % (speed_fraction * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 270.0, 14, Color("bfeaf2"))

	var stress_rect: Rect2 = Rect2(505.0, 500.0, 270.0, 18.0)
	var stress_color: Color = Color("66d88a")
	if gem_stress >= gem_stress_critical_threshold:
		stress_color = Color("ff4545")
	elif gem_stress >= gem_stress_warning_threshold:
		stress_color = Color("ff9f43")
	draw_rect(stress_rect, Color("120e18"), true)
	draw_rect(Rect2(stress_rect.position, Vector2(stress_rect.size.x * gem_stress, stress_rect.size.y)), stress_color, true)
	draw_rect(stress_rect, Color("e3d7e5"), false, 2.0)
	var stress_state: String = "CRITICAL — BACK OFF" if gem_stress >= gem_stress_critical_threshold else ("HOT" if gem_stress >= gem_stress_warning_threshold else "STABLE")
	draw_string(ThemeDB.fallback_font, Vector2(505.0, 495.0), "GEM STRESS %d%%  %s" % [roundi(gem_stress * 100.0), stress_state], HORIZONTAL_ALIGNMENT_LEFT, 270.0, 14, stress_color)
	draw_string(ThemeDB.fallback_font, Vector2(505.0, 278.0), "PRECISION ×%.2f    BEST %.0f" % [precision_multiplier(), best_precision_chain], HORIZONTAL_ALIGNMENT_CENTER, 270.0, 15, Color("91f0c0"))

## Clean mathematical silhouettes used only for the finished trophy. Gameplay
## remains the player's real eroded mask; the reveal translates that measured
## result into the visual language of a recognizably cut gemstone.
func _cut_shape_points(shape_name: String, center: Vector2, half_size: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	match shape_name:
		"CIRCLE", "OVAL":
			for index: int in range(12):
				var angle: float = -PI * 0.5 + TAU * float(index) / 12.0
				points.append(center + Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y))
		"DIAMOND":
			points = PackedVector2Array([center + Vector2(0.0, -half_size.y), center + Vector2(half_size.x, 0.0), center + Vector2(0.0, half_size.y), center + Vector2(-half_size.x, 0.0)])
		"EMERALD":
			var cut_x: float = half_size.x * 0.28
			var cut_y: float = half_size.y * 0.22
			points = PackedVector2Array([center + Vector2(-half_size.x + cut_x, -half_size.y), center + Vector2(half_size.x - cut_x, -half_size.y), center + Vector2(half_size.x, -half_size.y + cut_y), center + Vector2(half_size.x, half_size.y - cut_y), center + Vector2(half_size.x - cut_x, half_size.y), center + Vector2(-half_size.x + cut_x, half_size.y), center + Vector2(-half_size.x, half_size.y - cut_y), center + Vector2(-half_size.x, -half_size.y + cut_y)])
		"TEARDROP":
			points = PackedVector2Array([center + Vector2(0.0, -half_size.y), center + Vector2(half_size.x * 0.58, -half_size.y * 0.55), center + Vector2(half_size.x * 0.92, -half_size.y * 0.05), center + Vector2(half_size.x * 0.78, half_size.y * 0.53), center + Vector2(half_size.x * 0.38, half_size.y * 0.90), center + Vector2(0.0, half_size.y), center + Vector2(-half_size.x * 0.38, half_size.y * 0.90), center + Vector2(-half_size.x * 0.78, half_size.y * 0.53), center + Vector2(-half_size.x * 0.92, -half_size.y * 0.05), center + Vector2(-half_size.x * 0.58, -half_size.y * 0.55)])
		"HEXAGON":
			points = PackedVector2Array([center + Vector2(-half_size.x * 0.52, -half_size.y), center + Vector2(half_size.x * 0.52, -half_size.y), center + Vector2(half_size.x, 0.0), center + Vector2(half_size.x * 0.52, half_size.y), center + Vector2(-half_size.x * 0.52, half_size.y), center + Vector2(-half_size.x, 0.0)])
		_:
			points = PackedVector2Array([center + Vector2(0.0, -half_size.y), center + Vector2(half_size.x, 0.0), center + Vector2(0.0, half_size.y), center + Vector2(-half_size.x, 0.0)])
	return points

func _scaled_polygon(points: PackedVector2Array, center: Vector2, scale_factor: float) -> PackedVector2Array:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(center + (point - center) * scale_factor)
	return scaled

func _quality_adjusted_polygon(points: PackedVector2Array, center: Vector2, quality: float) -> PackedVector2Array:
	var adjusted: PackedVector2Array = PackedVector2Array()
	var imperfection: float = clampf(1.0 - quality, 0.0, 1.0)
	for index: int in range(points.size()):
		var local: Vector2 = points[index] - center
		var deterministic_wobble: float = sin(float(index) * 12.73 + 1.9) * imperfection * 0.055
		var chipped: float = imperfection * 0.18 if index == 1 else 0.0
		adjusted.append(center + local * (1.0 + deterministic_wobble - chipped))
	return adjusted

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed_points: PackedVector2Array = points.duplicate()
	if points.size() > 0:
		closed_points.append(points[0])
	return closed_points

func _draw_solid_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		draw_polygon(points, PackedColorArray([color]))

func _draw_final_reveal() -> void:
	var reveal_center: Vector2 = Vector2(640.0, 350.0)
	var t: float = clampf(final_reveal_progress, 0.0, 1.0)
	var eased: float = sin(t * PI * 0.5)
	var reveal_scale: float = 0.18 + eased * 0.82
	var source_max: float = maxf(target_half_size.x, target_half_size.y)
	var trophy_half: Vector2 = target_half_size * (final_gem_radius / maxf(1.0, source_max))
	var clean_outer: PackedVector2Array = _cut_shape_points(target_shape_name, Vector2.ZERO, trophy_half)
	var outer: PackedVector2Array = _quality_adjusted_polygon(clean_outer, Vector2.ZERO, final_quality_score)
	var middle: PackedVector2Array = _scaled_polygon(outer, Vector2.ZERO, 0.70)
	var table: PackedVector2Array = _scaled_polygon(outer, Vector2.ZERO, 0.40)
	var reveal_rotation: float = (1.0 - eased) * -0.20

	# The workbench recedes so the clean, mathematical reward art owns the frame.
	draw_rect(Rect2(235.0, 155.0, 810.0, 470.0), Color(0.035, 0.025, 0.055, 0.94), true)
	draw_rect(Rect2(235.0, 155.0, 810.0, 470.0), Color(gem_glow_color.r, gem_glow_color.g, gem_glow_color.b, 0.65), false, 3.0)
	for ring: int in range(4):
		var halo_radius: float = (final_gem_radius + 42.0) * (1.0 - float(ring) * 0.16) * reveal_scale
		var halo_alpha: float = (0.09 - float(ring) * 0.016) * eased * (0.45 + final_quality_score * 0.55)
		draw_circle(reveal_center, halo_radius, Color(gem_glow_color.r, gem_glow_color.g, gem_glow_color.b, halo_alpha))

	draw_set_transform(reveal_center, reveal_rotation, Vector2(reveal_scale, reveal_scale))
	var contrast: float = 0.55 + final_quality_score * 0.55
	for index: int in range(outer.size()):
		var next: int = (index + 1) % outer.size()
		var outer_quad: PackedVector2Array = PackedVector2Array([outer[index], outer[next], middle[next], middle[index]])
		var outer_multiplier: float = (0.56 if index % 2 == 0 else 1.18) * contrast
		_draw_solid_polygon(outer_quad, _multiply_color(gem_color, outer_multiplier))
		var inner_quad: PackedVector2Array = PackedVector2Array([middle[index], middle[next], table[next], table[index]])
		var inner_multiplier: float = (1.26 if index % 2 == 0 else 0.72) * contrast
		_draw_solid_polygon(inner_quad, _multiply_color(gem_color, inner_multiplier))
	_draw_solid_polygon(table, gem_color.lerp(gem_glow_color, 0.50 + final_quality_score * 0.25))
	var line_alpha: float = 0.35 + final_quality_score * 0.55
	draw_polyline(_closed_polygon(outer), Color(gem_glow_color.r, gem_glow_color.g, gem_glow_color.b, line_alpha), 3.0, true)
	draw_polyline(_closed_polygon(middle), Color(1.0, 1.0, 1.0, line_alpha * 0.62), 1.8, true)
	draw_polyline(_closed_polygon(table), Color(1.0, 1.0, 1.0, line_alpha * 0.82), 2.0, true)
	for index: int in range(outer.size()):
		draw_line(outer[index], table[index], Color(1.0, 1.0, 1.0, line_alpha * 0.50), 1.4, true)

	# A moving four-point specular star sells polish/refraction without pretending
	# to perform physically accurate 3D ray tracing.
	var glint_position: Vector2 = Vector2(cos(final_glint_phase) * trophy_half.x * 0.42, sin(final_glint_phase * 0.73) * trophy_half.y * 0.25)
	var glint_size: float = 10.0 + final_quality_score * 13.0
	draw_line(glint_position - Vector2(glint_size, 0.0), glint_position + Vector2(glint_size, 0.0), Color(1.0, 1.0, 1.0, line_alpha), 3.0, true)
	draw_line(glint_position - Vector2(0.0, glint_size), glint_position + Vector2(0.0, glint_size), Color(1.0, 1.0, 1.0, line_alpha), 3.0, true)
	draw_circle(glint_position, 4.0, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_string(ThemeDB.fallback_font, Vector2(300.0, 205.0), final_gem_name, HORIZONTAL_ALIGNMENT_CENTER, 680.0, 26, gem_glow_color)
	draw_string(ThemeDB.fallback_font, Vector2(300.0, 233.0), "SCORE  %d" % final_score, HORIZONTAL_ALIGNMENT_CENTER, 680.0, 22, Color("ffe39a"))
	draw_string(ThemeDB.fallback_font, Vector2(330.0, 545.0), "OVERALL QUALITY  %d%%" % roundi(final_quality_score * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 620.0, 20, Color("ffe39a"))
	draw_string(ThemeDB.fallback_font, Vector2(330.0, 575.0), "EXTRACTION %d%%    CUT %d%%    TUNE %d%%    TIME %d%%" % [roundi(final_exposure_score * 100.0), roundi(final_cut_score * 100.0), roundi(resonance_completion_accuracy * 100.0), roundi(final_time_score * 100.0)], HORIZONTAL_ALIGNMENT_CENTER, 620.0, 15, Color("d7cedf"))
	var limit_color: Color = Color("91f0c0") if final_rank_name == "MASTERWORK" else Color("ff8178")
	var limit_text: String = "MASTERWORK STANDARD MET" if final_rank_name == "MASTERWORK" else "RANK LIMITED BY: %s" % final_limiting_stage
	draw_string(ThemeDB.fallback_font, Vector2(330.0, 604.0), limit_text, HORIZONTAL_ALIGNMENT_CENTER, 620.0, 14, limit_color)

func _draw_waveforms() -> void:
	var exposure: float = gem_exposure_ratio()
	var erratic_weight: float = _resonance_erratic_weight(exposure)
	var target_points: PackedVector2Array = PackedVector2Array()
	var player_points: PackedVector2Array = PackedVector2Array()
	for index: int in range(101):
		var x: float = 680.0 + index * 5.0
		var normalized: float = float(index) / 100.0
		target_points.append(Vector2(x, 340.0 - sin(normalized * TAU * (1.0 + target_frequency * 2.0)) * (35.0 + target_amplitude * 35.0)))
		player_points.append(Vector2(x, 340.0 - sin(normalized * TAU * (1.0 + resonance_frequency * 2.0)) * (35.0 + resonance_amplitude * 35.0)))
	draw_rect(Rect2(665.0, 235.0, 520.0, 210.0), Color("1b1524"), true)
	draw_line(Vector2(680.0, 340.0), Vector2(1180.0, 340.0), Color(0.45, 0.38, 0.5, 0.45), 1.0)
	draw_polyline(target_points, Color(1.0, 0.35, 0.30, 0.95), 4.0)
	draw_polyline(player_points, Color(0.4, 0.95, 0.85, 0.95), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(665.0, 225.0), "TARGET F %.2f A %.2f    MOTION %d%%    NOW %d%%    SYNC %.1f/%.0fs" % [target_frequency, target_amplitude, roundi(erratic_weight * 100.0), roundi(_alignment_score() * 100.0), resonance_good_time, resonance_hold_target_seconds], HORIZONTAL_ALIGNMENT_LEFT, 520.0, 14, Color(0.95, 0.72, 0.72))

func _close() -> void:
	closed.emit()

class_name GemJamAudio extends Node

## Dedicated Jewel Jam sound layer. Grinding and X-ray remain lightweight
## procedural effects; Resonance uses the authored Resonance Cue and maps its
## linear volume directly to the player's current alignment accuracy.

const SAMPLE_RATE: float = 22050.0
const CONTINUOUS_BUFFER_SECONDS: float = 0.28
const XRAY_LENGTH_SECONDS: float = 1.15
const RESONANCE_CUE: AudioStreamMP3 = preload("res://assets/audio/Gem Jammer/Resonance Cue.mp3")
const SILENT_VOLUME_DB: float = -80.0

@export_category("Mix")
@export_range(0.0, 1.0, 0.01) var grind_volume: float = 0.16
@export_range(0.0, 1.0, 0.01) var xray_volume: float = 0.28

var grind_player: AudioStreamPlayer = null
var resonance_cue_player: AudioStreamPlayer = null
var xray_player: AudioStreamPlayer = null
var grind_playback: AudioStreamGeneratorPlayback = null

var grind_level: float = 0.0
var grind_target_level: float = 0.0
var grind_speed: float = 0.35
var gem_contact: float = 0.0
var resonance_cue_level: float = 0.0
var resonance_active: bool = false
var grind_sample_clock: int = 0
var xray_trigger_count: int = 0
var resonance_cue_start_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	grind_player = _create_generator_player("GentleGrindPlayer", CONTINUOUS_BUFFER_SECONDS)
	xray_player = _create_generator_player("XRayMachinePlayer", XRAY_LENGTH_SECONDS + 0.15)
	resonance_cue_player = AudioStreamPlayer.new()
	resonance_cue_player.name = "ResonanceCuePlayer"
	resonance_cue_player.bus = &"SFX"
	var cue_stream: AudioStreamMP3 = RESONANCE_CUE.duplicate() as AudioStreamMP3
	cue_stream.loop = true
	resonance_cue_player.stream = cue_stream
	resonance_cue_player.volume_db = SILENT_VOLUME_DB
	add_child(resonance_cue_player)
	grind_player.play()
	grind_playback = grind_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_grind_buffer()

func _create_generator_player(player_name: String, buffer_seconds: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"SFX"
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = buffer_seconds
	player.stream = generator
	add_child(player)
	return player

func update_state(delta: float, is_grinding: bool, normalized_wheel_speed: float, gem_contact_ratio: float, is_resonating: bool, tune_accuracy: float) -> void:
	grind_target_level = 1.0 if is_grinding else 0.0
	grind_speed = clampf(normalized_wheel_speed, 0.0, 1.0)
	gem_contact = clampf(gem_contact_ratio, 0.0, 1.0)
	var smoothing: float = 1.0 - exp(-delta * 7.0)
	grind_level = lerpf(grind_level, grind_target_level, smoothing)
	resonance_active = is_resonating
	set_resonance_cue_accuracy(tune_accuracy if is_resonating else 0.0)
	if is_resonating:
		start_resonance_cue()
	else:
		stop_resonance_cue()

func _process(_delta: float) -> void:
	_fill_grind_buffer()

func start_resonance_cue() -> void:
	resonance_active = true
	if resonance_cue_player == null or resonance_cue_player.playing:
		return
	resonance_cue_start_count += 1
	resonance_cue_player.play()

func stop_resonance_cue() -> void:
	resonance_active = false
	resonance_cue_level = 0.0
	if resonance_cue_player == null:
		return
	resonance_cue_player.volume_db = SILENT_VOLUME_DB
	if resonance_cue_player.playing:
		resonance_cue_player.stop()

func set_resonance_cue_accuracy(tune_accuracy: float) -> void:
	resonance_cue_level = clampf(tune_accuracy, 0.0, 1.0)
	if resonance_cue_player == null:
		return
	resonance_cue_player.volume_db = linear_to_db(maxf(0.0001, resonance_cue_level))

func play_xray_machine() -> void:
	xray_trigger_count += 1
	if xray_player == null:
		return
	xray_player.stop()
	xray_player.play()
	var playback: AudioStreamGeneratorPlayback = xray_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var requested_frames: int = int(XRAY_LENGTH_SECONDS * SAMPLE_RATE)
	var frame_count: int = mini(requested_frames, playback.get_frames_available())
	for frame: int in range(frame_count):
		var time: float = float(frame) / SAMPLE_RATE
		var sample: float = _xray_sample(time) * xray_volume
		playback.push_frame(Vector2(sample, sample))

func _fill_grind_buffer() -> void:
	if grind_playback == null:
		return
	var available: int = grind_playback.get_frames_available()
	for frame: int in range(available):
		var time: float = float(grind_sample_clock) / SAMPLE_RATE
		var sample: float = _grind_sample(time)
		grind_playback.push_frame(Vector2(sample, sample))
		grind_sample_clock += 1

func _grind_sample(time: float) -> float:
	var fine_grit: float = _smooth_noise(time, 7.0)
	var broad_grit: float = _smooth_noise(time + 0.317, 24.0)
	var wheel_hz: float = 82.0 + grind_speed * 92.0
	var wheel_tone: float = sin(TAU * wheel_hz * time) * 0.10
	var breathing: float = 0.90 + sin(TAU * 1.7 * time) * 0.10
	var material_softening: float = 1.0 - gem_contact * 0.48
	var sample: float = (fine_grit * 0.42 + broad_grit * 0.34 + wheel_tone) * grind_level * material_softening * breathing * grind_volume
	return clampf(sample, -0.45, 0.45)

func _xray_sample(time: float) -> float:
	var attack: float = clampf(time / 0.025, 0.0, 1.0)
	var release: float = clampf((XRAY_LENGTH_SECONDS - time) / 0.20, 0.0, 1.0)
	var envelope: float = attack * release
	var scanner_chirp: float = sin(TAU * (260.0 + time * 720.0) * time) * 0.30
	var machine_hum: float = sin(TAU * 96.0 * time) * 0.16 + sin(TAU * 192.0 * time) * 0.08
	var gate: float = 1.0 if fmod(time, 0.18) < 0.045 else 0.0
	var computer_beep: float = sin(TAU * 910.0 * time) * gate * 0.24
	var relay_one: float = exp(-absf(time - 0.055) * 95.0) * sin(TAU * 2100.0 * time) * 0.20
	var relay_two: float = exp(-absf(time - 0.72) * 80.0) * sin(TAU * 1650.0 * time) * 0.15
	return clampf((scanner_chirp + machine_hum + computer_beep + relay_one + relay_two) * envelope, -0.85, 0.85)

func _noise_lattice_value(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0

func _smooth_noise(time: float, frames_per_value: float) -> float:
	var lattice_position: float = time * SAMPLE_RATE / frames_per_value
	var left_index: int = floori(lattice_position)
	var blend: float = lattice_position - float(left_index)
	blend = blend * blend * (3.0 - 2.0 * blend)
	return lerpf(_noise_lattice_value(left_index), _noise_lattice_value(left_index + 1), blend)

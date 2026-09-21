class_name ResonanceRippleEffect extends Control

var active: bool = false
var elapsed: float = 0.0
var duration: float = 2.7
var center: Vector2 = Vector2.ZERO
var chime: AudioStreamPlayer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chime = AudioStreamPlayer.new()
	chime.stream = _make_chime()
	chime.bus = &"SFX"
	chime.volume_db = -7.0
	add_child(chime)
	visible = false

func play() -> void:
	center = size * 0.5
	elapsed = 0.0
	active = true
	visible = true
	if chime != null: chime.play()
	queue_redraw()

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	if elapsed >= duration:
		active = false
		visible = false
		queue_redraw()
		return
	queue_redraw()

func _draw() -> void:
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var fade: float = 1.0 - progress
	for ring_index: int in range(3):
		var ring_progress: float = clampf(progress + float(ring_index) * 0.12, 0.0, 1.0)
		var radius: float = 90.0 + ring_progress * 520.0
		var alpha: float = fade * (0.24 - float(ring_index) * 0.05)
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.35, 0.78, 1.0, alpha), 4.0, true)
	draw_circle(center, 120.0 + progress * 220.0, Color(0.25, 0.62, 1.0, fade * 0.035))

func _make_chime() -> AudioStreamWAV:
	var rate: int = 22050
	var duration_seconds: float = 2.7
	var sample_count: int = int(duration_seconds * rate)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for index: int in range(sample_count):
		var time_value: float = float(index) / rate
		var envelope: float = minf(1.0, time_value * 18.0) * clampf((duration_seconds - time_value) * 1.8, 0.0, 1.0)
		# Three gentle rising/falling arcade pulses: bee-woo, bee-woo, bee-ooouu.
		var pulse_time: float = fposmod(time_value, 0.86)
		var pulse_index: int = mini(2, int(time_value / 0.86))
		var pulse_envelope: float = sin(clampf(pulse_time / 0.86, 0.0, 1.0) * PI)
		var sweep: float = sin(pulse_time / 0.86 * PI)
		var base_frequency: float = 760.0 + float(pulse_index) * 35.0
		var frequency: float = base_frequency + sweep * 420.0 - pulse_time * 90.0
		var tone: float = sin(TAU * frequency * time_value) * 0.25 + sin(TAU * frequency * 1.5 * time_value) * 0.08
		data.encode_s16(index * 2, int(clampf(tone * envelope * pulse_envelope, -1.0, 1.0) * 32767.0))
	var wave: AudioStreamWAV = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.stereo = false
	wave.data = data
	return wave

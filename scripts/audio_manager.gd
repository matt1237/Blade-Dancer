class_name AudioManager extends Node

const SAMPLE_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.85

const SFX_BUS: StringName = &"SFX"

var players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for index: int in range(20):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		var generator: AudioStreamGenerator = AudioStreamGenerator.new()
		generator.mix_rate = SAMPLE_RATE
		generator.buffer_length = BUFFER_LENGTH
		player.stream = generator
		player.bus = SFX_BUS
		add_child(player)
		players.append(player)

func play_sfx(sound_name: String, intensity: float = 1.0, pitch_scale: float = 1.0) -> void:
	var index: int = _sound_index(sound_name)
	var player: AudioStreamPlayer = players[index]
	player.stop()
	player.pitch_scale = clampf(pitch_scale, 0.5, 1.5)
	# Smithing transients need to remain readable over the workshop music.
	player.volume_db = 5.0 if sound_name.begins_with("smith_") else 0.0
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null: return
	var frames: int = int(SAMPLE_RATE * _sound_length(sound_name))
	var available: int = mini(frames, playback.get_frames_available())
	for frame: int in range(available):
		var time: float = float(frame) / SAMPLE_RATE
		var sample: float = _sample(sound_name, time, intensity)
		playback.push_frame(Vector2(sample, sample))

func _sound_index(sound_name: String) -> int:
	match sound_name:
		"dash": return 1
		"enemy_hit": return 2
		"player_hit": return 3
		"heartbeat": return 3
		"flesh_hit": return 4
		"sword_clash": return 5
		"parry": return 6
		"slide": return 7
		"chakram_bat": return 8
		"projectile_deflect": return 9
		"forest_step": return 0
		"splash": return 10
		"smith_hiss": return 11
		"smith_ting": return 12
		"smith_donk": return 13
		"smith_sizzle": return 14
		"smith_quench": return 15
		"smith_bellows": return 16
		"grind_land": return 17
		"grind_start": return 18
		"glyph_bell": return 19
		_: return 0

func _sound_length(sound_name: String) -> float:
	match sound_name:
		"sword_clash", "parry": return 0.16
		"slide": return 0.28
		"flesh_hit": return 0.16
		"chakram_bat": return 0.14
		"projectile_deflect": return 0.1
		"forest_step": return 0.075
		"flesh_hit": return 0.13
		"splash": return 0.22
		"smith_hiss": return 0.65
		"smith_ting": return 0.34
		"smith_donk": return 0.18
		"smith_sizzle": return 0.38
		"smith_quench": return 0.78
		"smith_bellows": return 0.58
		"grind_land": return 0.22
		"grind_start": return 0.28
		"glyph_bell": return 0.42
		_: return 0.12

func _noise_lattice_value(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0

func _smooth_air_noise(time: float, frames_per_value: float) -> float:
	var lattice_position: float = time * SAMPLE_RATE / frames_per_value
	var left_index: int = int(floor(lattice_position))
	var blend: float = lattice_position - float(left_index)
	# Smoothstep interpolation removes the crunchy sample-and-hold character.
	blend = blend * blend * (3.0 - 2.0 * blend)
	return lerpf(_noise_lattice_value(left_index), _noise_lattice_value(left_index + 1), blend)

func _sample(sound_name: String, time: float, intensity: float) -> float:
	var envelope_rate: float = 34.0
	if sound_name == "smith_quench": envelope_rate = 3.5
	elif sound_name == "smith_bellows": envelope_rate = 3.2
	elif sound_name == "smith_hiss": envelope_rate = 8.0
	elif sound_name == "smith_sizzle": envelope_rate = 18.0
	elif sound_name == "slide": envelope_rate = 22.0
	elif sound_name in ["clash", "sword_clash", "parry"]: envelope_rate = 30.0
	elif sound_name == "splash": envelope_rate = 16.0
	elif sound_name == "grind_land": envelope_rate = 24.0
	elif sound_name == "grind_start": envelope_rate = 18.0
	var envelope: float = exp(-time * envelope_rate)
	var sample: float = 0.0
	match sound_name:
		"clash", "sword_clash":
			# Heavy, explosive metal collision with deep resonant body and anvil chime
			var low_punch: float = sin(TAU * (140.0 - time * 320.0) * time) * 0.75
			var anvil_ping: float = sin(TAU * 1280.0 * time) * 0.55 + sin(TAU * 2650.0 * time) * 0.35 + sin(TAU * 5800.0 * time) * 0.15
			sample = low_punch + anvil_ping
		"parry":
			# Exclusive sharp electric chime — high crystalline deflection ring
			sample = sin(TAU * 2600.0 * time) * 0.6 + sin(TAU * 5400.0 * time) * 0.45 + sin(TAU * 8200.0 * time) * 0.2
		"slide":
			# Bright rising scrape with a resonant metallic tail: "shiiiing".
			sample = sin(TAU * (1050.0 + time * 3200.0) * time) * 0.42 + sin(TAU * 4700.0 * time) * 0.24 + sin(TAU * 6900.0 * time) * 0.1
		"flesh_hit":
			# Descending low transient with a soft noisy texture: "shhluck".
			sample = sin(TAU * (210.0 - time * 650.0) * time) * 0.62 + sin(TAU * (1250.0 - time * 4200.0) * time) * 0.2 + sin(TAU * 83.0 * time) * 0.18
		"chakram_bat":
			sample = sin(TAU * (700.0 + time * 1400.0) * time) * 0.55 + sin(TAU * 2800.0 * time) * 0.18
		"projectile_deflect":
			sample = sin(TAU * 3200.0 * time) * 0.5 + sin(TAU * 6000.0 * time) * 0.2
		"dash":
			sample = sin(TAU * (260.0 + time * 900.0) * time) * 0.45
		"enemy_hit":
			sample = sin(TAU * 145.0 * time) * 0.65 + sin(TAU * 680.0 * time) * 0.2
		"player_hit":
			sample = sin(TAU * 95.0 * time) * 0.8 + sin(TAU * 430.0 * time) * 0.25
		"heartbeat":
			var beat: float = exp(-time * 38.0) + 0.65 * exp(-maxf(0.0, time - 0.045) * 42.0)
			sample = sin(TAU * 72.0 * time) * beat * 0.72
		"forest_step":
			# Short square-wave blip: deliberately reads as a tiny retro "boop".
			var step_envelope: float = exp(-time * 48.0)
			var step_pitch: float = 260.0 + 90.0 * sin(time * 18.0)
			sample = signf(sin(TAU * step_pitch * time)) * step_envelope * 0.32
		"splash":
			# A clean, cute single "BLOop" — one smooth downward pitch sweep,
			# no noise or percussive texture (that read as a snare, not a bloop).
			var bloop_pitch: float = maxf(150.0, 600.0 - time * 2500.0)
			sample = sin(TAU * bloop_pitch * time) * 0.8
		"smith_hiss":
			# Filtered synthetic steam: a bright hiss with a soft metallic ring.
			var hiss_noise: float = sin(TAU * 3311.0 * time) * 0.35 + sin(TAU * 4877.0 * time) * 0.2 + sin(TAU * 7123.0 * time) * 0.12
			var hiss_tone: float = sin(TAU * 980.0 * time) * 0.18
			sample = hiss_noise + hiss_tone
		"smith_ting":
			# Strong, unmistakable anvil ring with a lower body and bright tail.
			sample = sin(TAU * 1180.0 * time) * 0.78 + sin(TAU * 2380.0 * time) * 0.42 + sin(TAU * 4720.0 * time) * 0.2
		"smith_donk":
			sample = sin(TAU * 170.0 * time) * 0.72 + sin(TAU * 310.0 * time) * 0.22
		"smith_sizzle":
			var sizzle_noise: float = sin(TAU * 2600.0 * time) * 0.28 + sin(TAU * 5100.0 * time) * 0.2 + sin(TAU * 7300.0 * time) * 0.12
			sample = sizzle_noise + sin(TAU * 520.0 * time) * 0.2
		"smith_quench":
			# Broadband steam, deliberately noise-based so it cannot read as a
			# pitched hammer ring. Fast attack, then a long TSHHHhh tail.
			var quench_frame: float = float(int(time * SAMPLE_RATE))
			var quench_noise: float = fposmod(sin(quench_frame * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
			var quench_attack: float = clampf(time / 0.025, 0.0, 1.0)
			var steam_body: float = sin(TAU * 420.0 * time) * 0.12 + sin(TAU * 860.0 * time) * 0.08
			sample = (quench_noise * 0.82 + steam_body) * quench_attack
		"smith_bellows":
			# A soft leather-bellows exhale: two smoothly interpolated air layers,
			# no descending bass tone and no stepped retro-noise artifacts.
			var broad_air: float = _smooth_air_noise(time, 18.0)
			var soft_air: float = _smooth_air_noise(time + 0.137, 43.0)
			var bellows_attack: float = clampf(time / 0.09, 0.0, 1.0)
			var breath_pulse: float = 0.88 + sin(TAU * 2.1 * time) * 0.12
			sample = (broad_air * 0.48 + soft_air * 0.34) * bellows_attack * breath_pulse
		"grind_land":
			# Short metallic release click.
			var land_click: float = sin(TAU * 2600.0 * time) * 0.5 + sin(TAU * 4100.0 * time) * 0.3
			var land_knock: float = sin(TAU * (520.0 - time * 900.0) * time) * 0.5
			sample = land_click + land_knock
		"grind_start":
			# Cutlery clang at contact: two fixed, bright metal partials
			# with a short low strike underneath. No pitch sweep or wobble.
			var clang_low: float = sin(TAU * 430.0 * time) * 0.35
			var clang_mid: float = sin(TAU * 1730.0 * time) * 0.4
			var clang_high: float = sin(TAU * 2870.0 * time) * 0.28
			sample = clang_low + clang_mid + clang_high
		"glyph_bell":
			# A clean, bright bell strike with a soft resonant lower partial.
			var bell_body: float = sin(TAU * 420.0 * time) * 0.34
			var bell_fundamental: float = sin(TAU * 980.0 * time) * 0.62
			var bell_shimmer: float = sin(TAU * 2360.0 * time) * 0.34 + sin(TAU * 4120.0 * time) * 0.16
			sample = bell_body + bell_fundamental + bell_shimmer
	return clampf(sample * envelope * intensity, -0.95, 0.95)

extends Node

# Save-safe: never boot Main or Player._ready; all production audio calls use
# real AudioManager / MusicDirector, and enemy scenes keep their real hooks.
var audio_manager: AudioManager
var emitted_deaths: int = 0
var audit_music_volume: float = 1.0

class ChargeTarget extends Node2D:
	var visual_style: String = "procedural"

func audio_paths(directory: String = "res://assets/audio") -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	assert(dir != null)
	for file: String in dir.get_files():
		if file.get_extension().to_lower() in ["mp3", "wav", "ogg", "flac", "opus", "aiff"]:
			result.append(directory.path_join(file))
	for subdir: String in dir.get_directories():
		result.append_array(audio_paths(directory.path_join(subdir)))
	result.sort()
	return result

func test_all_audio_imports_decode() -> void:
	var paths: Array[String] = audio_paths()
	assert(paths.size() == 55, "Update the reviewed inventory when adding audio.")
	for path: String in paths:
		assert(FileAccess.file_exists(path + ".import"), "Missing importer: " + path)
		var stream: AudioStream = load(path) as AudioStream
		assert(stream != null and stream.get_length() > 0.0, "Invalid stream: " + path)
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		assert(playback != null, "Cannot instantiate: " + path)
		var peak: float = 0.0
		# Exercise decoder at beginning, middle and near end, not just the header.
		for position: float in [0.0, stream.get_length() * 0.5, maxf(0.0, stream.get_length() - 0.2)]:
			playback.start(position)
			var frames: PackedVector2Array = playback.mix_audio(1.0, 4096)
			assert(not frames.is_empty(), "No decoded frames: " + path)
			for frame: Vector2 in frames:
				assert(is_finite(frame.x) and is_finite(frame.y), "Invalid PCM: " + path)
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
			playback.stop()
		assert(peak > 0.00001, "Silent decoded samples: " + path)
		print("AUDIO ASSET %.3fs peak=%.4f %s" % [stream.get_length(), peak, path])
	print("AUDIO IMPORT PASS: %d streams decoded" % paths.size())

func _start_manager() -> void:
	audio_manager = AudioManager.new()
	add_child(audio_manager)

func _stop_clips() -> void:
	for voice: AudioStreamPlayer in audio_manager.combat_clip_players:
		voice.stop()

func _assert_clip_started(pool: Array) -> void:
	var playing: int = 0
	for voice: AudioStreamPlayer in audio_manager.combat_clip_players:
		if voice.playing:
			playing += 1
			assert(voice.stream in pool and voice.stream.get_length() > 0.0)
			await get_tree().create_timer(0.12).timeout
			assert(voice.get_playback_position() > 0.0, "Playback did not advance")
	assert(playing > 0, "Event failed to start a pooled voice")

func test_recorded_events_and_pool_reuse() -> void:
	_start_manager()
	for category: String in AudioManager.COMBAT_CLIP_POOLS:
		_stop_clips()
		audio_manager.play_combat_clip(category)
		await _assert_clip_started(AudioManager.COMBAT_CLIP_POOLS[category])
		print("AUDIO EVENT PASS combat=" + category)
	var cursor: int = audio_manager.combat_clip_player_cursor
	audio_manager.play_combat_clip("player_attack")
	assert(audio_manager.combat_clip_player_cursor == cursor, "Attack cooldown regressed")
	for category: String in AudioManager.ENEMY_DEATH_CLIPS:
		_stop_clips()
		audio_manager.play_enemy_death(category)
		await _assert_clip_started(AudioManager.ENEMY_DEATH_CLIPS[category])
		print("AUDIO EVENT PASS death=" + category)
	# Force all recorded samples through the real pooled helper; randomness must
	# not hide one bad clip. Then overflow the pool and release it while playing.
	for pools: Dictionary in [AudioManager.COMBAT_CLIP_POOLS, AudioManager.ENEMY_DEATH_CLIPS]:
		for pool: Array in pools.values():
			for clip: AudioStream in pool:
				_stop_clips()
				audio_manager._play_pooled_clip(clip, 1.0, 0.0)
				await _assert_clip_started([clip])
	for index: int in range(30):
		audio_manager.play_enemy_death("goblin_things")
	assert(audio_manager.combat_clip_players.size() == 12)
	audio_manager.queue_free()
	await get_tree().process_frame
	assert(not is_instance_valid(audio_manager))

func play_sfx(sound_name: String, intensity: float = 1.0, pitch_scale: float = 1.0) -> void:
	audio_manager.play_sfx(sound_name, intensity, pitch_scale)

func play_enemy_death(category: String, pitch_scale: float = 1.0) -> void:
	emitted_deaths += 1
	audio_manager.play_enemy_death(category, pitch_scale)

func test_real_enemy_death_routes() -> void:
	_start_manager()
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	for identity: String in ["turkey", "wolf", "ogre", "goblin", "sword_goblin", "archer_goblin", "bug", "goblin_bomber", "goblin_shaman"]:
		var routed: bool = false
		# Canonical death probability is intentional; retry fresh enemies instead
		# of modifying their tuning or pretending every kill must make a cry.
		for attempt: int in range(30):
			_stop_clips()
			var enemy: Enemy = load("res://scenes/enemies/" + identity + ".tscn").instantiate() as Enemy
			enemy.set_meta("training_no_drops", true)
			add_child(enemy)
			enemy.set_physics_process(false)
			assert(AudioManager.ENEMY_DEATH_CLIPS.has(enemy.death_sound_category))
			var pool: Array = AudioManager.ENEMY_DEATH_CLIPS[enemy.death_sound_category]
			var before: int = emitted_deaths
			enemy.take_damage(enemy.max_health + 1.0)
			if emitted_deaths > before:
				await _assert_clip_started(pool)
				routed = true
			await get_tree().process_frame
			assert(not is_instance_valid(enemy), "Death must release its enemy without stopping independent audio")
			if routed: break
		assert(routed, "No death event: " + identity)
		print("AUDIO ENEMY PASS " + identity)
	get_tree().current_scene = previous_scene
	audio_manager.queue_free()
	await get_tree().process_frame

func test_turkey_real_charge_bark() -> void:
	_start_manager()
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var target: ChargeTarget = ChargeTarget.new()
	add_child(target)
	var turkey: Turkey = preload("res://scenes/enemies/turkey.tscn").instantiate() as Turkey
	add_child(turkey)
	turkey.set_physics_process(false)
	turkey.player_ref = target
	var before: int = emitted_deaths
	for attempt: int in range(30):
		turkey.windup = 0.0
		turkey.charge_distance_left = 0.0
		turkey.charge_cooldown = 0.0
		turkey._run_concrete_ai(0.016)
		if emitted_deaths > before: break
	assert(emitted_deaths > before, "Turkey windup bark did not route to AudioManager")
	await _assert_clip_started(AudioManager.ENEMY_DEATH_CLIPS["turkey_death"])
	print("AUDIO TURKEY CHARGE PASS")
	turkey.queue_free()
	target.queue_free()
	get_tree().current_scene = previous_scene
	audio_manager.queue_free()
	await get_tree().process_frame

func test_synth_and_real_player_slide() -> void:
	_start_manager()
	assert(audio_manager._sound_index("clash") == audio_manager._sound_index("sword_clash"), "Clash alias must use the metal voice, not the footstep voice")
	for event: String in ["clash", "sword_clash", "parry", "slide", "flesh_hit", "enemy_hit", "player_hit", "dash", "heartbeat", "chakram_bat", "projectile_deflect", "forest_step", "splash", "smith_hiss", "smith_ting", "smith_donk", "smith_sizzle", "smith_quench", "smith_bellows", "grind_land", "grind_start", "glyph_bell"]:
		var peak: float = 0.0
		for frame: int in range(int(AudioManager.SAMPLE_RATE * audio_manager._sound_length(event))):
			peak = maxf(peak, absf(audio_manager._sample(event, frame / AudioManager.SAMPLE_RATE, 1.0)))
		assert(peak > 0.001, "Unimplemented synthesized event " + event)
		audio_manager.play_sfx(event)
		assert(audio_manager.players[audio_manager._sound_index(event)].playing)
	print("AUDIO SYNTH PASS: 22 event names")
	# Player is intentionally never put in tree: its normal _ready saves presets.
	var player: Player = Player.new()
	player._setup_slide_audio_player()
	var scrape: AudioStreamPlayer = player.slide_audio_player
	player.remove_child(scrape)
	add_child(scrape)
	player._play_slide_scrape_audio(300.0)
	assert(scrape.playing and scrape.stream == Player.METAL_SCRAPE_AUDIO)
	await get_tree().create_timer(0.12).timeout
	assert(scrape.get_playback_position() > 0.0)
	print("AUDIO PLAYER SLIDE PASS: " + scrape.stream.resource_path)
	player.free()
	scrape.queue_free()
	audio_manager.queue_free()
	await get_tree().process_frame

func test_music_playlists_start_and_advance() -> void:
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.bus = &"Music"
	add_child(voice)
	var director: MusicDirector = MusicDirector.new()
	add_child(director)
	director.setup(voice)
	director.set_music_volume(audit_music_volume)
	for mode: String in ["home", "forest", "combat", "forge", "boss"]:
		match mode:
			"home": pass
			"forest":
				director.set_adventure_zone("forest")
				director.enter_adventure()
			"combat":
				director.set_adventure_zone("chasm")
				director.enter_home()
				await get_tree().create_timer(0.8).timeout
				director.enter_adventure()
			"forge": director.enter_forge()
			"boss": director.enter_boss()
		await get_tree().create_timer(0.8).timeout
		assert(voice.playing and voice.get_playback_position() > 0.0)
		director._on_music_finished()
		assert(voice.playing and voice.stream != null)
		print("AUDIO MUSIC PASS " + mode + " " + voice.stream.resource_path)
	director.queue_free()
	voice.queue_free()
	await get_tree().process_frame

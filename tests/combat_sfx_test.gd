class_name CombatSfxTest extends Node

const COMBAT_CATEGORIES: Array[String] = ["low_health", "player_attack", "sword_swing", "parry_clash"]

func test_recorded_combat_clips_use_stream_playback_without_changing_generated_sfx() -> void:
	var audio_manager: AudioManager = AudioManager.new()
	add_child(audio_manager)
	assert(audio_manager.combat_clip_players.size() == AudioManager.COMBAT_CLIP_PLAYER_COUNT)
	for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
		assert(clip_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Recorded combat MP3 players must explicitly use Stream playback on Web.")
	for generated_player: AudioStreamPlayer in audio_manager.players:
		assert(generated_player.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT, "Do not alter the unrelated procedural SFX playback in this fix.")
	audio_manager.free()

func test_low_health_cue_only_triggers_when_a_hit_crosses_twenty_percent() -> void:
	assert(Player.low_health_hit_threshold_crossed(30.0, 20.0, 100.0), "A hit reaching exactly 20% health should trigger the warning cue.")
	assert(Player.low_health_hit_threshold_crossed(25.0, 19.0, 100.0), "A hit that drops health below 20% should trigger the warning cue.")
	assert(not Player.low_health_hit_threshold_crossed(19.0, 10.0, 100.0), "Further hits while already critical should not repeat the threshold-crossing cue.")
	assert(not Player.low_health_hit_threshold_crossed(30.0, 25.0, 100.0), "A hit that leaves health above 20% should not trigger the cue.")

func test_sword_swing_cue_plays_once_when_drive_crosses_medium_threshold() -> void:
	assert(Player.stroke_drive_crossed_threshold(0.49, 0.50, Player.SWORD_SWING_SFX_DRIVE_THRESHOLD), "Crossing medium drive should qualify the sword whoosh.")
	assert(not Player.stroke_drive_crossed_threshold(0.50, 0.70, Player.SWORD_SWING_SFX_DRIVE_THRESHOLD), "Continuing above medium drive should not retrigger the cue on the same stroke.")
	assert(not Player.stroke_drive_crossed_threshold(0.40, 0.49, Player.SWORD_SWING_SFX_DRIVE_THRESHOLD), "Drive below medium should stay quiet.")

func test_sword_swing_clips_are_reduced_by_thirty_four_percent() -> void:
	var audio_manager: AudioManager = AudioManager.new()
	add_child(audio_manager)
	audio_manager.play_combat_clip("sword_swing")
	assert(is_equal_approx(audio_manager.combat_clip_players[0].volume_db, AudioManager.SWORD_SWING_VOLUME_DB), "Sword swing clips should use the -3.61 dB level corresponding to 66% linear volume.")
	audio_manager.play_combat_clip("parry_clash")
	assert(is_zero_approx(audio_manager.combat_clip_players[1].volume_db), "The sword-swing volume reduction must not affect parry/clash clips.")
	audio_manager.free()

func test_player_attack_noise_has_one_shared_five_second_cooldown() -> void:
	var audio_manager: AudioManager = AudioManager.new()
	add_child(audio_manager)
	var before_first_play_msec: int = Time.get_ticks_msec()
	audio_manager.play_combat_clip("player_attack")
	var cursor_after_first_play: int = audio_manager.combat_clip_player_cursor
	var ready_at_msec: int = audio_manager.player_attack_clip_ready_at_msec
	assert(ready_at_msec >= before_first_play_msec + AudioManager.PLAYER_ATTACK_CLIP_COOLDOWN_MSEC, "A played attack noise should start its five-second cooldown.")
	audio_manager.play_combat_clip("player_attack")
	assert(audio_manager.combat_clip_player_cursor == cursor_after_first_play, "Attack noises during cooldown must not start another clip.")
	audio_manager.play_combat_clip("sword_swing")
	assert(audio_manager.combat_clip_player_cursor != cursor_after_first_play, "The attack-noise cooldown must not suppress unrelated SFX categories.")
	audio_manager.player_attack_clip_ready_at_msec = Time.get_ticks_msec() - 1
	var cursor_before_reenabled_attack: int = audio_manager.combat_clip_player_cursor
	audio_manager.play_combat_clip("player_attack")
	assert(audio_manager.combat_clip_player_cursor != cursor_before_reenabled_attack, "Attack noises should play again once the five-second cooldown expires.")
	audio_manager.free()

func test_each_combat_clip_category_plays_a_clip_from_its_pool() -> void:
	var audio_manager: AudioManager = AudioManager.new()
	add_child(audio_manager)
	for category: String in COMBAT_CATEGORIES:
		for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
			clip_player.stop()
			clip_player.stream = null
		audio_manager.play_combat_clip(category)
		var assigned_channel_count: int = 0
		for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
			if clip_player.stream != null:
				assigned_channel_count += 1
		assert(assigned_channel_count > 0, "Each event category must assign an imported clip to a playback channel.")
	audio_manager.free()

func test_every_enemy_archetype_maps_to_a_death_cry_pool() -> void:
	var scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.SWORD_GOBLIN_SCENE, WaveSpawner.ARCHER_GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]
	for scene: PackedScene in scenes:
		var enemy: Enemy = scene.instantiate() as Enemy
		enemy._configure_concrete_enemy()
		assert(not enemy.death_sound_category.is_empty(), "%s must declare a death-cry pool." % enemy.spawn_identity)
		assert(AudioManager.ENEMY_DEATH_CLIPS.has(enemy.death_sound_category), "%s's pool must exist in the audio manager." % enemy.spawn_identity)
		var pool: Array = AudioManager.ENEMY_DEATH_CLIPS[enemy.death_sound_category]
		assert(not pool.is_empty(), "%s's death-cry pool must not be empty." % enemy.spawn_identity)
		enemy.free()

func test_enemy_death_cry_plays_on_most_but_not_every_kill() -> void:
	assert(is_equal_approx(Enemy.DEATH_SOUND_CHANCE, 0.85), "Enemy death audio should play 85% of the time.")
	assert(Enemy.death_sound_should_play(0.0), "A roll at the bottom of the range plays the cry.")
	assert(Enemy.death_sound_should_play(0.8499), "A roll below the threshold plays the cry.")
	assert(not Enemy.death_sound_should_play(0.85), "A roll at the threshold stays silent.")
	assert(not Enemy.death_sound_should_play(0.9999), "The top of the range stays silent.")

func test_goblin_family_shares_one_pool_with_distinct_pitch_character() -> void:
	# Spear Goblin, Sword Goblin, Archer Goblin, and Shield Ogre share "Goblin Things"
	# but are pitched apart so they read as different creatures from the same folder.
	var ogre: Ogre = WaveSpawner.OGRE_SCENE.instantiate() as Ogre
	var archer: ArcherGoblin = WaveSpawner.ARCHER_GOBLIN_SCENE.instantiate() as ArcherGoblin
	var sword: SwordGoblin = WaveSpawner.SWORD_GOBLIN_SCENE.instantiate() as SwordGoblin
	var spear: Goblin = WaveSpawner.GOBLIN_SCENE.instantiate() as Goblin
	for enemy: Enemy in [ogre, archer, sword, spear]: enemy._configure_concrete_enemy()
	for enemy: Enemy in [ogre, archer, sword, spear]:
		assert(enemy.death_sound_category == "goblin_things", "%s must share the Goblin Things pool." % enemy.spawn_identity)
	assert(ogre.death_sound_pitch < 1.0, "The Shield Ogre must be pitched deeper.")
	assert(archer.death_sound_pitch > 1.0, "The Archer Goblin must be pitched higher.")
	assert(is_equal_approx(spear.death_sound_pitch, 1.0) and is_equal_approx(sword.death_sound_pitch, 1.0), "The melee goblins stay at their natural pitch.")
	ogre.free()
	archer.free()
	sword.free()
	spear.free()

func test_enemy_death_cry_picks_a_clip_and_clamps_its_pitch() -> void:
	var audio_manager: AudioManager = AudioManager.new()
	add_child(audio_manager)
	for attempt: int in range(5):
		for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
			clip_player.stop()
			clip_player.stream = null
		audio_manager.play_enemy_death("goblin_things", 1.0)
		var played: AudioStreamPlayer = null
		for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
			if clip_player.stream != null: played = clip_player
		assert(played != null, "A known pool must assign an imported clip to a playback channel.")
		assert(played.pitch_scale >= AudioManager.ENEMY_DEATH_PITCH_MIN - 0.001 and played.pitch_scale <= AudioManager.ENEMY_DEATH_PITCH_MAX + 0.001, "A neutral death pitch must stay inside the anti-metallic clamp.")
	# An extreme base pitch is clamped rather than passed through — that clamp is what
	# keeps the recorded voice from turning metallic/scratchy.
	for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
		clip_player.stop()
		clip_player.stream = null
	audio_manager.play_enemy_death("goblin_things", 2.0)
	for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
		if clip_player.stream != null:
			assert(is_equal_approx(clip_player.pitch_scale, AudioManager.ENEMY_DEATH_PITCH_MAX), "A too-high base pitch must clamp to the maximum.")
	# An unknown pool is a silent no-op, never an error.
	audio_manager.play_enemy_death("does_not_exist", 1.0)
	# Silence the pooled players before teardown so no playback outlives the manager.
	for clip_player: AudioStreamPlayer in audio_manager.combat_clip_players:
		clip_player.stop()
		clip_player.stream = null
	audio_manager.free()

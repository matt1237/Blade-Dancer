class_name CombatSfxTest extends Node

const COMBAT_CATEGORIES: Array[String] = ["low_health", "player_attack", "sword_swing", "parry_clash"]

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

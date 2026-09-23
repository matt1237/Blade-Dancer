class_name MusicDirectorBossThemeTest extends Node

var _spawned_players: Array[AudioStreamPlayer] = []

func _make_director() -> MusicDirector:
	var director: MusicDirector = MusicDirector.new()
	add_child(director)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/music/Combat/forest_combat_theme.mp3")
	add_child(player)
	_spawned_players.append(player)
	director.setup(player)
	return director

func _cleanup(director: MusicDirector) -> void:
	director.free()
	for player: AudioStreamPlayer in _spawned_players:
		if is_instance_valid(player): player.free()
	_spawned_players.clear()

func test_boss_tracks_are_rift_combo_riot_then_horn_of_the_void() -> void:
	assert(MusicDirector.BOSS_TRACKS.size() == 2, "The boss theme must be exactly two tracks.")
	assert(MusicDirector.BOSS_TRACKS[0].resource_path.ends_with("Rift Combo Riot.mp3"), "Rift Combo Riot must play first, the instant Zungar stops talking.")
	assert(MusicDirector.BOSS_TRACKS[1].resource_path.ends_with("Horn of the Void.mp3"), "Horn of the Void must play second.")

func test_enter_boss_starts_with_rift_combo_riot_unlooped() -> void:
	var director: MusicDirector = _make_director()
	director.enter_boss()
	await get_tree().create_timer(0.9).timeout
	assert(director.mode == MusicDirector.Mode.BOSS, "enter_boss() should switch MusicDirector into its BOSS mode.")
	var current_stream: AudioStream = director.music_player.stream
	assert(current_stream != null and current_stream.resource_path.ends_with("Rift Combo Riot.mp3"), "Boss theme must start on Rift Combo Riot.")
	assert(not (current_stream as AudioStreamMP3).loop, "Each boss track must play once (not single-stream loop) so it can hand off to the next track.")
	_cleanup(director)

func test_boss_theme_advances_and_wraps_forever() -> void:
	var director: MusicDirector = _make_director()
	director.enter_boss()
	await get_tree().create_timer(0.9).timeout
	director.boss_track_index = 0
	director._on_music_finished()
	assert(director.boss_track_index == 1, "First finish should advance from Rift Combo Riot to Horn of the Void.")
	assert(director.music_player.stream.resource_path.ends_with("Horn of the Void.mp3"), "Second track must be Horn of the Void.")
	director._on_music_finished()
	assert(director.boss_track_index == 0, "The pair must loop back to Rift Combo Riot instead of stopping.")
	assert(director.music_player.stream.resource_path.ends_with("Rift Combo Riot.mp3"), "Looping back should replay Rift Combo Riot.")
	_cleanup(director)

func test_main_starts_boss_theme_only_after_the_intro_dialogue_finishes() -> void:
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var intro_index: int = main_source.find("await _play_zungar_intro()")
	var enter_boss_index: int = main_source.find("music_director.call(\"enter_boss\")")
	var begin_fight_index: int = main_source.find("zungar_boss.begin_boss_fight()")
	assert(intro_index != -1 and enter_boss_index != -1 and begin_fight_index != -1, "Expected boss intro/music/fight-start calls were not found in main.gd.")
	assert(intro_index < enter_boss_index, "Boss music must start after the intro dialogue awaits, not before or during it.")
	assert(enter_boss_index < begin_fight_index, "Boss music should start before the fight officially begins.")

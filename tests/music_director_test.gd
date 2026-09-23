class_name MusicDirectorTest extends Node

const MUSIC_DIRECTOR_SCRIPT: Script = preload("res://scripts/audio/music_director.gd")

func test_main_music_uses_stream_playback_without_changing_sfx() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node = scene.instantiate()
	var player: AudioStreamPlayer = main.get_node("AudioStreamPlayer") as AudioStreamPlayer
	assert(player.playback_type == 1, "Web music should use Stream playback rather than the default Sample playback.")
	main.free()

func test_home_playlist_uses_all_tracks_before_repeating() -> void:
	var director: Node = MUSIC_DIRECTOR_SCRIPT.new() as Node
	var first_cycle: Array[AudioStream] = []
	for index: int in range(int(director.HOME_TRACKS.size())): first_cycle.append(director._next_home_track())
	assert(first_cycle.size() == director.HOME_TRACKS.size())
	for first_index: int in range(first_cycle.size()):
		for second_index: int in range(first_index + 1, first_cycle.size()):
			assert(first_cycle[first_index] != first_cycle[second_index], "Every Home song should play once before the shuffle bag refills.")
	var first_after_refill: AudioStream = director._next_home_track()
	assert(first_after_refill != first_cycle.back(), "A new shuffle cycle must not immediately repeat the previous song.")
	director.free()

func test_audio_unlock_does_not_restart_track_on_repeated_input() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/music/Combat/forest_combat_theme.mp3") as AudioStream
	add_child(player)
	var director: MusicDirector = MUSIC_DIRECTOR_SCRIPT.new() as MusicDirector
	add_child(director)
	director.setup(player)
	director.unlock_audio()
	player.seek(1.0)
	director.unlock_audio()
	assert(player.get_playback_position() >= 0.9, "Repeated input must not restart the playing song.")
	director.free()
	player.free()

func test_manual_music_retry_works_after_automatic_unlock_was_used() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/music/Combat/forest_combat_theme.mp3") as AudioStream
	add_child(player)
	var director: MusicDirector = MUSIC_DIRECTOR_SCRIPT.new() as MusicDirector
	add_child(director)
	director.setup(player)
	director.unlock_audio()
	player.seek(1.0)
	var message: String = director.retry_music_from_button()
	assert(message.contains("Music requested"))
	assert(player.get_playback_position() < 0.5, "The explicit button must retry even after automatic unlock was attempted.")
	director.free()
	player.free()

func test_music_volume_scales_current_and_forge_tracks() -> void:
	var director: Node = MUSIC_DIRECTOR_SCRIPT.new() as Node
	director.set_music_volume(0.5)
	assert(is_equal_approx(director.music_volume_linear, 0.5))
	director.set_forge_volume(0.6)
	assert(is_equal_approx(director._music_volume_db(), linear_to_db(0.5)))
	director.free()

func test_home_and_adventure_modes_select_expected_music() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/music/Combat/forest_combat_theme.mp3") as AudioStream
	add_child(player)
	var director: Node = MUSIC_DIRECTOR_SCRIPT.new() as Node
	add_child(director)
	director.setup(player)
	director.enter_home()
	assert(director.mode == 1)
	assert(director.current_home_index >= 0)
	director.enter_adventure()
	assert(director.mode == 0)
	var expected_combat_stream: AudioStream = load("res://assets/audio/music/Combat/forest_combat_theme.mp3") as AudioStream
	assert(director.combat_stream == expected_combat_stream)
	director.free()
	player.free()

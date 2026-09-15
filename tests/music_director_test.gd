class_name MusicDirectorTest extends Node

const MUSIC_DIRECTOR_SCRIPT: Script = preload("res://scripts/audio/music_director.gd")

func test_home_playlist_uses_all_tracks_before_repeating() -> void:
	var director: Node = MUSIC_DIRECTOR_SCRIPT.new() as Node
	var first_cycle: Array[AudioStream] = []
	for index: int in range(int(director.HOME_TRACKS.size())): first_cycle.append(director._next_home_track())
	assert(first_cycle.size() == 3)
	assert(first_cycle[0] != first_cycle[1] and first_cycle[0] != first_cycle[2] and first_cycle[1] != first_cycle[2], "Every Home song should play once before the shuffle bag refills.")
	var first_after_refill: AudioStream = director._next_home_track()
	assert(first_after_refill != first_cycle[2], "A new shuffle cycle must not immediately repeat the previous song.")
	director.free()

func test_music_volume_scales_current_and_forge_tracks() -> void:
	var director: Node = MUSIC_DIRECTOR_SCRIPT.new() as Node
	director.set_music_volume(0.5)
	assert(is_equal_approx(director.music_volume_linear, 0.5))
	director.set_forge_volume(0.6)
	assert(is_equal_approx(director._music_volume_db(), linear_to_db(0.5)))
	director.free()

func test_home_and_adventure_modes_select_expected_music() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load("res://scenes/New_Project.mp3") as AudioStream
	add_child(player)
	var director: Node = MUSIC_DIRECTOR_SCRIPT.new() as Node
	add_child(director)
	director.setup(player)
	director.enter_home()
	assert(director.mode == 1)
	assert(director.current_home_index >= 0)
	director.enter_adventure()
	assert(director.mode == 0)
	var expected_combat_stream: AudioStream = load("res://scenes/New_Project.mp3") as AudioStream
	assert(director.combat_stream == expected_combat_stream)
	director.free()
	player.free()

class_name MusicDirector extends Node

const HOME_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/Home/Happy Home.mp3"),
	preload("res://assets/audio/music/Home/Lanterns at Dusk.mp3"),
	preload("res://assets/audio/music/Home/Mossy Hearth.mp3"),
]
const FORGE_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/Forge/Forge of Moss and Iron.mp3"),
	preload("res://assets/audio/music/Forge/Runes at the Forge.mp3"),
]
## Boss encounter theme: plays in this fixed order (not shuffled), alternating
## forever once started -- Rift Combo Riot first (starts the instant the boss
## stops talking), then Horn of the Void, then back to Rift Combo Riot, etc.
const BOSS_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/Elite&Boss Tracks/Rift Combo Riot.mp3"),
	preload("res://assets/audio/music/Elite&Boss Tracks/Horn of the Void.mp3"),
]
const FADE_DURATION: float = 0.35
const SILENT_VOLUME_DB: float = -32.0

enum Mode { COMBAT, HOME, FORGE, SILENT, BOSS }

var music_player: AudioStreamPlayer = null
var combat_stream: AudioStream = null
var mode: Mode = Mode.COMBAT
var home_shuffle_bag: Array[int] = []
var forge_shuffle_bag: Array[int] = []
var current_home_index: int = -1
var current_forge_index: int = -1
var boss_track_index: int = -1
var transition_serial: int = 0
var music_volume_linear: float = 1.0
var forge_volume_linear: float = 0.60

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(player: AudioStreamPlayer) -> void:
	music_player = player
	combat_stream = music_player.stream
	_set_stream_loop(combat_stream, true)
	if not music_player.finished.is_connected(_on_music_finished): music_player.finished.connect(_on_music_finished)
	if not music_player.playing and music_player.is_inside_tree(): music_player.play()

func set_music_volume(value: float) -> void:
	music_volume_linear = clampf(value, 0.0, 1.0)
	if music_player == null or mode == Mode.SILENT:
		return
	music_player.volume_db = _current_music_volume_db()

func set_forge_volume(value: float) -> void:
	forge_volume_linear = clampf(value, 0.0, 1.0)
	if music_player != null and mode == Mode.FORGE:
		music_player.volume_db = _current_music_volume_db()

func _music_volume_db() -> float:
	return linear_to_db(maxf(0.0001, music_volume_linear))

func _forge_volume_db() -> float:
	return linear_to_db(maxf(0.0001, forge_volume_linear))

func _current_music_volume_db() -> float:
	return _forge_volume_db() + _music_volume_db() if mode == Mode.FORGE else _music_volume_db()

func enter_home() -> void:
	if music_player == null or mode == Mode.HOME: return
	mode = Mode.HOME
	transition_serial += 1
	_transition_to(_next_home_track(), false, transition_serial, _current_music_volume_db())

func enter_forge() -> void:
	if music_player == null or mode == Mode.FORGE: return
	mode = Mode.FORGE
	transition_serial += 1
	_transition_to(_next_forge_track(), false, transition_serial, _forge_volume_db())

## Fades the main home/forge/combat music out and pauses it entirely.
## Use this for any minigame (like Grindstone) that plays its own dedicated
## music, so the two tracks never overlap.
func enter_silence() -> void:
	if music_player == null or mode == Mode.SILENT: return
	mode = Mode.SILENT
	transition_serial += 1
	var serial: int = transition_serial
	music_player.stream_paused = false
	var fade_out: Tween = create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(music_player, "volume_db", SILENT_VOLUME_DB, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
	if serial != transition_serial or music_player == null: return
	music_player.stream_paused = true

func enter_adventure() -> void:
	if music_player == null or mode == Mode.COMBAT: return
	mode = Mode.COMBAT
	transition_serial += 1
	_transition_to(combat_stream, true, transition_serial, _current_music_volume_db())

## Starts the boss theme: Rift Combo Riot, then Horn of the Void, then loops
## the pair forever (each track plays once, non-looping, and _on_music_finished
## advances to the next -- see BOSS_TRACKS). Call this the moment the boss
## stops talking, not when the fight is first set up.
func enter_boss() -> void:
	if music_player == null or BOSS_TRACKS.is_empty(): return
	mode = Mode.BOSS
	boss_track_index = 0
	transition_serial += 1
	_transition_to(BOSS_TRACKS[boss_track_index], false, transition_serial, _current_music_volume_db())

func _transition_to(stream: AudioStream, should_loop: bool, serial: int, target_volume_db: float) -> void:
	# Clear any prior diagnostic pause before performing the normal crossfade.
	music_player.stream_paused = false
	var fade_out: Tween = create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(music_player, "volume_db", SILENT_VOLUME_DB, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
	if serial != transition_serial or music_player == null: return
	music_player.stop()
	music_player.stream = stream
	_set_stream_loop(stream, should_loop)
	music_player.volume_db = SILENT_VOLUME_DB
	music_player.play()
	var fade_in: Tween = create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(music_player, "volume_db", target_volume_db, FADE_DURATION).set_trans(Tween.TRANS_SINE)

func _next_home_track() -> AudioStream:
	if home_shuffle_bag.is_empty(): _refill_home_shuffle_bag()
	current_home_index = home_shuffle_bag.pop_front()
	return HOME_TRACKS[current_home_index]

func _refill_home_shuffle_bag() -> void:
	home_shuffle_bag.clear()
	for index: int in range(HOME_TRACKS.size()): home_shuffle_bag.append(index)
	home_shuffle_bag.shuffle()
	if home_shuffle_bag.size() > 1 and home_shuffle_bag[0] == current_home_index:
		var swap_index: int = randi_range(1, home_shuffle_bag.size() - 1)
		var held_index: int = home_shuffle_bag[0]
		home_shuffle_bag[0] = home_shuffle_bag[swap_index]
		home_shuffle_bag[swap_index] = held_index

func _next_forge_track() -> AudioStream:
	if forge_shuffle_bag.is_empty(): _refill_forge_shuffle_bag()
	current_forge_index = forge_shuffle_bag.pop_front()
	return FORGE_TRACKS[current_forge_index]

func _refill_forge_shuffle_bag() -> void:
	forge_shuffle_bag.clear()
	for index: int in range(FORGE_TRACKS.size()): forge_shuffle_bag.append(index)
	forge_shuffle_bag.shuffle()
	if forge_shuffle_bag.size() > 1 and forge_shuffle_bag[0] == current_forge_index:
		var swap_index: int = randi_range(1, forge_shuffle_bag.size() - 1)
		var held_index: int = forge_shuffle_bag[0]
		forge_shuffle_bag[0] = forge_shuffle_bag[swap_index]
		forge_shuffle_bag[swap_index] = held_index

func _on_music_finished() -> void:
	if music_player == null: return
	var next_track: AudioStream = null
	var target_volume_db: float = _current_music_volume_db()
	if mode == Mode.HOME:
		next_track = _next_home_track()
	elif mode == Mode.FORGE:
		next_track = _next_forge_track()
		target_volume_db = _forge_volume_db()
	elif mode == Mode.BOSS:
		boss_track_index = (boss_track_index + 1) % BOSS_TRACKS.size()
		next_track = BOSS_TRACKS[boss_track_index]
	else:
		return
	music_player.stream = next_track
	_set_stream_loop(next_track, false)
	music_player.volume_db = target_volume_db
	music_player.play()

func _set_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled

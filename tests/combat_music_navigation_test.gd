class_name CombatMusicNavigationTest extends Node

class HomeSpy extends Control:
	var home_tutorial_guide: Node = null

class MusicSpy extends MusicDirector:
	var combat_entries: int = 0
	var home_entries: int = 0
	func enter_adventure() -> void:
		combat_entries += 1
	func enter_home() -> void:
		home_entries += 1

func test_adventure_town_general_and_review_never_request_combat() -> void:
	# Exercise Main's navigation without entering Main._ready (which writes saves).
	var main: Main = Main.new()
	var home: HomeSpy = HomeSpy.new()
	var music: MusicSpy = MusicSpy.new()
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	hub.configure_town(main.home_progression, Callable(), Callable())
	main.home_menu = home
	main.end_run_hub = hub
	main.music_director = music
	main._return_to_adventure_from_home()
	assert(hub.active_tab == EndRunHub.Tab.ADVENTURE)
	hub.show_tab(EndRunHub.Tab.TOWN)
	hub.town_menu.open_general()
	hub.show_tab(EndRunHub.Tab.ADVENTURE)
	main._show_run_summary()
	assert(hub.active_tab == EndRunHub.Tab.RUN_REVIEW)
	assert(music.combat_entries == 0, "Browsing menus must never request combat music.")
	assert(music.home_entries == 2, "Adventure and review must use the existing noncombat playlist.")
	main.free()
	home.free()
	music.free()
	hub.queue_free()
	await get_tree().process_frame

func test_combat_entry_is_owned_by_playable_zone_starts_not_pause() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	for entry: String in ["_start_arena_run(zone_id: String)", "_start_backyard_run()"]:
		var start: int = source.find("func " + entry)
		var end: int = source.find("\nfunc ", start + 1)
		var body: String = source.substr(start, end - start if end >= 0 else -1)
		assert(body.contains("music_director.enter_adventure()"), "Actual combat zones must request combat music.")
		assert(body.contains("set_adventure_zone"), "Each zone must select its own combat playlist.")
	for exit_handler: String in ["_on_player_died()", "_on_end_run()", "_on_pause_return_home()"]:
		var start: int = source.find("func " + exit_handler)
		var end: int = source.find("\nfunc ", start + 1)
		assert(source.substr(start, end - start).contains("_finish_run("), "All combat exits must use the canonical run-finish path.")
	var finish_start: int = source.find("func _finish_run(")
	var finish_end: int = source.find("\nfunc ", finish_start + 1)
	assert(source.substr(finish_start, finish_end - finish_start).contains("_show_run_summary()"), "Finishing combat must restore noncombat music through review.")
	var pause_start: int = source.find("func _toggle_pause()")
	var pause_end: int = source.find("\nfunc ", pause_start + 1)
	assert(not source.substr(pause_start, pause_end - pause_start).contains("music_director"), "Combat pause/resume must not switch or restart music.")

func test_combat_fade_cannot_restart_after_leaving_and_reentry_is_idempotent() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = MusicDirector.COMBAT_TRACKS[0]
	add_child(player)
	var director: MusicDirector = MusicDirector.new()
	add_child(director)
	director.setup(player)
	assert(player.process_mode == Node.PROCESS_MODE_ALWAYS, "Home/town music must play while the game tree is paused.")
	assert(director.mode == MusicDirector.Mode.HOME)
	assert(MusicDirector.HOME_TRACKS.has(player.stream), "Setup must not briefly autoplay combat music.")
	for zone: String in ["forest", "chasm", "backyard"]:
		director.set_adventure_zone(zone)
		director.enter_adventure()
		var serial: int = director.transition_serial
		director.enter_adventure()
		assert(director.transition_serial == serial, "Repeated combat entry must not restart the track.")
		await get_tree().create_timer(0.8).timeout
		assert(director.mode == MusicDirector.Mode.COMBAT)
		assert(director.active_combat_tracks.has(player.stream))
		assert(not (player.stream as AudioStreamMP3).loop)
		director.enter_home()
		await get_tree().create_timer(0.8).timeout
		assert(MusicDirector.HOME_TRACKS.has(player.stream))
	# Leave before the delayed fade has a chance to install the combat stream.
	director.enter_adventure()
	director.enter_home()
	await get_tree().create_timer(0.8).timeout
	assert(director.mode == MusicDirector.Mode.HOME)
	assert(MusicDirector.HOME_TRACKS.has(player.stream), "Stale combat fade must not replace menu music.")
	director.free()
	player.free()

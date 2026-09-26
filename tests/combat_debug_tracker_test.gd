class_name CombatDebugTrackerTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func test_tracker_bounds_history_and_supports_pause_clear() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	var tracker: CombatDebugTracker = CombatDebugTracker.new()
	add_child(player)
	add_child(tracker)
	tracker.setup(player)
	for index: int in range(15):
		player.combat_debug_event.emit("SLIDE", {"pressure":float(index)})
	assert(tracker.event_history.size() == CombatDebugTracker.MAX_EVENTS)
	assert(int(tracker.event_counts["SLIDE"]) == 15)
	tracker._toggle_paused()
	player.combat_debug_event.emit("WEAPON BEAT", {})
	assert(not tracker.event_counts.has("WEAPON BEAT"), "Paused tracker must not capture new events.")
	tracker.clear_events()
	assert(tracker.event_history.is_empty() and tracker.event_counts.is_empty())
	tracker.queue_free()
	player.queue_free()

func test_tracker_formats_actionable_beat_and_release_reasons() -> void:
	var rejected: String = CombatDebugTracker.format_event_details("BEAT REJECTED", {"player_pressure":320.0, "pressure_spike":140.0, "leverage":0.03, "required_leverage":0.08})
	assert("FAIL" in rejected and "0.03" in rejected and "0.08" in rejected)
	var release: String = CombatDebugTracker.format_event_details("BIND RELEASE", {"reason":"blade separation", "contact_time":0.72, "tangent_travel":18.0})
	assert("blade separation" in release and "0.72" in release)

func test_bind_overhead_readout_stays_as_small_event_counts() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_contact_preset = 2
	player.combat_hand_settings = {"2:9":{"bind_debug":1.0}}
	player.sword_slide_count = 7
	player.experimental_bind_count = 3
	player.experimental_wind_count = 2
	player.experimental_beat_count = 1
	player.experimental_rejected_beat_count = 1
	var lines: PackedStringArray = player.experimental_overhead_debug_lines()
	assert(lines.size() == 4)
	assert(lines == PackedStringArray(["Winds: 2", "Binds: 3", "Beats: 1/1", "Slides: 7"]))
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	assert(player.experimental_overhead_debug_lines().is_empty(), "Ordinary forms must keep the overhead bind counters hidden.")
	player.free()

func test_bind_b_emits_candidate_stable_and_release_events() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	var captured: Array[String] = []
	player.combat_debug_event.connect(func(event_type: String, _details: Dictionary) -> void: captured.append(event_type))
	player._set_sword_event("STABLE BIND", Vector2.ZERO)
	player.experimental_bind_candidate = true
	player._release_experimental_bind("test release")
	assert("STABLE BIND" in captured and "BIND RELEASE" in captured)
	player.queue_free()

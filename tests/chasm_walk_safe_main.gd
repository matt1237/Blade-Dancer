extends Main
## Save-safe real Main lifecycle bench: replace persistence-bearing bootstrap,
## NOT navigation, camera, controls, collision, drop handling or area transitions.
var write_attempts: int = 0
var probe_seconds: float = 0.0

func save_game(_path: String = SAVE_PATH) -> bool:
	write_attempts += 1
	return false

func _begin_prepared_expedition() -> void:
	pass # Normal-area transition checks must not consume food or save either.

func set_forest_time_phase(phase: String) -> void:
	active_forest_time_phase = phase # No GlobalPresetConfig clock writer in this rig.

func _enter_tree() -> void:
	get_tree().debug_collisions_hint = false

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	# Read live active zoom only, without global preset initialization/migration.
	var library: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://blade_dancer_global_presets.json"))
	if library is Dictionary:
		var slot: Dictionary = library.get("slots", {}).get(str(int(library.get("active_slot", 2))), {})
		training_camera_zoom = float(slot.get("training_camera_zoom", 1.0))
	visual_style = "hd"
	player.set_visual_style(visual_style)
	player.set_input_mode(Player.INPUT_MODE_KEYBOARD_MOUSE)
	_configure_audio_buses()
	audio_manager = AUDIO_MANAGER_SCRIPT.new() as AudioManager
	add_child(audio_manager)
	_configure_music_loop()
	_create_remaining_enemies_label()
	end_run_hub.adventure_zone_requested.connect(_on_adventure_zone_requested)
	end_run_hub.adventure_zone_requested.connect(func(zone: String) -> void: print("[SAFE CHASM WALK] requested=", zone))
	end_run_hub.travel_home_requested.connect(_travel_home)
	home_menu.adventure_requested.connect(_return_to_adventure_from_home)
	chasm_stage.population.population_seed = 42
	_on_adventure_zone_requested("chasm_test")
	print("[SAFE CHASM WALK] canonical Player; live zoom=", training_camera_zoom, "; WASD, Esc/Home; persistence disabled before tree entry")

func _process(delta: float) -> void:
	super._process(delta)
	probe_seconds += delta
	if probe_seconds >= 1.0:
		probe_seconds = 0.0
		print("[SAFE CHASM WALK] player=", player.position, " camera=", presentation_camera.position, " vista=", (chasm_test_vista.painting.position if chasm_test_style == "chasm_test_2" else chasm_test_vista.distant.position) if is_instance_valid(chasm_test_vista) else Vector2.ZERO, " waves=", spawner.is_processing(), " writes=", write_attempts)

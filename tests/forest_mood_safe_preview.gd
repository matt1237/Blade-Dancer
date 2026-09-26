class_name ForestMoodSafePreview extends Main
## Save-free preview of the REAL Main scene, not a mock forest.
## Only Hazey is read. Revised profiles are composed in memory from source constants.
## No tuner is created: its explicit Save/Startup actions must never be exposed here.
var preview_hazey_values: Dictionary = {}
var preview_ready: bool = false
var preview_mood_name: String = ""

func _load_forest_visual_settings() -> void:
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	var hazey: Dictionary = library.find_latest_named_snapshot("Hazey")
	if not hazey.is_empty():
		var result: Error = forest_visual_settings.apply_snapshot_values(hazey["values"] as Dictionary)
		if result != OK:
			push_warning("Preview: invalid Hazey; using defaults.")
	else:
		print("Preview: no saved Hazey; using clean defaults (no files created).")
	preview_hazey_values = forest_visual_settings.values.duplicate(true)

func save_game() -> void:
	# Intentionally intercept EVERY inherited gameplay save call.
	pass

func load_game() -> void:
	# Stable preview; no progression migration or saved input/style preferences.
	pass

func _create_backyard_training_menu() -> void:
	# The tuner owns explicit file-write buttons. Omit it entirely in this fixture.
	pass

func _apply_forest_visual_settings() -> void:
	super._apply_forest_visual_settings()

func _ready() -> void:
	super._ready()
	visual_style = "hd"
	player.set_visual_style("hd")
	forest_floor.set_visual_style("hd")
	arena_generator.generation_seed = 9001
	_start_backyard_run()
	preview_ready = true
	select_preview_mood(3)
	_spawn_preview_enemies.call_deferred()
	print("SAVE-FREE FOREST: 1 Noon | 2 Morning v2 | 3 Dusk v2 | 4 Night v2. Normal movement/weapon controls remain live.")

func _spawn_preview_enemies() -> void:
	# Stationary real enemies for repeatable silhouette/eye checks, no save writes.
	var positions: Array[Vector2] = [Vector2(260, 160), Vector2(1000, 160), Vector2(200, 500), Vector2(1100, 530), Vector2(820, 360)]
	var scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]
	for index: int in range(scenes.size()):
		var enemy: Enemy = scenes[index].instantiate() as Enemy
		enemy.position = positions[index]
		add_child(enemy)
		enemy._update_hd_enemy_sprite()
		enemy.set_physics_process(false)

func select_preview_mood(index: int) -> void:
	assert(index >= 0 and index < ForestVisualProfileLibrary.REVISED_VARIANTS.size())
	var variant: Dictionary = ForestVisualProfileLibrary.REVISED_VARIANTS[index]
	var composed: Dictionary = preview_hazey_values.duplicate(true)
	var overrides: Dictionary = variant["overrides"] as Dictionary
	composed.merge(overrides, true)
	var result: Error = forest_visual_settings.apply_snapshot_values(composed)
	assert(result == OK)
	preview_mood_name = str(variant["name"])
	($CanvasLayer/PreviewCaption as Label).text = "PREVIEW / " + preview_mood_name + "   [1 Noon | 2 Morning | 3 Dusk | 4 Night]   NO SAVES"
	print("PREVIEW mood=", preview_mood_name, " night=", forest_visual_settings.get_value("night_strength"))

func _input(event: InputEvent) -> void:
	# Do not forward Main's menu/save shortcuts; Player handles gameplay itself.
	if not preview_ready or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		select_preview_mood(int(key.keycode - KEY_1))
		get_viewport().set_input_as_handled()

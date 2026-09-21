class_name TutorialProgressionTest extends Node

func test_tutorial_quests_advance_in_authored_order() -> void:
	var overlay: TutorialOverlay = TutorialOverlay.new()
	add_child(overlay)
	for hit_index: int in range(5):
		overlay.register_hit(5.0)
	assert(overlay.tutorial_step == 2, "Five initial sword contacts must begin authored-hit training.")
	for hit_index: int in range(5):
		overlay.register_hit(12.0)
	assert(overlay.tutorial_step == 3, "Five authored hits must begin the Chakram sequence.")
	overlay.register_action("chakram_hit", true)
	assert(overlay.tutorial_step == 3, "A skipped Chakram throw cannot complete the next quest early.")
	overlay.register_action("chakram_thrown")
	assert(overlay.tutorial_step == 4)
	overlay.register_action("chakram_hit", false)
	assert(overlay.tutorial_step == 4, "Only damage to the tutorial dummy counts.")
	overlay.register_action("chakram_hit", true)
	assert(overlay.tutorial_step == 5)
	overlay.register_action("chakram_batted")
	overlay.register_action("chakram_batted")
	assert(overlay.tutorial_step == 5 and overlay.chakram_bats == 2)
	overlay.register_action("chakram_batted")
	assert(overlay.tutorial_step == 6)
	overlay.register_action("grapple_connected_enemy", false)
	assert(overlay.tutorial_step == 6, "The direct grapple quest requires the training dummy.")
	overlay.register_action("grapple_connected_enemy", true)
	assert(overlay.tutorial_step == 7)
	overlay.register_action("grapple_connected", false)
	assert(overlay.tutorial_step == 7, "Terrain grapples cannot satisfy the Chakram quest.")
	overlay.register_action("grapple_connected_chakram")
	assert(overlay.tutorial_step == 8)
	overlay.register_action("chakram_wrapped_enemy", false)
	assert(overlay.tutorial_step == 8)
	overlay.register_action("chakram_wrapped_enemy", true)
	assert(overlay.tutorial_step == 9)
	overlay.register_action("dash_performed")
	assert(overlay.tutorial_step == 9 and overlay.dashes_completed == 1, "One dash must update the quest without completing it.")
	overlay.register_action("dash_performed")
	assert(overlay.tutorial_step == 10 and overlay.dashes_completed == 2, "Two successful dashes must begin Grandma's gathering quest.")
	overlay.register_material("Mushroom", 5)
	overlay.register_material("Forest Herb", 5)
	overlay.register_material("Turkey", 4)
	assert(overlay.tutorial_step == 10, "The gathering quest must wait for every existing ingredient goal.")
	overlay.register_material("Turkey", 1)
	assert(overlay.tutorial_step == 11, "Five mushrooms, herbs, and Turkey must complete the gathering quest.")
	overlay.queue_free()

func test_training_dummy_is_world_anchored_and_rejects_forces() -> void:
	var dummy_scene: PackedScene = load("res://scenes/training_dummy.tscn") as PackedScene
	var dummy: TrainingDummy = dummy_scene.instantiate() as TrainingDummy
	add_child(dummy)
	dummy.global_position = Vector2(120.0, 90.0)
	dummy.lock_world_position()
	assert(dummy.grapple_weight == Enemy.GrappleWeight.HEAVY, "The anchored dummy must pull the player like a heavy enemy.")
	dummy.apply_grapple_force(Vector2(5000.0, 0.0), 1.0)
	dummy.apply_void_pull(Vector2.RIGHT, 1000.0)
	dummy.global_position = Vector2(300.0, 300.0)
	dummy._physics_process(0.016)
	assert(dummy.global_position.is_equal_approx(Vector2(120.0, 90.0)), "The training dummy must return to its authored world anchor.")
	assert(dummy.velocity == Vector2.ZERO and dummy.knockback == Vector2.ZERO, "No force channel may move the training dummy.")
	dummy.queue_free()

func test_tutorial_uses_forest_backdrop_without_generated_content() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var start: int = source.find("func _start_tutorial")
	var finish: int = source.find("func _on_tutorial_action", start)
	var tutorial_source: String = source.substr(start, finish - start)
	assert(tutorial_source.contains("backyard_training_layout = \"forest\""))
	assert(tutorial_source.contains("$ForestFloor.visible = true"))
	assert(tutorial_source.contains("arena_generator.set_forest_content_enabled(false)"), "Tutorial forest must omit generated props, hazards, and farmables.")

func test_tutorial_dialogue_auto_closes_after_configured_hold() -> void:
	var box: BossDialogueBox = BossDialogueBox.new()
	add_child(box)
	box.auto_close_delay = 0.05
	box.start([""])
	box._process(0.0)
	assert(box.visible, "The completed final page must remain visible during its hold.")
	box._process(0.06)
	assert(not box.visible, "Tutorial dialogue must dismiss itself after the configured hold.")
	box.queue_free()

func test_field_tutorial_has_a_skip_step_shortcut() -> void:
	var overlay: TutorialOverlay = TutorialOverlay.new()
	add_child(overlay)
	assert(overlay.skip_button != null and overlay.skip_button.text == "SKIP STEP")
	overlay.tutorial_step = 5
	overlay.skip_current_step()
	assert(overlay.tutorial_step == 6, "Skipping a bat quest must advance to the grapple quest.")
	overlay.queue_free()

func test_tutorial_home_transition_defers_physics_cleanup() -> void:
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var transition_start: int = main_source.find("func _return_home_after_tutorial")
	var transition_end: int = main_source.find("func _on_tutorial_action", transition_start)
	var transition_source: String = main_source.substr(transition_start, transition_end - transition_start)
	assert(transition_source.find("_set_world_visible(false)") < transition_source.find("arena_generator.set_forest_content_enabled(false)"), "Home must cover and stop the old world before terrain teardown.")
	assert(transition_source.contains("await get_tree().physics_frame") and transition_source.contains("await get_tree().process_frame"), "Tutorial teardown must retire both physics and process callbacks first.")
	var generator_source: String = FileAccess.get_file_as_string("res://scripts/terrain/arena_generator.gd")
	var clear_start: int = generator_source.find("func _clear_generated_modules")
	var clear_end: int = generator_source.find("func ", clear_start + 5)
	var clear_source: String = generator_source.substr(clear_start, clear_end - clear_start)
	assert(not clear_source.contains(".free()"), "Generated terrain must never be freed immediately during a live transition.")
	assert(clear_source.contains("queue_free()"))

func test_tutorial_completion_waits_for_final_dialogue() -> void:
	var overlay: TutorialOverlay = TutorialOverlay.new()
	add_child(overlay)
	overlay.tutorial_step = 11
	var completion_count: Array[int] = [0]
	overlay.tutorial_completed.connect(func() -> void: completion_count[0] += 1)
	overlay._on_dialogue_finished()
	assert(completion_count[0] == 1, "Home countdown must begin only after the final supplies dialogue closes.")
	overlay.queue_free()

func test_tutorial_gathering_population_uses_existing_respawning_resources() -> void:
	var population: ArenaPopulation = ArenaPopulation.new()
	population.enabled = false
	add_child(population)
	population.populate_tutorial_gathering()
	var herbs: int = 0
	var mushrooms: int = 0
	for child: Node in population.get_children():
		var object: ArenaObject = child as ArenaObject
		if object == null:
			continue
		if object.object_kind == ArenaObject.ObjectKind.HERB:
			herbs += 1
		elif object.object_kind == ArenaObject.ObjectKind.MUSHROOM:
			mushrooms += 1
	assert(herbs >= 5 and mushrooms >= 5, "Grandma's quest must spawn enough existing herb and mushroom patches.")
	assert(population.tutorial_gathering_active, "Tutorial patches must remain eligible for respawn.")
	population.queue_free()

func test_tutorial_spawner_has_dedicated_turkey_only_mode() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/wave_spawner.gd")
	assert(source.contains("var selected_scene: PackedScene = TURKEY_SCENE if tutorial_turkey_mode"))
	assert(source.contains("func end_tutorial_turkeys"), "Turkey spawning must have an explicit stop when five Turkey are gathered.")

func test_later_dummy_damage_does_not_reset_chakram_quests() -> void:
	var overlay: TutorialOverlay = TutorialOverlay.new()
	add_child(overlay)
	overlay.tutorial_step = 5
	overlay.authored_hits = 5
	overlay.register_hit(20.0)
	assert(overlay.tutorial_step == 5, "Damage after sword training must not restart the throw quest.")
	overlay.queue_free()

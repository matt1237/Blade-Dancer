extends Node

const STAGE: PackedScene = preload("res://scenes/chasm/chasm_stage.tscn")

func test_chasm_contact_geometry_and_herb_scaling() -> void:
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	get_tree().root.add_child(stage)
	for seed_value: int in [1, 42, 43, 99, 512]:
		stage.population.population_seed = seed_value
		stage.regenerate()
		for child: Node in stage.population.get_children():
			var object: ChasmArenaObject = child as ChasmArenaObject
			var source: Vector2 = object._texture_for_kind().get_size()
			var visual: Rect2 = object.local_visual_bounds()
			var foot: Rect2 = object.local_footprint()
			assert(object.footprint_size.is_equal_approx(foot.size))
			assert(is_equal_approx(object.visual_sprite.scale.x, object.visual_sprite.scale.y))
			if object.object_kind == ArenaObject.ObjectKind.HERB:
				var prior_size: Vector2 = source * minf(72.0 / source.x, 88.0 / source.y)
				assert(visual.size.is_equal_approx(prior_size * 0.7))
				assert(foot.size.is_equal_approx(Vector2(16.8, 16.8)))
				assert(object.body == null and not object.blocks_navigation)
			else:
				assert(visual.encloses(foot))
				var expected_region: Rect2
				if object.object_kind == ArenaObject.ObjectKind.TREE:
					expected_region = Rect2(0.29, 0.86, 0.50, 0.12) if object.ancient_tree else Rect2(0.49, 0.84, 0.36, 0.12)
					assert(foot.position.y > visual.position.y + visual.size.y * 0.8)
				else:
					expected_region = Rect2(0.06, 0.65, 0.88, 0.26) if object.iron_ore else Rect2(0.16, 0.36, 0.68, 0.42)
				assert(foot.position.is_equal_approx(visual.position + expected_region.position * visual.size))
				assert(foot.size.is_equal_approx(expected_region.size * visual.size))
				var collision: CollisionShape2D = object.body.get_child(0) as CollisionShape2D
				var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
				assert(capsule != null and is_equal_approx(collision.rotation, PI * 0.5))
				assert(is_equal_approx(capsule.radius * 2, foot.size.y))
				assert(is_equal_approx(capsule.height, foot.size.x))
				assert(object.body.position.is_equal_approx(foot.get_center()))
				assert(object.world_collision_rect().position.is_equal_approx(object.position + foot.position))
				assert(object.world_collision_rect().size.is_equal_approx(foot.size))
				assert(object.world_footprint().is_equal_approx(object.world_collision_rect()))
				assert(object.world_blocking_rects()[0].is_equal_approx(object.world_collision_rect()))
		await get_tree().process_frame
	stage.queue_free()
	await get_tree().process_frame

class DropRecorder extends Node:
	var drops: Array[Dictionary] = []
	func spawn_terrain_drop(point: Vector2, item: String, quantity: int) -> void:
		drops.append({"point": point, "item": item, "quantity": quantity})

func test_herbs_use_shared_harvest_and_drop_once() -> void:
	var original_scene: Node = get_tree().current_scene
	var recorder: DropRecorder = DropRecorder.new()
	get_tree().root.add_child(recorder)
	get_tree().current_scene = recorder
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	recorder.add_child(stage)
	stage.population.population_seed = 42
	stage.regenerate()
	var herbs: int = 0
	for child: Node in stage.population.get_children():
		var herb: ChasmArenaObject = child as ChasmArenaObject
		if herb.object_kind != ArenaObject.ObjectKind.HERB: continue
		herbs += 1
		assert(herb.is_in_group("sword_farmables") and herb.visible)
		var expected_item: String = "Gummy Blue Berries" if herb.lotus_herb else "Spicy Red Berries"
		assert(herb.hit_by_sword(1))
		assert(recorder.drops.back()["item"] == expected_item)
		assert(herb.broken and herb.drop_spawned and not herb.visible)
		assert(not herb.hit_by_sword(1))
	assert(herbs == 3 and recorder.drops.size() == herbs)
	for drop: Dictionary in recorder.drops:
		assert(drop["item"] in ["Spicy Red Berries", "Gummy Blue Berries"] and drop["quantity"] == 1)
	stage.regenerate()
	assert(stage.population.get_child_count() == 10)
	get_tree().current_scene = original_scene
	recorder.queue_free()
	await get_tree().process_frame

func test_berries_canonical_inventory_discovery_roundtrip() -> void:
	var progression: HomeProgression = HomeProgression.new()
	for item: String in ["Spicy Red Berries", "Gummy Blue Berries"]:
		assert(HomeProgression.MATERIAL_NAMES.has(item))
		assert(progression.materials.has(item) and progression.material_count(item) == 0)
		var pickup: DropPickup = DropPickup.new()
		pickup.setup(item, 1, 1)
		assert(pickup.item_name == item and pickup.quantity == 1)
		assert(pickup.rarity == ItemConfig.Rarity.NORMAL)
		progression.add_material(pickup.item_name, pickup.quantity)
		progression.add_material(item, 1)
		pickup.free()
		assert(progression.material_count(item) == 2 and progression.discovered_items.has(item))
		# No existing fruit offers: do not invent prices or stock.
		assert(ItemConfig.general_sale_price(item) == 0 and ItemConfig.general_purchase_price(item) == 0)
		assert(not progression.kaji_stock.has(item))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(progression.to_save_data())) as Dictionary
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(saved)
	for item: String in ["Spicy Red Berries", "Gummy Blue Berries"]:
		assert(restored.material_count(item) == 2 and restored.discovered_items.has(item))
	assert(restored.material_count("Forest Herb") == 0)
	# Legacy discovery bootstrap must also recognize the canonical materials.
	saved.erase("discovered_items")
	restored.load_save_data(saved)
	for item: String in ["Spicy Red Berries", "Gummy Blue Berries"]:
		assert(restored.material_count(item) == 2 and restored.discovered_items.has(item))

func test_shared_sampler_rejects_impossible_floor() -> void:
	var population: ArenaPopulation = ArenaPopulation.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var empty_rects: Array[Rect2] = []
	var empty_segments: Array[PackedVector2Array] = []
	assert(population.sample_open_position(rng, Rect2(0, 0, 32, 32), Rect2(-50, -50, 100, 100), Rect2(-12, -12, 24, 24), empty_rects, empty_rects, empty_rects, empty_segments) == Vector2.INF)
	population.free()

func test_floor_bounds_and_spawn_clearance() -> void:
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	get_tree().root.add_child(stage)
	assert(stage.arena_rect == Rect2(0, 0, 1280, 720))
	assert(stage.get_playable_rect() == Rect2(26, 26, 1228, 668))
	var floor_sprite: Sprite2D = stage.get_node("Background") as Sprite2D
	assert(floor_sprite.texture.resource_path == "res://assets/generated/The Chasm Floor.png")
	assert((floor_sprite.texture.get_size() * floor_sprite.scale).distance_to(Vector2(1280, 720)) < 0.01)
	assert(stage.is_spawn_position_valid(Vector2(640, 360)))
	for point: Vector2 in [Vector2(42, 360), Vector2(1238, 360), Vector2(640, 42), Vector2(640, 678)]:
		assert(not stage.is_spawn_position_valid(point, 16))
	for wall_name: String in ["Top", "Right", "Bottom", "Left"]:
		var wall: CollisionShape2D = stage.get_node("ChasmBounds/" + wall_name) as CollisionShape2D
		assert(wall.shape is RectangleShape2D)
	stage.free()

func test_seed_counts_assets_spacing_and_regeneration() -> void:
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	get_tree().root.add_child(stage)
	var observed: Dictionary = {}
	var interior_objects: int = 0
	var quadrants: Dictionary = {}
	for seed_value: int in range(1, 513):
		stage.population.population_seed = seed_value
		var entrance: Vector2 = Vector2(-80, 48 + ((seed_value * 37) % 625))
		stage.regenerate(entrance)
		var first_layout: Array[Vector2] = []
		var visuals: Array[Rect2] = []
		var feet: Array[Rect2] = []
		var counts: Dictionary = {"tree": 0, "ore": 0, "stone": 0, "lotus": 0, "crimson": 0}
		var ancient_count: int = 0
		for child: Node in stage.population.get_children():
			var object: ChasmArenaObject = child as ChasmArenaObject
			assert(object != null and object.position.is_finite())
			var visual: Rect2 = Rect2(object.position + object.local_visual_bounds().position, object.local_visual_bounds().size)
			var foot: Rect2 = object.world_footprint()
			assert(stage.get_playable_rect().grow(-32).encloses(visual.merge(foot)))
			assert(not visual.merge(foot).intersects(Rect2(535, 255, 210, 210), true))
			assert(stage.population._segment_rect_entry(entrance, Vector2(640, 360), visual.merge(foot).grow(32)) == Vector2.INF)
			for prior: Rect2 in visuals: assert(not visual.grow(24).intersects(prior, true))
			for prior: Rect2 in feet: assert(not foot.grow(72).intersects(prior, true))
			visuals.append(visual)
			feet.append(foot)
			first_layout.append(object.position)
			quadrants[Vector2i(int(object.position.x >= 640), int(object.position.y >= 360))] = true
			if object.position.distance_to(Vector2(640, 360)) < 240: interior_objects += 1
			if object.object_kind == ArenaObject.ObjectKind.HERB:
				counts["lotus" if object.lotus_herb else "crimson"] += 1
				assert(object.sword_harvestable and not object.blocks_navigation and object.body == null and object.health == 1)
				assert(object._material_name() == ("Gummy Blue Berries" if object.lotus_herb else "Spicy Red Berries"))
				assert(object._material_quantity() == 1)
				assert(object.visual_sprite.texture == (ChasmArenaObject.LOTUS if object.lotus_herb else ChasmArenaObject.CRIMSON))
			else:
				assert(object.body != null and object.body.collision_layer == 4)
				assert(object.chakram_breakable and object.blocks_navigation and object.health == 90)
				assert(not stage.is_spawn_position_valid(object.world_footprint().get_center()))
				if object.object_kind == ArenaObject.ObjectKind.TREE:
					counts["tree"] += 1
					ancient_count += int(object.ancient_tree)
					assert(object._material_name() == "Wood")
					assert(object.visual_sprite.texture in [ChasmArenaObject.GNARLED, ChasmArenaObject.ANCIENT])
				else:
					counts["ore" if object.iron_ore else "stone"] += 1
					assert(object._material_name() == ("Iron Shard" if object.iron_ore else "Stone"))
					assert(object.visual_sprite.texture == (ChasmArenaObject.IRON if object.iron_ore else ArenaObject.ROCK_TEXTURE))
		for kind: String in counts:
			assert(counts[kind] in ([1, 2] if kind in ["lotus", "crimson"] else [2, 3]))
			observed[kind + str(counts[kind])] = true
		assert(ancient_count >= 1 and ancient_count < counts["tree"])
		var retired: ArenaObject = stage.population.get_child(0) as ArenaObject
		var old_body: StaticBody2D = retired.body
		stage.regenerate(entrance)
		assert(retired.broken and old_body.collision_layer == 0 and not retired.is_in_group("arena_objects"))
		assert(stage.population.get_child_count() == first_layout.size())
		for index: int in range(first_layout.size()):
			assert((stage.population.get_child(index) as Node2D).position == first_layout[index])
		assert(stage.is_spawn_position_valid(Vector2(640, 360)))
		await get_tree().process_frame
	assert(observed.size() == 10 and quadrants.size() == 4 and interior_objects > 0)
	stage.set_collision_enabled(false)
	assert(stage.population.get_child_count() == 0 and not stage.population.enabled)
	assert((stage.get_node("ChasmBounds") as StaticBody2D).collision_layer == 0)
	stage.set_collision_enabled(true)
	stage.regenerate()
	assert(stage.population.get_child_count() >= 8 and stage.population.get_child_count() <= 13)
	stage.queue_free()
	await get_tree().process_frame

func test_physical_walls_and_forest_retirement() -> void:
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	get_tree().root.add_child(stage)
	var probe: CharacterBody2D = CharacterBody2D.new()
	probe.collision_layer = 1
	probe.collision_mask = 4
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 16
	shape_node.shape = circle
	probe.add_child(shape_node)
	get_tree().root.add_child(probe)
	await get_tree().physics_frame
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		probe.position = Vector2(640, 360)
		var collision: KinematicCollision2D = null
		for step_index: int in range(100):
			collision = probe.move_and_collide(direction * 20)
			if collision != null: break
		assert(collision != null)
		if direction == Vector2.LEFT: assert(absf(probe.position.x - 42) < 0.2)
		if direction == Vector2.RIGHT: assert(absf(probe.position.x - 1238) < 0.2)
		if direction == Vector2.UP: assert(absf(probe.position.y - 42) < 0.2)
		if direction == Vector2.DOWN: assert(absf(probe.position.y - 678) < 0.2)
	var forest: ArenaPopulation = ArenaPopulation.new()
	forest.enabled = false
	get_tree().root.add_child(forest)
	forest.populate()
	var former: ArenaObject = forest.get_child(0) as ArenaObject
	var old_body: StaticBody2D = former.body
	forest.clear_population()
	assert(forest.get_child_count() == 0 and former.broken and old_body.collision_layer == 0)
	assert(not former.is_in_group("arena_objects") and not former.is_in_group("chakram_obstructions"))
	forest.queue_free()
	probe.queue_free()
	stage.queue_free()
	await get_tree().process_frame

func test_navigation_and_real_breakable_lifecycle() -> void:
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	get_tree().root.add_child(stage)
	stage.population.population_seed = 42
	stage.regenerate()
	var generator: ArenaGenerator = ArenaGenerator.new()
	generator.config = preload("res://resources/terrain/forest_terrain_config.tres")
	generator.forest_content_enabled = false
	get_tree().root.add_child(generator)
	await get_tree().process_frame
	generator.zone_population = stage.population
	generator.refresh_population_navigation()
	assert(generator.blocking_bounds.size() == stage.population.get_blocking_bounds().size())
	var object: ChasmArenaObject = stage.population.get_child(0) as ChasmArenaObject
	var contact_center: Vector2 = object.world_footprint().get_center()
	assert(not generator.is_position_clear(contact_center))
	assert(not stage.population.get_obstruction_hit(contact_center - Vector2(100, 0), contact_center + Vector2(100, 0), 4).is_empty())
	assert(object.hit_by_sword(45))
	assert(object.hit_by_chakram(45))
	assert(object.broken and object.body == null and object.drop_spawned)
	generator.refresh_population_navigation()
	assert(generator.is_position_clear(object.position, 0))
	stage.set_collision_enabled(false)
	generator.refresh_population_navigation()
	assert(generator.blocking_bounds.is_empty())
	generator.queue_free()
	stage.queue_free()
	await get_tree().process_frame

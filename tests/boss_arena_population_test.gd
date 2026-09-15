class_name BossArenaPopulationTest extends Node

const GENERATOR_SCENE: PackedScene = preload("res://scenes/terrain/arena_generator.tscn")

## Regression: prepare_boss_arena() used to only hide the population node
## (population.visible = false) without clearing it. Hiding a parent does NOT
## disable its children's StaticBody2D colliders, so every rock/tree/log/torch
## stayed solid but invisible for the whole Zungar fight -- invisible walls
## that wedged the boss and the player. Boss waves must contain no population
## props at all.
func test_boss_arena_removes_solid_population_props() -> void:
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	add_child(generator)
	# _ready() defers _initialize_arena(); force it now so population exists.
	generator._initialize_arena()
	assert(generator.population != null, "Arena generator should create its forest population.")
	# Deterministic densities: ignore any saved dev tuning file.
	generator.population.farmable_density = 0.5
	generator.population.big_things_density = 1.0
	generator.regenerate()

	assert(generator.population.get_child_count() > 0, "A normal Forest regeneration should place population props.")
	assert(_blocking_prop_count(generator) > 0, "Normal Forest runs must include solid rock/tree props.")

	generator.prepare_boss_arena()
	assert(generator.boss_arena_active, "prepare_boss_arena() must flag the arena as a boss-wave arena.")
	assert(generator.population.get_child_count() == 0, "Boss waves must not keep ANY population props: hidden-but-solid rocks/trees are invisible colliders.")
	assert(_blocking_prop_count(generator) == 0, "No solid rock/tree colliders may survive into a boss wave.")

	generator.regenerate()
	assert(not generator.boss_arena_active, "A normal regeneration must clear the boss-arena flag.")
	assert(generator.population.get_child_count() > 0, "Normal regeneration must restore population props after the boss wave.")
	generator.free()

## The collider itself (layer 3 / value 4) is what actually blocked Zungar --
## clearing the population must remove the StaticBody2D, not merely hide it.
func test_boss_arena_removes_population_collision_bodies() -> void:
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	add_child(generator)
	generator._initialize_arena()
	assert(generator.population != null, "Arena generator should create its forest population.")
	generator.population.big_things_density = 1.0
	generator.regenerate()
	assert(_population_solid_body_count(generator) > 0, "Solid population props should expose a layer-3 StaticBody2D.")

	generator.prepare_boss_arena()
	assert(_population_solid_body_count(generator) == 0, "Clearing the population must remove the layer-3 StaticBody2D colliders that wedge the boss.")
	generator.free()

func _blocking_prop_count(generator: ArenaGenerator) -> int:
	if generator.population == null:
		return 0
	var count: int = 0
	for node: Node in generator.population.get_children():
		var object: ArenaObject = node as ArenaObject
		if object != null and object.blocks_navigation and not object.broken:
			count += 1
	return count

func _population_solid_body_count(generator: ArenaGenerator) -> int:
	if generator.population == null:
		return 0
	var count: int = 0
	for node: Node in generator.population.get_children():
		var object: ArenaObject = node as ArenaObject
		if object == null or object.broken:
			continue
		for child: Node in object.get_children():
			var body: StaticBody2D = child as StaticBody2D
			if body != null and body.collision_layer == 4:
				count += 1
	return count

class_name ChasmPopulation extends ArenaPopulation

const CHASM_OBJECT: Script = preload("res://scripts/terrain/chasm_arena_object.gd")
var last_population_seed: int = 0

func _ready() -> void:
	# Zone-owned lifecycle; never load/save Forest density settings.
	z_as_relative = false
	z_index = 1
	if enabled: populate()

## Set by the zone lifecycle for the actual transition entrance, in arena space.
var entry_position: Vector2 = Vector2(0, 360)

func populate() -> void:
	_clear()
	enabled = true
	visible = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if population_seed == 0: rng.randomize()
	else: rng.seed = population_seed
	last_population_seed = int(rng.seed)
	var stage: ChasmStage = get_parent() as ChasmStage
	var floor_rect: Rect2 = stage.get_playable_rect()
	var center: Vector2 = floor_rect.get_center()
	var exclusions: Array[Rect2] = [Rect2(center - Vector2.ONE * spawn_clearance, Vector2.ONE * spawn_clearance * 2)]
	var entry_segments: Array[PackedVector2Array] = [PackedVector2Array([entry_position, center])]
	var objects: Array[ChasmArenaObject] = []
	for index: int in range(rng.randi_range(2, 3)):
		objects.append(_make_object(ArenaObject.ObjectKind.TREE, index % 2 == 1))
	for index: int in range(rng.randi_range(2, 3)):
		objects.append(_make_object(ArenaObject.ObjectKind.ROCK, true))
	for index: int in range(rng.randi_range(2, 3)):
		objects.append(_make_object(ArenaObject.ObjectKind.ROCK, false))
	# Count each species independently; never pool the two herb quotas.
	for lotus: bool in [false, true]:
		for index: int in range(rng.randi_range(1, 2)):
			objects.append(_make_object(ArenaObject.ObjectKind.HERB, lotus))
	# Finite whole-layout retries keep quotas intact without unsafe fallback sockets.
	for layout_attempt: int in range(32):
		var visuals: Array[Rect2] = []
		var feet: Array[Rect2] = []
		var complete: bool = true
		for object: ChasmArenaObject in objects:
			var local_feet: Rect2 = object.local_footprint()
			var local_visual: Rect2 = object.local_visual_bounds()
			var point: Vector2 = sample_open_position(rng, floor_rect, local_visual, local_feet, visuals, feet, exclusions, entry_segments)
			if point == Vector2.INF:
				complete = false
				break
			object.position = point
			visuals.append(Rect2(point + local_visual.position, local_visual.size))
			feet.append(Rect2(point + local_feet.position, local_feet.size))
		if not complete: continue
		for object: ChasmArenaObject in objects:
			add_child(object)
			if object.blocks_navigation: blocking_bounds.append(object.world_footprint())
		return
	for object: ChasmArenaObject in objects: object.free()
	push_error("Chasm population: no safe full layout for seed %d" % last_population_seed)

func _make_object(kind: ArenaObject.ObjectKind, variant: bool) -> ChasmArenaObject:
	var object: ChasmArenaObject = CHASM_OBJECT.new() as ChasmArenaObject
	object.object_kind = kind
	object.ancient_tree = variant
	object.iron_ore = variant
	object.lotus_herb = variant
	var herb: bool = kind == ArenaObject.ObjectKind.HERB
	object.footprint_size = object.local_footprint().size
	object.blocks_navigation = not herb
	object.chakram_breakable = not herb
	object.sword_harvestable = herb
	object.max_health = 1.0 if herb else 90.0
	return object

func clear_population() -> void:
	enabled = false
	super.clear_population()


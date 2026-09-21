class_name ArenaGenerator extends Node2D

@export var config: TerrainConfig
@export var wall_modules: Array[PackedScene] = []
@export var mud_patch_scene: PackedScene
@export var bear_trap_scene: PackedScene
@export var population_scene: PackedScene
## Set to 0 for a new layout each run. Use a fixed value to reproduce a layout.
@export var generation_seed: int = 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var placed_bounds: Array[Rect2] = []
var blocking_bounds: Array[Rect2] = []
var wall_collision_bounds: Array[Rect2] = []
var navigation_grid: AStarGrid2D = null
var last_generation_seed: int = 0
var trap_overlay: Node2D = null
var population: ArenaPopulation = null
var forest_content_enabled: bool = true
## True only for the span of a boss-wave arena. Set by prepare_boss_arena(),
## cleared by the next normal regenerate(). Boss waves are arena-clean: no
## forest population props (rocks/trees/logs/torches) may exist while true.
var boss_arena_active: bool = false

func _ready() -> void:
	if config == null:
		push_error("ArenaGenerator requires a TerrainConfig resource.")
		return
	# Main is still attaching children during _ready; create the sibling overlay deferred.
	call_deferred("_initialize_arena")

func _initialize_arena() -> void:
	if population == null and population_scene != null:
		population = population_scene.instantiate() as ArenaPopulation
		if population != null:
			population.enabled = forest_content_enabled
			get_parent().add_child(population)
	if trap_overlay == null:
		trap_overlay = Node2D.new()
		trap_overlay.name = "TerrainTrapOverlay"
		trap_overlay.z_as_relative = false
		trap_overlay.z_index = config.trap_visual_z_index
		trap_overlay.visible = forest_content_enabled
		get_parent().add_child(trap_overlay)
	regenerate()

func set_forest_content_enabled(enabled: bool) -> void:
	forest_content_enabled = enabled
	if population != null:
		population.enabled = enabled
	if enabled:
		# Returning to Forest/Backyard after a Chasm run must re-arm visibility
		# that set_forest_content_enabled(false) turned off below -- otherwise
		# every mud patch/bear trap regenerate() places afterward inherits a
		# hidden parent and keeps its full slow/root collision while rendering
		# nothing (invisible hazards with real movement side effects).
		if population != null: population.visible = true
		if trap_overlay != null: trap_overlay.visible = true
		return
	# Chasm uses its own saved collision perimeter; no Forest modules, traps,
	# or population objects should remain in the world while it is active.
	_clear_generated_modules()
	if population != null:
		population.clear_population()
		population.visible = false
	if trap_overlay != null:
		trap_overlay.visible = false

func prepare_boss_arena() -> void:
	# Boss waves are arena-clean. Hiding the population node is NOT enough: its
	# children keep their layer-3 StaticBody2D colliders alive and invisible,
	# which silently blocks the boss and the player (this is what wedged Zungar
	# against apparently empty ground). Clear the props outright.
	boss_arena_active = true
	if population != null: population.clear_population()
	_clear_generated_modules()
	if config != null: navigation_grid = ArenaLayoutValidator.build_navigation_grid([], config)

func _exit_tree() -> void:
	if trap_overlay != null and is_instance_valid(trap_overlay): trap_overlay.queue_free()
	if population != null and is_instance_valid(population): population.queue_free()

func regenerate() -> void:
	_clear_generated_modules()
	if config == null: return
	if not forest_content_enabled:
		if population != null:
			population.clear_population()
		if trap_overlay != null:
			trap_overlay.visible = false
		return
	# A normal regeneration means this is no longer a boss-wave arena.
	boss_arena_active = false
	# Belt-and-suspenders: any Forest regeneration must render its traps, even
	# if some earlier code path left trap_overlay hidden from a prior Chasm run.
	if trap_overlay != null:
		trap_overlay.visible = true
	if population != null:
		population.visible = true
	if population != null and population.enabled:
		population.populate()
		placed_bounds.append_array(population.get_blocking_bounds())
		blocking_bounds.append_array(population.get_blocking_bounds())
		wall_collision_bounds.append_array(population.get_blocking_bounds())
	if generation_seed == 0:
		rng.randomize()
		last_generation_seed = int(rng.seed)
	else:
		rng.seed = generation_seed
		last_generation_seed = generation_seed
	var target_count: int = rng.randi_range(mini(config.minimum_modules, config.maximum_modules), maxi(config.minimum_modules, config.maximum_modules))
	var plan: Array[PackedScene] = []
	if config.guarantee_bear_trap and bear_trap_scene != null and plan.size() < target_count: plan.append(bear_trap_scene)
	if config.guarantee_mud_patch and mud_patch_scene != null and plan.size() < target_count: plan.append(mud_patch_scene)
	while plan.size() < target_count and not wall_modules.is_empty():
		plan.append(wall_modules[rng.randi_range(0, wall_modules.size() - 1)])
	for plan_index: int in range(plan.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, plan_index)
		var held_scene: PackedScene = plan[plan_index]
		plan[plan_index] = plan[swap_index]
		plan[swap_index] = held_scene
	var rejected_count: int = 0
	for module_scene: PackedScene in plan:
		var placed: bool = false
		for attempt: int in range(config.placement_attempts_per_module):
			var module: Node2D = module_scene.instantiate() as Node2D
			if module == null: break
			_configure_module(module)
			var is_trap: bool = module is MudPatch or module is BearTrap
			module.rotation = 0.0 if is_trap else float(rng.randi_range(0, 3)) * PI * 0.5
			var usable: Rect2 = config.arena_rect.grow(-config.arena_edge_clearance)
			module.global_position = Vector2(rng.randf_range(usable.position.x, usable.end.x), rng.randf_range(usable.position.y, usable.end.y))
			var candidate: Rect2 = _module_footprint(module)
			if not ArenaLayoutValidator.candidate_is_safe(candidate, placed_bounds, config, is_trap):
				module.free()
				rejected_count += 1
				continue
			var candidate_blocking: Array[Rect2] = blocking_bounds.duplicate()
			if module is TerrainModule and (module as TerrainModule).blocks_navigation:
				candidate_blocking.append(candidate)
			if not ArenaLayoutValidator.routes_remain_open(candidate_blocking, config):
				module.free()
				rejected_count += 1
				continue
			var final_position: Vector2 = module.global_position
			if is_trap and trap_overlay != null:
				trap_overlay.add_child(module)
			else:
				add_child(module)
			module.global_position = final_position
			placed_bounds.append(candidate)
			if module is TerrainModule and (module as TerrainModule).blocks_navigation:
				blocking_bounds.append(candidate)
				wall_collision_bounds.append_array((module as TerrainModule).world_blocking_rects())
			placed = true
			break
		if not placed and config.print_generation_report:
			push_warning("Terrain module skipped after %d safe-placement attempts." % config.placement_attempts_per_module)
	navigation_grid = ArenaLayoutValidator.build_navigation_grid(blocking_bounds, config)
	if config.print_generation_report:
		var occupied_area: float = 0.0
		for bounds: Rect2 in placed_bounds: occupied_area += bounds.get_area()
		var open_ratio: float = 1.0 - occupied_area / maxf(config.arena_rect.get_area(), 1.0)
		print("Terrain layout seed %d: %d/%d modules placed, %.1f%% open, %d candidates rejected." % [last_generation_seed, placed_bounds.size(), target_count, open_ratio * 100.0, rejected_count])

func _configure_module(module: Node2D) -> void:
	if module.has_method("configure"): module.configure(config)
	if module is TerrainModule:
		(module as TerrainModule).draw_debug_footprint = config.draw_placement_bounds
		# Walls use their own z-index, distinct from traps.
		module.z_as_relative = false
		module.z_index = config.wall_visual_z_index
	elif module is MudPatch or module is BearTrap:
		# Traps must render below the player/enemies (z_index 2), never above them.
		module.z_as_relative = false
		module.z_index = config.trap_visual_z_index

func _module_footprint(module: Node2D) -> Rect2:
	if module.has_method("world_footprint"): return module.world_footprint()
	return Rect2(module.global_position - Vector2.ONE * 24.0, Vector2.ONE * 48.0)

func _clear_generated_modules() -> void:
	# Terrain can be disabled while the sword, Chakram, or navigation server still
	# references a generated physics body. Detach it immediately so gameplay no
	# longer sees it, then let Godot destroy it at the safe end-of-frame boundary.
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if trap_overlay != null:
		for trap_child: Node in trap_overlay.get_children():
			trap_overlay.remove_child(trap_child)
			trap_child.queue_free()
	placed_bounds.clear()
	blocking_bounds.clear()
	wall_collision_bounds.clear()
	navigation_grid = null

func refresh_population_navigation() -> void:
	if config == null: return
	placed_bounds.clear()
	blocking_bounds.clear()
	wall_collision_bounds.clear()
	if population != null and population.enabled:
		var population_bounds: Array[Rect2] = population.get_blocking_bounds()
		placed_bounds.append_array(population_bounds)
		blocking_bounds.append_array(population_bounds)
		wall_collision_bounds.append_array(population_bounds)
	for child: Node in get_children():
		var module: Node2D = child as Node2D
		if module == null or not module is TerrainModule: continue
		var terrain_module: TerrainModule = module as TerrainModule
		var footprint: Rect2 = terrain_module.world_footprint()
		placed_bounds.append(footprint)
		if terrain_module.blocks_navigation:
			blocking_bounds.append(footprint)
			wall_collision_bounds.append_array(terrain_module.world_blocking_rects())
	for child: Node in trap_overlay.get_children() if trap_overlay != null else []:
		var trap: Node2D = child as Node2D
		if trap != null and trap.has_method("world_footprint"):
			placed_bounds.append(trap.world_footprint())
	navigation_grid = ArenaLayoutValidator.build_navigation_grid(blocking_bounds, config)

func is_position_clear(world_position: Vector2, clearance: float = 36.0) -> bool:
	for bounds: Rect2 in placed_bounds:
		if bounds.grow(clearance).has_point(world_position): return false
	return true

func has_line_of_sight(start: Vector2, end: Vector2, margin: float = 0.0) -> bool:
	return segment_wall_collision(start, end, margin).is_empty()

func _arena_boundary_rects() -> Array[Rect2]:
	if config == null: return []
	var border: float = config.arena_border_thickness
	var arena: Rect2 = config.arena_rect
	# Centered exactly on the arena_rect edge, with no extra offset, so this matches
	# BossArenaBorder's own collision body and grass art pixel-for-pixel on every side.
	return [
		Rect2(arena.position.x - border * 0.5, arena.position.y - border * 0.5, arena.size.x + border, border),
		Rect2(arena.position.x - border * 0.5, arena.end.y - border * 0.5, arena.size.x + border, border),
		Rect2(arena.position.x - border * 0.5, arena.position.y, border, arena.size.y),
		Rect2(arena.end.x - border * 0.5, arena.position.y, border, arena.size.y)
	]

func segment_wall_collision(start: Vector2, end: Vector2, radius: float = 0.0) -> Dictionary:
	var earliest_hit: Dictionary = {}
	var earliest_time: float = INF
	var all_bounds: Array[Rect2] = wall_collision_bounds.duplicate()
	all_bounds.append_array(_arena_boundary_rects())
	for wall_rect: Rect2 in all_bounds:
		var hit: Dictionary = _segment_rect_collision(start, end, wall_rect.grow(radius))
		if not hit.is_empty() and float(hit["time"]) < earliest_time:
			earliest_time = float(hit["time"])
			earliest_hit = hit.duplicate()
			earliest_hit["rect"] = wall_rect
	return earliest_hit

func find_cover_positions(enemy_position: Vector2, player_position: Vector2, shot_clearance: float = 0.0, peek_distance_past_edge: float = 31.0) -> Dictionary:
	var best_cover: Dictionary = {}
	var best_score: float = INF
	var usable_arena: Rect2 = config.arena_rect.grow(-32.0)
	for wall_rect: Rect2 in wall_collision_bounds:
		var wall_center: Vector2 = wall_rect.get_center()
		var player_to_wall: Vector2 = player_position.direction_to(wall_center)
		if player_to_wall == Vector2.ZERO: continue
		var wall_half: Vector2 = wall_rect.size * 0.5
		var forward_extent: float = absf(player_to_wall.x) * wall_half.x + absf(player_to_wall.y) * wall_half.y
		var tangent: Vector2 = player_to_wall.orthogonal()
		var side_extent: float = absf(tangent.x) * wall_half.x + absf(tangent.y) * wall_half.y
		var hidden_position: Vector2 = wall_center + player_to_wall * (forward_extent + 30.0)
		if not usable_arena.has_point(hidden_position) or not _wall_position_clear(hidden_position, 18.0): continue
		if has_line_of_sight(hidden_position, player_position, shot_clearance): continue
		for side_index: int in range(2):
			var side: float = -1.0 if side_index == 0 else 1.0
			var peek_position: Vector2 = hidden_position + tangent * side * (side_extent + peek_distance_past_edge + shot_clearance) - player_to_wall * 8.0
			if not usable_arena.has_point(peek_position) or not _wall_position_clear(peek_position, 18.0): continue
			if not has_line_of_sight(peek_position, player_position, shot_clearance): continue
			var score: float = enemy_position.distance_to(hidden_position) + enemy_position.distance_to(peek_position) * 0.25
			if score < best_score:
				best_score = score
				best_cover = {"hidden": hidden_position, "peek": peek_position}
	return best_cover

func _wall_position_clear(world_position: Vector2, clearance: float) -> bool:
	for wall_rect: Rect2 in wall_collision_bounds:
		if wall_rect.grow(clearance).has_point(world_position): return false
	return true

func _segment_rect_collision(start: Vector2, end: Vector2, rectangle: Rect2) -> Dictionary:
	var motion: Vector2 = end - start
	var enter_time: float = 0.0
	var exit_time: float = 1.0
	var enter_normal: Vector2 = Vector2.ZERO
	for axis: int in range(2):
		var origin_value: float = start.x if axis == 0 else start.y
		var motion_value: float = motion.x if axis == 0 else motion.y
		var minimum_value: float = rectangle.position.x if axis == 0 else rectangle.position.y
		var maximum_value: float = rectangle.end.x if axis == 0 else rectangle.end.y
		if absf(motion_value) < 0.0001:
			if origin_value < minimum_value or origin_value > maximum_value: return {}
			continue
		var near_time: float = (minimum_value - origin_value) / motion_value
		var far_time: float = (maximum_value - origin_value) / motion_value
		if near_time > far_time:
			var held_time: float = near_time
			near_time = far_time
			far_time = held_time
		if near_time > enter_time:
			enter_time = near_time
			enter_normal = Vector2(-signf(motion_value), 0.0) if axis == 0 else Vector2(0.0, -signf(motion_value))
		exit_time = minf(exit_time, far_time)
		if enter_time > exit_time: return {}
	if enter_time < 0.0 or enter_time > 1.0: return {}
	if enter_normal == Vector2.ZERO:
		enter_normal = Vector2(-signf(motion.x), 0.0) if absf(motion.x) >= absf(motion.y) else Vector2(0.0, -signf(motion.y))
	return {"position": start + motion * enter_time, "normal": enter_normal, "time": enter_time}

func navigation_direction(from_position: Vector2, target_position: Vector2) -> Vector2:
	var direct_direction: Vector2 = from_position.direction_to(target_position)
	if navigation_grid == null or blocking_bounds.is_empty() or _segment_is_clear(from_position, target_position): return direct_direction
	var start_id: Vector2i = ArenaLayoutValidator.nearest_walkable_cell(ArenaLayoutValidator.world_to_cell(from_position, config, navigation_grid), navigation_grid)
	var target_id: Vector2i = ArenaLayoutValidator.nearest_walkable_cell(ArenaLayoutValidator.world_to_cell(target_position, config, navigation_grid), navigation_grid)
	var path: PackedVector2Array = navigation_grid.get_point_path(start_id, target_id, true)
	if path.is_empty(): return direct_direction
	for waypoint: Vector2 in path:
		if waypoint.distance_to(from_position) > config.navigation_cell_size * 0.55:
			return from_position.direction_to(waypoint)
	return direct_direction

func _segment_is_clear(start: Vector2, end: Vector2) -> bool:
	var distance: float = start.distance_to(end)
	var sample_count: int = maxi(1, ceili(distance / 18.0))
	for sample_index: int in range(sample_count + 1):
		var sample: Vector2 = start.lerp(end, float(sample_index) / float(sample_count))
		for bounds: Rect2 in blocking_bounds:
			if bounds.grow(config.navigation_margin * 0.7).has_point(sample): return false
	return true

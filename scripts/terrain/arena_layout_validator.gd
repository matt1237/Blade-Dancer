class_name ArenaLayoutValidator extends RefCounted

static func candidate_is_safe(candidate: Rect2, accepted: Array[Rect2], config: TerrainConfig, is_trap: bool) -> bool:
	var usable_arena: Rect2 = config.arena_rect.grow(-config.arena_edge_clearance)
	if not usable_arena.encloses(candidate): return false
	var closest_spawn_point: Vector2 = Vector2(clampf(config.player_spawn.x, candidate.position.x, candidate.end.x), clampf(config.player_spawn.y, candidate.position.y, candidate.end.y))
	if closest_spawn_point.distance_to(config.player_spawn) < config.player_spawn_clearance: return false
	var requested_spacing: float = maxf(config.module_spacing, config.trap_telegraph_clearance if is_trap else config.module_spacing)
	for occupied: Rect2 in accepted:
		if occupied.grow(requested_spacing).intersects(candidate): return false
	var occupied_area: float = candidate.get_area()
	for occupied: Rect2 in accepted: occupied_area += occupied.get_area()
	var open_ratio: float = 1.0 - occupied_area / maxf(config.arena_rect.get_area(), 1.0)
	return open_ratio >= config.minimum_open_area_ratio

static func routes_remain_open(blocking_rects: Array[Rect2], config: TerrainConfig) -> bool:
	var grid: AStarGrid2D = build_navigation_grid(blocking_rects, config)
	var spawn_id: Vector2i = world_to_cell(config.player_spawn, config, grid)
	if grid.is_point_solid(spawn_id): return false
	var arena: Rect2 = config.arena_rect.grow(-config.arena_edge_clearance)
	var anchors: Array[Vector2] = [
		Vector2(arena.position.x, arena.get_center().y),
		Vector2(arena.end.x, arena.get_center().y),
		Vector2(arena.get_center().x, arena.position.y),
		Vector2(arena.get_center().x, arena.end.y),
		arena.position,
		Vector2(arena.end.x, arena.position.y),
		arena.end,
		Vector2(arena.position.x, arena.end.y)
	]
	for anchor: Vector2 in anchors:
		var target_id: Vector2i = nearest_walkable_cell(world_to_cell(anchor, config, grid), grid)
		if grid.get_id_path(spawn_id, target_id, false).is_empty(): return false
	var left_id: Vector2i = nearest_walkable_cell(world_to_cell(anchors[0], config, grid), grid)
	var right_id: Vector2i = nearest_walkable_cell(world_to_cell(anchors[1], config, grid), grid)
	var top_id: Vector2i = nearest_walkable_cell(world_to_cell(anchors[2], config, grid), grid)
	var bottom_id: Vector2i = nearest_walkable_cell(world_to_cell(anchors[3], config, grid), grid)
	return not grid.get_id_path(left_id, right_id, false).is_empty() and not grid.get_id_path(top_id, bottom_id, false).is_empty()

static func build_navigation_grid(blocking_rects: Array[Rect2], config: TerrainConfig) -> AStarGrid2D:
	var grid: AStarGrid2D = AStarGrid2D.new()
	var columns: int = maxi(1, ceili(config.arena_rect.size.x / config.navigation_cell_size))
	var rows: int = maxi(1, ceili(config.arena_rect.size.y / config.navigation_cell_size))
	grid.region = Rect2i(0, 0, columns, rows)
	grid.cell_size = Vector2.ONE * config.navigation_cell_size
	grid.offset = config.arena_rect.position + Vector2.ONE * config.navigation_cell_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y: int in range(rows):
		for x: int in range(columns):
			var id: Vector2i = Vector2i(x, y)
			var point: Vector2 = grid.get_point_position(id)
			for blocking_rect: Rect2 in blocking_rects:
				if blocking_rect.grow(config.navigation_margin).has_point(point):
					grid.set_point_solid(id, true)
					break
	return grid

static func world_to_cell(world_position: Vector2, config: TerrainConfig, grid: AStarGrid2D) -> Vector2i:
	var local_position: Vector2 = world_position - config.arena_rect.position
	var id: Vector2i = Vector2i(floori(local_position.x / config.navigation_cell_size), floori(local_position.y / config.navigation_cell_size))
	return Vector2i(clampi(id.x, grid.region.position.x, grid.region.end.x - 1), clampi(id.y, grid.region.position.y, grid.region.end.y - 1))

static func nearest_walkable_cell(origin: Vector2i, grid: AStarGrid2D) -> Vector2i:
	if grid.is_in_boundsv(origin) and not grid.is_point_solid(origin): return origin
	for radius: int in range(1, 5):
		for y: int in range(origin.y - radius, origin.y + radius + 1):
			for x: int in range(origin.x - radius, origin.x + radius + 1):
				var candidate: Vector2i = Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	return origin

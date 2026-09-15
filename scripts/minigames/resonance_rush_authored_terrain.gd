class_name ResonanceRushAuthoredTerrain extends ResonanceRushTerrain

## Runtime adapter for editor-authored ResonanceRushChunk children.
## It compiles each chunk's visible DrivePath into the same height-field query
## data already consumed by ResonanceRushLandSail. No terrain is randomized.

func generate_course() -> Vector2:
	segments.clear()
	ground_polylines.clear()
	gap_edges.clear()
	mushroom_positions.clear()
	grapple_point_positions.clear()

	var chunks: Array[ResonanceRushChunk] = []
	_collect_chunks(self, chunks)
	chunks.sort_custom(_sort_chunks_left_to_right)
	if chunks.is_empty():
		push_error("ResonanceRushAuthoredTerrain: no ResonanceRushChunk children found")
		return Vector2.ZERO

	max_world_y = -INF
	for chunk: ResonanceRushChunk in chunks:
		var chunk_points: PackedVector2Array = chunk.get_surface_points()
		if chunk_points.size() < 2:
			continue
		var terrain_points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in chunk_points:
			var terrain_point: Vector2 = to_local(chunk.to_global(point))
			terrain_points.append(terrain_point)
			max_world_y = maxf(max_world_y, terrain_point.y)
		_append_segments(terrain_points)
		ground_polylines.append(terrain_points)

	if ground_polylines.is_empty():
		push_error("ResonanceRushAuthoredTerrain: authored chunks contain no usable DrivePath")
		return Vector2.ZERO
	start_position = ground_polylines[0][0]
	var final_polyline: PackedVector2Array = ground_polylines[ground_polylines.size() - 1]
	course_end_position = final_polyline[final_polyline.size() - 1]
	max_world_y += 700.0
	return start_position

func _collect_chunks(node: Node, output: Array[ResonanceRushChunk]) -> void:
	for child: Node in node.get_children():
		var chunk: ResonanceRushChunk = child as ResonanceRushChunk
		if chunk != null:
			output.append(chunk)
		else:
			_collect_chunks(child, output)

func _sort_chunks_left_to_right(a: ResonanceRushChunk, b: ResonanceRushChunk) -> bool:
	return a.global_position.x + a.get_entry_position().x < b.global_position.x + b.get_entry_position().x

## RushChunk draws its own editor-visible ground. Suppress the legacy terrain
## renderer so no lines, procedural fills, or stretched tile polygons appear.
func _draw() -> void:
	pass

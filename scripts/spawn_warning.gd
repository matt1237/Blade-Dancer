class_name SpawnWarning extends Node2D

var elapsed: float = 0.0

## World rewind (WorldRewindRecorder contract). The payload is the `finished` connection itself,
## which stays on the node, so a revived warning spawns the same thing again.
const REWIND_GAMEPLAY_GROUPS: Array[StringName] = [&"spawn_warnings"]
var rewind_retired: bool = false

func _ready() -> void:
	add_to_group("spawn_warnings")
	add_to_group(WorldRewindRecorder.REWINDABLE_GROUP)
signal finished(position: Vector2)

func _process(delta: float) -> void:
	if rewind_retired:
		return
	elapsed += delta * WorldTime.enemy_scale() # World Slow: part of the slowed spawn cadence
	queue_redraw()
	if elapsed >= 1.0:
		finished.emit(global_position)
		WorldRewindRecorder.retire_or_free(self, REWIND_GAMEPLAY_GROUPS)

func rewind_stride() -> int:
	return 3

func rewind_capture(d: PackedFloat32Array, o: int) -> void:
	d[o] = global_position.x; d[o + 1] = global_position.y; d[o + 2] = elapsed

func rewind_restore(d: PackedFloat32Array, o: int) -> void:
	global_position = Vector2(d[o], d[o + 1]); elapsed = d[o + 2]
	queue_redraw()

func _draw() -> void:
	var pulse: float = (sin(elapsed * TAU * 6.0) + 1.0) * 0.5
	var radius: float = 25.0 + pulse * 5.0
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.0, 0.0, 0.12 + pulse * 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.05, 0.02, 0.55 + pulse * 0.45), 3.0, true)
	draw_circle(Vector2.ZERO, 4.0 + pulse * 3.0, Color("ff3028"))

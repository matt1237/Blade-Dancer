class_name SpawnWarning extends Node2D

var elapsed: float = 0.0

func _ready() -> void:
	add_to_group("spawn_warnings")
signal finished(position: Vector2)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= 1.0:
		finished.emit(global_position)
		queue_free()

func _draw() -> void:
	var pulse: float = (sin(elapsed * TAU * 6.0) + 1.0) * 0.5
	var radius: float = 25.0 + pulse * 5.0
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.0, 0.0, 0.12 + pulse * 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.05, 0.02, 0.55 + pulse * 0.45), 3.0, true)
	draw_circle(Vector2.ZERO, 4.0 + pulse * 3.0, Color("ff3028"))

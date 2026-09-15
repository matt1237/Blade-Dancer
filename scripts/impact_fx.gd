class_name ImpactFX extends Node2D

enum ImpactType { GENERIC, CLASH, PARRY }

@export var lifetime: float = 0.18
@export var intensity: float = 1.0
@export var impact_type: ImpactType = ImpactType.GENERIC

var elapsed: float = 0.0
var directions: Array[Vector2] = []

func _ready() -> void:
	var count: int = 12 if impact_type == ImpactType.CLASH else (10 if impact_type == ImpactType.PARRY else 8)
	for index: int in range(count):
		directions.append(Vector2.RIGHT.rotated(float(index) * TAU / float(count) + randf_range(-0.18, 0.18)))
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()

func _draw() -> void:
	var progress: float = clampf(elapsed / lifetime, 0.0, 1.0)
	var alpha: float = 1.0 - progress

	match impact_type:
		ImpactType.PARRY:
			# EXCLUSIVE ELECTRIC CYAN / CERULEAN BLUE PARRY
			# Expanding sharp deflection ripple ring
			var ring_radius: float = lerpf(6.0, 36.0, progress) * intensity
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(0.25, 0.85, 1.0, alpha * 0.9), 3.0 * (1.0 - progress * 0.5), true)
			draw_circle(Vector2.ZERO, lerpf(6.0, 20.0, progress) * intensity, Color(0.1, 0.65, 1.4, alpha * 0.3))
			draw_circle(Vector2.ZERO, 5.0 * (1.0 - progress), Color(1.7, 1.95, 2.0, alpha))
			# High-speed electric spark needles
			for direction: Vector2 in directions:
				var start: Vector2 = direction * (4.0 + progress * 8.0)
				var end: Vector2 = direction * (14.0 + progress * 38.0) * intensity
				draw_line(start, end, Color(0.2, 0.8, 1.0, alpha * 0.8), 2.5 * (1.0 - progress * 0.5), true)
				draw_line(start, start + (end - start) * 0.6, Color(0.85, 0.98, 1.0, alpha), 1.2, true)

		ImpactType.CLASH:
			# HEAVY EXPLOSIVE WHITE-HOT / DEEP AMBER CLASH
			# Massive shockwave blast ring
			var shockwave_radius: float = lerpf(8.0, 48.0, progress) * intensity
			draw_arc(Vector2.ZERO, shockwave_radius, 0.0, TAU, 36, Color(1.0, 0.82, 0.25, alpha * 0.85), 4.0 * (1.0 - progress * 0.7), true)
			draw_arc(Vector2.ZERO, shockwave_radius * 0.6, 0.0, TAU, 28, Color(1.0, 0.35, 0.05, alpha * 0.6), 2.5 * (1.0 - progress * 0.5), true)
			# Blinding white-hot core flare
			draw_circle(Vector2.ZERO, lerpf(12.0, 26.0, progress) * intensity, Color(1.4, 0.5, 0.1, alpha * 0.4))
			draw_circle(Vector2.ZERO, lerpf(5.0, 10.0, progress) * intensity, Color(2.0, 1.8, 1.35, alpha * 0.95))
			# High-energy ember shards
			for direction: Vector2 in directions:
				var start: Vector2 = direction * (6.0 + progress * 10.0)
				var end: Vector2 = direction * (16.0 + progress * 42.0) * intensity
				draw_line(start, end, Color(1.0, 0.38, 0.08, alpha * 0.85), 3.0 * (1.0 - progress * 0.6), true)
				draw_line(start, start + (end - start) * 0.7, Color(1.0, 0.95, 0.75, alpha), 1.5, true)

		_:
			# Generic sparks (yellow/amber)
			draw_circle(Vector2.ZERO, lerpf(8.0, 25.0, progress) * intensity, Color(1.35, 1.0, 0.35, alpha * 0.35))
			for direction: Vector2 in directions:
				var start: Vector2 = direction * (4.0 + progress * 5.0)
				var end: Vector2 = direction * (12.0 + progress * 28.0) * intensity
				draw_line(start, end, Color(1.0, 0.92, 0.55, alpha), lerpf(3.0, 0.5, progress), true)

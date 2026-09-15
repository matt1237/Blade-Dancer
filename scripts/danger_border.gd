class_name DangerBorder extends Control

var health_ratio: float = 1.0
var pulse_time: float = 0.0

func set_health_ratio(value: float) -> void:
	health_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	if health_ratio >= 0.3: return
	var danger: float = clampf((0.3 - health_ratio) / 0.3, 0.0, 1.0)
	var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(pulse_time * TAU * 1.4))
	var alpha: float = danger * pulse * 0.75
	var viewport_size: Vector2 = get_viewport_rect().size
	var color: Color = Color(1.0, 0.04, 0.03, alpha)
	draw_rect(Rect2(7.0, 7.0, viewport_size.x - 14.0, viewport_size.y - 14.0), color, false, 8.0)
	draw_rect(Rect2(18.0, 18.0, viewport_size.x - 36.0, viewport_size.y - 36.0), Color(1.0, 0.08, 0.03, alpha * 0.28), false, 3.0)

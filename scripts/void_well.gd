class_name VoidWell extends Node2D

var pull_strength: float = 180.0
var lifetime: float = 2.4
var elapsed: float = 0.0

func setup(position_value: Vector2, strength: float) -> void:
	global_position = position_value
	pull_strength = strength

func _physics_process(delta: float) -> void:
	elapsed += delta
	lifetime -= delta
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy != null and is_instance_valid(enemy):
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance < 145.0 and distance > 8.0:
				enemy.apply_void_pull(global_position.direction_to(enemy.global_position), pull_strength * (1.0 - distance / 145.0) * delta)
	if lifetime <= 0.0: queue_free()
	queue_redraw()

func _draw() -> void:
	var fade: float = clampf(lifetime / 2.4, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(elapsed * TAU * 3.0)
	draw_circle(Vector2.ZERO, 28.0 + pulse * 5.0, Color(0.08, 0.01, 0.14, fade * 0.8))
	draw_circle(Vector2.ZERO, 15.0, Color(0.01, 0.0, 0.02, fade))
	draw_arc(Vector2.ZERO, 38.0 + pulse * 8.0, 0.0, TAU, 40, Color(0.55, 0.12, 0.85, fade * 0.9), 4.0, true)
	draw_arc(Vector2.ZERO, 52.0 - pulse * 8.0, 0.0, TAU, 40, Color(0.3, 0.05, 0.55, fade * 0.55), 2.0, true)

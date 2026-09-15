class_name TreeCanopyOverlay extends Node2D

var host: ArenaObject = null

func setup(tree: ArenaObject) -> void:
	host = tree
	z_as_relative = false
	z_index = 3
	queue_redraw()

func _process(_delta: float) -> void:
	if is_instance_valid(host): queue_redraw()

func _draw() -> void:
	if not is_instance_valid(host) or host.broken: return
	var alpha: float = host.canopy_alpha
	var tint: Color = Color(1.0, 1.0, 1.0, alpha)
	var canopy_dark: Color = Color(0.08, 0.18, 0.15, alpha)
	var canopy: Color = Color(0.18, 0.36, 0.24, alpha)
	draw_circle(Vector2(-25, -34), 34.0, canopy_dark * tint)
	draw_circle(Vector2(24, -37), 38.0, canopy_dark * tint)
	draw_circle(Vector2(0, -58), 42.0, canopy_dark * tint)
	draw_circle(Vector2(-20, -35), 27.0, canopy * tint)
	draw_circle(Vector2(21, -39), 30.0, canopy * tint)
	draw_circle(Vector2(0, -59), 33.0, canopy * tint)
	draw_circle(Vector2(-14, -66), 11.0, Color(0.36, 0.55, 0.28, alpha) * tint)

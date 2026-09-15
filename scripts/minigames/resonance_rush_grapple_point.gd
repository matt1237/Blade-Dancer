@tool
class_name ResonanceRushGrapplePoint extends Node2D

## Editor-placeable grapple anchor. Put instances beneath a RushChunk's
## GrapplePoints container, select them in the Scene tree, and move them with W.

@export var active: bool = true
@export var show_editor_drop_line: bool = true
@export var editor_drop_line_length: float = 150.0
@export var show_editor_hook_range: bool = true
@export var editor_hook_range: float = 560.0

func _ready() -> void:
	if active:
		add_to_group("resonance_grapple_point")
	queue_redraw()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08
			sprite.scale = Vector2.ONE * pulse

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if show_editor_hook_range:
		draw_arc(Vector2.ZERO, editor_hook_range, 0.0, TAU, 96, Color(0.35, 0.85, 1.0, 0.16), 2.0, true)
	if show_editor_drop_line:
		draw_line(Vector2.ZERO, Vector2(0.0, editor_drop_line_length), Color(0.35, 0.85, 1.0, 0.28), 2.0, true)
		draw_circle(Vector2.ZERO, 31.0, Color(0.35, 0.85, 1.0, 0.08))
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 28, Color(0.35, 0.85, 1.0, 0.85), 2.0, true)

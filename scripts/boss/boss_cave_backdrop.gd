class_name BossCaveBackdrop extends Node2D

func _ready() -> void:
	z_index = 1
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(510.0, -10.0, 260.0, 130.0), Color("241d27"), true)
	draw_arc(Vector2(640.0, 118.0), 130.0, PI, TAU, 32, Color("6a4439"), 20.0, true)
	draw_arc(Vector2(640.0, 118.0), 104.0, PI, TAU, 32, Color("17151c"), 14.0, true)
	draw_line(Vector2(535.0, 115.0), Vector2(745.0, 115.0), Color("36262a"), 8.0, true)

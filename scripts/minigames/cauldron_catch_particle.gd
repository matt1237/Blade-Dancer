class_name CauldronCatchParticle extends Control

## Tiny reusable circle particle for the cauldron's idle bubbles and the
## splash burst when something lands in it. Pure procedural drawing — no
## art asset needed for a handful of simmering dots and droplets.

var radius: float = 4.0
var particle_color: Color = Color(0.55, 0.95, 0.4, 0.85)

func _draw() -> void:
	draw_circle(Vector2(radius, radius), radius, particle_color)

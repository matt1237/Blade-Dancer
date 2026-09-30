extends RefCounted
## PX ARENA — the walled box the prototype is played in.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")


## Build four static walls around Cfg.ARENA, parented to `parent`.
static func build(parent: Node) -> void:
	var t: float = Cfg.WALL_THICKNESS
	var walls: Array[Rect2] = [
		Rect2(Cfg.ARENA.position + Vector2(-t, -t), Vector2(Cfg.ARENA.size.x + t * 2.0, t)),
		Rect2(Cfg.ARENA.position + Vector2(-t, Cfg.ARENA.size.y), Vector2(Cfg.ARENA.size.x + t * 2.0, t)),
		Rect2(Cfg.ARENA.position + Vector2(-t, 0.0), Vector2(t, Cfg.ARENA.size.y)),
		Rect2(Cfg.ARENA.position + Vector2(Cfg.ARENA.size.x, 0.0), Vector2(t, Cfg.ARENA.size.y)),
	]
	for wall: Rect2 in walls:
		var body := StaticBody2D.new()
		body.collision_layer = Cfg.L_WALLS
		body.collision_mask = 0
		body.position = wall.position + wall.size * 0.5
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall.size
		shape.shape = rect
		body.add_child(shape)
		parent.add_child(body)


## A random point just inside the arena edge, for spawns.
static func random_edge_point() -> Vector2:
	var margin: float = 60.0
	match randi() % 4:
		0: return Vector2(randf_range(Cfg.ARENA.position.x + margin, Cfg.ARENA.end.x - margin), Cfg.ARENA.position.y + margin)
		1: return Vector2(randf_range(Cfg.ARENA.position.x + margin, Cfg.ARENA.end.x - margin), Cfg.ARENA.end.y - margin)
		2: return Vector2(Cfg.ARENA.position.x + margin, randf_range(Cfg.ARENA.position.y + margin, Cfg.ARENA.end.y - margin))
		_: return Vector2(Cfg.ARENA.end.x - margin, randf_range(Cfg.ARENA.position.y + margin, Cfg.ARENA.end.y - margin))
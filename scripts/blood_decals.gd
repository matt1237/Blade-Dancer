class_name BloodDecals extends Node2D
## Ground blood pools left behind by split kills. Lives on its own low-z layer
## (above the arena floor, below the player) so a pool reads as being on the
## ground rather than painted over the body. Pools grow briefly, then fade.

class BloodPool extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var radius: float = 18.0
	var max_radius: float = 28.0
	var life: float = 0.0
	var total_life: float = 2.0
	## Per-pool colour, so a tinted enemy (e.g. the green Bug) pools its own blood.
	var color: Color = Color(0.42, 0.015, 0.03, 0.9)

@export var pool_total_life: float = 2.0
@export var pool_limit: int = 40
@export var pool_color: Color = Color(0.42, 0.015, 0.03, 0.9)

var pools: Array[BloodPool] = []

func spawn_pool(world_position: Vector2, base_radius: float, tint: Color = Color(-1.0, -1.0, -1.0, -1.0)) -> void:
	var pool: BloodPool = BloodPool.new()
	# Sit the pool slightly below the kill so it reads as pooling at the feet.
	pool.world_position = world_position + Vector2(0.0, 6.0)
	# A supplied tint keeps the pool's own opacity/behaviour but takes the caller's
	# hue, so a green Bug leaves a green puddle while everything else stays red.
	pool.color = pool_color if tint.a < 0.0 else Color(tint.r, tint.g, tint.b, pool_color.a)
	pool.max_radius = clampf(base_radius, 10.0, 70.0)
	pool.radius = pool.max_radius * 0.5
	pool.total_life = pool_total_life
	pool.life = pool.total_life
	pools.append(pool)
	while pools.size() > maxi(1, pool_limit):
		pools.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	if pools.is_empty():
		return
	for index: int in range(pools.size() - 1, -1, -1):
		var pool: BloodPool = pools[index]
		pool.life -= delta
		if pool.life <= 0.0:
			pools.remove_at(index)
			continue
		var progress: float = 1.0 - pool.life / maxf(pool.total_life, 0.001)
		pool.radius = pool.max_radius * (0.6 + 0.4 * smoothstep(0.0, 0.3, progress))
	queue_redraw()

func _draw() -> void:
	for pool: BloodPool in pools:
		var life_ratio: float = clampf(pool.life / maxf(pool.total_life, 0.001), 0.0, 1.0)
		var alpha: float = pool.color.a * clampf(life_ratio / 0.45, 0.0, 1.0)
		var local_position: Vector2 = to_local(pool.world_position)
		_draw_puddle(local_position, pool.radius, Color(pool.color.r, pool.color.g, pool.color.b, alpha))
		_draw_puddle(local_position, pool.radius * 0.62, Color(pool.color.r * 0.7, pool.color.g * 0.6, pool.color.b * 0.6, alpha))

func _draw_puddle(center: Vector2, radius: float, color: Color) -> void:
	# Flattened ellipse built by hand: primitives can ignore draw transforms for
	# scale in some render backends, so build the shape directly instead.
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 20
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius * 1.15, sin(angle) * radius * 0.55))
	draw_colored_polygon(points, color)
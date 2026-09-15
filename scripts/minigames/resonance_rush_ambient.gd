class_name ResonanceRushAmbient extends Node2D

## Very small ambient-life spawner: a few glowing birds drift by ahead of
## the player and are cleaned up once they fall behind. Left intentionally
## tiny — the architecture (spawn_interval / textures / this script) is where
## later altitude-gated events (bigger creatures, a phoenix at high
## altitude) would hook in, but none of that is built yet.

@export var bird_texture: Texture2D
@export var spawn_interval: float = 3.5
@export var max_ambient: int = 6
@export var spawn_ahead_distance: float = 900.0
@export var spawn_height_range: Vector2 = Vector2(-500.0, -50.0)

var land_sail: Node2D = null
var time_since_spawn: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _process(delta: float) -> void:
	if land_sail == null or bird_texture == null:
		return
	time_since_spawn += delta
	if time_since_spawn >= spawn_interval and get_child_count() < max_ambient:
		time_since_spawn = 0.0
		_spawn_bird()
	for child: Node in get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null:
			continue
		var drift: Vector2 = sprite.get_meta("velocity", Vector2.ZERO)
		sprite.position += drift * delta
		if sprite.global_position.x < land_sail.global_position.x - 500.0:
			sprite.queue_free()

func _spawn_bird() -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = bird_texture
	sprite.global_position = land_sail.global_position + Vector2(
		spawn_ahead_distance + rng.randf_range(-100.0, 200.0),
		rng.randf_range(spawn_height_range.x, spawn_height_range.y)
	)
	sprite.set_meta("velocity", Vector2(rng.randf_range(-40.0, -10.0), rng.randf_range(-15.0, 15.0)))
	add_child(sprite)
	var tween: Tween = create_tween().set_loops(2000)
	tween.tween_property(sprite, "position:y", 14.0, 0.9).as_relative()
	tween.tween_property(sprite, "position:y", -14.0, 0.9).as_relative()

class_name ResonanceRushClouds extends Node2D

## Physical-feeling but non-blocking clouds: flying through one makes it
## poof/fade out, then it quietly reforms after reform_delay. Pure visual
## toy — no collision response, works from any direction of travel.

@export var cloud_texture: Texture2D
@export var cloud_count: int = 16
@export var spawn_height_range: Vector2 = Vector2(-2600.0, -80.0)
@export var poof_radius: float = 80.0
@export var reform_delay: float = 4.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var clouds: Array[Dictionary] = []
var land_sail: Node2D = null

func populate(course_start: Vector2, course_length: float) -> void:
	for entry: Dictionary in clouds:
		(entry["sprite"] as Sprite2D).queue_free()
	clouds.clear()
	if cloud_texture == null:
		return
	for _index: int in range(cloud_count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = cloud_texture
		var scale_value: float = rng.randf_range(1.5, 3.2)
		sprite.scale = Vector2.ONE * scale_value
		sprite.modulate.a = 0.85
		sprite.global_position = Vector2(
			course_start.x + rng.randf_range(300.0, course_length),
			rng.randf_range(spawn_height_range.x, spawn_height_range.y)
		)
		add_child(sprite)
		clouds.append({"sprite": sprite, "original_scale": sprite.scale, "poofed": false, "timer": 0.0})

func _process(delta: float) -> void:
	if land_sail == null:
		return
	for entry: Dictionary in clouds:
		var sprite: Sprite2D = entry["sprite"]
		if entry["poofed"]:
			entry["timer"] -= delta
			if entry["timer"] <= 0.0:
				entry["poofed"] = false
				sprite.visible = true
				sprite.modulate.a = 0.85
				sprite.scale = entry["original_scale"]
			continue
		if sprite.global_position.distance_to(land_sail.global_position) < poof_radius:
			_poof(entry)

func _poof(entry: Dictionary) -> void:
	entry["poofed"] = true
	entry["timer"] = reform_delay
	var sprite: Sprite2D = entry["sprite"]
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", (entry["original_scale"] as Vector2) * 1.6, 0.25)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: sprite.visible = false)

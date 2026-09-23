class_name PlayerScarfRig extends Node2D

const POINT_COUNT: int = 6
const SEGMENT_LENGTH: float = 8.0
const CONSTRAINT_ITERATIONS: int = 5
const SCARF_SEGMENT_TEXTURE: Texture2D = preload("res://assets/generated/leather_scarf_segment.png")
const SCARF_TIP_TEXTURE: Texture2D = preload("res://assets/generated/leather_scarf_tip.png")
const SCARF_TEXTURE_LENGTH: float = 32.0
const SCARF_TEXTURE_HEIGHT_SCALE: float = 0.72

@export var follow_strength: float = 22.0
@export var drag_per_second: float = 5.5
@export var gravity: float = 34.0
@export var velocity_influence: float = 0.055
@export var dash_influence: float = 0.09
@export var max_extension: float = 47.0

var actor: Player = null
var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []
var last_actor_velocity: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var segment_sprites: Array[Sprite2D] = []

func setup(player: Player) -> void:
	actor = player
	z_index = -2
	z_as_relative = true
	_create_segment_sprites()
	_reset_chain()

func _create_segment_sprites() -> void:
	for sprite: Sprite2D in segment_sprites:
		if is_instance_valid(sprite): sprite.queue_free()
	segment_sprites.clear()
	for index: int in range(POINT_COUNT - 1):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "ScarfTip" if index == POINT_COUNT - 2 else "ScarfSegment%d" % index
		sprite.texture = SCARF_TIP_TEXTURE if index == POINT_COUNT - 2 else SCARF_SEGMENT_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.z_index = index
		add_child(sprite)
		segment_sprites.append(sprite)

func _reset_chain() -> void:
	points.clear()
	previous_points.clear()
	var anchor: Vector2 = _neck_anchor()
	var trail_direction: Vector2 = Vector2(-_facing_sign(), 0.18).normalized()
	for index: int in range(POINT_COUNT):
		var point: Vector2 = anchor + trail_direction * SEGMENT_LENGTH * float(index)
		points.append(point)
		previous_points.append(point)
	_update_segment_sprites()

func _physics_process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor): return
	visible = actor.visual_style == "hd" and actor.equipped_armor_id == "Basic Leather Armor"
	if not visible: return
	if points.size() != POINT_COUNT:
		_reset_chain()
		return
	elapsed += delta
	var anchor: Vector2 = _neck_anchor()
	var actor_velocity: Vector2 = actor.velocity
	var acceleration: Vector2 = (actor_velocity - last_actor_velocity) / maxf(delta, 0.001)
	last_actor_velocity = actor_velocity
	points[0] = anchor
	previous_points[0] = anchor
	var damping: float = exp(-drag_per_second * delta)
	for index: int in range(1, POINT_COUNT):
		var current: Vector2 = points[index]
		var inherited_motion: Vector2 = (points[index] - previous_points[index]) * damping
		previous_points[index] = current
		var wake: Vector2 = -actor_velocity * velocity_influence
		var impulse_wake: Vector2 = -acceleration.limit_length(1200.0) * dash_influence * delta
		var idle_flutter: Vector2 = Vector2(0.0, sin(elapsed * 3.1 + float(index) * 0.7) * 3.0) * delta
		points[index] += inherited_motion + (Vector2.DOWN * gravity + wake) * delta + impulse_wake + idle_flutter
	for iteration: int in range(CONSTRAINT_ITERATIONS):
		points[0] = anchor
		for index: int in range(1, POINT_COUNT):
			var offset: Vector2 = points[index] - points[index - 1]
			var distance: float = maxf(offset.length(), 0.001)
			var correction: Vector2 = offset * ((distance - SEGMENT_LENGTH) / distance)
			points[index] -= correction
		# Keep cloth out of the torso/head core without commanding a canned path.
		for index: int in range(1, POINT_COUNT):
			var from_body: Vector2 = points[index] - Vector2(0.0, -5.0)
			if from_body.length() < 15.0:
				points[index] = Vector2(0.0, -5.0) + from_body.normalized() * 15.0
	var final_offset: Vector2 = points[POINT_COUNT - 1] - anchor
	if final_offset.length() > max_extension:
		points[POINT_COUNT - 1] = anchor + final_offset.normalized() * max_extension
	_update_segment_sprites()

func _update_segment_sprites() -> void:
	if segment_sprites.size() != POINT_COUNT - 1 or points.size() != POINT_COUNT: return
	for index: int in range(segment_sprites.size()):
		var offset: Vector2 = points[index + 1] - points[index]
		var length: float = maxf(1.0, offset.length())
		var sprite: Sprite2D = segment_sprites[index]
		sprite.position = points[index]
		sprite.rotation = offset.angle()
		sprite.scale = Vector2(length / SCARF_TEXTURE_LENGTH, SCARF_TEXTURE_HEIGHT_SCALE)
		sprite.visible = visible

func _facing_sign() -> float:
	if actor != null and actor.knight_sprite_hd != null:
		return -1.0 if actor.knight_sprite_hd.flip_h else 1.0
	return 1.0

func _neck_anchor() -> Vector2:
	if actor == null: return Vector2(0.0, -20.0)
	var body_offset: Vector2 = actor.knight_sprite_hd.position if actor.knight_sprite_hd != null else Vector2.ZERO
	return body_offset + Vector2(-_facing_sign() * 6.0, -20.0)

func _draw() -> void:
	# Authored Sprite2D segments render the constrained geometry. Keeping this
	# draw hook empty avoids layering a procedural ribbon over the pixel art.
	pass

class_name BossCampfire extends Node2D

const BONFIRE_ATLAS: Texture2D = preload("res://assets/generated/hd_zungar_bonfire_atlas.png")
const FRAME_SIZE: Vector2 = Vector2(384.0, 384.0)
const FRAME_COUNT: int = 4
const DISPLAY_SCALE: float = 0.64
const SPRITE_OFFSET: Vector2 = Vector2(0.0, -82.0)
const IGNITION_OFFSET: Vector2 = Vector2(0.0, -55.0)

@export_category("Boss Campfire Tuning")
@export var ignition_radius: float = ZungarConfig.CAMPFIRE_IGNITION_RADIUS
@export var disabled_duration: float = ZungarConfig.CAMPFIRE_DISABLED_DURATION

var fire_active: bool = true
var disabled_left: float = 0.0
var flame_sprite: AnimatedSprite2D = null

signal fire_ignited()
signal fire_extinguished()

func _ready() -> void:
	add_to_group("zungar_campfire")
	_create_illustrated_bonfire()

func _create_illustrated_bonfire() -> void:
	flame_sprite = AnimatedSprite2D.new()
	flame_sprite.name = "IllustratedBonfire"
	flame_sprite.sprite_frames = _build_sprite_frames()
	flame_sprite.position = SPRITE_OFFSET
	flame_sprite.scale = Vector2.ONE * DISPLAY_SCALE
	flame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flame_sprite.play(&"burn")
	add_child(flame_sprite)

func _build_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", 9.0)
	frames.set_animation_loop(&"burn", true)
	for frame_index: int in range(FRAME_COUNT):
		var frame_texture: AtlasTexture = AtlasTexture.new()
		frame_texture.atlas = BONFIRE_ATLAS
		frame_texture.region = Rect2(Vector2(float(frame_index) * FRAME_SIZE.x, 0.0), FRAME_SIZE)
		frames.add_frame(&"burn", frame_texture)
	return frames

func _process(delta: float) -> void:
	if not fire_active:
		disabled_left = maxf(0.0, disabled_left - delta)
		if disabled_left <= 0.0:
			fire_active = true
			fire_ignited.emit()
	if flame_sprite == null:
		return
	if fire_active:
		flame_sprite.speed_scale = 1.0
		var flicker: float = 0.94 + 0.06 * sin(Time.get_ticks_msec() * 0.009)
		flame_sprite.modulate = Color(1.0, flicker, flicker * 0.92, 1.0)
	else:
		flame_sprite.speed_scale = 0.12
		flame_sprite.modulate = Color(0.26, 0.23, 0.22, 0.5)

func get_ignition_center() -> Vector2:
	return global_position + IGNITION_OFFSET

func sword_crossed(start: Vector2, end: Vector2) -> bool:
	if not fire_active:
		return false
	if _distance_to_segment(get_ignition_center(), start, end) > ignition_radius:
		return false
	fire_ignited.emit()
	return true

func stomp_out() -> void:
	if not fire_active:
		return
	fire_active = false
	disabled_left = disabled_duration
	fire_extinguished.emit()

func take_charge_hit(_direction: Vector2) -> void:
	stomp_out()

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared < 0.001:
		return point.distance_to(start)
	var ratio: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

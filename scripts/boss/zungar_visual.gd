@tool
class_name ZungarVisual extends Node2D

const ZUNGAR_CONFIG = preload("res://scripts/boss/zungar_config.gd")
const CHARGE_WINDUP_ATLAS: Texture2D = preload("res://assets/generated/hd_boss_zungar_charge_windup_smooth.png")
const CHARGE_TRAVEL_ATLAS: Texture2D = preload("res://assets/generated/hd_boss_zungar_charge_travel_smooth.png")
const STUNNED_ATLAS: Texture2D = preload("res://assets/generated/hd_boss_zungar_stunned_smooth.png")
const GENERATED_FRAME_SIZE: Vector2 = Vector2(256.0, 256.0)
const BODY_TARGET_SIZE: float = 512.0 * ZUNGAR_CONFIG.BODY_SCALE

@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var executioner_sword: Sprite2D = $WeaponPivot/ExecutionerSword

var current_animation: StringName = &""
var configured_origin_offset: float = ZUNGAR_CONFIG.EXECUTIONER_SWORD_ORIGIN_OFFSET
var configured_reach: float = ZUNGAR_CONFIG.EXECUTIONER_SWORD_REACH
var visual_time: float = 0.0

func _ready() -> void:
	_register_polish_animations()
	configure_weapon(configured_origin_offset, configured_reach)
	_play_animation(&"idle")

func configure_weapon(origin_offset: float, reach: float) -> void:
	configured_origin_offset = origin_offset
	configured_reach = reach
	_apply_weapon_pose(0.0)
	refresh_body_scale()

func refresh_body_scale() -> void:
	if body_sprite == null:
		return
	_match_body_display_size(&"idle")

func sync_presentation(animation_name: StringName, facing_left: bool, blade_angle: float, aggressive: bool, fire_strength: float, metronome_peak: float) -> void:
	visual_time += get_process_delta_time()
	_play_animation(animation_name)
	body_sprite.flip_h = facing_left
	_apply_weapon_pose(blade_angle)
	var body_tint: Color = Color.WHITE
	if aggressive:
		body_tint = body_tint.lerp(Color("d9c5e8"), 0.1)
	if fire_strength > 0.0:
		body_tint = body_tint.lerp(Color("ffad65"), clampf(fire_strength, 0.0, 1.0) * 0.42)
	body_sprite.modulate = body_tint
	var bob_amount: float = sin(visual_time * 7.0) * 2.2 if animation_name == &"walk" else sin(visual_time * 2.2) * 1.25
	if animation_name in [&"charge_windup", &"charge_travel", &"jump", &"stunned"]:
		bob_amount = 0.0
	body_sprite.position.y = bob_amount
	executioner_sword.modulate = Color.WHITE.lerp(Color("ffd79a"), clampf(metronome_peak, 0.0, 1.0) * 0.16)

func _play_animation(animation_name: StringName) -> void:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return
	if not body_sprite.sprite_frames.has_animation(animation_name):
		animation_name = &"idle"
	if current_animation != animation_name:
		current_animation = animation_name
		body_sprite.play(animation_name)
	_match_body_display_size(animation_name)

func _apply_weapon_pose(blade_angle: float) -> void:
	if weapon_pivot == null or executioner_sword == null:
		return
	weapon_pivot.position = Vector2.ZERO
	weapon_pivot.rotation = blade_angle
	executioner_sword.position = Vector2(configured_origin_offset + configured_reach * 0.5, 0.0)
	executioner_sword.rotation = 0.0
	executioner_sword.visible = true
	executioner_sword.scale = Vector2.ONE * _weapon_scale_for_reach(configured_reach)

func _weapon_scale_for_reach(reach: float) -> float:
	if executioner_sword == null or executioner_sword.texture == null:
		return 1.0
	return reach / maxf(1.0, executioner_sword.texture.get_size().x)

func _register_polish_animations() -> void:
	if body_sprite == null:
		return
	if body_sprite.sprite_frames == null:
		body_sprite.sprite_frames = SpriteFrames.new()
	_register_atlas_animation(&"charge_windup", CHARGE_WINDUP_ATLAS, 8, 8.0, false)
	_register_atlas_animation(&"charge_travel", CHARGE_TRAVEL_ATLAS, 8, 10.0, true)
	_register_atlas_animation(&"stunned", STUNNED_ATLAS, 6, 8.0, true)
	var frames: SpriteFrames = body_sprite.sprite_frames
	if frames.has_animation(&"jump"):
		frames.set_animation_speed(&"jump", 0.95)
		frames.set_animation_loop(&"jump", false)

func _register_atlas_animation(animation_name: StringName, atlas: Texture2D, frame_count: int, fps: float, loops: bool) -> void:
	var frames: SpriteFrames = body_sprite.sprite_frames
	if frames.has_animation(animation_name):
		frames.remove_animation(animation_name)
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index: int in range(frame_count):
		var frame_texture: AtlasTexture = AtlasTexture.new()
		frame_texture.atlas = atlas
		frame_texture.region = Rect2(Vector2(float(frame_index) * GENERATED_FRAME_SIZE.x, 0.0), GENERATED_FRAME_SIZE)
		frames.add_frame(animation_name, frame_texture)

func _match_body_display_size(animation_name: StringName) -> void:
	var frames: SpriteFrames = body_sprite.sprite_frames
	if frames == null or not frames.has_animation(animation_name) or frames.get_frame_count(animation_name) <= 0:
		return
	var frame_texture: Texture2D = frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return
	var frame_height: float = maxf(1.0, frame_texture.get_size().y)
	body_sprite.scale = Vector2.ONE * (BODY_TARGET_SIZE / frame_height)

func has_required_animations() -> bool:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return false
	for animation_name: StringName in [&"idle", &"walk", &"charge", &"jump", &"charge_windup", &"charge_travel", &"stunned"]:
		if not body_sprite.sprite_frames.has_animation(animation_name):
			return false
	return true

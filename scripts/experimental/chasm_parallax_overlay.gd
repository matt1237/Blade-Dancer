extends Node2D
## Shared experimental full-vista authority; no gameplay or camera ownership.
const VISTA: Texture2D = preload("res://assets/generated/Chasm Background.png")
const SCROLL_SPEED: float = 0.22
# Preserve the old asset for rollback, never instantiate separate cliffs.
const SIDES: Texture2D = preload("res://assets/generated/Chasm Sides.png")
const ACCEPTED_WIDTH: float = 1736.6153846
var distant: Sprite2D
var anchor: Vector2
var reference_camera: Vector2
var parallax_enabled: bool = true
var original_sprites: Array[Dictionary] = []
var presentation_bounds: Rect2

static func walking_presentation_rect(arena: Rect2) -> Rect2:
	return Main.presentation_rect_for_arena(arena)

static func walking_camera_target(target: Vector2, _arena: Rect2) -> Vector2:
	return target # Full vista no longer needs upper-only camera headroom.

func build(stage: ChasmStage, viewport_size: Vector2, _camera_zoom: Vector2, _walking: bool = false) -> void:
	z_as_relative = false
	z_index = 0
	distant = Sprite2D.new()
	distant.name = "DistantVista"
	distant.z_as_relative = false
	distant.z_index = -2
	distant.texture = VISTA
	distant.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(distant)
	reference_camera = stage.arena_rect.get_center()
	anchor = reference_camera
	# Build-time overscan for the canonical 1–2 zoom range, not camera accordion.
	# Native viewport retains the accepted feature scale and full source aspect.
	if not presentation_bounds.has_area(): presentation_bounds = walking_presentation_rect(stage.arena_rect)
	var extent: Vector2 = presentation_bounds.size
	var travel: Vector2 = (extent - viewport_size).max(Vector2.ZERO) * 0.5 + (presentation_bounds.get_center() - reference_camera).abs()
	var required: Vector2 = viewport_size + travel * (2.0 * SCROLL_SPEED) + Vector2(32, 32)
	var uniform: float = maxf(ACCEPTED_WIDTH / VISTA.get_width(), maxf(required.x / VISTA.get_width(), required.y / VISTA.get_height()))
	distant.scale = Vector2.ONE * uniform
	var floor_texture: Texture2D = (stage.get_node("Background") as Sprite2D).texture
	for child: Node in stage.perimeter.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null: continue
		original_sprites.append({"sprite": sprite, "visible": sprite.visible})
		# Only exterior plates/decor; any neutral collision lip stays intact.
		if sprite.texture in [floor_texture, ChasmArenaObject.IRON, ChasmArenaObject.GNARLED, ChasmArenaObject.ANCIENT]: sprite.hide()
	update_camera(reference_camera)

func update_camera(center: Vector2) -> void:
	# 78% compensation leaves 22% apparent motion; never resize the texture.
	distant.position = anchor + (center - reference_camera) * (1.0 - SCROLL_SPEED) if parallax_enabled else anchor

func restore_perimeter() -> void:
	for state: Dictionary in original_sprites:
		if is_instance_valid(state["sprite"]): state["sprite"].visible = state["visible"]
	original_sprites.clear()

func image_rect() -> Rect2:
	var size: Vector2 = distant.texture.get_size() * distant.scale
	return Rect2(distant.position - size * 0.5, size)

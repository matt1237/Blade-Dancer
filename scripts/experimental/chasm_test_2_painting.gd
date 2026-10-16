extends "res://scripts/experimental/chasm_parallax_overlay.gd"
## Complete transparent foreground, fixed in world space over the shared vista.
const PREVIOUS_PAINTING: Texture2D = preload("res://assets/generated/ChasmTest2.png")
const PAINTING: Texture2D = preload("res://assets/generated/ChasmTest3.png")
# Inspected open floor, not whole-image fit. Conservative corner-safe rectangle.
const SAFE_SOURCE_FLOOR: Rect2 = Rect2(450, 385, 770, 420)
const PREVIOUS_SOURCE_FLOOR: Rect2 = Rect2(364, 365, 944, 514)
const PRESENTATION_SOURCE_FLOOR: Rect2 = Rect2(250, 230, 1000, 570)
var painting: Sprite2D
var original_visibility: Array[Dictionary] = []

static func painting_rect(playable: Rect2) -> Rect2:
	var uniform_scale: float = maxf(playable.size.x / PRESENTATION_SOURCE_FLOOR.size.x, playable.size.y / PRESENTATION_SOURCE_FLOOR.size.y)
	var origin: Vector2 = playable.get_center() - PRESENTATION_SOURCE_FLOOR.get_center() * uniform_scale
	return Rect2(origin, PAINTING.get_size() * uniform_scale)

static func presentation_rect(arena: Rect2, playable: Rect2) -> Rect2:
	# Same Forest clamp algorithm; let this experiment see beyond its painted rim.
	return walking_presentation_rect(arena).merge(painting_rect(playable).grow(160.0))

func build(stage: ChasmStage, viewport_size: Vector2, camera_zoom: Vector2, walking: bool = true) -> void:
	presentation_bounds = presentation_rect(stage.arena_rect, stage.get_playable_rect())
	super.build(stage, viewport_size, camera_zoom, walking)
	for node: CanvasItem in [stage.get_node("Background"), stage.perimeter, stage.get_node("StageTitle")]:
		original_visibility.append({"node": node, "visible": node.visible})
		node.hide()
	var bounds: Rect2 = painting_rect(stage.get_playable_rect())
	painting = Sprite2D.new()
	painting.name = "FullOriginalPainting"
	painting.texture = PAINTING
	painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	painting.scale = Vector2.ONE * (bounds.size.x / PAINTING.get_width())
	painting.position = bounds.get_center()
	add_child(painting)

func restore_perimeter() -> void:
	super.restore_perimeter()
	for state: Dictionary in original_visibility:
		if is_instance_valid(state["node"]): state["node"].visible = state["visible"]
	original_visibility.clear()

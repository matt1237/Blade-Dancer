class_name ChasmArtStyle extends Resource
## Machine-readable style contract for The Chasm.
## Human-facing explanations and dated decisions live in the docs files beside this resource.

@export var style_id: String = "chasm"
@export var style_version: String = "0.1"
@export var source_image: Texture2D = null
@export var reference_images: Array[Texture2D] = []
@export_multiline var art_direction: String = "Open-concept crystal cavern. Preserve the source illustration's composition, palette, depth, and hand-painted atmosphere."
@export_multiline var asset_rules: String = "Keep the original source image untouched. Derive isolated props as separate transparent assets. Keep decorative art separate from gameplay collision."
@export var texture_filter: int = CanvasItem.TEXTURE_FILTER_NEAREST
@export var world_scale: float = 1.0
@export var playable_arena_size: Vector2 = Vector2(1280.0, 720.0)
@export var background_tint: Color = Color.WHITE
@export var ambient_tint: Color = Color.WHITE
@export var background_z_index: int = -20
@export var decoration_z_index: int = 0
@export var actor_z_index: int = 2
@export var foreground_z_index: int = 10
@export var collision_is_invisible: bool = true
@export var collision_follows_playable_rect: bool = true
@export_multiline var palette_notes: String = "Palette is intentionally left as a documented extraction task until the reference image is formally analyzed."
@export_multiline var lighting_notes: String = "Lighting and atmosphere should be authored independently from collision and actor readability."

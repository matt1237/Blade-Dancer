class_name ForestFloor extends Node2D

const PRESENTATION_SHADER: Shader = preload("res://shaders/forest_ground_detail.gdshader")
const CLASSIC_TILE_TEXTURE: Texture2D = preload("res://assets/generated/forest_floor_tile.png")
const VISUAL_SETTINGS_SCRIPT: GDScript = preload("res://scripts/forest_visual_settings.gd")

# These are the only shared settings owned by the ground compositor. Grading
# here is ground-only; clouds, rays, haze and other atmosphere belong elsewhere.
const GROUND_PARAMETER_NAMES: Array[String] = [
	"grass_brightness", "grass_saturation", "detail_scale", "dirt_amount",
	"path_width", "path_meander", "edge_breakup", "dark_soil",
	"grading_enabled", "grade_saturation", "grade_contrast", "sunlight_warmth"
]

const HD_TILE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/generated/forest_floor_heroic_quiet_frame_0.png"),
	preload("res://assets/generated/forest_floor_heroic_quiet_frame_1.png"),
	preload("res://assets/generated/forest_floor_heroic_quiet_frame_2.png"),
	preload("res://assets/generated/forest_floor_heroic_quiet_frame_3.png")
]

@export_category("Forest Floor Tiling")
@export var tile_size: int = 64
@export var tile_variant_count: int = 4
@export var extra_tile_margin: int = 1

var tile_texture: Texture2D = CLASSIC_TILE_TEXTURE
var use_hd_overhaul: bool = false
var presentation_material: ShaderMaterial = null
var visual_rect: Rect2 = Rect2(-360.0, -180.0, 2000.0, 1080.0)
var _ground_settings: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	presentation_material = ShaderMaterial.new()
	presentation_material.shader = PRESENTATION_SHADER
	var sampler_names: Array[String] = ["grass_a", "grass_b", "grass_c", "grass_d"]
	for i: int in range(HD_TILE_TEXTURES.size()):
		presentation_material.set_shader_parameter(sampler_names[i], HD_TILE_TEXTURES[i])
	# Also supports applying a profile before this node enters the scene tree.
	apply_visual_settings(_ground_settings)
	_set_presentation_shader_state()
	queue_redraw()

func set_presentation_rect(rect: Rect2) -> void:
	visual_rect = rect
	queue_redraw()


func set_visual_style(mode: String) -> void:
	use_hd_overhaul = mode == "hd"
	_set_presentation_shader_state()
	queue_redraw()

## Accepts ForestVisualSettings.get_effective_values(), including bypassed
## effects. Ground compositing stays enabled in HD even with grading disabled.
## Missing/invalid values reset to shared defaults; unrelated keys are ignored.
func apply_visual_settings(settings: Dictionary) -> void:
	var checked_settings: Dictionary = {}
	for spec: Dictionary in VISUAL_SETTINGS_SCRIPT.SPECS:
		var key: String = str(spec["key"])
		if not GROUND_PARAMETER_NAMES.has(key):
			continue
		var default_value: Variant = spec["default"]
		var value: Variant = settings.get(key, default_value)
		if default_value is bool:
			value = value if value is bool else default_value
		elif (value is int or value is float) and is_finite(float(value)):
			value = clampf(float(value), float(spec["min"]), float(spec["max"]))
		else:
			value = default_value
		checked_settings[key] = value
		if presentation_material != null:
			presentation_material.set_shader_parameter(key, value)
	_ground_settings = checked_settings


func _set_presentation_shader_state() -> void:
	material = presentation_material if use_hd_overhaul else null

func _draw() -> void:
	if tile_texture == null: return
	if use_hd_overhaul:
		# Native-scale, world-anchored detail. White preserves the sampled source color.
		# Decorative stamps belong to border nodes, not this continuous combat surface.
		draw_rect(visual_rect, Color.WHITE, true)
		return
	var start_x: int = floori(visual_rect.position.x / float(tile_size)) * tile_size
	var end_x: int = ceili(visual_rect.end.x / float(tile_size)) * tile_size
	var start_y: int = floori(visual_rect.position.y / float(tile_size)) * tile_size
	var end_y: int = ceili(visual_rect.end.y / float(tile_size)) * tile_size
	for tile_y: int in range(start_y, end_y, tile_size):
		for tile_x: int in range(start_x, end_x, tile_size):
			var tile_position: Vector2 = Vector2(float(tile_x), float(tile_y))
			# Use cell indices: pixel multiples of 64 selected variant zero every time.
			var cell_x: int = floori(tile_x / float(tile_size))
			var cell_y: int = floori(tile_y / float(tile_size))
			var variant_index: int = posmod(cell_x * 17 + cell_y * 31, maxi(tile_variant_count, 1))
			var destination_rect: Rect2 = Rect2(tile_position, Vector2(tile_size, tile_size))
			var source_rect: Rect2 = Rect2(Vector2(float(variant_index * tile_size), 0.0), Vector2(tile_size, tile_size))
			draw_texture_rect_region(tile_texture, destination_rect, source_rect)

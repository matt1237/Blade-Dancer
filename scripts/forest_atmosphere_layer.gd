class_name ForestAtmosphereLayer extends Node2D
## World-only overlay; never captures or processes the HUD.
const ATMOSPHERE_SHADER: Shader = preload("res://shaders/forest_atmosphere.gdshader")
var visual_rect: Rect2 = Rect2(-360.0, -180.0, 2000.0, 1080.0)
var atmosphere_material: ShaderMaterial = ShaderMaterial.new()

func _init() -> void:
	atmosphere_material.shader = ATMOSPHERE_SHADER
	material = atmosphere_material
	z_index = 8
	visible = false

func apply_visual_settings(settings: Dictionary, world_rect: Rect2, arena: Rect2) -> void:
	visual_rect = world_rect
	for key: String in ["clouds_enabled", "cloud_strength", "cloud_scale", "cloud_speed", "cloud_coverage", "cloud_softness", "rays_enabled", "ray_strength", "ray_width", "ray_angle_degrees", "moon_glow_enabled", "moon_glow_strength", "dapple_enabled", "dapple_strength", "haze_enabled", "haze_strength", "sunlight_warmth", "mood_temperature", "mist_strength", "night_strength"]:
		if settings.has(key):
			atmosphere_material.set_shader_parameter(key, settings[key])
	atmosphere_material.set_shader_parameter("arena_rect", Vector4(arena.position.x, arena.position.y, arena.size.x, arena.size.y))
	queue_redraw()

func _draw() -> void:
	draw_rect(visual_rect, Color.WHITE)

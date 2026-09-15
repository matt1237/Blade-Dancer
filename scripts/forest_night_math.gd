class_name ForestNightMath extends RefCounted
## Pure, save-free contract shared by the overlay and regression tests.
static func sanitized(settings: Dictionary) -> Dictionary:
	return {
		"night_strength": clampf(float(settings.get("night_strength", 0.0)), 0.0, 1.0),
		"light_radius": clampf(float(settings.get("light_radius", 240.0)), 160.0, 640.0),
		"mood_temperature": clampf(float(settings.get("mood_temperature", 0.0)), -1.0, 1.0),
		"mist_strength": clampf(float(settings.get("mist_strength", 0.0)), 0.0, 1.0),
		"moon_glow_enabled": bool(settings.get("moon_glow_enabled", false)),
		"moon_glow_strength": clampf(float(settings.get("moon_glow_strength", 0.16)), 0.0, 0.4),
		"moon_beams_enabled": bool(settings.get("moon_beams_enabled", true)),
		"moon_beam_strength": clampf(float(settings.get("moon_beam_strength", 0.12)), 0.0, 0.35),
		"moon_beam_width": clampf(float(settings.get("moon_beam_width", 150.0)), 40.0, 300.0),
		"moon_beam_angle_degrees": clampf(float(settings.get("moon_beam_angle_degrees", -18.0)), -85.0, 85.0)
	}

static func enabled(hd: bool, world_visible: bool, rush_active: bool, strength: float) -> bool:
	return hd and world_visible and not rush_active and strength > 0.0001

static func reveal_at(point: Vector2, light: Vector4) -> float:
	var distance_ratio: float = point.distance_to(Vector2(light.x, light.y)) / maxf(light.z, 1.0)
	return (1.0 - smoothstep(0.42, 1.0, distance_ratio)) * clampf(light.w, 0.0, 1.0)

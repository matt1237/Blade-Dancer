class_name SwordContactData extends RefCounted

var contact_point: Vector2 = Vector2.ZERO
var impact_normal: Vector2 = Vector2.ZERO
var blade_direction: Vector2 = Vector2.RIGHT
var blade_velocity: Vector2 = Vector2.ZERO
var relative_velocity: Vector2 = Vector2.ZERO
var blade_position: float = 0.5
var impact_speed: float = 0.0
var impact_quality: float = 0.0
var swept_distance: float = INF

func damage_multiplier() -> float:
	return 0.8 + impact_quality * 0.5

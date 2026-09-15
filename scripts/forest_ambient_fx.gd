class_name ForestAmbientFX extends Node2D

class AmbientMote extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var radius: float = 1.0
	var alpha: float = 0.2
	var phase: float = 0.0

class Firefly extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var phase: float = 0.0
	var radius: float = 1.5
	var color: Color = Color(1.0, 0.85, 0.35, 1.0)
	var always_visible: bool = false
	var target_chest: ArenaObject = null

class LeafParticle extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var rotation_speed: float = 0.0
	var size: float = 3.0
	var color: Color = Color(0.35, 0.55, 0.18, 0.8)

@export_category("Forest Atmosphere")
@export var enabled: bool = true
@export var mote_count: int = 34
@export var firefly_count: int = 8
@export var leaf_count: int = 12
@export var wind_speed: float = 15.0
@export var atmosphere_alpha: float = 0.16

var elapsed: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var motes: Array[AmbientMote] = []
var fireflies: Array[Firefly] = []
var leaves: Array[LeafParticle] = []
var particle_visibility: bool = true
var leaf_half_length: float = 9.0
var firefly_halo_strength: float = 0.45
var atmosphere_layer: ForestAtmosphereLayer = null
var visual_settings: Dictionary = {}
var atmosphere_requested: bool = false

func apply_visual_settings(settings: Dictionary) -> void:
	visual_settings = settings.duplicate(true)
	particle_visibility = bool(settings.get("particles_enabled", true))
	var new_count: int = clampi(int(settings.get("leaf_count", 12)), 0, 40)
	var new_firefly_count: int = clampi(int(settings.get("firefly_count", 8)), 0, 20)
	var particles_changed: bool = new_count != leaf_count or new_firefly_count != firefly_count
	leaf_half_length = clampf(float(settings.get("leaf_size", 9.0)), 4.0, 20.0)
	wind_speed = clampf(float(settings.get("wind_speed", 18.0)), 0.0, 55.0)
	firefly_count = new_firefly_count
	firefly_halo_strength = clampf(float(settings.get("firefly_glow", 0.45)), 0.0, 1.0)
	if particles_changed:
		leaf_count = new_count
		if is_inside_tree():
			rng.seed = 814273
			_build_particles()
	atmosphere_requested = bool(settings.get("clouds_enabled", false)) or bool(settings.get("rays_enabled", false)) or bool(settings.get("moon_glow_enabled", false)) or bool(settings.get("dapple_enabled", false)) or bool(settings.get("haze_enabled", false))
	if atmosphere_layer != null:
		atmosphere_layer.apply_visual_settings(settings, _presentation_rect(), _gameplay_rect())
	_refresh_presentation_visibility()
	queue_redraw()

func _refresh_presentation_visibility() -> void:
	if atmosphere_layer != null:
		atmosphere_layer.visible = atmosphere_requested and _is_hd_visual() and is_visible_in_tree()


func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atmosphere_layer = ForestAtmosphereLayer.new()
	atmosphere_layer.name = "CanopyAtmosphere"
	add_child(atmosphere_layer)
	visibility_changed.connect(_refresh_presentation_visibility)
	rng.seed = 814273
	_build_particles()
	apply_visual_settings(visual_settings)
	queue_redraw()

func _is_hd_visual() -> bool:
	var current_scene: Node = get_tree().current_scene
	return enabled and current_scene != null and str(current_scene.get("visual_style")) == "hd"

func _is_night_phase() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false
	var phase: String = str(current_scene.get("active_forest_time_phase"))
	return phase == "Night" or phase == "Night v2"

func _find_live_chest() -> ArenaObject:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group("arena_objects"):
		var object: ArenaObject = node as ArenaObject
		if object != null and object.object_kind == ArenaObject.ObjectKind.CHEST and not object.broken and object.is_visible_in_tree():
			return object
	return null

func _presentation_rect() -> Rect2:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_presentation_rect"):
		var scene_rect: Variant = current_scene.call("get_presentation_rect")
		if scene_rect is Rect2:
			return scene_rect
	return Rect2(-360.0, -180.0, 2000.0, 1080.0)

func _gameplay_rect() -> Rect2:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_gameplay_arena_rect"):
		var scene_rect: Variant = current_scene.call("get_gameplay_arena_rect")
		if scene_rect is Rect2:
			return scene_rect
	return Rect2(0.0, 0.0, 1280.0, 720.0)

func _build_particles() -> void:
	motes.clear()
	fireflies.clear()
	leaves.clear()
	var visual_rect: Rect2 = _presentation_rect()
	var arena_rect: Rect2 = _gameplay_rect()
	for index: int in range(mote_count):
		var mote: AmbientMote = AmbientMote.new()
		mote.world_position = Vector2(rng.randf_range(visual_rect.position.x, visual_rect.end.x), rng.randf_range(visual_rect.position.y, visual_rect.end.y))
		mote.velocity = Vector2(rng.randf_range(3.0, 11.0), rng.randf_range(-2.0, 3.0))
		mote.radius = rng.randf_range(0.6, 1.7)
		mote.alpha = rng.randf_range(0.08, 0.26)
		mote.phase = rng.randf_range(0.0, TAU)
		motes.append(mote)
	for index: int in range(firefly_count):
		var firefly: Firefly = Firefly.new()
		firefly.world_position = Vector2(rng.randf_range(arena_rect.position.x + 48.0, arena_rect.end.x - 48.0), rng.randf_range(arena_rect.position.y + 48.0, arena_rect.end.y - 48.0))
		firefly.phase = rng.randf_range(0.0, TAU)
		firefly.radius = rng.randf_range(1.0, 2.0)
		firefly.color = Color(1.0, rng.randf_range(0.72, 0.92), rng.randf_range(0.22, 0.48), 1.0)
		fireflies.append(firefly)
	# One storybook firefly is always reserved for the chest-attractor behavior.
	var chest_firefly: Firefly = Firefly.new()
	chest_firefly.world_position = arena_rect.get_center() + Vector2(-42.0, 18.0)
	chest_firefly.phase = rng.randf_range(0.0, TAU)
	chest_firefly.radius = 1.8
	chest_firefly.color = Color(1.0, 0.92, 0.42, 1.0)
	chest_firefly.always_visible = true
	fireflies.append(chest_firefly)
	for index: int in range(leaf_count):
		var leaf: LeafParticle = LeafParticle.new()
		# Some leaves drift across the clearing; not all hidden behind the border.
		leaf.world_position = Vector2(rng.randf_range(arena_rect.position.x, arena_rect.end.x), rng.randf_range(arena_rect.position.y, arena_rect.end.y)) if index % 3 == 0 else _random_border_position(visual_rect, arena_rect)
		leaf.velocity = Vector2(rng.randf_range(12.0, 28.0), rng.randf_range(-4.0, 8.0))
		leaf.rotation = rng.randf_range(0.0, TAU)
		leaf.rotation_speed = rng.randf_range(-1.5, 1.5)
		leaf.size = rng.randf_range(2.0, 4.5)
		leaf.color = Color(0.34 + rng.randf() * 0.18, 0.48 + rng.randf() * 0.22, 0.12 + rng.randf() * 0.12, rng.randf_range(0.42, 0.78))
		leaves.append(leaf)

func _random_border_position(visual_rect: Rect2, arena_rect: Rect2) -> Vector2:
	var side: int = rng.randi_range(0, 3)
	var edge_margin: float = 18.0
	match side:
		0:
			return Vector2(rng.randf_range(visual_rect.position.x, visual_rect.end.x), rng.randf_range(visual_rect.position.y, arena_rect.position.y - edge_margin))
		1:
			return Vector2(rng.randf_range(visual_rect.position.x, visual_rect.end.x), rng.randf_range(arena_rect.end.y + edge_margin, visual_rect.end.y))
		2:
			return Vector2(rng.randf_range(visual_rect.position.x, arena_rect.position.x - edge_margin), rng.randf_range(arena_rect.position.y, arena_rect.end.y))
		_:
			return Vector2(rng.randf_range(arena_rect.end.x + edge_margin, visual_rect.end.x), rng.randf_range(arena_rect.position.y, arena_rect.end.y))

func _process(delta: float) -> void:
	_refresh_presentation_visibility()
	if not _is_hd_visual() or not is_visible_in_tree():
		return
	elapsed += delta
	if atmosphere_requested:
		atmosphere_layer.atmosphere_material.set_shader_parameter("elapsed", elapsed)
	if not particle_visibility:
		return
	var visual_rect: Rect2 = _presentation_rect()
	for mote: AmbientMote in motes:
		mote.world_position += mote.velocity * delta
		mote.world_position.y += sin(elapsed * 0.7 + mote.phase) * delta * 2.0
		if mote.world_position.x > visual_rect.end.x + 8.0:
			mote.world_position.x = visual_rect.position.x - 8.0
		if mote.world_position.y > visual_rect.end.y + 8.0:
			mote.world_position.y = visual_rect.position.y - 8.0
	var live_chest: ArenaObject = _find_live_chest()
	for firefly: Firefly in fireflies:
		if firefly.always_visible:
			if not is_instance_valid(firefly.target_chest) or firefly.target_chest.broken:
				firefly.target_chest = live_chest
			if is_instance_valid(firefly.target_chest) and not firefly.target_chest.broken:
				var hover_offset: Vector2 = Vector2(sin(elapsed * 1.4 + firefly.phase) * 22.0, cos(elapsed * 1.9 + firefly.phase) * 14.0)
				var target_position: Vector2 = firefly.target_chest.global_position + hover_offset
				firefly.world_position = firefly.world_position.move_toward(target_position, delta * 42.0)
			else:
				firefly.world_position.y += sin(elapsed * 0.8 + firefly.phase) * delta * 4.0
		else:
			firefly.world_position.y += sin(elapsed * 0.8 + firefly.phase) * delta * 4.0
	for leaf: LeafParticle in leaves:
		leaf.world_position += leaf.velocity * delta * (wind_speed / 18.0)
		leaf.rotation += leaf.rotation_speed * delta
		if leaf.world_position.x > visual_rect.end.x + 12.0:
			leaf.world_position.x = visual_rect.position.x - 12.0
			leaf.world_position.y = rng.randf_range(visual_rect.position.y, visual_rect.end.y)
	queue_redraw()

func _draw() -> void:
	if not _is_hd_visual() or not particle_visibility:
		return
	# Optional atmosphere is owned by CanopyAtmosphere, not duplicated here.
	for mote: AmbientMote in motes:
		var mote_alpha: float = mote.alpha * (0.72 + 0.28 * sin(elapsed * 1.2 + mote.phase))
		draw_circle(mote.world_position, mote.radius, Color(1.0, 0.92, 0.62, mote_alpha))
	for firefly: Firefly in fireflies:
		if not firefly.always_visible and not _is_night_phase():
			continue
		var pulse: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(elapsed * 2.2 + firefly.phase))
		var glow_color: Color = Color(firefly.color.r, firefly.color.g, firefly.color.b, 0.18 * pulse * firefly_halo_strength)
		draw_circle(firefly.world_position, firefly.radius * 4.0, glow_color)
		draw_circle(firefly.world_position, firefly.radius, Color(firefly.color.r, firefly.color.g, firefly.color.b, 0.8 * pulse))
	for leaf: LeafParticle in leaves:
		var leaf_direction: Vector2 = Vector2.RIGHT.rotated(leaf.rotation)
		var half_length: float = leaf_half_length * leaf.size / 3.25
		var leaf_side: Vector2 = leaf_direction.orthogonal() * half_length * 0.44
		var leaf_points: PackedVector2Array = PackedVector2Array([
			leaf.world_position - leaf_direction * half_length,
			leaf.world_position + leaf_side - leaf_direction * half_length * 0.25,
			leaf.world_position + leaf_side * 0.7 + leaf_direction * half_length * 0.4,
			leaf.world_position + leaf_direction * half_length,
			leaf.world_position - leaf_side
		])
		draw_colored_polygon(leaf_points, leaf.color)
		draw_line(leaf.world_position - leaf_direction * half_length * 0.7, leaf.world_position + leaf_direction * half_length * 0.7, Color(0.62, 0.68, 0.23, leaf.color.a), 1.0, true)

func _draw_edge_haze(visual_rect: Rect2, arena_rect: Rect2) -> void:
	var haze_color: Color = Color(0.04, 0.19, 0.15, atmosphere_alpha)
	var top_haze: PackedVector2Array = PackedVector2Array([
		Vector2(visual_rect.position.x, visual_rect.position.y),
		Vector2(visual_rect.end.x, visual_rect.position.y),
		Vector2(visual_rect.end.x - 80.0, arena_rect.position.y - 18.0),
		Vector2(arena_rect.position.x + 780.0, arena_rect.position.y - 42.0),
		Vector2(arena_rect.position.x + 330.0, arena_rect.position.y - 20.0),
		Vector2(visual_rect.position.x + 70.0, arena_rect.position.y - 36.0)
	])
	draw_colored_polygon(top_haze, haze_color)
	var bottom_haze: PackedVector2Array = PackedVector2Array([
		Vector2(visual_rect.position.x + 40.0, visual_rect.end.y),
		Vector2(visual_rect.end.x, visual_rect.end.y),
		Vector2(visual_rect.end.x - 80.0, arena_rect.end.y + 34.0),
		Vector2(arena_rect.position.x + 720.0, arena_rect.end.y + 22.0),
		Vector2(arena_rect.position.x + 260.0, arena_rect.end.y + 44.0),
		Vector2(visual_rect.position.x, arena_rect.end.y + 18.0)
	])
	draw_colored_polygon(bottom_haze, Color(0.02, 0.11, 0.10, atmosphere_alpha * 0.9))

func _draw_dappled_lights(arena_rect: Rect2) -> void:
	var light_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 170.0, arena_rect.position.y + 110.0),
		Vector2(arena_rect.position.x + 470.0, arena_rect.position.y + 86.0),
		Vector2(arena_rect.position.x + 900.0, arena_rect.position.y + 122.0),
		Vector2(arena_rect.position.x + 1080.0, arena_rect.position.y + 510.0),
		Vector2(arena_rect.position.x + 360.0, arena_rect.end.y - 90.0)
	]
	for index: int in range(light_positions.size()):
		var pulse: float = 0.72 + 0.28 * sin(elapsed * 0.35 + float(index) * 1.7)
		var light_position: Vector2 = light_positions[index]
		draw_circle(light_position, 54.0, Color(1.0, 0.78, 0.3, 0.012 * pulse))
		draw_circle(light_position, 26.0, Color(1.0, 0.86, 0.48, 0.018 * pulse))

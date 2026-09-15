class_name ForestNightLighting extends Node2D
## Read-only presentation adapter. World canvas only; HUD lives on layer 2.
## Authored HD eye overlays render separately at absolute z 4001.
const NightMath: GDScript = preload("res://scripts/forest_night_math.gd")
const NIGHT_SHADER: Shader = preload("res://shaders/forest_night.gdshader")
const MAX_LIGHTS: int = 64
var host: Node2D = null
var player: Player = null
var ambient: ForestAmbientFX = null
var settings: Dictionary = NightMath.sanitized({})
var night_material: ShaderMaterial = ShaderMaterial.new()
var lights: PackedVector4Array = PackedVector4Array()
var light_count: int = 0
var visual_rect: Rect2 = Rect2(-360.0, -180.0, 2000.0, 1080.0)
var elapsed: float = 0.0

func _init() -> void:
	name = "ForestNightLighting"
	z_as_relative = false
	z_index = 4000
	process_priority = 100
	visible = false
	lights.resize(MAX_LIGHTS)
	night_material.shader = NIGHT_SHADER
	material = night_material

func setup(world: Node2D, actor: Player, particles: ForestAmbientFX) -> void:
	host = world
	player = actor
	ambient = particles

func apply_visual_settings(values: Dictionary) -> void:
	settings = NightMath.sanitized(values)
	for key: String in ["night_strength", "mood_temperature", "mist_strength", "moon_glow_enabled", "moon_glow_strength", "moon_beams_enabled", "moon_beam_strength", "moon_beam_width", "moon_beam_angle_degrees"]:
		night_material.set_shader_parameter(key, settings[key])
	if float(settings["night_strength"]) <= 0.0001:
		visible = false

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(player):
		visible = false
		return
	visible = NightMath.enabled(str(host.get("visual_style")) == "hd", host.is_visible_in_tree() and player.is_visible_in_tree(), is_instance_valid(host.get("resonance_rush_instance")), float(settings["night_strength"]))
	if not visible:
		return
	elapsed += delta
	if host.has_method("get_presentation_rect"):
		visual_rect = host.call("get_presentation_rect") as Rect2
	var arena_rect: Rect2 = host.call("get_gameplay_arena_rect") as Rect2 if host.has_method("get_gameplay_arena_rect") else Rect2(0.0, 0.0, 1280.0, 720.0)
	night_material.set_shader_parameter("arena_rect", Vector4(arena_rect.position.x, arena_rect.position.y, arena_rect.size.x, arena_rect.size.y))
	collect_lights()
	night_material.set_shader_parameter("lights", lights)
	night_material.set_shader_parameter("light_count", light_count)
	night_material.set_shader_parameter("elapsed", elapsed)
	queue_redraw()

func _append_light(point: Vector2, radius: float, strength: float = 1.0) -> void:
	if light_count >= MAX_LIGHTS:
		return
	lights[light_count] = Vector4(point.x, point.y, radius, strength)
	light_count += 1

func collect_lights() -> void:
	light_count = 0
	# Higher Flow makes the player (and the blade) brighter light sources at
	# night — same onset/ramp curve the Flow aura/afterimage VFX use, so the
	# lighting and the visual presentation build together.
	var flow_ratio: float = clampf(player.flow / 100.0, 0.0, 1.0)
	var flow_intensity: float = FlowColorUtils.intensity(flow_ratio)
	_append_light(player.global_position, float(settings["light_radius"]) * lerpf(1.0, 1.3, flow_intensity), lerpf(1.0, 1.85, flow_intensity))
	# Cached collision blade endpoints are updated by gameplay; never invoke the
	# sword transform helper (some forms update pose state as a side effect).
	if player.previous_blade_end != Vector2.ZERO:
		_append_light(player.previous_blade_start.lerp(player.previous_blade_end, 0.65), lerpf(125.0, 210.0, flow_intensity), lerpf(0.85, 1.6, flow_intensity))
	for disc: Chakram in player.active_chakrams:
		if is_instance_valid(disc) and disc.is_visible_in_tree():
			_append_light(disc.global_position, 115.0)
	var grapple: GrappleController = player.grapple_controller
	if is_instance_valid(grapple):
		if grapple.active:
			_append_light(grapple.anchor_position, 120.0)
		elif grapple.firing:
			_append_light(grapple.hook_position, 85.0)
	# Reserve budget for attack readability ahead of decorative particles.
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var enemy: Enemy = node as Enemy
			if enemy != null and host.is_ancestor_of(enemy) and enemy.is_visible_in_tree() and enemy.engagement_attack_in_progress():
				_append_light(enemy.global_position, 125.0, 0.9)
			if light_count >= 36:
				break
		for node: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
			var projectile: Node2D = node as Node2D
			if projectile != null and host.is_ancestor_of(projectile) and projectile.is_visible_in_tree():
				_append_light(projectile.global_position, 48.0, 0.9)
			if light_count >= 46:
				break
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("night_lights"):
			var source: Node2D = node as Node2D
			if source != null and source.is_visible_in_tree():
				_append_light(source.global_position, 92.0, 0.42)
	if is_instance_valid(ambient) and ambient.enabled and ambient.particle_visibility and ambient.is_visible_in_tree():
		for firefly: ForestAmbientFX.Firefly in ambient.fireflies:
			var pulse: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(ambient.elapsed * 2.2 + firefly.phase))
			_append_light(ambient.to_global(firefly.world_position), 34.0 + 12.0 * pulse, 0.65 + 0.3 * pulse)

func _draw() -> void:
	draw_rect(visual_rect.grow(64.0), Color.WHITE)

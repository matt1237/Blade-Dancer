class_name ZungarChargeFX extends Node2D

const DUST_ATLAS: Texture2D = preload("res://assets/generated/hd_zungar_dirt_puff_atlas.png")
const FRAME_SIZE: Vector2 = Vector2(128.0, 128.0)
const FRAME_COUNT: int = 6
const MAX_PARTICLES: int = 72

class DustParticle extends RefCounted:
	var global_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var lifetime: float = 0.8
	var start_size: float = 32.0
	var end_size: float = 72.0
	var rotation_value: float = 0.0
	var spin: float = 0.0

var particles: Array[DustParticle] = []
var trail_emission_accumulator: float = 0.0

func _ready() -> void:
	z_index = -1

func begin_windup(origin: Vector2, charge_direction: Vector2) -> void:
	trail_emission_accumulator = 0.0
	_emit_burst(origin, -charge_direction, 17, 118.0, 0.9)

func emit_charge_trail(origin: Vector2, charge_direction: Vector2, delta: float, particles_per_second: float) -> void:
	trail_emission_accumulator += maxf(0.0, particles_per_second) * delta
	while trail_emission_accumulator >= 1.0:
		trail_emission_accumulator -= 1.0
		_emit_particle(origin + _random_perpendicular(charge_direction, 24.0), -charge_direction, randf_range(42.0, 104.0), randf_range(0.58, 0.94))

func impact_burst(origin: Vector2, impact_direction: Vector2) -> void:
	trail_emission_accumulator = 0.0
	_emit_burst(origin, -impact_direction, 25, 175.0, 1.05)

func stop_emission() -> void:
	trail_emission_accumulator = 0.0

func _emit_burst(origin: Vector2, preferred_direction: Vector2, count: int, speed_max: float, lifetime_scale: float) -> void:
	for particle_index: int in range(count):
		var angle_spread: float = randf_range(-1.35, 1.35)
		var direction: Vector2 = preferred_direction.rotated(angle_spread).normalized()
		if particle_index % 4 == 0:
			direction = Vector2.from_angle(randf_range(0.0, TAU))
		_emit_particle(origin + Vector2(randf_range(-18.0, 18.0), randf_range(-7.0, 9.0)), direction, randf_range(speed_max * 0.28, speed_max), randf_range(0.58, 0.92) * lifetime_scale)

func _emit_particle(origin: Vector2, direction: Vector2, speed_value: float, lifetime_value: float) -> void:
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	var particle: DustParticle = DustParticle.new()
	particle.global_position = origin
	particle.velocity = direction.normalized() * speed_value + Vector2(0.0, randf_range(-42.0, -12.0))
	particle.lifetime = maxf(0.2, lifetime_value)
	particle.start_size = randf_range(28.0, 46.0)
	particle.end_size = particle.start_size * randf_range(1.7, 2.45)
	particle.rotation_value = randf_range(-PI, PI)
	particle.spin = randf_range(-1.2, 1.2)
	particles.append(particle)
	queue_redraw()

func _random_perpendicular(direction: Vector2, spread: float) -> Vector2:
	var normal: Vector2 = Vector2(-direction.y, direction.x).normalized()
	return normal * randf_range(-spread, spread)

func _process(delta: float) -> void:
	var surviving_particles: Array[DustParticle] = []
	for particle: DustParticle in particles:
		particle.age += delta
		if particle.age >= particle.lifetime:
			continue
		particle.velocity = particle.velocity.move_toward(Vector2(0.0, -8.0), delta * 90.0)
		particle.global_position += particle.velocity * delta
		particle.rotation_value += particle.spin * delta
		surviving_particles.append(particle)
	particles = surviving_particles
	if not particles.is_empty():
		queue_redraw()

func _draw() -> void:
	for particle: DustParticle in particles:
		var progress: float = clampf(particle.age / maxf(particle.lifetime, 0.001), 0.0, 1.0)
		var frame_index: int = mini(FRAME_COUNT - 1, floori(progress * float(FRAME_COUNT)))
		var source_rect: Rect2 = Rect2(Vector2(float(frame_index) * FRAME_SIZE.x, 0.0), FRAME_SIZE)
		var display_size: float = lerpf(particle.start_size, particle.end_size, smoothstep(0.0, 1.0, progress))
		var fade: float = smoothstep(1.0, 0.63, progress) * smoothstep(0.0, 0.08, progress)
		var local_position: Vector2 = to_local(particle.global_position)
		draw_set_transform(local_position, particle.rotation_value, Vector2.ONE)
		draw_texture_rect_region(DUST_ATLAS, Rect2(-display_size * 0.5, -display_size * 0.5, display_size, display_size), source_rect, Color(1.0, 0.9, 0.78, fade * 0.86))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

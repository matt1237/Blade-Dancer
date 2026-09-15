class_name PlayerFlowFX extends Node2D
## Player-attached Flow presentation: HD body aura, high-Flow afterimages for
## both the body and the sword blade, drawn-in motes, and movement/dash dust.
## Pull-model: reads Player state each frame and never mutates it. HD visual
## style only; classic mode is untouched. Everything here (aura, body
## afterimages, sword afterimages, motes) shares one onset point via
## FlowColorUtils.ONSET_RATIO (40% Flow), ramping to full strength at 100%.
##
## IMPORTANT: never call Player._sword_transform() from here — some sword
## forms mutate pose state as a side effect (see forest_night_lighting.gd).
## Use the cached player.previous_blade_start/previous_blade_end instead.

const SILHOUETTE_SHADER: Shader = preload("res://shaders/silhouette_aura.gdshader")
const GROUND_PULSE_SCENE: PackedScene = preload("res://scenes/ground_pulse_aura.tscn")
const MOTE_TEXTURE: Texture2D = preload("res://assets/generated/flow_mote_spark_frame_0.png")
const DUST_TEXTURE: Texture2D = preload("res://assets/generated/movement_dust_puff_frame_0.png")
const GHOST_COUNT: int = 5
const GHOST_LIFETIME: float = 0.32
const SWORD_GHOST_COUNT: int = 5
const SWORD_GHOST_LIFETIME: float = 0.22
const SWORD_VISUAL_SCALE: float = 0.055
const GROUND_PULSE_VISUAL_SCALE: float = 0.34
const GROUND_PULSE_BASE_ALPHA: float = 0.28
const GROUND_PULSE_MAX_ALPHA: float = 0.94

@export_category("Flow Aura & Motes")
@export var aura_max_alpha: float = 0.85
@export var aura_scale_boost: float = 0.08
@export var ghost_base_interval: float = 0.09
@export var sword_ghost_base_interval: float = 0.05
@export var mote_max_count: int = 8
@export var mote_spawn_radius: float = 70.0
## Disabled by default so the sword path remains the visual focus. Kept as a
## reversible option for future readability passes.
@export var ground_pulse_enabled: bool = false
@export var sword_afterimages_enabled: bool = false

@export_category("Movement Dust")
@export var dust_spawn_interval: float = 0.11
@export var dust_dash_burst_count: int = 8

class Mote extends RefCounted:
	var angle: float = 0.0
	var radius: float = 0.0
	var speed: float = 1.0
	var life: float = 0.0
	var max_life: float = 1.0

class DustPuff extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var max_life: float = 0.45
	var puff_scale: float = 1.0

var player: Player = null
var shared_aura_material: ShaderMaterial = null
var body_aura: AnimatedSprite2D = null
var ground_pulse: AnimatedSprite2D = null
var last_ground_pulse_swing_count: int = 0
var ghosts: Array[AnimatedSprite2D] = []
var ghost_write_index: int = 0
var ghost_spawn_timer: float = 0.0
var sword_ghosts: Array[Sprite2D] = []
var sword_ghost_write_index: int = 0
var sword_ghost_spawn_timer: float = 0.0
var elapsed: float = 0.0
var motes: Array[Mote] = []
var mote_spawn_timer: float = 0.0
var dust_puffs: Array[DustPuff] = []
var dust_spawn_timer: float = 0.0
var was_dashing: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(owner_player: Player) -> void:
	player = owner_player
	z_as_relative = false
	shared_aura_material = ShaderMaterial.new()
	shared_aura_material.shader = SILHOUETTE_SHADER
	_build_body_aura()
	_build_ground_pulse()
	_build_ghosts()
	_build_sword_ghosts()

func _build_body_aura() -> void:
	body_aura = AnimatedSprite2D.new()
	body_aura.name = "FlowBodyAura"
	body_aura.material = shared_aura_material
	body_aura.z_as_relative = false
	body_aura.z_index = 1
	body_aura.visible = false
	add_child(body_aura)

func _build_ground_pulse() -> void:
	ground_pulse = GROUND_PULSE_SCENE.instantiate() as AnimatedSprite2D
	ground_pulse.name = "GroundPulseAura"
	ground_pulse.position = Vector2(0.0, 16.0)
	ground_pulse.scale = Vector2.ONE * GROUND_PULSE_VISUAL_SCALE
	ground_pulse.z_as_relative = false
	ground_pulse.z_index = 0
	ground_pulse.visible = false
	ground_pulse.stop()
	ground_pulse.frame = 5
	add_child(ground_pulse)

func _build_ghosts() -> void:
	for index: int in range(GHOST_COUNT):
		var ghost: AnimatedSprite2D = AnimatedSprite2D.new()
		ghost.name = "FlowGhost%d" % index
		ghost.material = shared_aura_material
		ghost.z_as_relative = false
		ghost.z_index = 1
		ghost.visible = false
		ghost.set_meta("life", 0.0)
		add_child(ghost)
		ghosts.append(ghost)

## Sword afterimages get the exact same treatment as the body: a pool of
## silhouette copies of the current blade pose, spawned as it swings and
## faded out over a short lifetime. No separate outline/glow sprite anymore.
func _build_sword_ghosts() -> void:
	for index: int in range(SWORD_GHOST_COUNT):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.name = "SwordGhost%d" % index
		ghost.material = shared_aura_material
		ghost.centered = true
		ghost.z_as_relative = false
		ghost.z_index = 1
		ghost.visible = false
		ghost.set_meta("life", 0.0)
		add_child(ghost)
		sword_ghosts.append(ghost)

func reset() -> void:
	motes.clear()
	dust_puffs.clear()
	for ghost: AnimatedSprite2D in ghosts:
		ghost.visible = false
		ghost.set_meta("life", 0.0)
	for ghost: Sprite2D in sword_ghosts:
		ghost.visible = false
		ghost.set_meta("life", 0.0)
	if body_aura != null: body_aura.visible = false
	if ground_pulse != null:
		ground_pulse.visible = false
		ground_pulse.stop()
		ground_pulse.frame = 5
	last_ground_pulse_swing_count = player.swing_count if player != null else 0

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player): return
	elapsed += delta
	_update_dust(delta)
	var hd_active: bool = player.visual_style == "hd" and is_instance_valid(player.knight_sprite_hd)
	var flow_ratio: float = clampf(player.visual_flow / 100.0, 0.0, 1.0)
	var intensity: float = FlowColorUtils.intensity(flow_ratio)
	_update_ground_pulse(hd_active, flow_ratio)
	var active: bool = hd_active and intensity > 0.0
	body_aura.visible = active
	if not active:
		for ghost: AnimatedSprite2D in ghosts: ghost.visible = false
		for ghost: Sprite2D in sword_ghosts: ghost.visible = false
		motes.clear()
		queue_redraw()
		return
	shared_aura_material.set_shader_parameter("aura_color", FlowColorUtils.oscillating_color(elapsed, flow_ratio))
	_update_body_aura(intensity)
	_update_ghosts(delta, intensity)
	if sword_afterimages_enabled:
		_update_sword_ghosts(delta, intensity)
	else:
		for ghost: Sprite2D in sword_ghosts: ghost.visible = false
	_update_motes(delta, intensity)
	queue_redraw()

func _update_ground_pulse(hd_active: bool, flow_ratio: float) -> void:
	if ground_pulse == null:
		return
	var active: bool = hd_active and ground_pulse_enabled
	ground_pulse.visible = active
	if not active:
		return
	# This pulse is intentionally visible from zero Flow, unlike the stronger
	# onset-gated aura package. Flow increases alpha and shifts white toward the
	# shared Flow shimmer without hiding the beat at low intensity.
	var pulse_color: Color = Color.WHITE.lerp(FlowColorUtils.oscillating_color(elapsed, flow_ratio), flow_ratio * 0.7)
	var pulse_alpha: float = lerpf(GROUND_PULSE_BASE_ALPHA, GROUND_PULSE_MAX_ALPHA, flow_ratio)
	ground_pulse.modulate = Color(pulse_color.r, pulse_color.g, pulse_color.b, pulse_alpha)
	var pulse_rate: float = maxf(player._sword_cycle_frequency() * 2.0, 0.1)
	ground_pulse.speed_scale = clampf(pulse_rate / (5.0 / 6.0), 0.25, 3.0)
	if player.swing_count != last_ground_pulse_swing_count:
		last_ground_pulse_swing_count = player.swing_count
		ground_pulse.frame = 0
		ground_pulse.play()

func _update_body_aura(intensity: float) -> void:
	var source: AnimatedSprite2D = player.knight_sprite_hd
	if body_aura.sprite_frames != source.sprite_frames: body_aura.sprite_frames = source.sprite_frames
	if source.sprite_frames != null and source.animation != &"" and body_aura.animation != source.animation:
		body_aura.animation = source.animation
	body_aura.frame = source.frame
	body_aura.flip_h = source.flip_h
	body_aura.position = source.position
	body_aura.rotation = source.rotation
	body_aura.scale = source.scale * (1.0 + aura_scale_boost * intensity)
	body_aura.modulate = Color(1.0, 1.0, 1.0, aura_max_alpha * intensity)

func _update_ghosts(delta: float, intensity: float) -> void:
	var source: AnimatedSprite2D = player.knight_sprite_hd
	var moving: bool = player.velocity.length() > 15.0
	ghost_spawn_timer -= delta
	if moving and ghost_spawn_timer <= 0.0:
		ghost_spawn_timer = ghost_base_interval / lerpf(0.5, 1.8, intensity)
		var ghost: AnimatedSprite2D = ghosts[ghost_write_index]
		ghost_write_index = (ghost_write_index + 1) % ghosts.size()
		if ghost.sprite_frames != source.sprite_frames: ghost.sprite_frames = source.sprite_frames
		if source.sprite_frames != null and source.animation != &"": ghost.animation = source.animation
		ghost.frame = source.frame
		ghost.flip_h = source.flip_h
		ghost.position = source.position
		ghost.rotation = source.rotation
		ghost.scale = source.scale
		ghost.visible = true
		ghost.set_meta("life", GHOST_LIFETIME)
	for ghost: AnimatedSprite2D in ghosts:
		if not ghost.visible: continue
		var life: float = float(ghost.get_meta("life", 0.0)) - delta
		if life <= 0.0:
			ghost.visible = false
			continue
		ghost.set_meta("life", life)
		ghost.modulate = Color(1.0, 1.0, 1.0, aura_max_alpha * intensity * clampf(life / GHOST_LIFETIME, 0.0, 1.0))

## Spawns a silhouette copy of the current blade pose into the sword ghost
## pool as it swings, same shape as _update_ghosts() for the body. Position
## matches the real sword draw exactly: hilt anchor + BLADE_HILT_INSET +
## BLADE_LENGTH*0.34 along the blade direction (see Player._draw()).
func _update_sword_ghosts(delta: float, intensity: float) -> void:
	var blade_start: Vector2 = player.previous_blade_start
	var blade_end: Vector2 = player.previous_blade_end
	var blade_vector: Vector2 = blade_end - blade_start
	sword_ghost_spawn_timer -= delta
	if blade_vector.length_squared() > 1.0 and sword_ghost_spawn_timer <= 0.0:
		sword_ghost_spawn_timer = sword_ghost_base_interval / lerpf(0.6, 2.2, intensity)
		var angle: float = blade_vector.angle()
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var texture_center_global: Vector2 = blade_start + direction * (Player.BLADE_HILT_INSET + Player.BLADE_LENGTH * 0.34)
		var ghost: Sprite2D = sword_ghosts[sword_ghost_write_index]
		sword_ghost_write_index = (sword_ghost_write_index + 1) % sword_ghosts.size()
		ghost.texture = player.equipped_sword_texture()
		ghost.position = to_local(texture_center_global)
		ghost.rotation = angle - PI * 0.5
		ghost.scale = Vector2(SWORD_VISUAL_SCALE, SWORD_VISUAL_SCALE)
		ghost.visible = true
		ghost.set_meta("life", SWORD_GHOST_LIFETIME)
	for ghost: Sprite2D in sword_ghosts:
		if not ghost.visible: continue
		var life: float = float(ghost.get_meta("life", 0.0)) - delta
		if life <= 0.0:
			ghost.visible = false
			continue
		ghost.set_meta("life", life)
		ghost.modulate = Color(1.0, 1.0, 1.0, aura_max_alpha * intensity * clampf(life / SWORD_GHOST_LIFETIME, 0.0, 1.0))

func _update_motes(delta: float, intensity: float) -> void:
	var desired_count: int = int(round(mote_max_count * intensity))
	mote_spawn_timer -= delta
	if motes.size() < desired_count and mote_spawn_timer <= 0.0:
		mote_spawn_timer = 0.12
		var mote: Mote = Mote.new()
		mote.angle = rng.randf_range(0.0, TAU)
		mote.radius = mote_spawn_radius * rng.randf_range(0.85, 1.15)
		mote.speed = rng.randf_range(0.6, 1.3) * (1.0 if rng.randf() > 0.5 else -1.0)
		mote.max_life = rng.randf_range(0.7, 1.1)
		mote.life = mote.max_life
		motes.append(mote)
	for index: int in range(motes.size() - 1, -1, -1):
		var mote: Mote = motes[index]
		mote.life -= delta
		mote.angle += delta * mote.speed
		mote.radius = move_toward(mote.radius, 0.0, delta * (mote_spawn_radius / maxf(mote.max_life, 0.1)))
		if mote.life <= 0.0 or mote.radius <= 2.0:
			motes.remove_at(index)

func _update_dust(delta: float) -> void:
	if player == null: return
	var speed: float = player.velocity.length()
	var moving: bool = speed > 20.0
	var dashing: bool = player.dash_left > 0.0
	if dashing and not was_dashing:
		for index: int in range(dust_dash_burst_count): _spawn_dust_burst_puff()
	was_dashing = dashing
	dust_spawn_timer -= delta
	if moving and dust_spawn_timer <= 0.0:
		var move_ratio: float = clampf(speed / maxf(player.move_speed, 1.0), 0.4, 2.5)
		dust_spawn_timer = (dust_spawn_interval / move_ratio) * (0.4 if dashing else 1.0)
		_spawn_dust_puff(1.6 if dashing else 1.0)
	for index: int in range(dust_puffs.size() - 1, -1, -1):
		var puff: DustPuff = dust_puffs[index]
		puff.life -= delta
		puff.world_position += puff.velocity * delta
		puff.velocity = puff.velocity.move_toward(Vector2.ZERO, delta * 80.0)
		if puff.life <= 0.0: dust_puffs.remove_at(index)
	if not dust_puffs.is_empty(): queue_redraw()

func _spawn_dust_puff(size_multiplier: float) -> void:
	if dust_puffs.size() > 40: return
	var puff: DustPuff = DustPuff.new()
	var feet_offset: Vector2 = Vector2(0.0, 14.0)
	puff.world_position = player.global_position + feet_offset + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-3.0, 3.0))
	var away: Vector2 = -player.velocity.normalized() if player.velocity.length_squared() > 1.0 else Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	puff.velocity = away.rotated(rng.randf_range(-0.5, 0.5)) * rng.randf_range(18.0, 36.0) * size_multiplier
	puff.max_life = rng.randf_range(0.35, 0.55)
	puff.life = puff.max_life
	puff.puff_scale = size_multiplier * rng.randf_range(0.7, 1.1)
	dust_puffs.append(puff)

func _spawn_dust_burst_puff() -> void:
	if dust_puffs.size() > 40: return
	var puff: DustPuff = DustPuff.new()
	puff.world_position = player.global_position + Vector2(0.0, 14.0) + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0))
	puff.velocity = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(40.0, 90.0)
	puff.max_life = rng.randf_range(0.4, 0.65)
	puff.life = puff.max_life
	puff.puff_scale = rng.randf_range(1.1, 1.7)
	dust_puffs.append(puff)

func _draw() -> void:
	if not motes.is_empty():
		var aura_color: Color = Color.WHITE
		if shared_aura_material != null and shared_aura_material.shader != null:
			aura_color = shared_aura_material.get_shader_parameter("aura_color")
		for mote: Mote in motes:
			var life_ratio: float = clampf(mote.life / mote.max_life, 0.0, 1.0)
			var local_pos: Vector2 = Vector2.RIGHT.rotated(mote.angle) * mote.radius
			draw_texture(MOTE_TEXTURE, local_pos - MOTE_TEXTURE.get_size() * 0.5, Color(aura_color.r, aura_color.g, aura_color.b, life_ratio))
	for puff: DustPuff in dust_puffs:
		var ratio: float = clampf(puff.life / puff.max_life, 0.0, 1.0)
		var size: Vector2 = DUST_TEXTURE.get_size() * puff.puff_scale
		var local_pos: Vector2 = to_local(puff.world_position)
		draw_texture_rect(DUST_TEXTURE, Rect2(local_pos - size * 0.5, size), false, Color(1.0, 1.0, 1.0, ratio * 0.6))

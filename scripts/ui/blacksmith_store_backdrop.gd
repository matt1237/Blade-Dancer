class_name BlacksmithStoreBackdrop extends Control
## Presentation-only animated layer for Jimbo's Blacksmiths page. Never writes saves.

const ROOM: Texture2D = preload("res://assets/portraits/Blacksmith Store.png")
const EFFECT: Shader = preload("res://scripts/ui/blacksmith_store.gdshader")
const EMBER_ATLAS: Texture2D = preload("res://assets/generated/blacksmith_ember_atlas_v1.png")
const DUST_ATLAS: Texture2D = preload("res://assets/generated/blacksmith_dust_atlas_v1.png")
const SOURCE_SIZE: Vector2 = Vector2(1672.0, 941.0)
const EMBER_COUNT: int = 6
const DUST_COUNT: int = 6
const EMBER_SIZE: float = 9.0
const DUST_SIZE: float = 5.0
var painting_factor: float = 1.0
const BIRD_FRAMES: int = 6
const BIRD_VARIANTS: int = 3

var painting: TextureRect
var clock: float = 0.0
var last_tick_ms: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ember_sprites: Array[Sprite2D] = []
var dust_sprites: Array[Sprite2D] = []
var ember_source_positions: Array[Vector2] = []
var dust_source_positions: Array[Vector2] = []
var bird_textures: Array[Array] = []
var bird_active: bool = false
var bird_wait: float = 3.0
var bird_elapsed: float = 0.0
var bird_duration: float = 3.4
var bird_variant: int = 0
var bird_reverse: bool = false
var bird_y: float = 250.0
var bird_size_source: float = 29.0
var bird_test_override: bool = false
var ambient_enabled: bool = true
var sign_sprite: Sprite2D
var sign_backing: Sprite2D
var sign_hinge: Marker2D
const SIGN_PATCH_POSITION: Vector2 = Vector2.ZERO
const SIGN_PATCH_SCALE: float = 0.62

func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting = TextureRect.new()
	painting.name = "WorkshopPainting"
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting.texture = ROOM
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var effect: ShaderMaterial = ShaderMaterial.new()
	effect.shader = EFFECT
	painting.material = effect
	add_child(painting)
	sign_backing = Sprite2D.new()
	sign_backing.name = "SignBackgroundPatch"
	sign_backing.texture = load("res://assets/generated/blacksmith_sign_matte_v1.png") as Texture2D
	sign_backing.centered = false
	sign_backing.position = SIGN_PATCH_POSITION
	sign_backing.scale = Vector2.ONE * SIGN_PATCH_SCALE
	sign_backing.z_index = 2
	painting.add_child(sign_backing)
	sign_hinge = Marker2D.new()
	sign_hinge.name = "SignHinge"
	sign_hinge.position = Vector2(140.0, 111.0)
	painting.add_child(sign_hinge)
	sign_sprite = Sprite2D.new()
	sign_sprite.name = "SwayingSign"
	sign_sprite.texture = load("res://assets/generated/blacksmith_sign_cutout_v1_2.png") as Texture2D
	sign_sprite.centered = true
	sign_sprite.position = Vector2(10.0, 50.0)
	sign_sprite.offset = Vector2(0.0, -158.0)
	sign_sprite.scale = Vector2.ONE * 0.58
	sign_sprite.z_index = 3
	sign_hinge.add_child(sign_sprite)
	_create_particle_sprites(EMBER_ATLAS, ember_sprites, ember_source_positions, EMBER_COUNT, Vector2(1310.0, 470.0), 110.0, 12.0, EMBER_SIZE)
	_create_particle_sprites(DUST_ATLAS, dust_sprites, dust_source_positions, DUST_COUNT, Vector2(1230.0, 455.0), 220.0, 40.0, DUST_SIZE)
	for variant: int in range(BIRD_VARIANTS):
		var frames: Array[Texture2D] = []
		for frame: int in range(BIRD_FRAMES):
			frames.append(load("res://assets/generated/kaji_bird_%d_frame_%d_v1.png" % [variant, frame]) as Texture2D)
		bird_textures.append(frames)
	var birds_material: ShaderMaterial = painting.material as ShaderMaterial
	birds_material.set_shader_parameter("bird_texture", bird_textures[0][0])
	get_viewport().size_changed.connect(_fit)
	_fit()
	process_mode = Node.PROCESS_MODE_ALWAYS
	last_tick_ms = Time.get_ticks_msec()
	visibility_changed.connect(_sync_animation)
	_sync_animation()

func _create_particle_sprites(atlas: Texture2D, target: Array[Sprite2D], source_positions: Array[Vector2], count: int, center: Vector2, spread_x: float, spread_y: float, size_source: float) -> void:
	for index: int in range(count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = atlas
		sprite.hframes = 4
		sprite.vframes = 2
		sprite.frame = index % 8
		sprite.centered = true
		var source_position: Vector2 = center + Vector2(rng.randf_range(-spread_x * 0.5, spread_x * 0.5), rng.randf_range(-spread_y * 0.5, spread_y * 0.5))
		source_positions.append(source_position)
		sprite.position = source_position
		sprite.scale = Vector2.ONE * size_source / 128.0
		sprite.z_index = 4 if atlas == EMBER_ATLAS else 1
		sprite.modulate.a = 0.68 if atlas == EMBER_ATLAS else 0.52
		painting.add_child(sprite)
		target.append(sprite)

func _sync_animation() -> void:
	if not is_instance_valid(painting):
		return
	if is_visible_in_tree() or not ambient_enabled:
		clock = 0.0
		bird_active = false
		bird_wait = rng.randf_range(2.0, 5.0)
	var effect_material: ShaderMaterial = painting.material as ShaderMaterial
	effect_material.set_shader_parameter("ambient_time", clock)
	effect_material.set_shader_parameter("bird_visible", false)
	# Rejected generated overlays remain retained, but never cover the original sign.
	sign_backing.visible = false
	sign_sprite.visible = false
	for sprite: Sprite2D in ember_sprites:
		sprite.visible = ambient_enabled
	for sprite: Sprite2D in dust_sprites:
		sprite.visible = ambient_enabled
	last_tick_ms = Time.get_ticks_msec()
	set_process(is_visible_in_tree())

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var seconds: float = float(now - last_tick_ms) / 1000.0
	last_tick_ms = now
	advance_ambient(seconds)

func advance_ambient(seconds: float) -> void:
	if not is_visible_in_tree() or not ambient_enabled:
		return
	var elapsed: float = maxf(0.0, seconds)
	clock += elapsed
	var effect_material: ShaderMaterial = painting.material as ShaderMaterial
	effect_material.set_shader_parameter("ambient_time", clock)
	effect_material.set_shader_parameter("bird_visible", bird_active)
	# The sign belongs to the untouched room painting; no replacement or sway.
	_update_particles(ember_sprites, true)
	_update_particles(dust_sprites, false)
	if not bird_active:
		bird_wait -= elapsed
		if bird_wait <= 0.0 and ambient_enabled:
			_begin_bird()
	else:
		bird_elapsed += elapsed
		if bird_elapsed >= bird_duration and not bird_test_override:
			_finish_bird()
		else:
			_present_bird()

func set_ambient_enabled(enabled: bool) -> void:
	ambient_enabled = enabled
	_sync_animation()

func _update_particles(sprites: Array[Sprite2D], embers: bool) -> void:
	for index: int in range(sprites.size()):
		var sprite: Sprite2D = sprites[index]
		var source_position: Vector2 = ember_source_positions[index] if embers else dust_source_positions[index]
		if embers:
			var rise: float = fposmod(clock * (12.0 + float(index % 3) * 3.0) + float(index) * 31.0, 110.0)
			sprite.position = (source_position + Vector2(sin(clock * 1.7 + float(index) * 2.1) * 6.0, -rise)) * painting_factor
			sprite.frame = (int(clock * 8.0) + index * 3) % 8
			sprite.modulate.a = (0.28 + 0.18 * (0.5 + 0.5 * sin(clock * 6.0 + float(index)))) * (1.0 - rise / 110.0)
		else:
			var drift: float = fposmod(clock * (2.0 + float(index % 4)) + float(index) * 19.0, 80.0)
			sprite.position = (source_position + Vector2(sin(clock * 0.31 + float(index) * 1.8) * 8.0, -drift)) * painting_factor
			sprite.frame = (int(clock * 2.4) + index * 5) % 8
			sprite.modulate.a = 0.10 + 0.12 * (0.5 + 0.5 * sin(clock * 1.1 + float(index) * 2.0))

func _begin_bird() -> void:
	bird_active = true
	bird_elapsed = 0.0
	bird_duration = rng.randf_range(2.6, 4.0)
	bird_variant = rng.randi_range(0, BIRD_VARIANTS - 1)
	bird_reverse = rng.randf() < 0.5
	bird_y = rng.randf_range(245.0, 315.0) if rng.randf() < 0.5 else rng.randf_range(285.0, 345.0)
	bird_size_source = rng.randf_range(24.0, 32.0)
	_present_bird()

func _present_bird() -> void:
	var progress: float = clampf(bird_elapsed / bird_duration, 0.0, 1.0)
	if bird_reverse:
		progress = 1.0 - progress
	var bird_material: ShaderMaterial = painting.material as ShaderMaterial
	bird_material.set_shader_parameter("bird_visible", true)
	bird_material.set_shader_parameter("bird_center", Vector2(508.0 + progress * 126.0, bird_y + sin(bird_elapsed * 5.0) * 2.0))
	bird_material.set_shader_parameter("bird_size", bird_size_source)
	bird_material.set_shader_parameter("bird_reverse", bird_reverse)
	bird_material.set_shader_parameter("bird_texture", bird_textures[bird_variant][int(bird_elapsed * 12.0) % BIRD_FRAMES])

func _finish_bird() -> void:
	bird_active = false
	bird_elapsed = 0.0
	bird_wait = rng.randf_range(8.0, 19.0)
	if is_instance_valid(painting):
		(painting.material as ShaderMaterial).set_shader_parameter("bird_visible", false)

static func image_rect(viewport_size: Vector2) -> Rect2:
	var factor: float = minf(viewport_size.x / SOURCE_SIZE.x, viewport_size.y / SOURCE_SIZE.y)
	var dimensions: Vector2 = SOURCE_SIZE * factor
	return Rect2((viewport_size - dimensions) * 0.5, dimensions)

func _fit() -> void:
	size = get_viewport_rect().size
	var rect: Rect2 = image_rect(size)
	painting.position = rect.position
	painting.size = rect.size
	var factor: float = rect.size.x / SOURCE_SIZE.x
	painting_factor = factor
	if is_instance_valid(sign_backing):
		sign_backing.position = SIGN_PATCH_POSITION * factor
		sign_backing.scale = Vector2.ONE * factor * SIGN_PATCH_SCALE
	if is_instance_valid(sign_hinge):
		sign_hinge.position = Vector2(140.0, 111.0) * factor
	if is_instance_valid(sign_sprite):
		sign_sprite.scale = Vector2.ONE * factor * 0.58
		sign_sprite.position = Vector2(10.0, 50.0) * factor
		sign_sprite.offset = Vector2(0.0, -158.0) * factor
	for sprite: Sprite2D in ember_sprites:
		sprite.scale = Vector2.ONE * factor * (EMBER_SIZE / 128.0)
	for sprite: Sprite2D in dust_sprites:
		sprite.scale = Vector2.ONE * factor * (DUST_SIZE / 128.0)
	_update_particles(ember_sprites, true)
	_update_particles(dust_sprites, false)

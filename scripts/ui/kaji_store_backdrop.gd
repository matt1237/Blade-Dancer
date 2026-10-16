class_name KajiStoreBackdrop extends Control
## Presentation-only backdrop. Hiding reveals the existing scene unchanged.
const ROOM: Texture2D = preload("res://assets/portraits/Kaji's General Store.png")
const EFFECT: Shader = preload("res://scripts/ui/kaji_store.gdshader")
const SOURCE_SIZE: Vector2 = Vector2(1672, 941)
const WINDOW_MATTE: Texture2D = preload("res://assets/generated/kaji_window_sun_matte_v1.png")
var painting: TextureRect
# This backdrop alone owns the exterior schedule; no weather/save authority.
var ambient_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambient_seconds: float = 0.0
var last_tick_ms: int = 0
var bird_frames: Array[Array] = []
var bird_active: bool = false
var bird_variant: int = 0
var bird_window: int = 0
var bird_wait: float = 0.0
var bird_elapsed: float = 0.0
var bird_duration: float = 3.0
var bird_y: float = 215.0
var bird_size: float = 25.0
var bird_reverse: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting = TextureRect.new()
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting.texture = ROOM
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var effect: ShaderMaterial = ShaderMaterial.new()
	effect.shader = EFFECT
	effect.set_shader_parameter("strength", 1.0)
	painting.material = effect
	add_child(painting)
	get_viewport().size_changed.connect(_fit)
	_fit()
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambient_rng.randomize()
	for v: int in range(3):
		var frames: Array[Texture2D] = []
		for f: int in range(6):
			frames.append(load("res://assets/generated/kaji_bird_%d_frame_%d_v1.png" % [v,f]) as Texture2D)
		bird_frames.append(frames)
	effect.set_shader_parameter("window_matte", WINDOW_MATTE)
	visibility_changed.connect(_sync_ambient)
	_sync_ambient()

func _sync_ambient() -> void:
	if not is_instance_valid(painting):
		return
	ambient_seconds = 0.0
	last_tick_ms = Time.get_ticks_msec()
	_finish_bird()
	# First visit gets a short settling beat; later passages are 10–30 seconds apart.
	bird_wait = ambient_rng.randf_range(4.0, 8.0)
	set_process(is_visible_in_tree())
	(painting.material as ShaderMaterial).set_shader_parameter("ambient_time", 0.0)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var seconds: float = float(now-last_tick_ms)/1000.0
	last_tick_ms = now
	advance_ambient(seconds)

func advance_ambient(seconds: float) -> void:
	if not is_visible_in_tree():
		return
	ambient_seconds += seconds
	var effect: ShaderMaterial = painting.material as ShaderMaterial
	effect.set_shader_parameter("ambient_time", ambient_seconds)
	if not bird_active:
		bird_wait -= seconds
		if bird_wait <= 0.0:
			_begin_bird()
	else:
		bird_elapsed += seconds
		if bird_elapsed >= bird_duration:
			_finish_bird()
		else:
			_present_bird()

func _begin_bird() -> void:
	bird_active = true
	bird_elapsed = 0.0
	bird_variant = ambient_rng.randi_range(0,2)
	bird_window = ambient_rng.randi_range(0,1)
	bird_duration = ambient_rng.randf_range(2.2,3.8)
	bird_y = ambient_rng.randf_range(195.0,238.0) if bird_window == 0 else ambient_rng.randf_range(237.0,274.0)
	bird_size = ambient_rng.randf_range(23.0,30.0)
	bird_reverse = ambient_rng.randf() < 0.5
	_present_bird()

func _finish_bird() -> void:
	bird_active = false
	bird_elapsed = 0.0
	bird_wait = ambient_rng.randf_range(10.0,30.0)
	if is_instance_valid(painting):
		(painting.material as ShaderMaterial).set_shader_parameter("bird_visible", false)

func _present_bird() -> void:
	var progress: float = clampf(bird_elapsed/bird_duration,0.0,1.0)
	if bird_reverse:
		progress = 1.0-progress
	var x: float = lerpf(330.0,490.0,progress) if bird_window == 0 else lerpf(1220.0,1420.0,progress)
	var center: Vector2 = Vector2(x,bird_y-5.0*bird_elapsed/bird_duration+1.4*sin(bird_elapsed*7.0))
	var effect: ShaderMaterial = painting.material as ShaderMaterial
	effect.set_shader_parameter("bird_visible", bird_active)
	effect.set_shader_parameter("bird_center", center)
	effect.set_shader_parameter("bird_size", bird_size)
	effect.set_shader_parameter("bird_reverse", bird_reverse)
	effect.set_shader_parameter("bird_texture", bird_frames[bird_variant][int(bird_elapsed*12.0)%6])

static func image_rect(viewport_size: Vector2) -> Rect2:
	# Contain, not cover: keep both right-hand enchanted objects in view.
	var factor: float = minf(viewport_size.x / SOURCE_SIZE.x, viewport_size.y / SOURCE_SIZE.y)
	var dimensions: Vector2 = SOURCE_SIZE * factor
	return Rect2((viewport_size-dimensions)*0.5, dimensions)

func _fit() -> void:
	size = get_viewport_rect().size
	var rect: Rect2 = image_rect(size)
	painting.position = rect.position
	painting.size = rect.size

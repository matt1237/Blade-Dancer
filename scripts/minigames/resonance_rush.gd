class_name ResonanceRushLegacyGame extends ResonanceRushGame

## Resonance Rush — legacy procedural prototype.
##
## Standalone traversal scene: ground momentum -> ramp launch -> grapple
## swing -> release -> glide -> dive -> land -> repeat. No progression,
## economy, or enemies yet — this exists purely to feel-test the movement.

@export_category("Zones")
@export var mid_zone_altitude_m: float = 150.0
@export var high_zone_altitude_m: float = 450.0

@export_category("Camera")
@export var camera_smooth_speed: float = 4.5
@export var look_ahead_distance: float = 220.0
@export var camera_zoom_min: float = 1.0
@export var camera_zoom_max: float = 1.25
@export var camera_speed_reference: float = 900.0

@onready var terrain: ResonanceRushTerrain = $TerrainRoot
@onready var land_sail: ResonanceRushLandSail = $LandSail
@onready var camera: Camera2D = $Camera2D
@onready var ambient_spawner: ResonanceRushAmbient = $AmbientSpawner
@onready var clouds: ResonanceRushClouds = $Clouds
@onready var altitude_label: Label = $CanvasLayer/AltitudeLabel
@onready var speed_label: Label = $CanvasLayer/SpeedLabel
@onready var zone_label: Label = $CanvasLayer/ZoneLabel
@onready var glide_bar: ProgressBar = $CanvasLayer/GlideBar
@onready var hint_label: Label = $CanvasLayer/HintLabel
@onready var close_button: Button = $CanvasLayer/CloseButton
@onready var forest_layer: ParallaxLayer = $ParallaxBackground/ForestLayer
@onready var mountains_layer: ParallaxLayer = $ParallaxBackground/MountainsLayer
@onready var neon_layer: ParallaxLayer = $ParallaxBackground/NeonMountainsLayer

var current_zone: String = "FOREST"

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	var course_start: Vector2 = terrain.generate_course()
	land_sail.terrain = terrain
	land_sail.altitude_changed.connect(_on_altitude_changed)
	land_sail.state_changed.connect(_on_state_changed)
	land_sail.fell_off_course.connect(_on_fell_off_course)
	land_sail.begin_at(course_start)
	ambient_spawner.land_sail = land_sail
	clouds.land_sail = land_sail
	clouds.populate(course_start, terrain.course_end_position.x - course_start.x)
	camera.global_position = course_start
	camera.make_current()
	_on_state_changed("GROUND")

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_hud()
	_update_parallax_zone_blend()

func _update_camera(delta: float) -> void:
	var target: Vector2 = land_sail.global_position
	var facing: float = signf(land_sail.velocity.x) if absf(land_sail.velocity.x) > 5.0 else 1.0
	var speed_fraction: float = clampf(land_sail.velocity.length() / camera_speed_reference, 0.0, 1.0)
	var ahead: Vector2 = Vector2(look_ahead_distance * facing, -80.0 - speed_fraction * 60.0)
	if land_sail.velocity.y < -50.0:
		ahead.y -= 120.0
	var desired: Vector2 = target + ahead
	camera.global_position = camera.global_position.lerp(desired, clampf(camera_smooth_speed * delta, 0.0, 1.0))
	camera.zoom = Vector2.ONE * lerpf(camera_zoom_max, camera_zoom_min, speed_fraction)

func _update_hud() -> void:
	altitude_label.text = "ALT  %d m" % roundi(land_sail.altitude_m)
	speed_label.text = "SPEED  %d" % roundi(land_sail.velocity.length())
	glide_bar.max_value = land_sail.glide_duration
	glide_bar.value = land_sail.glide_energy
	zone_label.text = current_zone

func _on_altitude_changed(altitude_m: float) -> void:
	if altitude_m >= high_zone_altitude_m:
		current_zone = "NEON SKY"
	elif altitude_m >= mid_zone_altitude_m:
		current_zone = "MOUNTAINS"
	else:
		current_zone = "FOREST"

func _update_parallax_zone_blend() -> void:
	var altitude_m: float = land_sail.altitude_m
	var forest_alpha: float = clampf(1.0 - altitude_m / mid_zone_altitude_m, 0.15, 1.0)
	var mid_span: float = maxf(1.0, high_zone_altitude_m - mid_zone_altitude_m * 0.5)
	var mountains_alpha: float = clampf(1.0 - absf(altitude_m - mid_zone_altitude_m) / (mid_zone_altitude_m + mid_span), 0.35, 1.0)
	var neon_alpha: float = clampf((altitude_m - mid_zone_altitude_m * 0.5) / mid_span, 0.0, 1.0)
	_set_layer_alpha(forest_layer, forest_alpha)
	_set_layer_alpha(mountains_layer, mountains_alpha)
	_set_layer_alpha(neon_layer, neon_alpha)

func _set_layer_alpha(layer: ParallaxLayer, alpha: float) -> void:
	for child: Node in layer.get_children():
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item != null:
			canvas_item.modulate.a = alpha

func _on_state_changed(state_name: String) -> void:
	hint_label.text = _hint_for_state(state_name)

func _hint_for_state(state_name: String) -> String:
	match state_name:
		"GROUND": return "A/D or ←/→ to drive  —  Space to jump  —  aim + hold Left Click near a glowing orb to grapple"
		"AIR": return "Space to glide  —  hold Left Click near an orb to grapple"
		"GRAPPLE": return "A swings counter-clockwise, D clockwise — release Left Click to launch"
		"GLIDE": return "A/D pitch: backward pulls up, forward dives  —  Space folds the wing"
		_: return ""

func _on_fell_off_course() -> void:
	hint_label.text = "Recovered! Keep the flow going."

func _on_close_pressed() -> void:
	request_close()

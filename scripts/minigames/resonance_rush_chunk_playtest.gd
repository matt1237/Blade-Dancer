class_name ResonanceRushChunkPlaytest extends ResonanceRushGame

## Minimal harness for Phase 1 RushChunk authoring. It deliberately contains
## no procedural course logic: the Land Sail drives the instantiated graybox
## chunk's exact DrivePath through ResonanceRushAuthoredTerrain.

@export var course_title: String = "GRAYBOX RUSHCHUNK"
@export var camera_follow_speed: float = 7.0
@export var camera_look_ahead: Vector2 = Vector2(260.0, -100.0)

@onready var terrain: ResonanceRushTerrain = $TerrainRoot
@onready var land_sail: ResonanceRushLandSail = $LandSail
@onready var camera: Camera2D = $Camera2D
## Single source of truth for on-screen status: course name, current
## movement state, and the controls relevant to that state.
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var close_button: Button = get_node_or_null("CanvasLayer/CloseButton") as Button
@onready var clouds: ResonanceRushClouds = get_node_or_null("Clouds") as ResonanceRushClouds
@onready var ambient_spawner: ResonanceRushAmbient = get_node_or_null("AmbientSpawner") as ResonanceRushAmbient
## Procedural gradient/silhouette backdrop (see resonance_rush_sky.gdshader).
## Resolution-independent by construction, so it never looks stretched or
## blocky the way a scaled-up pixel-art bitmap does across a long course.
@onready var sky_rect: ColorRect = get_node_or_null("BackgroundLayer/SkyGradient") as ColorRect

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(request_close)
	var course_start: Vector2 = terrain.generate_course()
	land_sail.terrain = terrain
	land_sail.state_changed.connect(_on_state_changed)
	land_sail.begin_at(course_start)
	camera.global_position = course_start + camera_look_ahead
	camera.make_current()
	_on_state_changed("GROUND")
	if clouds != null:
		clouds.land_sail = land_sail
		clouds.populate(course_start, terrain.course_end_position.x - course_start.x)
	if ambient_spawner != null:
		ambient_spawner.land_sail = land_sail

func _process(delta: float) -> void:
	var desired_position: Vector2 = land_sail.global_position + camera_look_ahead
	camera.global_position = camera.global_position.lerp(desired_position, clampf(camera_follow_speed * delta, 0.0, 1.0))
	_update_sky_shader()

func _update_sky_shader() -> void:
	if sky_rect == null:
		return
	var sky_material: ShaderMaterial = sky_rect.material as ShaderMaterial
	if sky_material == null:
		return
	sky_material.set_shader_parameter("camera_world_pos", camera.global_position)
	sky_material.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_X or event.physical_keycode == KEY_ESCAPE:
			request_close()
			get_viewport().set_input_as_handled()

func _on_state_changed(state_name: String) -> void:
	print("RushChunk state: ", state_name)
	var controls: String = "D/→ drive   Space jump   Aim + hold Left Click to fire hook"
	match state_name:
		"GRAPPLE": controls = "A counter-clockwise / D clockwise   Release Left Click to launch"
		"GLIDE": controls = "A/D pitch — backward pulls up, forward dives   Space folds wing"
		"AIR": controls = "Space deploys glider   Aim + hold Left Click to fire hook"
	status_label.text = "%s  •  %s\n%s" % [course_title, state_name, controls]

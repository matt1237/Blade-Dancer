class_name MetronomeTopBar extends Control

var player_ref: Player = null
var display_mode: String = "player"
var beat_pulse_percent: float = 50.0
var visualizer_counts: int = 2
var beat_visualizer_size: float = 1.0
var visualizer: MetronomeVisualizer = null
var visualizer_palette: String = "gold"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visualizer = MetronomeVisualizer.new()
	visualizer.name = "AuthoredMetronomeVisualizer"
	visualizer.scale = Vector2.ONE * 0.9
	add_child(visualizer)
	set_process(true)

func configure(player: Player, mode: String, beat_percent: float = 50.0, beat_size: float = 1.0, counts: int = 2) -> void:
	visualizer_counts = clampi(counts, 1, 4)
	player_ref = player
	display_mode = mode
	beat_pulse_percent = clampf(beat_percent, 0.0, 100.0)
	beat_visualizer_size = clampf(beat_size, 0.5, 2.5)
	if visualizer != null:
		visualizer.configure(player_ref, beat_pulse_percent, visualizer_palette, visualizer_counts)
		visualizer.set_display_enabled(display_mode in ["beat", "top_bar"])
		visualizer.scale = Vector2.ONE * (0.9 * clampf(beat_visualizer_size, 0.5, 2.5))
	queue_redraw()

func set_visualizer_palette(value: String) -> void:
	visualizer_palette = value if value in ["gold", "blue", "green"] else "gold"
	if visualizer != null:
		visualizer.set_palette(visualizer_palette)

func set_visualizer_counts(value: int) -> void:
	visualizer_counts = clampi(value, 1, 4)
	if visualizer != null:
		visualizer.set_visualizer_counts(visualizer_counts)

func set_beat_pulse_percent(value: float) -> void:
	beat_pulse_percent = clampf(value, 0.0, 100.0)
	if visualizer != null:
		visualizer.set_beat_percent(beat_pulse_percent)

func set_beat_visualizer_size(value: float) -> void:
	beat_visualizer_size = clampf(value, 0.5, 2.5)
	if visualizer != null:
		visualizer.scale = Vector2.ONE * (0.9 * beat_visualizer_size)
	queue_redraw()

func _process(_delta: float) -> void:
	if visualizer != null:
		var viewport_size: Vector2 = get_viewport_rect().size
		var visualizer_y: float = 64.0 if display_mode == "top_bar" else viewport_size.y - 42.0
		visualizer.position = Vector2(viewport_size.x * 0.5, visualizer_y)
	queue_redraw()

## Rendering is delegated to the authored MetronomeVisualizer sprite.
## This node remains as the HUD anchor for the existing display modes.
func _draw() -> void:
	return

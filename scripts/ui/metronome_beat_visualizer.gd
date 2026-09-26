class_name MetronomeBeatVisualizer extends Control

var player_ref: Player = null
var display_mode: String = "off"
var pulse_percent: float = 50.0
var pulse_strength: float = 0.0
var last_stroke_index: int = -1
var last_progress: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func configure(player: Player, mode: String, beat_percent: float) -> void:
	player_ref = player
	display_mode = mode
	pulse_percent = clampf(beat_percent, 0.0, 100.0)
	last_stroke_index = -1
	last_progress = 0.0
	queue_redraw()

func set_pulse_percent(value: float) -> void:
	pulse_percent = clampf(value, 0.0, 100.0)
	last_stroke_index = -1
	last_progress = 0.0

func _process(delta: float) -> void:
	var visual_delta: float = delta
	if is_instance_valid(player_ref) and player_ref.is_experimental_bind_form() and player_ref.experimental_bind_active:
		visual_delta /= clampf(player_ref.get_combat_hand_setting("bind_focus_time_scale"), 0.2, 1.0)
	pulse_strength = move_toward(pulse_strength, 0.0, visual_delta * 5.5)
	if display_mode != "beat" or player_ref == null or get_tree().paused:
		queue_redraw()
		return
	if player_ref.sword_style not in [Player.SwordStyle.METRONOME, Player.SwordStyle.METRONOME_WINDUP] and not player_ref.is_experimental_bind_form():
		queue_redraw()
		return
	var current_phase: float = player_ref.sword_phase
	var current_progress: float = Player.metronome_stroke_progress(current_phase)
	var current_stroke_index: int = floori((current_phase + PI * 0.5) / PI)
	var pulse_at_boundary: bool = pulse_percent <= 0.0 or pulse_percent >= 100.0
	if last_stroke_index < 0:
		last_stroke_index = current_stroke_index
		last_progress = current_progress
	elif current_stroke_index != last_stroke_index:
		last_stroke_index = current_stroke_index
		last_progress = 0.0
		if pulse_at_boundary:
			pulse_strength = 1.0
	else:
		var target_progress: float = clampf(pulse_percent / 100.0, 0.0, 0.999)
		if last_progress < target_progress and current_progress >= target_progress:
			pulse_strength = 1.0
		last_progress = current_progress
	queue_redraw()

func _draw() -> void:
	if display_mode != "beat":
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y - 42.0)
	var pulse: float = clampf(pulse_strength, 0.0, 1.0)
	var glow_radius: float = 8.0 + pulse * 14.0
	var ball_radius: float = 5.0 + pulse * 3.0
	var gold: Color = Color(1.0, 0.76, 0.16, 1.0)
	draw_circle(center, glow_radius, Color(gold.r, gold.g, gold.b, 0.10 + pulse * 0.26))
	draw_circle(center, ball_radius, Color.WHITE.lerp(gold, pulse))
	draw_circle(center - Vector2(1.5, 1.5), 1.8 + pulse, Color(1.0, 1.0, 1.0, 0.95))

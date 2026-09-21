class_name RedHeartGlow extends Control

const PARTICLE_COUNT: int = 14

var target: Control = null
var elapsed: float = 0.0
var particles: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 119
	for index: int in range(PARTICLE_COUNT):
		particles.append({"x":randf(), "y":randf(), "speed":randf_range(0.2, 0.5), "phase":randf_range(0.0, TAU), "size":randf_range(1.5, 3.2)})
	visible = false

func set_charged(control: Control, charged: bool) -> void:
	target = control if charged else null
	visible = charged and control != null
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not visible or target == null or not is_instance_valid(target) or not target.is_visible_in_tree(): return
	elapsed += delta
	for particle: Dictionary in particles:
		particle["y"] = fposmod(float(particle["y"]) + float(particle["speed"]) * delta, 1.0)
	queue_redraw()

func _draw() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree(): return
	var global_rect: Rect2 = target.get_global_rect()
	var rect: Rect2 = Rect2(global_rect.position - global_position, global_rect.size).grow(5.0)
	var pulse: float = 0.5 + 0.5 * sin(elapsed * 4.8)
	for ring: int in range(4):
		var expansion: float = float(ring) * 3.0 + pulse * 2.0
		var alpha: float = (0.34 - float(ring) * 0.06) * (0.72 + pulse * 0.28)
		draw_style_box(_outline_style(Color(1.0, 0.12, 0.22, alpha), 2), rect.grow(expansion))
	var fall_height: float = 55.0
	for particle: Dictionary in particles:
		var y_ratio: float = float(particle["y"])
		var sparkle_position: Vector2 = Vector2(lerpf(rect.position.x, rect.end.x, float(particle["x"])), rect.end.y + y_ratio * fall_height)
		var sparkle_size: float = float(particle["size"]) * (0.55 + 0.45 * sin(elapsed * 7.0 + float(particle["phase"])))
		var color: Color = Color(1.0, 0.35, 0.42, (1.0 - y_ratio) * 0.92)
		draw_line(sparkle_position - Vector2(sparkle_size, 0.0), sparkle_position + Vector2(sparkle_size, 0.0), color, 1.4)
		draw_line(sparkle_position - Vector2(0.0, sparkle_size), sparkle_position + Vector2(0.0, sparkle_size), color, 1.4)

func _outline_style(color: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	return style

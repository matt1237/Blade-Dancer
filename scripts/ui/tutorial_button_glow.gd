class_name TutorialButtonGlow extends Control

const PARTICLE_COUNT: int = 18

var target: Control = null
var prompt_label: Label = null
var elapsed: float = 0.0
var particles: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color("eaf8ff"))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.2, 0.38, 0.95))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_label)
	for index: int in range(PARTICLE_COUNT):
		particles.append({"x": randf(), "y": randf(), "speed": randf_range(0.18, 0.46), "phase": randf_range(0.0, TAU), "size": randf_range(1.5, 3.5)})
	visible = false

func highlight(control: Control, message: String) -> void:
	target = control
	prompt_label.text = message
	visible = target != null
	elapsed = 0.0
	queue_redraw()

func clear_highlight() -> void:
	target = null
	visible = false

func _process(delta: float) -> void:
	if not visible or target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	elapsed += delta
	for particle: Dictionary in particles:
		particle["y"] = fposmod(float(particle["y"]) + float(particle["speed"]) * delta, 1.0)
	queue_redraw()

func _target_local_rect() -> Rect2:
	var global_rect: Rect2 = target.get_global_rect()
	return Rect2(global_rect.position - global_position, global_rect.size)

func _draw() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var rect: Rect2 = _target_local_rect().grow(7.0)
	var pulse: float = 0.5 + 0.5 * sin(elapsed * 4.2)
	for ring: int in range(4):
		var expansion: float = float(ring) * 3.0 + pulse * 2.0
		var alpha: float = (0.24 - float(ring) * 0.045) * (0.72 + pulse * 0.28)
		draw_style_box(_outline_style(Color(0.58, 0.86, 1.0, alpha), 2), rect.grow(expansion))
	var fall_height: float = 72.0
	for particle: Dictionary in particles:
		var x_ratio: float = float(particle["x"])
		var y_ratio: float = float(particle["y"])
		var sparkle_position: Vector2 = Vector2(lerpf(rect.position.x, rect.end.x, x_ratio), rect.end.y + y_ratio * fall_height)
		var fade: float = 1.0 - y_ratio
		var twinkle: float = 0.55 + 0.45 * sin(elapsed * 7.0 + float(particle["phase"]))
		var sparkle_size: float = float(particle["size"]) * twinkle
		var color: Color = Color(0.76, 0.93, 1.0, fade * 0.9)
		draw_line(sparkle_position - Vector2(sparkle_size, 0.0), sparkle_position + Vector2(sparkle_size, 0.0), color, 1.4)
		draw_line(sparkle_position - Vector2(0.0, sparkle_size), sparkle_position + Vector2(0.0, sparkle_size), color, 1.4)
	prompt_label.position = Vector2(rect.position.x - 50.0, rect.end.y + fall_height + 4.0)
	prompt_label.size = Vector2(rect.size.x + 100.0, 30.0)

func _outline_style(color: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style

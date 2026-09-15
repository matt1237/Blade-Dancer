class_name MobileControls extends Control

signal movement_changed(value: Vector2)
signal aim_changed(value: Vector2)
signal ability_changed(ability: String, held: bool)

const ABILITIES: Array[String] = ["chakram", "dash", "grapple"]
const MOVE_TOUCH_ROLE: String = "move"
const AIM_TOUCH_ROLE: String = "aim"
const MOUSE_POINTER_ID: int = -999

@export_category("Visibility")
@export var show_on_touch_devices: bool = true
@export var force_visible_on_desktop: bool = false
@export_category("Layout")
@export var safe_margin: float = 24.0
@export var stick_radius: float = 88.0
@export var button_radius: float = 38.0
@export var control_alpha: float = 0.72

var gameplay_visible: bool = false
var left_stick_center: Vector2 = Vector2.ZERO
var right_stick_center: Vector2 = Vector2.ZERO
var current_stick_radius: float = 88.0
var current_button_radius: float = 38.0
var move_value: Vector2 = Vector2.ZERO
var aim_value: Vector2 = Vector2.ZERO
var active_touch_roles: Dictionary = {}
var touch_positions: Dictionary = {}
var ability_touch_ids: Dictionary = {}
var ability_held: Dictionary = {"chakram": false, "dash": false, "grapple": false}
var mouse_role: String = ""
var mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recalculate_layout()
	set_gameplay_visible(force_visible_on_desktop)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recalculate_layout()

func _device_supports_touch() -> bool:
	return DisplayServer.is_touchscreen_available()

func _should_show_controls() -> bool:
	return force_visible_on_desktop or (show_on_touch_devices and _device_supports_touch())

func set_gameplay_visible(gameplay: bool) -> void:
	gameplay_visible = gameplay
	_set_controls_visible(gameplay and _should_show_controls())
	if not gameplay:
		_reset_all_inputs()

func is_mobile_input_active() -> bool:
	return visible and gameplay_visible and _should_show_controls()

func _set_controls_visible(should_show: bool) -> void:
	visible = should_show
	set_process_input(should_show)
	queue_redraw()

func _recalculate_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var scale_factor: float = clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.72, 1.2)
	current_stick_radius = clampf(stick_radius * scale_factor, 64.0, 102.0)
	current_button_radius = clampf(button_radius * scale_factor, 30.0, 46.0)
	var horizontal_margin: float = maxf(safe_margin, viewport_size.x * 0.035)
	var bottom_margin: float = maxf(safe_margin, viewport_size.y * 0.055)
	var side_spacing: float = current_stick_radius + horizontal_margin
	var ability_reach: float = current_stick_radius * 1.85 + current_button_radius + horizontal_margin
	var stick_y: float = viewport_size.y - bottom_margin - current_stick_radius
	left_stick_center = Vector2(side_spacing, stick_y)
	right_stick_center = Vector2(viewport_size.x - ability_reach, stick_y)
	if viewport_size.x < viewport_size.y:
		# Keep both controls usable on a portrait phone, even though landscape is
		# the recommended presentation for this 16:9 arena.
		stick_y = viewport_size.y - bottom_margin - current_stick_radius
		left_stick_center = Vector2(viewport_size.x * 0.24, stick_y)
		right_stick_center = Vector2(minf(viewport_size.x * 0.76, viewport_size.x - ability_reach), stick_y)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_mobile_input_active():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		_handle_pointer(touch.index, touch.position, touch.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_handle_pointer_motion(drag.index, drag.position)
		get_viewport().set_input_as_handled()
	elif force_visible_on_desktop and event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_handle_pointer(MOUSE_POINTER_ID, mouse_button.position, mouse_button.pressed)
			get_viewport().set_input_as_handled()
	elif force_visible_on_desktop and event is InputEventMouseMotion and not mouse_role.is_empty():
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_pointer_motion(MOUSE_POINTER_ID, mouse_motion.position)
		get_viewport().set_input_as_handled()

func _handle_pointer(pointer_id: int, pointer_position: Vector2, pressed: bool) -> void:
	if pressed:
		_handle_pointer_down(pointer_id, pointer_position)
	else:
		_handle_pointer_up(pointer_id)

func _handle_pointer_down(pointer_id: int, touch_position: Vector2) -> void:
	if active_touch_roles.has(pointer_id):
		return
	var ability: String = _ability_at(touch_position)
	if not ability.is_empty():
		if ability_touch_ids.has(ability):
			return
		active_touch_roles[pointer_id] = ability
		touch_positions[pointer_id] = touch_position
		ability_touch_ids[ability] = pointer_id
		_set_ability_held(ability, true)
		if pointer_id == MOUSE_POINTER_ID:
			mouse_role = ability
		return
	if touch_position.distance_squared_to(left_stick_center) <= pow(current_stick_radius * 1.35, 2.0) and not _role_is_active(MOVE_TOUCH_ROLE):
		active_touch_roles[pointer_id] = MOVE_TOUCH_ROLE
		touch_positions[pointer_id] = touch_position
		if pointer_id == MOUSE_POINTER_ID:
			mouse_role = MOVE_TOUCH_ROLE
		_update_move(touch_position)
		return
	if touch_position.distance_squared_to(right_stick_center) <= pow(current_stick_radius * 1.35, 2.0) and not _role_is_active(AIM_TOUCH_ROLE):
		active_touch_roles[pointer_id] = AIM_TOUCH_ROLE
		touch_positions[pointer_id] = touch_position
		if pointer_id == MOUSE_POINTER_ID:
			mouse_role = AIM_TOUCH_ROLE
		_update_aim(touch_position)

func _handle_pointer_motion(pointer_id: int, touch_position: Vector2) -> void:
	if not active_touch_roles.has(pointer_id):
		return
	touch_positions[pointer_id] = touch_position
	var role: String = str(active_touch_roles[pointer_id])
	if role == MOVE_TOUCH_ROLE:
		_update_move(touch_position)
	elif role == AIM_TOUCH_ROLE:
		_update_aim(touch_position)

func _handle_pointer_up(pointer_id: int) -> void:
	if not active_touch_roles.has(pointer_id):
		return
	var role: String = str(active_touch_roles[pointer_id])
	active_touch_roles.erase(pointer_id)
	touch_positions.erase(pointer_id)
	if role == MOVE_TOUCH_ROLE:
		move_value = Vector2.ZERO
		movement_changed.emit(move_value)
	elif role == AIM_TOUCH_ROLE:
		aim_value = Vector2.ZERO
		queue_redraw()
	elif ABILITIES.has(role):
		if ability_touch_ids.get(role, -1) == pointer_id:
			ability_touch_ids.erase(role)
		_set_ability_held(role, false)
	if pointer_id == MOUSE_POINTER_ID:
		mouse_role = ""
	queue_redraw()

func _role_is_active(role: String) -> bool:
	return active_touch_roles.values().has(role)

func _update_move(stick_position: Vector2) -> void:
	move_value = _stick_vector(left_stick_center, stick_position)
	movement_changed.emit(move_value)
	queue_redraw()

func _update_aim(stick_position: Vector2) -> void:
	aim_value = _stick_vector(right_stick_center, stick_position)
	if aim_value.length_squared() > 0.0001:
		aim_changed.emit(aim_value.normalized())
	queue_redraw()

func _stick_vector(center: Vector2, stick_position: Vector2) -> Vector2:
	var offset: Vector2 = stick_position - center
	var reach: float = current_stick_radius
	if offset.length() > reach:
		offset = offset.normalized() * reach
	return offset / reach

func _ability_at(tap_position: Vector2) -> String:
	for ability: String in ABILITIES:
		if tap_position.distance_squared_to(_ability_center(ability)) <= pow(current_button_radius * 1.3, 2.0):
			return ability
	return ""

func _ability_center(ability: String) -> Vector2:
	var angle: float = -2.55
	match ability:
		"chakram": angle = -2.55
		"dash": angle = -1.57
		"grapple": angle = -0.59
	return right_stick_center + Vector2.from_angle(angle) * (current_stick_radius * 1.85)

func _set_ability_held(ability: String, held: bool) -> void:
	if not ABILITIES.has(ability) or bool(ability_held.get(ability, false)) == held:
		return
	ability_held[ability] = held
	ability_changed.emit(ability, held)
	queue_redraw()

func _reset_all_inputs() -> void:
	active_touch_roles.clear()
	touch_positions.clear()
	ability_touch_ids.clear()
	mouse_role = ""
	move_value = Vector2.ZERO
	aim_value = Vector2.ZERO
	for ability: String in ABILITIES:
		if bool(ability_held.get(ability, false)):
			ability_held[ability] = false
			ability_changed.emit(ability, false)
	movement_changed.emit(move_value)
	queue_redraw()

func _draw() -> void:
	var stick_fill: Color = Color(0.06, 0.10, 0.16, control_alpha * 0.72)
	var stick_ring: Color = Color(0.55, 0.82, 0.96, control_alpha)
	var knob_fill: Color = Color(0.78, 0.92, 1.0, control_alpha * 0.9)
	_draw_stick(left_stick_center, move_value, stick_fill, stick_ring, knob_fill, "MOVE")
	_draw_stick(right_stick_center, aim_value, stick_fill, Color(0.95, 0.75, 0.35, control_alpha), knob_fill, "AIM")
	for ability: String in ABILITIES:
		_draw_ability_button(ability)

func _draw_stick(center: Vector2, value: Vector2, fill: Color, ring: Color, knob: Color, label: String) -> void:
	draw_circle(center, current_stick_radius, fill)
	draw_arc(center, current_stick_radius, 0.0, TAU, 48, ring, 3.0, true)
	draw_arc(center, current_stick_radius * 0.62, 0.0, TAU, 48, Color(ring.r, ring.g, ring.b, 0.25), 2.0, true)
	var knob_position: Vector2 = center + value * current_stick_radius * 0.62
	draw_circle(knob_position, current_stick_radius * 0.29, Color(0.02, 0.04, 0.07, control_alpha * 0.9))
	draw_circle(knob_position, current_stick_radius * 0.25, knob)
	draw_string(ThemeDB.fallback_font, center + Vector2(-28.0, current_stick_radius + 24.0), label, HORIZONTAL_ALIGNMENT_CENTER, 56.0, 14, Color(0.86, 0.94, 1.0, control_alpha))

func _draw_ability_button(ability: String) -> void:
	var center: Vector2 = _ability_center(ability)
	var held: bool = bool(ability_held.get(ability, false))
	var base_color: Color = Color("d76b55")
	var label: String = "C"
	match ability:
		"dash":
			base_color = Color("6e9fe0")
			label = "D"
		"grapple":
			base_color = Color("c79a54")
			label = "G"
	var fill_color: Color = base_color.lightened(0.28) if held else base_color
	draw_circle(center + Vector2(3.0, 4.0), current_button_radius + 3.0, Color(0.01, 0.02, 0.04, control_alpha * 0.8))
	draw_circle(center, current_button_radius, Color(fill_color.r, fill_color.g, fill_color.b, control_alpha))
	draw_arc(center, current_button_radius, 0.0, TAU, 40, Color(1.0, 0.93, 0.72, control_alpha), 2.5 if held else 1.8, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, 24.0, 24, Color.WHITE)
	draw_string(ThemeDB.fallback_font, center + Vector2(-44.0, current_button_radius + 18.0), ability.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 88.0, 12, Color(0.96, 0.94, 0.87, control_alpha))
	var gesture_text: String = "RELEASE" if held else "HOLD + AIM"
	draw_string(ThemeDB.fallback_font, center + Vector2(-48.0, current_button_radius + 34.0), gesture_text, HORIZONTAL_ALIGNMENT_CENTER, 96.0, 11, Color(1.0, 0.86, 0.5, control_alpha))
	if ability == "grapple":
		draw_string(ThemeDB.fallback_font, center + Vector2(-48.0, current_button_radius + 48.0), "TAP = DETACH", HORIZONTAL_ALIGNMENT_CENTER, 96.0, 10, Color(0.6, 0.95, 0.92, control_alpha))

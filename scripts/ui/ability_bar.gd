class_name AbilityBar
extends Control
## Session-local quick binds. No save writes; abilities and slots are independent.
const SLOT_COUNT = 12
const SLOT_SIZE = Vector2(60.0, 66.0)
const GAP = 2.0
const DISPLAY_SCALE = 0.85
const BOTTOM_MARGIN = 5.0
const REWIND_ICON = preload("res://assets/generated/Rewind Icon.png")
const SLOW_ICON = preload("res://assets/generated/Time Slow.png")
const HOTKEY_BLUE = Color(0.28, 0.72, 1.0)
const DEFAULT_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const RESERVED_KEYS: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_Z, KEY_X, KEY_ESCAPE, KEY_TAB, KEY_ENTER, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
var player_ref: Player = null
var bindings: Array[int] = DEFAULT_KEYS.duplicate()
var abilities: Array[String] = ["rewind", "slow", "", "", "", "", "", "", "", "", "", ""]
var buttons: Array[Button] = []
var key_labels: Array[Label] = []
var cooldown_labels: Array[Label] = []
var fills: Array[ProgressBar] = []
var icons: Array[TextureRect] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_ref = get_node_or_null("../../Player") as Player
	for index: int in range(SLOT_COUNT):
		_build_slot(index)
	_refresh()

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _build_slot(index: int) -> void:
	var button: Button = Button.new()
	button.name = "Slot%d" % (index + 1)
	button.position = Vector2(float(index) * (SLOT_SIZE.x + GAP), 0.0)
	button.size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(Color(0.035, 0.045, 0.065, 0.94), Color(0.32, 0.37, 0.45)))
	button.add_theme_stylebox_override("hover", _style(Color(0.07, 0.12, 0.18, 0.98), HOTKEY_BLUE))
	button.add_theme_stylebox_override("pressed", _style(Color(0.025, 0.06, 0.10), HOTKEY_BLUE))
	button.pressed.connect(activate_slot.bind(index))
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and is_instance_valid(player_ref):
			player_ref.ability_ui_mouse_capture = true
	)
	add_child(button)
	buttons.append(button)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(5.0, 7.0)
	icon.size = Vector2(47.0, 47.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = REWIND_ICON if abilities[index] == "rewind" else (SLOW_ICON if abilities[index] == "slow" else null)
	button.add_child(icon)
	icons.append(icon)
	var fill: ProgressBar = ProgressBar.new()
	fill.name = "Recharge"
	fill.position = Vector2(53.0, 25.0)
	fill.size = Vector2(4.0, 35.0)
	fill.max_value = 1.0
	fill.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	fill.show_percentage = false
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("background", _style(Color(0.01, 0.025, 0.04), Color.TRANSPARENT))
	fill.add_theme_stylebox_override("fill", _style(HOTKEY_BLUE, HOTKEY_BLUE))
	button.add_child(fill)
	fills.append(fill)
	var cooldown: Label = Label.new()
	cooldown.name = "Cooldown"
	cooldown.position = Vector2(3.0, 32.0)
	cooldown.size = Vector2(48.0, 29.0)
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown.add_theme_font_size_override("font_size", 22)
	cooldown.add_theme_color_override("font_outline_color", Color.BLACK)
	cooldown.add_theme_constant_override("outline_size", 5)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cooldown)
	cooldown_labels.append(cooldown)
	var hotkey: Label = Label.new()
	hotkey.name = "Hotkey"
	hotkey.position = Vector2(4.0, 1.0)
	hotkey.size = Vector2(51.0, 22.0)
	hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hotkey.add_theme_font_size_override("font_size", 17)
	hotkey.add_theme_color_override("font_color", HOTKEY_BLUE)
	hotkey.add_theme_color_override("font_outline_color", Color(0.0, 0.015, 0.035))
	hotkey.add_theme_constant_override("outline_size", 5)
	hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(hotkey)
	key_labels.append(hotkey)

func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * GAP
	var fit: float = minf(DISPLAY_SCALE, (viewport_size.x - 24.0) / width)
	scale = Vector2.ONE * fit
	size = Vector2(width, SLOT_SIZE.y)
	position = Vector2((viewport_size.x - width * fit) * 0.5, viewport_size.y - SLOT_SIZE.y * fit - BOTTOM_MARGIN)
	_refresh()

static func binding_label(key: int) -> String:
	match key:
		0: return "—"
		KEY_MINUS: return "-"
		KEY_EQUAL: return "="
	return OS.get_keycode_string(key)

func _refresh() -> void:
	for index: int in range(buttons.size()):
		key_labels[index].text = binding_label(bindings[index])
		var ability: String = abilities[index]
		var left: float = player_ref.ability_cooldowns.left(ability) if is_instance_valid(player_ref) and not ability.is_empty() else 0.0
		var active: bool = is_instance_valid(player_ref) and ((ability == "rewind" and player_ref.rewind_active) or (ability == "slow" and WorldTime.slow_active()))
		cooldown_labels[index].text = str(ceili(left)) if left > 0.0 else ""
		fills[index].visible = not ability.is_empty()
		fills[index].value = 1.0 - left / AbilityCooldowns.TIME_ABILITY_COOLDOWN
		icons[index].modulate = Color.WHITE if left <= 0.0 or active else Color(0.42, 0.45, 0.5)
		buttons[index].tooltip_text = "%s\nClick or press hotkey to %s.\nHover + press a new key to rebind (this session).\nMovement, dash, forms and menu keys are reserved." % [ability.capitalize() if not ability.is_empty() else "Empty slot", "stop" if active else "activate"]

func is_pointer_over_bar() -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())

func hovered_slot() -> int:
	if not is_visible_in_tree():
		return -1
	for index: int in range(buttons.size()):
		if buttons[index].get_global_rect().has_point(get_global_mouse_position()):
			return index
	return -1

func rebind_slot(index: int, key: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or key <= 0 or key in RESERVED_KEYS:
		return false
	var previous_key: int = bindings[index]
	var existing: int = bindings.find(key)
	if existing >= 0 and existing != index:
		bindings[existing] = previous_key
	bindings[index] = key
	_refresh()
	return true

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not is_visible_in_tree() or not is_instance_valid(player_ref) or not player_ref.time_ability_input_allowed():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed or key_event.shift_pressed:
		return
	var key: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	var hovered: int = hovered_slot()
	if hovered >= 0 and key != bindings[hovered]:
		if rebind_slot(hovered, key):
			get_viewport().set_input_as_handled()
		return
	var index: int = bindings.find(key)
	if index >= 0:
		activate_slot(index)
		get_viewport().set_input_as_handled()

func activate_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or abilities[index].is_empty() or not is_instance_valid(player_ref):
		return
	player_ref.use_time_ability(abilities[index])
	_refresh()

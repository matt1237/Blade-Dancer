class_name BossDialogueBox extends PanelContainer
## Shining Force 2-style dialogue box: a rectangular panel with typewriter text,
## a retro letter blip, and page-advance input. Lives in a CanvasLayer and runs
## with PROCESS_MODE_ALWAYS so it works while the game is paused.

signal finished

## Characters revealed per second (~30 gives a comfortable reading pace).
const CHAR_PER_SEC: float = 30.0
## How often the retro blip plays while letters appear.
const BLIP_INTERVAL: float = 0.06

var _label: Label
var _portrait: TextureRect
var _content: HBoxContainer
var _blip: AudioStreamPlayer
var _pages: Array[String] = []
var _page_index: int = 0
var _char_count: int = 0
var _accum: float = 0.0
var _blip_timer: float = 0.0
var _typing: bool = false
## Negative keeps the original click-to-close behavior. Tutorial dialogue sets
## this to five seconds so the completed final page remains readable, then fades.
var auto_close_delay: float = -1.0
var _auto_close_left: float = -1.0
var _box_height: float = 120.0
var _avoid_control: Control = null

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 80.0
	offset_right = -80.0
	offset_top = -175.0
	offset_bottom = -55.0
	visible = false

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.1, 0.96)
	panel_style.border_color = Color("ffe8b0")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", panel_style)

	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(112.0, 112.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	_content.add_child(_portrait)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color("f5ead0"))
	_content.add_child(_label)

	_blip = AudioStreamPlayer.new()
	_blip.bus = &"SFX"
	_blip.stream = _make_blip()
	_blip.volume_db = -12.0
	add_child(_blip)

func set_portrait(texture: Texture2D) -> void:
	if _portrait == null:
		return
	_portrait.texture = texture
	_portrait.visible = texture != null

func set_box_height(height: float) -> void:
	_box_height = height
	offset_top = -height - 55.0

func avoid_control(control: Control) -> void:
	_avoid_control = control
	_layout_away_from_control()

func clear_avoid_control() -> void:
	_avoid_control = null
	_layout_at_safe_bottom()

func _layout_at_safe_bottom() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var horizontal_margin: float = clampf(viewport_size.x * 0.055, 32.0, 80.0)
	var selected_y: float = maxf(24.0, viewport_size.y - _box_height - 55.0)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = horizontal_margin
	offset_right = viewport_size.x - horizontal_margin
	offset_top = selected_y
	offset_bottom = minf(viewport_size.y - 20.0, selected_y + _box_height)

func _layout_away_from_control() -> void:
	if _avoid_control == null or not is_instance_valid(_avoid_control) or not _avoid_control.is_visible_in_tree():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_rect: Rect2 = _avoid_control.get_global_rect().grow(14.0)
	var candidate_y: Array[float] = [viewport_size.y - _box_height - 55.0, 70.0, (viewport_size.y - _box_height) * 0.5]
	var selected_y: float = candidate_y[candidate_y.size() - 1]
	for y_position: float in candidate_y:
		var candidate_rect: Rect2 = Rect2(Vector2(46.0, y_position), Vector2(viewport_size.x - 92.0, _box_height))
		if not candidate_rect.intersects(target_rect):
			selected_y = y_position
			break
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 46.0
	offset_right = viewport_size.x - 46.0
	offset_top = selected_y
	offset_bottom = selected_y + _box_height

func start(new_pages: Array[String]) -> void:
	if _avoid_control == null: _layout_at_safe_bottom()
	_pages = new_pages
	_page_index = 0
	visible = true
	_auto_close_left = -1.0
	_show_page()

func _show_page() -> void:
	_label.text = _pages[_page_index]
	_label.visible_characters = 0
	_char_count = 0
	_accum = 0.0
	_blip_timer = 0.0
	_typing = true

func _process(delta: float) -> void:
	_layout_away_from_control()
	if not visible:
		return
	if not _typing:
		if _auto_close_left >= 0.0:
			_auto_close_left -= delta
			if _auto_close_left <= 0.0:
				_close()
		return
	_accum += delta
	_blip_timer -= delta
	var target: int = int(_accum * CHAR_PER_SEC)
	while _char_count < target and _char_count < _label.text.length():
		if _blip_timer <= 0.0:
			_blip.play()
			_blip_timer = BLIP_INTERVAL
		_char_count += 1
	_label.visible_characters = _char_count
	if _char_count >= _label.text.length():
		_typing = false
		if _page_index == _pages.size() - 1 and auto_close_delay >= 0.0:
			_auto_close_left = auto_close_delay

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _typing: return
	var advance: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event is InputEventKey and event.pressed:
		advance = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E
	elif event.is_action_pressed("ui_accept"):
		advance = true
	if not advance: return
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_show_page()
	elif auto_close_delay < 0.0:
		_close()

func _close() -> void:
	if not visible:
		return
	visible = false
	_auto_close_left = -1.0
	finished.emit()

func _make_blip() -> AudioStreamWAV:
	# A tiny retro "worble" — a short decaying square-ish blip.
	var rate: int = 22050
	var length_samples: int = int(0.045 * rate)
	var data: PackedByteArray = PackedByteArray()
	data.resize(length_samples * 2)
	for index: int in range(length_samples):
		var time_value: float = float(index) / rate
		var wobble: float = 0.5 + 0.5 * sin(TAU * 60.0 * time_value)
		var envelope: float = 1.0 - time_value / 0.045
		var sample: float = (0.28 * sin(TAU * 720.0 * time_value) + 0.16 * sin(TAU * 1080.0 * time_value)) * envelope * wobble
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wave: AudioStreamWAV = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.stereo = false
	wave.data = data
	return wave

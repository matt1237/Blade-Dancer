extends CanvasLayer
## PX TUNING TOOLS — the in-game overlay, built like Blade Dancer's own Training
## Tools: ONE bar across the top of the screen. Click it to drop the panel of tabs
## open, click it again to hide it.
##
## Two tabs:
##   Combat Tuning — the sword motor's feel constants (live), and the metronome.
##   Enemies       — spawn toggles. The arena starts EMPTY; nothing spawns
##                   until a toggle is switched ON.
##
## This node OWNS the live tunables; the game reads stiffness/damping/max_torque/
## arc/frequency from it each frame, and hears intent through its signals, so this
## overlay never reaches into the game.

signal chaser_toggled(on: bool)
signal sword_enemy_toggled(on: bool)
signal test_dummy_toggled(on: bool)
signal metronome_toggled(on: bool)

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## Assembly geometry. The bar is deliberately narrower than the viewport: the
## status HUD owns the top-left corner out to roughly x=350, and a wider bar
## would sit on top of it.
const BAR_HEIGHT: float = 40.0
const BAR_GAP: float = 8.0
const BAR_WIDTH: float = 560.0
const TOP_MARGIN: float = 8.0

var stiffness: float = Cfg.DEFAULT_MOTOR_STIFFNESS
var damping: float = Cfg.DEFAULT_MOTOR_DAMPING
var max_torque: float = Cfg.DEFAULT_MAX_TORQUE

## Metronome. ON: the motor chases Blade Dancer's Form III arc — a sine sweep
## of +/- arc_degrees about the aim — instead of the aim itself. OFF is the free
## baseline. The two are meant to be flipped between live: the whole point is
## watching the arc come apart when the motor meets something it cannot move.
var metronome_on: bool = false
var arc_degrees: float = Cfg.METRONOME_ARC_DEGREES
var frequency: float = Cfg.METRONOME_FREQUENCY

## The hand: how far from the body the grip orbits along the aim. The cursor's
## distance picks a point between the two, so min is the hug and max is full
## extension. Same pair the game's own hand settings carry.
var hand_min: float = Cfg.DEFAULT_HAND_MIN
var hand_max: float = Cfg.DEFAULT_HAND_MAX

## The bar and the panel it opens. Held as members so the open/close state is
## inspectable (and drivable) without miming a mouse click.
var bar: Button = null
var panel: PanelContainer = null

var _sliders: Dictionary = {}
var _metronome_button: Button = null


func _init() -> void:
	bar = Button.new()
	bar.name = "TuningToolsBar"
	bar.text = "PX TUNING TOOLS"
	bar.focus_mode = Control.FOCUS_NONE
	bar.pressed.connect(_toggle_panel)
	add_child(bar)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	add_child(panel)

	var tabs := TabContainer.new()
	tabs.name = "TuningTabs"
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.tab_focus_mode = Control.FOCUS_NONE
	panel.add_child(tabs)
	# A shorter tab must not leave the panel at the taller one's height.
	tabs.tab_changed.connect(func(_index: int) -> void: _apply_layout())

	var combat := VBoxContainer.new()
	combat.name = "Combat Tuning"
	# Tighter than Godot's default: seven tunables have to fit on one tab.
	combat.add_theme_constant_override("separation", 8)
	tabs.add_child(combat)
	_add_slider(combat, "stiffness", "Motor Stiffness", 0.0, 300000.0, 1000.0, stiffness,
		func(v: float) -> void: stiffness = v)
	_add_slider(combat, "damping", "Motor Damping", 0.0, 40000.0, 100.0, damping,
		func(v: float) -> void: damping = v)
	_add_slider(combat, "torque", "Max Torque", 0.0, 600000.0, 1000.0, max_torque,
		func(v: float) -> void: max_torque = v)
	_metronome_button = Button.new()
	_metronome_button.text = "Metronome Swing"
	_metronome_button.tooltip_text = "ON: the motor chases Blade Dancer's Form III arc — a sine sweep of +/- Arc about your aim — instead of the aim itself.\nOFF: the blade simply points where you point."
	_metronome_button.toggle_mode = true
	_metronome_button.toggled.connect(_on_metronome_toggled)
	combat.add_child(_metronome_button)
	_add_slider(combat, "arc", "Arc (degrees)", 0.0, 180.0, 1.0, arc_degrees,
		func(v: float) -> void: arc_degrees = v)
	_add_slider(combat, "frequency", "Swing Frequency (Hz)", 0.05, 3.0, 0.05, frequency,
		func(v: float) -> void: frequency = v)
	_add_slider(combat, "hand_min", "Hand Min (px)", 0.0, 300.0, 1.0, hand_min,
		func(v: float) -> void: hand_min = v)
	_add_slider(combat, "hand_max", "Hand Max (px)", 0.0, 300.0, 1.0, hand_max,
		func(v: float) -> void: hand_max = v)
	var reset_button := Button.new()
	reset_button.text = "Reset to defaults"
	reset_button.pressed.connect(_reset_to_defaults)
	combat.add_child(reset_button)

	var enemy_tab := VBoxContainer.new()
	enemy_tab.name = "Enemies"
	enemy_tab.add_theme_constant_override("separation", 12)
	tabs.add_child(enemy_tab)
	var chaser_button := Button.new()
	chaser_button.text = "Spawn Chaser"
	chaser_button.toggle_mode = true
	chaser_button.toggled.connect(func(on: bool) -> void: chaser_toggled.emit(on))
	enemy_tab.add_child(chaser_button)
	var sword_button := Button.new()
	sword_button.text = "Spawn Sword Enemy"
	sword_button.toggle_mode = true
	sword_button.toggled.connect(func(on: bool) -> void: sword_enemy_toggled.emit(on))
	enemy_tab.add_child(sword_button)
	var dummy_button := Button.new()
	dummy_button.text = "Spawn Test Dummy"
	dummy_button.toggle_mode = true
	dummy_button.toggled.connect(func(on: bool) -> void: test_dummy_toggled.emit(on))
	enemy_tab.add_child(dummy_button)
	var note := Label.new()
	note.text = "ON keeps exactly one alive;\ntoggle off removes it."
	note.add_theme_font_size_override("font_size", 13)
	enemy_tab.add_child(note)


func _ready() -> void:
	_apply_layout()
	if not get_viewport().size_changed.is_connected(_apply_layout):
		get_viewport().size_changed.connect(_apply_layout)


## The bar sits at the top of the screen and the panel drops out directly beneath
## it, the two sharing one width. Same shape as Training Tools, but anchored to
## the top rather than centred vertically.
func _apply_layout() -> void:
	if bar == null or panel == null or not is_inside_tree():
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var width: float = minf(BAR_WIDTH, maxf(320.0, viewport_size.x - TOP_MARGIN * 2.0))
	var left: float = (viewport_size.x - width) * 0.5
	bar.position = Vector2(left, TOP_MARGIN)
	bar.size = Vector2(width, BAR_HEIGHT)
	panel.position = Vector2(left, TOP_MARGIN + BAR_HEIGHT + BAR_GAP)
	# Height is left to the panel's own content, so adding a tunable cannot clip.
	panel.size = Vector2(width, 0.0)


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_apply_layout()


func _add_slider(parent: Control, key: String, label_text: String, min_v: float, max_v: float, step: float, value: float, setter: Callable) -> void:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = label_text
	box.add_child(title)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(272.0, 18.0)
	box.add_child(slider)
	var readout := Label.new()
	readout.text = _format_number(value)
	box.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = _format_number(v)
		setter.call(v)
	)
	_sliders[key] = slider
	parent.add_child(box)


func _format_number(v: float) -> String:
	if absf(v) >= 100.0:
		return "%.0f" % v
	return "%.2f" % v


func _on_metronome_toggled(on: bool) -> void:
	metronome_on = on
	metronome_toggled.emit(on)


func _reset_to_defaults() -> void:
	(_sliders["stiffness"] as HSlider).value = Cfg.DEFAULT_MOTOR_STIFFNESS
	(_sliders["damping"] as HSlider).value = Cfg.DEFAULT_MOTOR_DAMPING
	(_sliders["torque"] as HSlider).value = Cfg.DEFAULT_MAX_TORQUE
	(_sliders["arc"] as HSlider).value = Cfg.METRONOME_ARC_DEGREES
	(_sliders["frequency"] as HSlider).value = Cfg.METRONOME_FREQUENCY
	(_sliders["hand_min"] as HSlider).value = Cfg.DEFAULT_HAND_MIN
	(_sliders["hand_max"] as HSlider).value = Cfg.DEFAULT_HAND_MAX
	# Back to the launch state: the free baseline, not the driven arc. Setting
	# the button re-fires toggled(false), so the game hears about it too.
	_metronome_button.button_pressed = false
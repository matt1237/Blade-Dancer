extends CanvasLayer
## PX TUNING TOOLS — the in-game overlay, built like Blade Dancer's own Training
## Tools: ONE bar across the top of the screen. Click it to drop the panel of tabs
## open, click it again to hide it.
##
## Four tabs:
##   Combat Tuning  — the sword motor's feel constants (live), the metronome and
##                    its wind-up.
##   Sword & Reach  — the aim feel (Aim Inertia) and the hand's min/max reach.
##   Enemies        — spawn toggles. The arena starts EMPTY; nothing spawns
##                    until a toggle is switched ON.
##   Global         — save/load the whole setup to BDPX's own user:// file.
##
## This node OWNS the live tunables; the game reads stiffness/damping/max_torque/
## arc/frequency from it each frame, and hears intent through its signals, so this
## overlay never reaches into the game.

signal chaser_toggled(on: bool)
signal sword_enemy_toggled(on: bool)
signal test_dummy_toggled(on: bool)
signal metronome_toggled(on: bool)
signal aim_inertia_toggled(on: bool)
signal windup_toggled(on: bool)
signal servo_feedforward_toggled(on: bool)
signal hilt_spring_toggled(on: bool)
signal show_ghost_toggled(on: bool)
signal save_settings_requested()
signal load_settings_requested()

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

## Two settings keys (full, persisted names) differ from their slider keys
## (terse, internal). Everything else matches by name.
const SLIDER_ALIASES: Dictionary = {
	"max_torque": "torque",
	"arc_degrees": "arc",
}

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

## Metronome. ON: the motor chases Blade Dancer's metronome arc — a sine sweep
## of +/- arc_degrees about the aim — instead of the aim itself. OFF is the free
## baseline. The two are meant to be flipped between live: the whole point is
## watching the arc come apart when the motor meets something it cannot move.
var metronome_on: bool = false
var arc_degrees: float = Cfg.METRONOME_ARC_DEGREES
var frequency: float = Cfg.METRONOME_FREQUENCY
## Anti-windup leash: how far the sweep may lead the blade (degrees).
var lead_degrees: float = Cfg.METRONOME_MAX_LEAD_DEGREES
## Metronome wind-up (Form II). OFF is the plain sine; ON redistributes the
## stroke's speed (slow open, fast strike, slow recovery) at `windup_profile`.
var windup_on: bool = Cfg.WINDUP_ENABLED
var windup_profile: float = Cfg.DEFAULT_WINDUP_PROFILE
## Aim feel ("Core Sword & Reach"). OFF: the aim snaps to the cursor. ON: the
## commanded aim gains weight (aim point drag + aim angle drag + a turn cap).
var aim_inertia_on: bool = Cfg.AIM_INERTIA_ENABLED
var mouse_drag: float = Cfg.DEFAULT_MOUSE_DRAG
var rotation_speed: float = Cfg.DEFAULT_ROTATION_SPEED
var max_turn_speed_deg: float = Cfg.DEFAULT_MAX_TURN_SPEED_DEG
## Reference-following servo: adds the reference's angular velocity to the torque
## so the blade holds the intended arc instead of lagging it. OFF = plain PD motor.
var servo_feedforward_on: bool = Cfg.SERVO_FEEDFORWARD_ENABLED
## Hilt spring: the grip is held to the hand by a springy pin, so a contact can
## shove it off and it recovers. OFF = a rigid weld to the hand.
var hilt_spring_on: bool = Cfg.HILT_SPRING_ENABLED
## Debug ghost: draw the ORIGINAL target motion (the real sword art) beside the
## physical blade.
var show_ghost: bool = Cfg.SHOW_GHOST_ENABLED
## Ghost opacity, in percent — how far the translucent "shadow twin" is dimmed.
var ghost_opacity: float = Cfg.GHOST_OPACITY_PERCENT

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
## Each tab's inner VBox, kept so _apply_layout can size the panel to the tallest
## tab (and cap it to the screen so the tabs scroll instead of clipping).
var _tab_contents: Array[Control] = []
var _metronome_button: Button = null
## Spawn toggles, keyed by their BDPX-global setting names, so apply_values()
## can drive them and load a saved setup back into the panel.
var _spawn_buttons: Dictionary = {}
## Boolean feature toggles (metronome, aim inertia, wind-up), keyed by their
## BDPX-global setting names, for the same round-trip reason.
var _toggle_buttons: Dictionary = {}
## The "last saved" readout on the Global tab (this overlay is built in code, so
## it is a plain member, not an @onready path).
var _saved_label: Label = null


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
	combat.name = "CombatContent"
	# Tighter than Godot's default: seven tunables have to fit on one tab.
	combat.add_theme_constant_override("separation", 8)
	_add_tab(tabs, "Combat Tuning", combat)
	_add_slider(combat, "stiffness", "Motor Stiffness", 0.0, 300000.0, 1000.0, stiffness,
		func(v: float) -> void: stiffness = v)
	_add_slider(combat, "damping", "Motor Damping", 0.0, 40000.0, 100.0, damping,
		func(v: float) -> void: damping = v)
	_add_slider(combat, "torque", "Max Torque", 0.0, 600000.0, 1000.0, max_torque,
		func(v: float) -> void: max_torque = v)
	var servo_button := Button.new()
	servo_button.text = "Servo Feedforward"
	servo_button.tooltip_text = "ON: the motor also matches how fast the target is turning, not just its angle, so the blade holds the intended arc instead of lagging it. OFF: the plain PD motor.\nA kill switch — if the feel is wrong, switch it off and we delete the code."
	servo_button.toggle_mode = true
	servo_button.button_pressed = servo_feedforward_on
	servo_button.toggled.connect(func(on: bool) -> void: servo_feedforward_toggled.emit(on))
	combat.add_child(servo_button)
	_toggle_buttons["servo_feedforward_on"] = servo_button
	_metronome_button = Button.new()
	_metronome_button.text = "Metronome Swing"
	_metronome_button.tooltip_text = "ON: the motor chases Blade Dancer's metronome arc — a sine sweep of +/- Arc about your aim — instead of the aim itself.\nOFF: the blade simply points where you point."
	_metronome_button.toggle_mode = true
	_metronome_button.toggled.connect(_on_metronome_toggled)
	combat.add_child(_metronome_button)
	_toggle_buttons["metronome_on"] = _metronome_button
	_add_slider(combat, "arc", "Arc (degrees)", 0.0, 180.0, 1.0, arc_degrees,
		func(v: float) -> void: arc_degrees = v)
	_add_slider(combat, "frequency", "Swing Frequency (Hz)", 0.05, 3.0, 0.05, frequency,
		func(v: float) -> void: frequency = v)
	_add_slider(combat, "lead_degrees", "Metronome Lead (deg)", 0.0, 180.0, 1.0, lead_degrees,
		func(v: float) -> void: lead_degrees = v)
	var windup_button := Button.new()
	windup_button.text = "Metronome Wind-up"
	windup_button.tooltip_text = "ON: the stroke opens slowly, strikes fast, then recovers slowly (Blade Dancer's Form II). OFF: a plain sine at constant speed.\nA kill switch — if the feel is wrong, switch it off and we delete the code."
	windup_button.toggle_mode = true
	windup_button.button_pressed = windup_on
	windup_button.toggled.connect(func(on: bool) -> void: windup_toggled.emit(on))
	combat.add_child(windup_button)
	_toggle_buttons["windup_on"] = windup_button
	_add_slider(combat, "windup_profile", "Wind-up Profile", 0.0, 1.0, 0.05, windup_profile,
		func(v: float) -> void: windup_profile = v)
	var reset_button := Button.new()
	reset_button.text = "Reset to defaults"
	reset_button.pressed.connect(_reset_to_defaults)
	combat.add_child(reset_button)

	var reach := VBoxContainer.new()
	reach.name = "ReachContent"
	reach.add_theme_constant_override("separation", 8)
	_add_tab(tabs, "Sword & Reach", reach)
	var aim_inertia_button := Button.new()
	aim_inertia_button.text = "Aim Inertia"
	aim_inertia_button.tooltip_text = "ON: the commanded aim gains weight — the aim point trails your cursor and the blade's aim angle trails that (Core Sword & Reach). OFF: the aim snaps straight to the cursor.\nA kill switch — if it feels wrong, switch it off and we delete the code."
	aim_inertia_button.toggle_mode = true
	aim_inertia_button.button_pressed = aim_inertia_on
	aim_inertia_button.toggled.connect(func(on: bool) -> void: aim_inertia_toggled.emit(on))
	reach.add_child(aim_inertia_button)
	_toggle_buttons["aim_inertia_on"] = aim_inertia_button
	_add_slider(reach, "mouse_drag", "Mouse Drag (Aim Inertia)", 3.0, 35.0, 0.5, mouse_drag,
		func(v: float) -> void: mouse_drag = v)
	_add_slider(reach, "rotation_speed", "Rotation Speed (Aim Turn)", 2.0, 40.0, 0.5, rotation_speed,
		func(v: float) -> void: rotation_speed = v)
	_add_slider(reach, "max_turn_speed_deg", "Max Turn Speed (0 = off)", 0.0, 1800.0, 90.0, max_turn_speed_deg,
		func(v: float) -> void: max_turn_speed_deg = v)
	_add_slider(reach, "hand_min", "Hand Min (px)", 0.0, 300.0, 1.0, hand_min,
		func(v: float) -> void: hand_min = v)
	_add_slider(reach, "hand_max", "Hand Max (px)", 0.0, 300.0, 1.0, hand_max,
		func(v: float) -> void: hand_max = v)
	var hilt_button := Button.new()
	hilt_button.text = "Hilt Spring"
	hilt_button.tooltip_text = "ON: the grip is held to the hand by a spring, so a contact can shove the sword off your hand and it springs back. OFF: the grip is welded to the hand.\nA kill switch — if you don't want it, switch it off (and we can delete the code)."
	hilt_button.toggle_mode = true
	hilt_button.button_pressed = hilt_spring_on
	hilt_button.toggled.connect(func(on: bool) -> void: hilt_spring_toggled.emit(on))
	reach.add_child(hilt_button)
	_toggle_buttons["hilt_spring_on"] = hilt_button
	var ghost_button := Button.new()
	ghost_button.text = "Show Ghost (debug)"
	ghost_button.tooltip_text = "ON: draw the REAL sword art — where the hand and blade SHOULD be — as a translucent ghost UNDER the physical blade. Same art, same scale: tune the two until the ghost disappears behind the blade (a perfect match). Any lag shows as a translucent offset, and the readout gives the numbers."
	ghost_button.toggle_mode = true
	ghost_button.button_pressed = show_ghost
	ghost_button.toggled.connect(func(on: bool) -> void: show_ghost_toggled.emit(on))
	reach.add_child(ghost_button)
	_toggle_buttons["show_ghost"] = ghost_button
	_add_slider(reach, "ghost_opacity", "Ghost Opacity (%)", 0.0, 100.0, 5.0, ghost_opacity,
		func(v: float) -> void: ghost_opacity = v)

	var enemy_tab := VBoxContainer.new()
	enemy_tab.name = "EnemyContent"
	enemy_tab.add_theme_constant_override("separation", 12)
	_add_tab(tabs, "Enemies", enemy_tab)
	var chaser_button := Button.new()
	chaser_button.text = "Spawn Chaser"
	chaser_button.toggle_mode = true
	chaser_button.toggled.connect(func(on: bool) -> void: chaser_toggled.emit(on))
	enemy_tab.add_child(chaser_button)
	_spawn_buttons["chaser_wanted"] = chaser_button
	var sword_button := Button.new()
	sword_button.text = "Spawn Sword Enemy"
	sword_button.toggle_mode = true
	sword_button.toggled.connect(func(on: bool) -> void: sword_enemy_toggled.emit(on))
	enemy_tab.add_child(sword_button)
	_spawn_buttons["sword_enemy_wanted"] = sword_button
	var dummy_button := Button.new()
	dummy_button.text = "Spawn Test Dummy"
	dummy_button.toggle_mode = true
	dummy_button.toggled.connect(func(on: bool) -> void: test_dummy_toggled.emit(on))
	enemy_tab.add_child(dummy_button)
	_spawn_buttons["test_dummy_wanted"] = dummy_button
	var note := Label.new()
	note.text = "ON keeps exactly one alive;\ntoggle off removes it."
	note.add_theme_font_size_override("font_size", 13)
	enemy_tab.add_child(note)

	var global_tab := VBoxContainer.new()
	global_tab.name = "GlobalContent"
	global_tab.add_theme_constant_override("separation", 12)
	_add_tab(tabs, "Global", global_tab)
	var save_button := Button.new()
	save_button.text = "Save Settings"
	save_button.tooltip_text = "Write the current tuning + spawn setup to user://bdpx_global.json.\nThis file is BDPX's own — the game's live save is never touched."
	save_button.pressed.connect(func() -> void: save_settings_requested.emit())
	global_tab.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "Load Settings"
	load_button.tooltip_text = "Re-apply the saved setup."
	load_button.pressed.connect(func() -> void: load_settings_requested.emit())
	global_tab.add_child(load_button)
	_saved_label = Label.new()
	_saved_label.add_theme_font_size_override("font_size", 13)
	_saved_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	global_tab.add_child(_saved_label)


func _ready() -> void:
	_apply_layout()
	if not get_viewport().size_changed.is_connected(_apply_layout):
		get_viewport().size_changed.connect(_apply_layout)
	show_saved_state()


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
	# Size the panel to the tallest tab, but never past the bottom of the screen:
	# each tab is a ScrollContainer, so anything that doesn't fit scrolls instead
	# of being clipped off the viewport (the old "stuff I can't get to" bug).
	var available: float = maxf(160.0, viewport_size.y - panel.position.y - TOP_MARGIN)
	var content_height: float = 0.0
	for content: Control in _tab_contents:
		content_height = maxf(content_height, content.get_combined_minimum_size().y)
	# +48 covers the tab strip and the panel's own margins.
	panel.size = Vector2(width, clampf(content_height + 48.0, 160.0, available))


## One tab = a ScrollContainer (its name is the tab title) wrapping the tab's VBox.
## ScrollContainers report a near-zero minimum height, which is what lets the
## panel be capped to the screen and the content scroll, rather than the panel
## growing off the bottom of the viewport.
func _add_tab(tabs: TabContainer, title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	tabs.add_child(scroll)
	_tab_contents.append(content)


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
	(_sliders["lead_degrees"] as HSlider).value = Cfg.METRONOME_MAX_LEAD_DEGREES
	(_sliders["windup_profile"] as HSlider).value = Cfg.DEFAULT_WINDUP_PROFILE
	(_sliders["mouse_drag"] as HSlider).value = Cfg.DEFAULT_MOUSE_DRAG
	(_sliders["rotation_speed"] as HSlider).value = Cfg.DEFAULT_ROTATION_SPEED
	(_sliders["max_turn_speed_deg"] as HSlider).value = Cfg.DEFAULT_MAX_TURN_SPEED_DEG
	(_sliders["hand_min"] as HSlider).value = Cfg.DEFAULT_HAND_MIN
	(_sliders["hand_max"] as HSlider).value = Cfg.DEFAULT_HAND_MAX
	# Back to the launch state: the free baseline, not the driven arc. Setting
	# a toggle re-fires toggled(), so the game hears about it too.
	_metronome_button.button_pressed = false
	(_toggle_buttons["windup_on"] as Button).button_pressed = Cfg.WINDUP_ENABLED
	(_toggle_buttons["aim_inertia_on"] as Button).button_pressed = Cfg.AIM_INERTIA_ENABLED
	(_toggle_buttons["servo_feedforward_on"] as Button).button_pressed = Cfg.SERVO_FEEDFORWARD_ENABLED
	(_toggle_buttons["hilt_spring_on"] as Button).button_pressed = Cfg.HILT_SPRING_ENABLED
	(_toggle_buttons["show_ghost"] as Button).button_pressed = Cfg.SHOW_GHOST_ENABLED
	(_sliders["ghost_opacity"] as HSlider).value = Cfg.GHOST_OPACITY_PERCENT


## Push a full settings dictionary into the live controls. Setting a slider fires
## value_changed (so the backing tunables update) and a spawn toggle fires its
## toggled signal (so the game spawns or removes). This is how a loaded BDPX save
## reaches every control without the game poking at the panel directly.
func apply_values(values: Dictionary) -> void:
	for setting_key: String in values.keys():
		var slider_key: String = SLIDER_ALIASES.get(setting_key, setting_key)
		if _sliders.has(slider_key):
			(_sliders[slider_key] as HSlider).value = float(values[setting_key])
	for key: String in _toggle_buttons.keys():
		if values.has(key):
			(_toggle_buttons[key] as Button).button_pressed = bool(values[key])
	for key: String in _spawn_buttons.keys():
		if values.has(key):
			(_spawn_buttons[key] as Button).button_pressed = bool(values[key])


## Refresh the "last saved" readout on the Global tab.
func show_saved_state() -> void:
	if _saved_label == null:
		return
	if BDPXGlobal.has_save():
		_saved_label.text = "Last saved: %s" % BDPXGlobal.saved_at()
	else:
		_saved_label.text = "No BDPX save yet."
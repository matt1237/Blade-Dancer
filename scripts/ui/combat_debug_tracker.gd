class_name CombatDebugTracker extends PanelContainer

const MAX_EVENTS = 12
const EVENT_COLORS: Dictionary = {
	"SLIDE": "75dcff", "BIND CANDIDATE": "75dcff", "STABLE BIND": "ffd166",
	"WIND": "c59cff", "WEAPON BEAT": "8cff9b", "BEAT REJECTED": "ffad66",
	"GUARD WRAP": "c59cff", "ROLLOVER DISENGAGE": "c59cff",
	"GUARD-WRAP RE-ENTRY": "8cff9b", "ROLLOVER RE-ENTRY": "8cff9b",
	"BIND RELEASE": "ff7d7d", "CLASH": "ffad66", "PARRY": "75dcff"
}

var player_ref: Player = null
var event_history: Array[Dictionary] = []
var event_counts: Dictionary = {}
var elapsed: float = 0.0
var paused: bool = false
var compact: bool = true
var header_label: Label = null
var live_label: Label = null
var history_label: RichTextLabel = null
var summary_label: Label = null
var body: VBoxContainer = null
var minimize_button: Button = null
var pause_button: Button = null

func _ready() -> void:
	name = "CombatDebugTracker"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -446.0
	offset_right = -16.0
	offset_top = 104.0
	custom_minimum_size = Vector2(430.0, 0.0)
	_build_ui()

func setup(player: Player) -> void:
	player_ref = player
	if not player_ref.combat_debug_event.is_connected(_on_combat_debug_event):
		player_ref.combat_debug_event.connect(_on_combat_debug_event)

func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	add_child(root)
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	header_label = Label.new()
	header_label.text = "COMBAT TRACKER · Waiting"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.add_theme_color_override("font_color", Color("#ffd166"))
	header.add_child(header_label)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.tooltip_text = "Pause event capture while leaving the live values visible."
	pause_button.pressed.connect(_toggle_paused)
	header.add_child(pause_button)
	var clear_button: Button = Button.new()
	clear_button.text = "CLEAR"
	clear_button.pressed.connect(clear_events)
	header.add_child(clear_button)
	minimize_button = Button.new()
	minimize_button.text = "EXPAND"
	minimize_button.tooltip_text = "Expand or minimize the combat tracker."
	minimize_button.pressed.connect(_toggle_compact)
	header.add_child(minimize_button)
	body = VBoxContainer.new()
	body.visible = false
	root.add_child(body)
	live_label = Label.new()
	live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_label.add_theme_color_override("font_color", Color("#dbe8ef"))
	body.add_child(live_label)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", Color("#a9bcc7"))
	body.add_child(summary_label)
	history_label = RichTextLabel.new()
	history_label.bbcode_enabled = true
	history_label.fit_content = true
	history_label.scroll_active = false
	history_label.custom_minimum_size = Vector2(410.0, 150.0)
	body.add_child(history_label)

func _process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(player_ref):
		visible = false
		return
	visible = player_ref.visible and player_ref.debug_show_sword_events
	if not visible:
		return
	_update_live_readout()

func _update_live_readout() -> void:
	var state: String = "FREE"
	if player_ref.experimental_reentry_time_left > 0.0:
		state = "RE-ENTRY %.2fs" % player_ref.experimental_reentry_time_left
	elif player_ref.experimental_bind_active:
		state = "BOUND"
	elif player_ref.experimental_bind_candidate:
		state = "CAPTURING"
	var leverage_quality: String = "GOOD" if player_ref.experimental_bind_leverage >= player_ref.get_combat_hand_setting("bind_beat_leverage") else "POOR"
	header_label.text = "%s · %s · P %.0f · L %s" % [_short_form_name(), state, player_ref.experimental_bind_pressure, leverage_quality]
	if compact:
		return
	var required_pressure: float = player_ref.get_combat_hand_setting("bind_beat_pressure")
	var required_spike: float = player_ref.get_combat_hand_setting("bind_beat_spike")
	var pressure_spike: float = player_ref.experimental_bind_player_pressure - player_ref.experimental_bind_previous_player_pressure
	live_label.text = "STATE %s | Contact %.2fs | Capture %.2fs\nPressure %.0f | Authored %.0f / %.0f | Spike %.0f / %.0f\nTangent %.0f | Travel %.0f | Leverage %.2f (%s) | Enemy contact %.0f%%" % [state, player_ref.experimental_bind_total_contact_time, player_ref.experimental_bind_stable_time, player_ref.experimental_bind_pressure, player_ref.experimental_bind_player_pressure, required_pressure, pressure_spike, required_spike, player_ref.experimental_bind_tangent_speed, player_ref.experimental_bind_tangent_travel, player_ref.experimental_bind_leverage, leverage_quality, player_ref.experimental_bind_enemy_fraction * 100.0]

func _short_form_name() -> String:
	match player_ref.sword_style:
		Player.SwordStyle.METRONOME_BIND: return "BIND A"
		Player.SwordStyle.METRONOME_BIND_B: return "BIND B"
		_: return "SWORD"

func _on_combat_debug_event(event_type: String, details: Dictionary) -> void:
	if paused:
		return
	var entry: Dictionary = {"time": elapsed, "type": event_type, "details": details.duplicate(true)}
	event_history.push_front(entry)
	if event_history.size() > MAX_EVENTS:
		event_history.resize(MAX_EVENTS)
	event_counts[event_type] = int(event_counts.get(event_type, 0)) + 1
	_update_history()

func _update_history() -> void:
	if history_label == null:
		return
	var lines: PackedStringArray = []
	for entry: Dictionary in event_history:
		var event_type: String = str(entry["type"])
		var details: Dictionary = entry["details"] as Dictionary
		var color: String = str(EVENT_COLORS.get(event_type, "dbe8ef"))
		lines.append("[color=#%s]%06.2f  %-18s[/color] %s" % [color, float(entry["time"]), event_type, format_event_details(event_type, details)])
	history_label.text = "\n".join(lines)
	var parts: PackedStringArray = []
	for key: String in ["SLIDE", "STABLE BIND", "WIND", "WEAPON BEAT", "BEAT REJECTED", "BIND RELEASE"]:
		if event_counts.has(key):
			parts.append("%s %d" % [key.capitalize(), int(event_counts[key])])
	summary_label.text = "SESSION · " + (" · ".join(parts) if not parts.is_empty() else "No events yet")

static func format_event_details(event_type: String, details: Dictionary) -> String:
	if event_type == "BIND RELEASE":
		return "%s · %.2fs · travel %.0f" % [str(details.get("reason", "unknown")), float(details.get("contact_time", 0.0)), float(details.get("tangent_travel", 0.0))]
	if event_type == "BEAT REJECTED" or event_type == "WEAPON BEAT":
		var leverage: float = float(details.get("leverage", 0.0))
		var required: float = float(details.get("required_leverage", 0.0))
		return "pressure %.0f · spike %.0f · leverage %.2f/%0.2f %s" % [float(details.get("player_pressure", 0.0)), float(details.get("pressure_spike", 0.0)), leverage, required, "PASS" if leverage >= required else "FAIL"]
	if event_type == "BIND CANDIDATE":
		return "need %.2fs · pressure ≥ %.0f" % [float(details.get("required_capture", 0.0)), float(details.get("required_pressure", 0.0))]
	if event_type in ["SLIDE", "STABLE BIND", "WIND", "GUARD WRAP", "ROLLOVER DISENGAGE", "GUARD-WRAP RE-ENTRY", "ROLLOVER RE-ENTRY"]:
		return "P %.0f · tangent %.0f · travel %.0f · leverage %.2f" % [float(details.get("pressure", 0.0)), float(details.get("tangent_speed", 0.0)), float(details.get("tangent_travel", 0.0)), float(details.get("leverage", 0.0))]
	return ""

func _toggle_compact() -> void:
	compact = not compact
	body.visible = not compact
	minimize_button.text = "EXPAND" if compact else "COLLAPSE"

func _toggle_paused() -> void:
	paused = not paused
	pause_button.text = "RESUME" if paused else "PAUSE"

func clear_events() -> void:
	event_history.clear()
	event_counts.clear()
	_update_history()

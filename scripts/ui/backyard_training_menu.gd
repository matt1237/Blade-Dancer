class_name BackyardTrainingMenu extends Control

var main: Node = null
var toggle_button: Button = null
var panel: PanelContainer = null
var training_tabs: TabContainer = null
var forest_visual_tuner: ForestVisualTuner = null
var bonus_rows: Dictionary = {}
var combat_status: Label = null
var event_monitor_label: Label = null
var main_preset_status: Label = null
var disk_feedback_label: Label = null
var snapshot_name_edit: LineEdit = null
var snapshot_list: VBoxContainer = null
var snapshot_feedback_label: Label = null
var auto_spawner_button: Button = null
var auto_spawner_status: Label = null
var training_dummy_button: Button = null
var test_turkey_button: Button = null

var hand_controls: Dictionary = {}
var contact_controls: Dictionary = {}
var blade_shape_controls: Dictionary = {}
## Single source of truth for equipped visual, blade shape, and hand tuning.
var selected_combat_sword_id: String = "Basic Longsword"
var combat_sword_option: OptionButton = null
var blade_shape_status: Label = null
var grapple_controls: Dictionary = {}
var visualizer_controls: Dictionary = {}
var global_preset_rows: Dictionary = {}
var grapple_status_label: Label = null
var experimental_bind_section: VBoxContainer = null
var experimental_bind_status: Label = null
var weapon_collision_zones_button: Button = null

var last_hand_key: String = ""
var last_contact_key: String = ""
var main_game_preset: int = 2

const DESIRED_MENU_SIZE: Vector2 = Vector2(900.0, 600.0)
const VIEWPORT_SIDE_MARGIN: float = 24.0
const VIEWPORT_VERTICAL_MARGIN: float = 24.0
const TOGGLE_HEIGHT: float = 40.0
const TOGGLE_GAP: float = 8.0

func _ready() -> void:
	name = "BackyardTrainingMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_apply_training_layout()
	if not get_viewport().size_changed.is_connected(_apply_training_layout):
		get_viewport().size_changed.connect(_apply_training_layout)
	visible = false

func _build_ui() -> void:
	toggle_button = Button.new()
	toggle_button.name = "TrainingTools"
	toggle_button.text = "TRAINING TOOLS"
	toggle_button.position = Vector2(0.0, -(TOGGLE_HEIGHT + TOGGLE_GAP))
	toggle_button.size = Vector2(DESIRED_MENU_SIZE.x, TOGGLE_HEIGHT)
	toggle_button.pressed.connect(_toggle_panel)
	# Latch on press, before release opens the panel, so clicking the tuner
	# cannot also throw a chakram into the preview.
	toggle_button.button_down.connect(func() -> void: _set_gameplay_input_locked(true))
	toggle_button.button_up.connect(func() -> void: _sync_training_input_lock.call_deferred())
	toggle_button.focus_mode = Control.FOCUS_NONE
	add_child(toggle_button)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	training_tabs = TabContainer.new()
	training_tabs.name = "TrainingTabs"
	training_tabs.focus_mode = Control.FOCUS_NONE
	training_tabs.tab_focus_mode = Control.FOCUS_NONE
	# Hidden combat controls must not force the forest side dock to their width.
	training_tabs.use_hidden_tabs_for_min_size = false
	training_tabs.clip_tabs = true
	training_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(training_tabs)

	_build_layout_tab(training_tabs)
	_build_enemy_tab(training_tabs)
	_build_spawn_items_tab(training_tabs)
	_build_bonus_tab(training_tabs)
	_build_combat_tab(training_tabs)
	_build_charged_guard_tab(training_tabs)
	_build_authored_metronome_tab(training_tabs)
	_build_windup_tab(training_tabs)
	_build_visualizer_tab(training_tabs)
	_build_global_presets_tab(training_tabs)
	_build_saves_tab(training_tabs)
	_build_forest_visuals_tab(training_tabs)
	training_tabs.tab_changed.connect(_on_training_tab_changed)

func _build_layout_tab(tabs: TabContainer) -> void:
	var layout_tab: VBoxContainer = VBoxContainer.new()
	layout_tab.name = "Layout"
	layout_tab.add_theme_constant_override("separation", 12)
	tabs.add_child(layout_tab)

	var title: Label = Label.new()
	title.text = "BACKYARD LAYOUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout_tab.add_child(title)

	var forest_button: Button = Button.new()
	forest_button.name = "ForestLayout"
	forest_button.text = "Forest"
	forest_button.custom_minimum_size = Vector2(0.0, 52.0)
	forest_button.focus_mode = Control.FOCUS_NONE
	forest_button.pressed.connect(_select_backyard_layout.bind("forest"))
	layout_tab.add_child(forest_button)

	var empty_button: Button = Button.new()
	empty_button.name = "EmptyLayout"
	empty_button.text = "Empty"
	empty_button.custom_minimum_size = Vector2(0.0, 52.0)
	empty_button.focus_mode = Control.FOCUS_NONE
	empty_button.pressed.connect(_select_backyard_layout.bind("empty"))
	layout_tab.add_child(empty_button)

	var hint: Label = Label.new()
	hint.text = "Forest uses the current generated backyard. Empty removes all forest scenery, props, hazards, and wrap obstacles while keeping the player, arena bounds, and Training Tools available."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout_tab.add_child(hint)

func _select_backyard_layout(layout_id: String) -> void:
	if is_instance_valid(main) and main.has_method("set_backyard_training_layout"):
		main.call("set_backyard_training_layout", layout_id)

func _build_forest_visuals_tab(tabs: TabContainer) -> void:
	forest_visual_tuner = ForestVisualTuner.new()
	forest_visual_tuner.name = "Forest Visuals"
	# Main owns and initializes the one shared profile before building the menu.
	# Never create a UI-local fallback or load a preset as a side effect of opening.
	_bind_forest_visual_settings()
	tabs.add_child(forest_visual_tuner)
	call_deferred("_bind_forest_visual_settings")

func _bind_forest_visual_settings() -> void:
	if forest_visual_tuner == null:
		return
	var profile: ForestVisualSettings = null
	var population: ArenaPopulation = null
	if is_instance_valid(main) and main.has_method("get_forest_visual_settings"):
		profile = main.call("get_forest_visual_settings") as ForestVisualSettings
	if is_instance_valid(main) and main.has_method("get_arena_population"):
		population = main.call("get_arena_population") as ArenaPopulation
	var global_day_presets: Dictionary = {}
	var global_slot: int = 2
	var global_phase: String = "Noon"
	if is_instance_valid(main) and main.has_method("get_active_global_forest_day_presets"):
		global_day_presets = main.call("get_active_global_forest_day_presets") as Dictionary
		global_slot = int(main.call("get_global_preset_slot")) if main.has_method("get_global_preset_slot") else 2
		global_phase = str(main.call("get_forest_time_phase")) if main.has_method("get_forest_time_phase") else "Noon"
	# Import the global bundle once when the tuner is initialized. Reopening the
	# menu must not replace its live/dirty phase workspace with saved values.
	# Main explicitly calls apply_global_day_presets() after a real Global Load.
	if not global_day_presets.is_empty() and not forest_visual_tuner.global_preset_mode:
		forest_visual_tuner.apply_global_day_presets(global_day_presets, global_slot, global_phase)
	forest_visual_tuner.configure(profile, population)
	if not forest_visual_tuner.time_phase_selected.is_connected(_on_forest_time_phase_selected):
		forest_visual_tuner.time_phase_selected.connect(_on_forest_time_phase_selected)

func _on_forest_time_phase_selected(phase: String) -> void:
	if is_instance_valid(main) and main.has_method("set_forest_time_phase"):
		main.call("set_forest_time_phase", phase)

func _on_training_tab_changed(_index: int) -> void:
	if forest_visual_tuner != null and training_tabs.get_current_tab_control() != forest_visual_tuner:
		forest_visual_tuner.end_comparison()
	_apply_training_layout()
	# Reapply after containers invalidate their previous minimum size.
	_apply_training_layout.call_deferred()

## Returns a viewport-safe panel rectangle. The separate toggle sits directly
## above it, and the combined toggle+panel assembly is centered as one unit.
## Explicit top-left geometry avoids container minimum-size changes growing a
## centered Control toward one side on different window/aspect sizes.
static func centered_training_rect(viewport_size: Vector2) -> Rect2:
	var available_width: float = maxf(1.0, viewport_size.x - VIEWPORT_SIDE_MARGIN * 2.0)
	var available_height: float = maxf(1.0, viewport_size.y - VIEWPORT_VERTICAL_MARGIN * 2.0 - TOGGLE_HEIGHT - TOGGLE_GAP)
	var menu_size: Vector2 = Vector2(minf(DESIRED_MENU_SIZE.x, available_width), minf(DESIRED_MENU_SIZE.y, available_height))
	var assembly_height: float = menu_size.y + TOGGLE_HEIGHT + TOGGLE_GAP
	var assembly_top: float = maxf(VIEWPORT_VERTICAL_MARGIN, (viewport_size.y - assembly_height) * 0.5)
	var menu_position: Vector2 = Vector2((viewport_size.x - menu_size.x) * 0.5, assembly_top + TOGGLE_HEIGHT + TOGGLE_GAP)
	return Rect2(menu_position, menu_size)

## Training Tools keeps the same centered geometry across every tab, including
## Forest Visuals, and recomputes it whenever the viewport changes.
func _apply_training_layout() -> void:
	if training_tabs == null or toggle_button == null or panel == null:
		return
	var centered_rect: Rect2 = centered_training_rect(get_viewport_rect().size)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = centered_rect.position
	size = centered_rect.size
	toggle_button.position = Vector2(0.0, -(TOGGLE_HEIGHT + TOGGLE_GAP))
	toggle_button.size = Vector2(centered_rect.size.x, TOGGLE_HEIGHT)
	# Panel is not container-parented; explicitly clear any stale grown offsets.
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0

func _build_enemy_tab(tabs: TabContainer) -> void:
	var enemy_tab: VBoxContainer = VBoxContainer.new()
	enemy_tab.name = "Enemies"
	enemy_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(enemy_tab)

	var title: Label = Label.new()
	title.text = "SPAWN ENEMIES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_tab.add_child(title)

	var visual_shortcut: Button = Button.new()
	visual_shortcut.name = "OpenForestVisuals"
	visual_shortcut.text = "Open Forest Visuals"
	visual_shortcut.focus_mode = Control.FOCUS_NONE
	visual_shortcut.pressed.connect(func() -> void: training_tabs.current_tab = forest_visual_tuner.get_index())
	enemy_tab.add_child(visual_shortcut)

	auto_spawner_button = Button.new()
	auto_spawner_button.focus_mode = Control.FOCUS_NONE
	auto_spawner_button.custom_minimum_size = Vector2(0.0, 44.0)
	auto_spawner_button.pressed.connect(_toggle_production_spawner)
	enemy_tab.add_child(auto_spawner_button)

	auto_spawner_status = Label.new()
	auto_spawner_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_spawner_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_tab.add_child(auto_spawner_status)
	_sync_auto_spawner_controls()

	training_dummy_button = Button.new()
	training_dummy_button.name = "TrainingDummyToggle"
	training_dummy_button.custom_minimum_size = Vector2(0.0, 44.0)
	training_dummy_button.focus_mode = Control.FOCUS_NONE
	training_dummy_button.pressed.connect(_toggle_training_dummy)
	enemy_tab.add_child(training_dummy_button)

	test_turkey_button = Button.new()
	test_turkey_button.name = "TestTurkeyToggle"
	test_turkey_button.custom_minimum_size = Vector2(0.0, 44.0)
	test_turkey_button.focus_mode = Control.FOCUS_NONE
	test_turkey_button.pressed.connect(_toggle_test_turkey)
	enemy_tab.add_child(test_turkey_button)
	_sync_training_target_controls()

	for enemy_entry: Dictionary in [
		{"label":"Turkey", "scene":WaveSpawner.TURKEY_SCENE},
		{"label":"Spear Goblin", "scene":WaveSpawner.GOBLIN_SCENE},
		{"label":"Archer Goblin", "scene":WaveSpawner.ARCHER_GOBLIN_SCENE},
		{"label":"Sword Goblin", "scene":WaveSpawner.SWORD_GOBLIN_SCENE},
		{"label":"Bug", "scene":WaveSpawner.BUG_SCENE},
		{"label":"Wolf", "scene":WaveSpawner.WOLF_SCENE},
		{"label":"Ogre", "scene":WaveSpawner.OGRE_SCENE}
	]:
		var button: Button = Button.new()
		button.text = "Spawn " + str(enemy_entry["label"])
		button.custom_minimum_size = Vector2(0.0, 38.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_spawn_enemy.bind(enemy_entry["scene"] as PackedScene))
		enemy_tab.add_child(button)

	var zungar_button: Button = Button.new()
	zungar_button.name = "SpawnZungarSwordTest"
	zungar_button.text = "Spawn Zungar (Sword Test)"
	zungar_button.custom_minimum_size = Vector2(0.0, 44.0)
	zungar_button.focus_mode = Control.FOCUS_NONE
	zungar_button.pressed.connect(_spawn_zungar_sword_test)
	enemy_tab.add_child(zungar_button)

	var hint: Label = Label.new()
	hint.text = "Manual spawns stay separate. Production Spawner runs the real WaveSpawner configuration in training mode with no drops or progression rewards."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_tab.add_child(hint)

func _build_spawn_items_tab(tabs: TabContainer) -> void:
	var items_tab: VBoxContainer = VBoxContainer.new()
	items_tab.name = "Spawn Items"
	items_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(items_tab)

	var title: Label = Label.new()
	title.text = "SPAWN ITEMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_tab.add_child(title)

	var chest_button: Button = Button.new()
	chest_button.text = "Spawn Chest"
	chest_button.custom_minimum_size = Vector2(0.0, 38.0)
	chest_button.focus_mode = Control.FOCUS_NONE
	chest_button.pressed.connect(_spawn_chest)
	items_tab.add_child(chest_button)

	var hint: Label = Label.new()
	hint.text = "Spawns a destructible chest near you immediately, bypassing the normal per-wave drop chance. Break it with Chakram or Sword like any other obstruction to test item drops and the Armory."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_tab.add_child(hint)

func _spawn_chest() -> void:
	if main != null: main.call("spawn_training_chest")

func _build_bonus_tab(tabs: TabContainer) -> void:
	var bonus_scroll: ScrollContainer = ScrollContainer.new()
	bonus_scroll.name = "Bonuses"
	bonus_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(bonus_scroll)

	var bonus_box: VBoxContainer = VBoxContainer.new()
	bonus_box.add_theme_constant_override("separation", 8)
	bonus_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_scroll.add_child(bonus_box)

	var title: Label = Label.new()
	title.text = "TECHNIQUE RANKS (0 - %d)" % BonusConfig.MAX_RANK
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_box.add_child(title)

	for bonus_id: String in BonusConfig.all_bonus_ids():
		var row: VBoxContainer = VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label: Label = Label.new()
		label.text = BonusConfig.display_name(bonus_id)
		row.add_child(label)

		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = float(BonusConfig.MAX_RANK)
		slider.step = 1.0
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_bonus_changed.bind(bonus_id))
		row.add_child(slider)

		var value_label: Label = Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		bonus_box.add_child(row)
		bonus_rows[bonus_id] = {"slider": slider, "value_label": value_label}

## Shape controls follow the single sword selector shared by visuals and hand
## tuning. Profiles come from Player.BLADE_PROFILES, so future swords appear in
## that selector automatically. Shape remains independent of contact preset.
func _build_blade_shape_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section_header(parent, "BLADE SHAPE (Per Sword Type)")

	var hint: Label = Label.new()
	hint.text = "Hilt is always fixed at the grip (t=0, offset 0). Mid-point and tip below bow the blade's hit polyline AND its rendered art together -- this is what actually gets swept for damage, not just a cosmetic curve."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(hint)

	blade_shape_status = Label.new()
	blade_shape_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blade_shape_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(blade_shape_status)

	_create_blade_shape_slider(section, "mid_t", "Mid-Point Position", 0.05, 0.95, 0.01, "", "Where along the blade (0 = hilt, 1 = tip) the interior control point sits.")
	_create_blade_shape_slider(section, "mid_offset", "Mid-Point Offset", -40.0, 40.0, 0.5, " px", "Perpendicular bow at the mid-point. Positive/negative sides depend on swing direction, not screen direction -- just watch it live.")
	_create_blade_shape_slider(section, "tip_offset", "Tip Offset", -60.0, 60.0, 0.5, " px", "Perpendicular bow at the very tip -- this is what makes a scimitar-style curve read at full reach.")
	_sync_blade_shape_controls()

func _create_blade_shape_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, suffix: String, tooltip: String = "") -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)

	var label: Label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(label)

	if not tooltip.is_empty():
		var tip_badge: Label = Label.new()
		tip_badge.text = "[?]"
		tip_badge.tooltip_text = tooltip
		tip_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		tip_badge.modulate = Color(0.45, 0.85, 1.0, 0.9)
		title_row.add_child(tip_badge)

	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_blade_shape_setting_changed.bind(key))
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	blade_shape_controls[key] = {"slider": slider, "label": value_label, "suffix": suffix}

func _blade_shape_setting_changed(value: float, key: String) -> void:
	var player: Player = _player()
	if player == null: return
	player.set_blade_shape_setting(selected_combat_sword_id, key, value)
	_sync_blade_shape_controls()

func _sync_blade_shape_controls() -> void:
	var player: Player = _player()
	if player == null: return
	for key: String in blade_shape_controls:
		var row: Dictionary = blade_shape_controls[key]
		var value: float = player.get_blade_shape_setting(selected_combat_sword_id, key)
		var suffix: String = str(row.get("suffix", ""))
		(row["slider"] as HSlider).set_value_no_signal(value)
		(row["label"] as Label).text = ("%.2f%s" if suffix == "" else "%.1f%s") % [value, suffix]
	if blade_shape_status != null:
		blade_shape_status.text = "Editing and equipped: %s" % selected_combat_sword_id

func _build_charged_guard_tab(tabs: TabContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Charged Guard"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "CHARGED GUARD (OPT-IN PROTOTYPE)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note: Label = Label.new()
	note.text = "Acquire Guard State by driving the mouse toward the sword's pommel when the metronome reaches the turn of its stroke. The pull must be aligned, fast enough, and sustained through real travel; cursor rotation is not required. Hold the resulting guard shape briefly to lock it. An abandoned pull resets instead of banking old movement, and a candidate expires quickly if the shape is not confirmed. An amber ring fills around the hand as the guard builds; the hand turns blue only after the separate charged-state hold. A hard sideways flick breaks a held guard, the Guard Hold Limit runs it out, and a completed gesture discharges it as an attack."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_create_contact_slider(box, "charged_guard_enabled", "Charged Guard Enabled", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Opt in to acquiring a counter-swing guard; off preserves normal combat exactly.", "Guard recognition and lock are disabled.", "Driving the pommel back against the metronome swing can shape and charge a guard.", "Tune the gesture below; no extra button is used."))
	_create_contact_slider(box, "charged_guard_position_charge_enabled", "Charged Guard State (Blue) Enabled (0/1)", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Separately enable the delayed blue charged-position layer without disabling the original Charged Guard acquisition and lock.", "Original Guard only: no delayed charge, blue glow, afterimages, or slow-reposition behavior.", "After the confirmation hold, enable the blue persistent state and slow reposition.", "Leave at 0 while tuning the original Guard. This switch does not disable Guard itself."))
	_create_contact_slider(box, "charged_guard_hold_duration", "Guard Charge Time", 0.05, 0.25, 0.01, " s", _form_three_feel_tip("Time required holding the folded guard shape to lock it within the candidate's 0.30-second deadline.", "Locks quickly after a valid fold.", "Requires a longer, steadier guard hold.", "The hard candidate deadline caps effective hold time at 0.25 seconds, including older saved values above that range. Charge-rate boosts below can shorten the real time."))
	_create_contact_slider(box, "charged_guard_awaken_duration", "Charged Position Confirm Time", 0.20, 2.00, 0.05, " s", _form_three_feel_tip("Time to maintain a locked guard before its hand position becomes fully charged and blue.", "The blue charged state arrives quickly.", "The hand must remain steady longer before the charged shimmer appears.", "Default is one second. Once fully charged, the state persists until the Guard Hold Limit runs out, you flick the guard away, or a gesture discharges it."))
	_create_contact_slider(box, "charged_guard_hold_limit", "Guard Hold Limit", 1.0, 15.0, 0.5, " s", _form_three_feel_tip("How long the blue guard holds before releasing itself, counted from the moment it goes blue.", "The guard is a quick brace: it releases after a second or two.", "The guard can be held for a long stretch, up to fifteen seconds.", "Default 4 seconds. The charge is free, so this counts from blue and never from the moment you start acquiring, and it pauses while you are drawing a gesture so a circle can never be timed out from under your hand. When it expires, a fresh guard is blocked for half a second, so a shape you are still holding does not immediately take again. The exits are a hard sideways flick, this limit, or discharging a gesture."))
	_create_contact_slider(box, "charged_guard_break_speed", "Guard Flick Break Speed", 100.0, 2000.0, 25.0, " px/s", _form_three_feel_tip("How fast a sideways flick must cross the aim to break the guard, geared by how far out the cursor is held so the same flick works wherever the hand is.", "An easy flick breaks the guard: it lets go almost as soon as you drag across.", "Only a hard, deliberate snap breaks the guard.", "Default 600. It measures lateral speed only -- the part of the motion crossing the aim, not the part running along it -- so a straight drawn stroke can never be mistaken for a flick. This is the quickest way out of a guard; the Guard Hold Limit is the backstop."))
	_create_contact_slider(box, "charged_guard_acquisition_window", "Guard Rhythm Window", 0.20, 0.95, 0.01, "", _form_three_feel_tip("How much of each metronome turn permits a pommel pull to build a guard candidate.", "A narrow beat demands precise pull timing.", "A wider beat forgives timing without forgiving weak or misaligned pulls.", "The pull must build its travel and intent inside this window; outside it no new guard evidence is earned. Keep it wide enough for a deliberate sustained pull."))
	_create_contact_slider(box, "charged_guard_pommel_alignment", "Pommel Direction Precision", 0.50, 0.99, 0.01, "", _form_three_feel_tip("How straight the counter-drive must be against the blade before it counts at all.", "Quite diagonal drives still count.", "The drive must be almost exactly against the blade.", "Measured against the blade the metronome is swinging, so the drive has to answer the swing as it happens. Alignment decides whether a drive counts, and scales how much of it banks."))
	_create_contact_slider(box, "charged_guard_pommel_speed", "Minimum Pommel-Drive Speed", 20.0, 300.0, 5.0, " px/s", _form_three_feel_tip("How fast the counter-drive must move for it to count, and for recent-movement credit.", "A slow drive still counts.", "Requires a fast, deliberate drive.", "The floor that keeps ordinary aiming from banking a guard. Default 90."))
	_create_contact_slider(box, "charged_guard_pommel_travel", "Pommel Drive Travel Required", 2.0, 40.0, 1.0, " px", _form_three_feel_tip("How much counter-drive travel must bank before a guard latches.", "A short drive sets the guard.", "A long sustained drive is required.", "Travel is capped at this bar and resets after a very short interruption; unrelated later motion cannot finish an old pull. Works with the time requirement below."))
	_create_contact_slider(box, "charged_guard_pommel_intent_time", "Pommel Drive Time Required", 0.02, 0.20, 0.01, " s", _form_three_feel_tip("How long the qualifying drive must be sustained before a guard latches.", "A brief, crisp drive is enough.", "The drive must hold together longer.", "Works with the travel bar: both must be met before a guard latches."))
	_create_contact_slider(box, "charged_guard_near_body_radius", "Near-Body Charge Radius", 10.0, 100.0, 2.0, " px", _form_three_feel_tip("Hilt distance from the player within which the near-body charge boost applies.", "Only a close hand position earns this boost.", "A wider area around the body earns it.", "Proximity speeds an already acquired guard; it does not trigger one."))
	_create_contact_slider(box, "charged_guard_near_body_rate", "Near-Body Charge Boost", 0.0, 3.0, 0.1, "×", _form_three_feel_tip("Extra charge-rate multiplier while the hilt is within the Near-Body Charge Radius.", "Near-body position adds no charge speed.", "Near-body position strongly speeds the hold.", "This only changes charge rate once a guard is being charged. Default 0, so the Charge Time is the whole charge rate on its own."))
	_create_contact_slider(box, "charged_guard_recent_motion_rate", "Recent-Movement Charge Boost", 0.0, 3.0, 0.1, "×", _form_three_feel_tip("Extra charge rate briefly after sufficiently strong authored aim movement.", "Only a perfectly still hold charges at baseline speed.", "Recent authored movement speeds the guard charge considerably.", "The movement cue expires quickly, it never acquires a guard on its own, and it defaults to 0 so the charge time applies by itself."))
	_create_contact_slider(box, "charged_guard_pommel_rate", "Continued Pommel-Pull Charge Boost", 0.0, 3.0, 0.1, "×", _form_three_feel_tip("Extra charge rate while authored movement remains aligned with the pommel axis.", "After acquisition, continued pull adds no speed.", "Maintaining the pommel pull rapidly charges the guard.", "Precision still gates this boost, and it defaults to 0, so a drive that keeps its shape charges at the Charge Time."))
	_create_contact_slider(box, "apex_hang_time", "Authored Apex Hang", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Strongly driven strokes earn a short committed hold at the endpoint before returning.", "No drive-earned endpoint hold.", "Stroke Drive above 50% earns the tuned endpoint hold.", "Each stroke earns its own hang; the hold cannot be extended indefinitely."))
	_create_contact_slider(box, "apex_hang_duration", "Apex Hang Time", 0.05, 0.30, 0.01, " s", _form_three_feel_tip("Maximum endpoint dwell earned by a fully driven stroke; the existing Authored Apex Hang switch must also be on.", "Brief 0.05-second punctuation at the endpoint.", "A clear 0.30-second hold before the return stroke.", "Only Stroke Drive above 50% earns a proportional share of this duration."))

	var gesture_section: VBoxContainer = _create_section_header(box, "GESTURES", true)
	var gesture_note: Label = Label.new()
	gesture_note.text = "While the blue charged state is up, draw a gesture with the mouse and bring it to rest to discharge the guard as an attack. A long straight stroke fires a lunging thrust along that line; a full circle sweeps the whole sword one turn around you, going whichever way you drew it, so the tip cuts a ring all the way round and lands back where it started. Either way the stroke is drawn back as a blue trail so you can see what you are drawing, and it flashes when a gesture is read. The whirlwind does not move you or hold you in place -- it only forces the sword's animation, so it hits, slides, parries and clashes like any other swing. A stroke that is not read as one of the shapes above simply does nothing: it never breaks the guard, and the guard's only exits are a hard sideways flick, the Guard Hold Limit, or discharging a gesture as an attack."
	gesture_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gesture_section.add_child(gesture_note)
	_create_contact_slider(gesture_section, "charged_guard_gestures_enabled", "Gestures Enabled (0/1)", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Allow deliberately drawn cursor gestures, made while the blue charged state is up, to discharge the guard as an attack.", "Off. The guard behaves exactly as it does today and no trail is drawn.", "On. While blue, a long straight stroke brought to rest fires a lunging thrust along that line, and a full circle sweeps the whole sword one turn around you, the way you drew it.", "The straight stroke must span roughly 220 screen pixels, stay about 85% straight, complete inside 1.5 seconds and come to rest. The circle is deliberately far more forgiving, because a circle is much harder to draw than a line: roughly 80 pixels across, drawn within 3 seconds, either brought back near its own start or swept plainly the whole way round, so overshooting still counts. It only has to stay round rather than spiralling, and rough drawing is expected. Nothing is lost to speed: a stroke that is not read as a gesture leaves the guard standing untouched. The trail follows the same colour as the hand glow, so the two breathe together."))

func _build_authored_metronome_tab(tabs: TabContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Authored Metronome"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "AUTHORED METRONOME (OPT-IN PROTOTYPE)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note: Label = Label.new()
	note.text = "For metronome-based forms on Presets 1–3. Authored aim movement fills arc energy and widens the metronome. After the idle grace that energy bleeds away and the arc eases back down to a blade that simply points at your aim, then sheathes after a separate Ready-only delay. Preset 4's evolving form is untouched."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_create_contact_slider(box, "authored_metronome_enabled", "Authored Metronome (0–1)", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Opt into manual metronome wake-up and ready/sheathed states; off preserves existing sword behavior.", "Existing autonomous metronome behavior stays unchanged.", "The blade waits pointed and ready for deliberate authored aim movement.", "Only metronome-based forms on Presets 1–3 use this prototype; Charged Guard and other combat tuners remain separate."))
	_create_contact_slider(box, "authored_metronome_wake_speed", "Wake Speed Threshold", 50.0, 1200.0, 25.0, " px/s", _form_three_feel_tip("Authored aim speed required to start filling the metronome's arc energy.", "Gentler aim movement starts widening the arc.", "Only a sharper, faster movement starts widening the arc.", "Movement below this threshold still repositions the pointed blade and holds off sheathing; tune by feel for your input device."))
	_create_contact_slider(box, "authored_metronome_energy_build", "Arc Energy Build Rate", 0.2, 3.0, 0.05, " /s", _form_three_feel_tip("How fast authored aim movement fills arc energy.", "The arc takes its time widening; the blade stays close to your aim.", "The arc opens almost the moment you start moving.", "Energy only builds above the Wake Speed Threshold. Full energy is the widest metronome arc; zero energy is a blade simply pointing at your aim."))
	_create_contact_slider(box, "authored_metronome_energy_fade", "Arc Energy Fade Rate", 0.1, 2.0, 0.05, " /s", _form_three_feel_tip("How fast arc energy bleeds away once the idle grace has passed with no authored aim movement.", "The wide arc lingers a long while after you stop.", "The arc narrows back toward your aim quickly.", "Wind-down only begins after the Idle Grace. The arc eases closed, so the last stretch down to a plain pointed blade stays gentle."))
	_create_contact_slider(box, "authored_metronome_idle_grace", "Authored Metronome Idle Grace", 0.5, 8.0, 0.1, " s", _form_three_feel_tip("Time without authored aim movement before arc energy starts to fade and the metronome winds down.", "The arc begins winding down soon after you stop moving.", "The arc holds its width through a longer pause.", "This grace stops brief stops from flinching the arc. The Ready sheathe timer only starts after the wind-down finishes."))
	_create_contact_slider(box, "authored_metronome_sheathe_time", "Ready Idle → Sheathe Time", 0.2, 4.0, 0.1, " s", _form_three_feel_tip("Time with no meaningful aim movement in Ready before the sword fades into its sheathed state.", "The ready blade sheathes quickly.", "The ready blade remains available longer.", "This timer runs only in Ready; any meaningful aim movement immediately brings back the pointed blade."))

func _build_windup_tab(tabs: TabContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Metronome Wind-up"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "METRONOME WIND-UP LAB (EXPERIMENTAL)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note: Label = Label.new()
	note.text = "Currently affects Form II: Metronome Wind-up only. Form I: Metronome V remains the untouched comparison stance. Fractions choose when phases happen; relative speed sliders choose how distinct they feel while total timing stays normalized."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var timing_section: VBoxContainer = _create_section_header(box, "STROKE TIMING", true)
	_create_hand_slider(timing_section, "windup_profile", "Wind-up Profile Strength", 0.0, 1.0, 0.05, "", "0 = linear timing. Higher values slow the opening and recovery portions while concentrating speed in the strike window.")
	_create_hand_slider(timing_section, "windup_fraction", "Wind-up Fraction", 0.10, 0.50, 0.01, "", "Fraction of each stroke spent leaving the reversal before the fast strike window.")
	_create_hand_slider(timing_section, "recovery_fraction", "Follow-through / Recovery Fraction", 0.10, 0.40, 0.01, "", "Fraction of each stroke spent easing out before the next reversal.")
	_create_hand_slider(timing_section, "windup_speed", "Wind-up Speed (Relative)", 0.05, 1.00, 0.05, "×", "How slow the opening phase is relative to the base phase rate. Lower is more deliberate; total stroke duration stays normalized.")
	_create_hand_slider(timing_section, "strike_speed", "Strike Speed (Relative)", 1.00, 4.00, 0.05, "×", "Relative speed of the central committed strike window. Higher makes the contrast clearer without changing total cycle time.")
	_create_hand_slider(timing_section, "recovery_speed", "Recovery Speed (Relative)", 0.05, 1.00, 0.05, "×", "How slow the follow-through is relative to the base phase rate. Lower gives a longer, more visible recovery.")
	var momentum_section: VBoxContainer = _create_section_header(box, "FORWARD STEP", true)
	_create_hand_slider(momentum_section, "authored_step_enabled", "Authored Step", 0.0, 1.0, 1.0, "", _form_three_feel_tip("A hard, sustained swing-through can carry the player into the committed cut with a physical step.", "No forward step occurs.", "Only strongly driven strokes can pull the body forward behind the cut.", "The step fires at most once per stroke and requires deliberate motion with the blade before the commitment point."))
	_create_hand_slider(momentum_section, "forward_impulse", "Forward Step Impulse", 0.0, 800.0, 10.0, " px/s", "Physical velocity toward the live aim point when an Authored Step is earned. Higher values make full-drive power swings carry the body farther.")
	_create_hand_slider(momentum_section, "forward_impulse_timing", "Forward Step Timing", 0.05, 0.95, 0.01, "", "Where the forward step lands inside the stroke. Default 0.30 means it fires as the strike leaves wind-up.")
	_create_hand_slider(momentum_section, "backstep_enabled", "Backstep Enabled", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Allows the separately tuned opposite-direction movement impulse during a stroke.", "Backstep is fully disabled.", "Backstep can fire using its Impulse and Timing settings.", "This switch is independent from Authored Step; E no longer controls either movement."))
	_create_hand_slider(momentum_section, "backstep_impulse", "Backstep Impulse", 0.0, 300.0, 5.0, " px/s", "Opposite cutting-tangent impulse per stroke when Backstep Enabled is on.")
	_create_hand_slider(momentum_section, "backstep_impulse_timing", "Backstep Timing", 0.05, 0.95, 0.01, "", "Where the opposite step lands inside the stroke. Use this independently from Forward Step Timing.")
	var action_section: VBoxContainer = _create_section_header(box, "ACTION COMMITMENT (METRONOME)", true)
	_create_hand_slider(action_section, "action_commitment_strength", "Action Commitment Strength", 0.0, 1.0, 0.05, "", "0 = freely redirectable; 1 = no-cancel during the late-stroke action window.")
	_create_hand_slider(action_section, "action_commitment_start", "Action Phase Start", 0.30, 0.90, 0.01, "", "Default 0.60 begins the no-cancel window around 60% through the stroke.")
	_create_hand_slider(action_section, "action_commitment_end", "Action Phase End", 0.70, 1.0, 0.01, "", "Default 0.90 releases aim authority into the final recovery before reversal.")
	var warning: Label = Label.new()
	warning.text = "Wind-up timing, forward step, and Action Commitment are active only in Form II: Metronome Wind-up."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.modulate = Color(1.0, 0.78, 0.35)
	box.add_child(warning)

func _build_visualizer_tab(tabs: TabContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Visualizer"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "METRONOME VISUALIZER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note: Label = Label.new()
	note.text = "These controls affect the Beat mode from Home > Options. The pulse stays fixed at the bottom of the screen while its timing and authored HD size are tuned here."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_create_visualizer_slider(box, "visualizer_counts", "Visualizer Counts", 1.0, 4.0, 1.0, "", "One full charge and release over N sword strokes, peaking on the Nth stroke. Combat timing is unchanged.")
	_create_visualizer_slider(box, "beat_pulse_percent", "Beat Pulse Position", 0.0, 100.0, 5.0, "%", "Where the gold peak lands inside the selected Nth sword stroke.")
	_create_visualizer_slider(box, "beat_visualizer_size", "Beat Ball Size", 0.5, 2.5, 0.1, "×", "Scales the round core and horizontal energy.")
	_create_visualizer_slider(box, "training_camera_zoom", "Camera Zoom", 1.0, 2.0, 0.05, "×", "HD camera zoom. 1.0× is the normal view; higher values bring the swordplay closer without changing gameplay geometry.")

func _create_visualizer_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, suffix: String, tooltip: String = "") -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)
	var label: Label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(label)
	var tip_badge: Label = Label.new()
	tip_badge.text = "[?]"
	tip_badge.tooltip_text = tooltip
	tip_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	tip_badge.modulate = Color(0.45, 0.85, 1.0, 0.9)
	title_row.add_child(tip_badge)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_visualizer_setting_changed.bind(key))
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	visualizer_controls[key] = {"slider": slider, "label": value_label, "suffix": suffix}

func _visualizer_setting_changed(value: float, key: String) -> void:
	if not is_instance_valid(main): return
	if key == "beat_pulse_percent" and main.has_method("set_beat_pulse_percent_from_training"):
		main.call("set_beat_pulse_percent_from_training", value)
	elif key == "beat_visualizer_size" and main.has_method("set_beat_visualizer_size_from_training"):
		main.call("set_beat_visualizer_size_from_training", value)
	elif key == "visualizer_counts" and main.has_method("set_visualizer_counts_from_training"):
		main.call("set_visualizer_counts_from_training", int(value))
	elif key == "training_camera_zoom" and main.has_method("set_training_camera_zoom_from_training"):
		main.call("set_training_camera_zoom_from_training", value)
	_sync_visualizer_controls()

func _sync_visualizer_controls() -> void:
	if not is_instance_valid(main): return
	for key: String in visualizer_controls:
		var row: Dictionary = visualizer_controls[key]
		var value: float = 0.0
		if key == "beat_pulse_percent" and main.has_method("get_beat_pulse_percent"):
			value = float(main.call("get_beat_pulse_percent"))
		elif key == "beat_visualizer_size" and main.has_method("get_beat_visualizer_size"):
			value = float(main.call("get_beat_visualizer_size"))
		elif key == "visualizer_counts" and main.has_method("get_visualizer_counts"):
			value = float(main.call("get_visualizer_counts"))
		elif key == "training_camera_zoom" and main.has_method("get_training_camera_zoom"):
			value = float(main.call("get_training_camera_zoom"))
		(row["slider"] as HSlider).set_value_no_signal(value)
		var value_format: String = "%.0f%s" if key in ["beat_pulse_percent", "visualizer_counts"] else "%.1f%s"
		(row["label"] as Label).text = value_format % [value, str(row.get("suffix", ""))]

static func _form_three_feel_tip(description: String, left_feel: String, right_feel: String, tuning_tip: String = "") -> String:
	var text: String = "%s\n\nFEEL GUIDE\n← LEFT: %s\n→ RIGHT: %s" % [description, left_feel, right_feel]
	if not tuning_tip.is_empty():
		text += "\n\nTIP: %s" % tuning_tip
	return text

static func _grapple_feel_tip(key: String) -> String:
	var guide: Dictionary = {
		"max_tether_length": ["Maximum distance a fired hook may travel and attach.", "Short, close-range grapples.", "Long-reaching grapples with more distant commitments.", "Set reach first; Grapple Mastery scales this same authority at runtime."],
		"hook_travel_speed": ["Speed of the hook projectile before attachment.", "Readable, delayed distant attachments.", "Fast, nearly immediate attachment.", "Tune reach before judging flight speed."],
		"reel_speed": ["Rate the rope shortens after it is taut and reeling.", "Slow, sustained hauling.", "Fast rope recovery and shorter exchanges.", "This changes rope length, not pull acceleration."],
		"slack_take_up_speed": ["Rate used only to close Initial Attachment Slack.", "A softer delayed catch.", "Attachment slack disappears quickly.", "This stops acting once the first catch becomes taut."],
		"initial_slack": ["Extra rope granted when the hook reaches its target.", "A crisp measured catch with little or no loose line.", "A visibly looser attachment before tension.", "Set this to zero to rule out attachment slack completely."],
		"taut_catch_impulse_seconds": ["Duration of the one-shot hand impulse when the line first catches.", "Subtle hand influence at capture.", "A stronger directional flick into orbit.", "This changes velocity once; it never changes rope length."],
		"yoyo_catch_radial_retention": ["Fraction of inward/outward radial velocity preserved as orbit begins.", "Radial drift is removed for a crisp tangent-only hang.", "More radial motion survives and may create temporary slack.", "Use zero when inward movement makes the caught line feel loose."],
		"tension_ramp_distance": ["Stretch distance required to reach full pull acceleration.", "Stiff, immediate rope tension.", "Progressive, springier tension.", "Raise if taut contact snaps; lower if the rope feels vague."],
		"enemy_pull_strength": ["Base reel acceleration applied to Light targets.", "Light enemies resist the reel.", "Light enemies accelerate strongly toward the player.", "Hand-authored steering is tuned separately by Light Target Hand Gain."],
		"light_yank_strength": ["Gain for hand-motion steering of Light targets.", "The hand barely redirects Light targets.", "Hand sweeps strongly redirect Light targets.", "Direction Transfer and Outward Bias shape this gain; they do not replace it."],
		"light_slide_fraction": ["Fraction of a Light target yank retained as an off-balance momentum tail.", "Targets settle quickly after each yank.", "Targets skid and carry yank momentum longer.", "Tune after Light Target Hand Gain."],
		"medium_reel_multiplier": ["Scale applied to Light Target Reel Force for Medium targets.", "Medium targets resist the reel strongly.", "Medium targets approach the Light reel response.", "This affects target pull only; Medium Target Player Pull is the opposite side."],
		"medium_yank_strength": ["Gain for hand-motion steering of Medium targets.", "Medium targets ignore most hand sweeps.", "Hand sweeps redirect Medium targets strongly.", "Keep below Light Target Hand Gain to preserve weight identity."],
		"medium_slide_fraction": ["Fraction of a Medium target yank retained as a momentum tail.", "Heavy, planted recovery.", "More visible off-balance sliding.", "Tune after Medium Target Hand Gain."],
		"medium_player_pull_strength": ["Acceleration pulling the player toward a Medium target.", "The player converges slowly.", "The player is drawn strongly toward the target.", "Balance against Medium Target Reel Scale; the two act on opposite bodies."],
		"heavy_player_pull_strength": ["Acceleration pulling the player toward stable Heavy and boss targets.", "Slow approach to the anchor-like target.", "Strong, fast player pull.", "Heavy targets remain stationary; this never pulls the target."],
		"chakram_tether_strength": ["Recall acceleration applied to the Chakram during reeling.", "Gentle, wide recall path.", "Forceful return toward the active pivot.", "This is recall force; Chakram Hand-Steering Gain controls hand redirection."],
		"chakram_yank_strength": ["Gain for hand-motion steering of a tethered flying Chakram.", "The orbit mostly preserves its existing course.", "Hand sweeps bend the Chakram path strongly.", "Tune after the Yo-yo catch; total speed still obeys the Chakram ceiling."],
		"directional_transfer_ratio": ["Shared fraction of hand direction transmitted to dynamic enemies and Chakram.", "Target-specific hand gains transmit little direction.", "Target-specific hand gains transmit their full direction.", "This is a shared signal gate; use target Hand Gain sliders for identity."],
		"radial_yank_ratio": ["Shared outward-only radial bias applied to dynamic-target hand gains.", "Hand motion favors tangential steering.", "Moving the hand away adds a stronger radial yank.", "It never changes inward motion or player-to-anchor steering."],
		"player_hand_orbit_strength": ["Tangential hand-steering gain while the player is pulled toward terrain, Medium, or Heavy anchors.", "The player follows a direct pull line.", "Hand sweeps curve the player's approach strongly.", "This affects the player, not dynamic-target or Chakram steering."],
		"player_radial_yank_strength": ["Extra player pull generated only when the taut hand moves away from an anchor.", "Little outward-hand pull boost.", "Strong outward-hand acceleration toward the anchor.", "Tune after Terrain/Medium/Heavy Player Pull Force."],
		"hand_velocity_smoothing": ["Response rate of the hand-motion signal used by all hand steering.", "Soft, delayed input with less animation jitter.", "Immediate hand response that may expose jitter.", "Choose signal quality before tuning any Hand Gain."],
		"hand_velocity_cap": ["Maximum hand-motion speed admitted into steering and yank calculations.", "Large hand or dash spikes are heavily limited.", "More extreme motion reaches the gain stages.", "Raise only if deliberate fast gestures feel clipped."],
		"body_movement_transfer": ["Fraction of player movement admitted into the shared hand signal.", "Walking and dashing barely whip targets; hand motion relative to the body stays expressive.", "Body movement strongly whips the Chakram and dynamic targets.", "Keep this low if ordinary movement masquerades as an intentional yank."],
		"wall_pull_strength": ["Base acceleration pulling the player toward terrain or glyph anchors.", "Slow, floaty traversal pull.", "Fast, forceful traversal pull.", "Hand steering layers on top; this remains the base pull authority."],
		"grapple_dash_traction": ["Steering retained during grapple-dashes and brief terrain-release slides.", "Dash momentum commits to its existing path.", "Movement input redirects the dash strongly.", "This does not change rope pull or ordinary grounded traction."],
		"yoyo_enabled": ["Master switch for Chakram extension, catch, and held orbit states.", "Ordinary Chakram grapple behavior only.", "A flying grappled Chakram may enter the Yo-yo sequence.", "Disable for baseline comparison; enemy and terrain grapples are unchanged."],
		"yoyo_soft_tension_zone": ["Distance before full extension where outward-speed easing begins.", "Late, abrupt catch near the line limit.", "Early, broad approach into tension.", "Move right if the catch snaps; left if energy dies too early."],
		"yoyo_radial_damping": ["Brake applied only to outward radial speed during the catch approach.", "Springy catch with more overshoot.", "Firm catch that settles onto the radius quickly.", "This preserves tangent; Orbit Energy Burn is the separate tangent control."],
		"yoyo_orbit_drag": ["Tangential energy lost per second while orbiting at full extension.", "Long, lively orbit and more trick time.", "Orbit settles quickly while remaining at its held radius.", "Tune only after the catch feels right."],
		"yoyo_orbit_slack_recovery_speed": ["Rate unused rope is recovered while the Chakram remains in Orbiting.", "Loose line remains visible longer after inward travel.", "Slack cleans up quickly around the new live path.", "This stops at the Chakram path and cannot pull inward or trigger recall."],
		"yoyo_min_orbit_time": ["Minimum time the caught Chakram hangs in orbit before low energy may start recall.", "A quick catch-and-return cycle.", "A longer trick window before recall is allowed.", "This is a minimum window: sufficient tangential speed continues sustaining the orbit."],
		"yoyo_recall_speed_threshold": ["Tangential speed at or below which recall begins after Hang Time.", "Only a nearly spent orbit begins reeling.", "Recall begins while the Chakram still carries more orbital speed.", "Move left for player-sustained tricks; move right for a more automatic return."],
		"yoyo_static_pivot_enabled": ["Allows one static obstruction point to redirect the Yo-yo rope when full boundary wrapping is off.", "Rope always uses the direct hand-to-Chakram path.", "Rocks, trees, and walls may become one local pivot.", "This is the stable fallback; Full Boundary Wrap overrides it."],
		"yoyo_boundary_wrap_enabled": ["Enables enemy and collision-object tether wrapping.", "Uses direct tethering, or the separate Static Tether Point option when enabled.", "Rope intersections may progress into committed automated coils.", "This overrides Static Tether Point."],
		"yoyo_wrap_commit_turns": ["Player-authored turns required before the coil automates.", "The coil commits quickly after a shallow bend.", "More manual winding is required before commitment.", "Set the hand-authored skill threshold before tuning automation speed."],
		"yoyo_coil_revolutions": ["Full automated turns completed while the spiral cinches inward.", "One concise revolution.", "Two highly readable revolutions.", "Start at 1.5 turns so the wrap is unmistakable."],
		"yoyo_coil_tangential_speed": ["Authoritative sideways speed around the wrapped target.", "A slower deliberate orbit.", "A forceful fast coil that resists stalling.", "This remains independent from inward cinch speed."],
		"yoyo_coil_radial_speed": ["Independent speed that closes the spiral radius.", "Wide revolutions remain visible longer.", "The Chakram cinches toward contact quickly.", "Keep below tangential speed for a readable spiral."],
		"yoyo_coil_speed_gain": ["Extra tangential speed gained as the spiral tightens.", "The orbit keeps a constant linear speed.", "The Chakram accelerates strongly toward impact.", "A moderate gain makes the tightening spiral feel energetic without becoming unreadable."],
		"yoyo_coil_hold_duration": ["Time a completed damaging coil treats the enemy as grappled.", "A brief positional beat.", "A longer pull-and-movement window.", "Default is the requested one-second hold."],
		"yoyo_unwind_speed": ["Reverse travel speed after the committed coil hits an obstruction.", "A slow visible escape.", "A quick recovery back out of the wrap.", "The impact bounce remains physical; this controls the deterministic escape."],
	}
	var values: Array = guide.get(key, ["Grapple tuning value.", "Less of this effect.", "More of this effect.", "Tune one authority at a time."]) as Array
	return _form_three_feel_tip(str(values[0]), str(values[1]), str(values[2]), str(values[3]))

static func _contact_feel_tip(key: String) -> String:
	match key:
		"clash_contact_tolerance", "parry_contact_tolerance":
			return _form_three_feel_tip("Maximum blade-to-blade distance that may qualify this contact.", "Precise and rarer; fast contacts may miss.", "Forgiving and frequent; near misses may count.", "Tune geometry before presentation effects.")
		"clash_angle_min":
			return _form_three_feel_tip("Minimum crossing angle required for a clash.", "Shallow crossings clash more easily, leaving fewer contacts as slides.", "Only clearly opposed crossings clash; shallow contacts remain slides or glances.")
		"clash_angle_max":
			return _form_three_feel_tip("Maximum crossing angle accepted as a clash.", "A narrow angle band makes clashes rarer.", "A broad angle band accepts more opposed blade contacts.", "Keep this above Crossing Angle Min.")
		"clash_cooldown", "parry_cooldown":
			return _form_three_feel_tip("Minimum delay before this reaction can trigger again.", "Rapid repeated reactions and possible contact chatter.", "Clear separation between reactions, but valid follow-ups may be ignored.")
		"clash_player_recoil", "parry_player_recoil":
			return _form_three_feel_tip("Physical push applied to the player by this weapon contact.", "The player holds ground and can stay close.", "The player is thrown back strongly and the exchange resets distance.")
		"clash_enemy_recoil", "parry_enemy_recoil":
			return _form_three_feel_tip("Physical push applied to the enemy by this weapon contact.", "Subtle deflection that preserves close pressure.", "Strong displacement that clearly wins space but may break follow-up range.")
		"clash_hitstop", "parry_hitstop":
			return _form_three_feel_tip("Brief impact freeze when the reaction succeeds.", "Fluid and fast contact.", "Heavy, dramatic contact that can interrupt rhythm.", "Use less for parries than major clashes if you want parries to feel skillful and quick.")
		"clash_stagger", "parry_stagger":
			return _form_three_feel_tip("How long the enemy's weapon/stance is disrupted.", "Tiny opening and quick recovery.", "Large, readable follow-up opening.", "This is control time, not direct damage.")
		"clash_recovery", "parry_recovery":
			return _form_three_feel_tip("How long player sword recovery remains constrained after contact.", "Immediate control and easier chaining.", "Committed recovery with greater consequence and less responsiveness.")
		"clash_flow":
			return _form_three_feel_tip("Flow resource removed by a clash.", "Clashes barely interrupt momentum.", "Clashes strongly punish rhythm and repeated blade collisions.")
		"clash_sparks", "parry_sparks":
			return _form_three_feel_tip("Number of sparks emitted by the reaction.", "Subtle, clean contact feedback.", "Dense, bright feedback that may obscure blade geometry.", "Presentation only.")
		"clash_shake_strength", "parry_shake_strength":
			return _form_three_feel_tip("Camera shake distance on contact.", "Stable and readable.", "Forceful and rough, but potentially tiring.", "Presentation only.")
		"clash_shake_duration", "parry_shake_duration":
			return _form_three_feel_tip("How long contact shake decays.", "Quick pulse.", "Lingering vibration that can blur the next action.")
		"clash_zoom", "parry_zoom":
			return _form_three_feel_tip("Brief camera zoom added on contact.", "Wide tactical view.", "Stronger cinematic emphasis with less peripheral view.", "Presentation only.")
		"clash_zoom_duration", "parry_zoom_duration":
			return _form_three_feel_tip("How long the contact zoom takes to settle.", "Sharp pulse.", "Slow cinematic settle that may overlap later actions.")
		"clash_impact", "parry_impact":
			return _form_three_feel_tip("Overall impact and speed-line presentation intensity.", "Quiet and geometry-focused.", "Bold, energetic contact feedback.", "Presentation only.")
		"parry_rotation_speed":
			return _form_three_feel_tip("Enemy blade rotation required to classify a defensive contact as a parry.", "Slower enemy turns may parry, making the defense more permissive.", "Only fast active guard movement qualifies, making parries rarer and sharper.")
		"parry_focus":
			return _form_three_feel_tip("Strength of the parry focus vignette.", "Little visual isolation.", "Strong attention around the successful defense.", "Presentation only.")
		"parry_focus_duration":
			return _form_three_feel_tip("How long the parry focus vignette remains.", "Brief flash.", "Long dramatic emphasis that may cover the follow-up.")
	return ""

func _build_combat_tab(tabs: TabContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Combat Presets"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	var title: Label = Label.new()
	title.text = "BLADE CONTACT LAB v0.1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var preset_row: HBoxContainer = HBoxContainer.new()
	preset_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_theme_constant_override("separation", 4)
	box.add_child(preset_row)

	for preset_num: int in [1, 2, 3, 4]:
		var p_btn: Button = Button.new()
		var p_title: String = "P1: Safe Baseline" if preset_num == 1 else ("P2: Distinct Contacts" if preset_num == 2 else ("P3: Dynamic Metronome" if preset_num == 3 else "P4: Form Evolution"))
		p_btn.text = p_title
		p_btn.focus_mode = Control.FOCUS_NONE
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.custom_minimum_size = Vector2(0.0, 36.0)
		p_btn.pressed.connect(_select_combat_preset.bind(preset_num))
		preset_row.add_child(p_btn)

	combat_status = Label.new()
	combat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(combat_status)

	weapon_collision_zones_button = Button.new()
	weapon_collision_zones_button.name = "WeaponCollisionZones"
	weapon_collision_zones_button.focus_mode = Control.FOCUS_NONE
	weapon_collision_zones_button.custom_minimum_size = Vector2(0.0, 44.0)
	weapon_collision_zones_button.tooltip_text = "Developer overlay: red pommel, yellow grip/guard, cyan cutting blade, white swept motion."
	weapon_collision_zones_button.pressed.connect(_toggle_weapon_collision_zones)
	box.add_child(weapon_collision_zones_button)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 6)
	box.add_child(action_row)

	var copy_btn: Button = Button.new()
	copy_btn.text = "📋 Copy Settings From..."
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(copy_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "Save Settings"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_all_settings)
	action_row.add_child(save_btn)

	var load_btn: Button = Button.new()
	load_btn.text = "Load Settings"
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(_load_all_settings)
	action_row.add_child(load_btn)

	var reset_btn: Button = Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_reset_all_defaults)
	action_row.add_child(reset_btn)

	var copy_strip: HBoxContainer = HBoxContainer.new()
	copy_strip.visible = false
	copy_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_strip.add_theme_constant_override("separation", 6)
	box.add_child(copy_strip)

	copy_btn.pressed.connect(func() -> void:
		copy_strip.visible = not copy_strip.visible
		if copy_strip.visible:
			_rebuild_copy_strip(copy_strip)
	)

	var promote_btn: Button = Button.new()
	promote_btn.text = "★ Set as Main Game Preset"
	promote_btn.focus_mode = Control.FOCUS_NONE
	promote_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	promote_btn.pressed.connect(_promote_active_preset)
	box.add_child(promote_btn)

	main_preset_status = Label.new()
	main_preset_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(main_preset_status)

	disk_feedback_label = Label.new()
	disk_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disk_feedback_label.modulate = Color(0.4, 1.0, 0.4)
	box.add_child(disk_feedback_label)

	event_monitor_label = Label.new()
	event_monitor_label.text = "Latest Contact: None"
	event_monitor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(event_monitor_label)

	_build_combat_sword_selector(box)
	_build_blade_shape_section(box)

	var core_section: VBoxContainer = _create_section_header(box, "CORE SWORD & REACH (Per Weapon, Preset & Style)")
	_create_hand_slider(core_section, "mouse_drag", "Overall Mouse Drag (Aim Inertia)", 3.0, 35.0, 0.5, "", "Lower is heavier; higher follows the cursor more directly.")
	_create_hand_slider(core_section, "rotation", "Rotation Speed (Aim Turn Drag)", 2.0, 40.0, 0.5, "", "Angular response rate toward the cursor.")
	_create_hand_slider(core_section, "max_turn_speed", "Max Turn Speed (0 = Unlimited)", 0.0, 1800.0, 90.0, "°/s", "Higher values turn faster with less resistance. Lower values impose a heavier speed cap. 0 = Unlimited.")
	_create_hand_slider(core_section, "strike_commitment", "Strike Commitment (Anti-Flail)", 0.0, 1.0, 0.05, "", "Higher values reward committed peak-stroke hits and weaken rapid mouse flailing.")
	_create_hand_slider(core_section, "swing_commitment", "Swing Commitment (Reversal Drag)", 0.0, 1.0, 0.05, "", "With-the-blade aim stays responsive; opposing the current swing becomes heavier. 0 = neutral, 1 = strongest.")
	_create_hand_slider(core_section, "swing_commitment_duration", "Swing Commitment Duration", 0.0, 0.50, 0.01, "s", "How long opposing player input remains heavy after an intentional reversal. Default 0.16s.")
	_create_hand_slider(core_section, "tempo_assist_enabled", "Swing Tempo Assist", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Lets deliberate hand motion accelerate the current metronome stroke when both travel in the same direction.", "Original fixed sword rhythm.", "The blade catches up with deliberate same-direction input.", "Assistance resets at every reversal, so each stroke must be physically reinforced."))
	_create_hand_slider(core_section, "directional_arc_opening_enabled", "Directional Arc Opening", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Deliberate hand movement with the blade progressively opens the destination of the active stroke.", "Every stroke uses the normal symmetric arc.", "Driven strokes gain up to 10° of directional follow-through.", "The earned extension remains until reversal; each return stroke must earn its own opening."))
	_create_hand_slider(core_section, "swing_gesture_gearing_degrees", "Swing Gesture Gearing", 15.0, 360.0, 1.0, "°", _form_three_feel_tip("Aligned, intentional hand travel required to fully drive one metronome stroke; faster travel counts more.", "Short, slow movements add little drive.", "Long, fast straight flicks build drive rapidly.", "Gesture pace matters too; merely tracing a long slow arc does not max the stroke."))
	_create_hand_slider(core_section, "radial_response", "Radial Response (In/Out Drag)", 0.05, 1.0, 0.05, "", "How quickly hand reach responds to mouse distance.")
	_create_hand_slider(core_section, "scale", "Mouse Reach Scale (Spatial Gearing)", 1.0, 10.0, 0.1, "×", "How much mouse travel is required to reach maximum hand range.")
	_create_hand_slider(core_section, "min", "Min Hand Range", 5.0, 140.0, 1.0, " px")
	_create_hand_slider(core_section, "max", "Max Hand Range", 5.0, 200.0, 1.0, " px")
	_create_hand_slider(core_section, "arc", "Arc Degrees", 5.0, 120.0, 1.0, "°")
	_create_hand_slider(core_section, "frequency", "Swing Frequency", 0.2, 3.0, 0.05, " Hz", "Form II: one cycle includes all thrusts sweeping across the longitudinal arcs. Form III-VI: one cycle includes the figure-eight lobes. Form VII uses repeated thrusts.")
	_create_hand_slider(core_section, "thrusts_per_cycle", "Form II — Thrusts per Sweep", 2.0, 15.0, 1.0, "", "Evenly spaced longitudinal thrust strokes across each half-cycle sweep, default 7. Thrusts bow out along meridian arcs converging at target X.")
	_create_hand_slider(core_section, "moulinet_aim_smoothing", "Form V — Aim Direction Smoothing", 0.05, 30.0, 0.05, " /s", "Original direction restored: lower values are slower and heavier; higher values reverse faster. The 0.05 /s minimum supports very slow momentum changes.")

	var grapple_section: VBoxContainer = _create_section_header(box, "GRAPPLE V1 (Global)")
	grapple_status_label = Label.new()
	grapple_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grapple_status_label.modulate = Color(1.0, 0.82, 0.36)
	grapple_section.add_child(grapple_status_label)
	_create_grapple_slider(grapple_section, "max_tether_length", "Hook Reach Limit", 200.0, 1000.0, 10.0, " px", _grapple_feel_tip("max_tether_length"))
	_create_grapple_slider(grapple_section, "hook_travel_speed", "Hook Flight Speed", 300.0, 3000.0, 50.0, " px/s", _grapple_feel_tip("hook_travel_speed"))
	_create_grapple_slider(grapple_section, "reel_speed", "Rope Shortening Speed", 0.0, 600.0, 5.0, " px/s", _grapple_feel_tip("reel_speed"))
	_create_grapple_slider(grapple_section, "slack_take_up_speed", "Initial Slack Recovery", 0.0, 600.0, 5.0, " px/s", _grapple_feel_tip("slack_take_up_speed"))
	_create_grapple_slider(grapple_section, "initial_slack", "Initial Attachment Slack", 0.0, 120.0, 1.0, " px", _grapple_feel_tip("initial_slack"))
	_create_grapple_slider(grapple_section, "taut_catch_impulse_seconds", "Taut-Catch Hand Burst", 0.0, 0.5, 0.01, " s", _grapple_feel_tip("taut_catch_impulse_seconds"))
	_create_grapple_slider(grapple_section, "yoyo_catch_radial_retention", "Yo-yo Catch Radial Retention", 0.0, 1.0, 0.05, "×", _grapple_feel_tip("yoyo_catch_radial_retention"))
	_create_grapple_slider(grapple_section, "tension_ramp_distance", "Tension Stiffness Distance", 1.0, 40.0, 1.0, " px", _grapple_feel_tip("tension_ramp_distance"))
	_create_grapple_slider(grapple_section, "enemy_pull_strength", "Light Target Reel Force", 100.0, 3000.0, 50.0, " px/s²", _grapple_feel_tip("enemy_pull_strength"))
	_create_grapple_slider(grapple_section, "light_yank_strength", "Light Target Hand Gain", 0.0, 12.0, 0.25, "×", _grapple_feel_tip("light_yank_strength"))
	_create_grapple_slider(grapple_section, "light_slide_fraction", "Light Target Momentum Tail", 0.0, 0.25, 0.01, "×", _grapple_feel_tip("light_slide_fraction"))
	_create_grapple_slider(grapple_section, "medium_reel_multiplier", "Medium Target Reel Scale", 0.0, 1.0, 0.05, "×", _grapple_feel_tip("medium_reel_multiplier"))
	_create_grapple_slider(grapple_section, "medium_yank_strength", "Medium Target Hand Gain", 0.0, 8.0, 0.25, "×", _grapple_feel_tip("medium_yank_strength"))
	_create_grapple_slider(grapple_section, "medium_slide_fraction", "Medium Target Momentum Tail", 0.0, 0.15, 0.01, "×", _grapple_feel_tip("medium_slide_fraction"))
	_create_grapple_slider(grapple_section, "medium_player_pull_strength", "Medium Target Player Pull", 100.0, 4000.0, 50.0, " px/s²", _grapple_feel_tip("medium_player_pull_strength"))
	_create_grapple_slider(grapple_section, "heavy_player_pull_strength", "Heavy Target Player Pull", 100.0, 5000.0, 50.0, " px/s²", _grapple_feel_tip("heavy_player_pull_strength"))
	_create_grapple_slider(grapple_section, "chakram_tether_strength", "Chakram Recall Force", 100.0, 3000.0, 50.0, " px/s²", _grapple_feel_tip("chakram_tether_strength"))
	_create_grapple_slider(grapple_section, "chakram_yank_strength", "Chakram Hand-Steering Gain", 0.0, 16.0, 0.25, "×", _grapple_feel_tip("chakram_yank_strength"))
	_create_grapple_slider(grapple_section, "body_movement_transfer", "Body Movement Transfer", 0.0, 1.0, 0.05, "×", _grapple_feel_tip("body_movement_transfer"))
	var yoyo_section: VBoxContainer = _create_section_header(grapple_section, "GRAPPLE YO-YO (Global)", true)
	var yoyo_note: Label = Label.new()
	yoyo_note.text = "A rope intersection begins a manual bend. At Wrap Commit the Chakram automates inward, reverses out after an obstruction bounce, or damages and holds a fully coiled enemy as the grapple target."
	yoyo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	yoyo_section.add_child(yoyo_note)
	_create_grapple_slider(yoyo_section, "yoyo_enabled", "Yo-yo Sequence Enabled", 0.0, 1.0, 1.0, "", _grapple_feel_tip("yoyo_enabled"))
	_create_grapple_slider(yoyo_section, "yoyo_soft_tension_zone", "Yo-yo Catch Approach", 0.0, 180.0, 5.0, " px", _grapple_feel_tip("yoyo_soft_tension_zone"))
	_create_grapple_slider(yoyo_section, "yoyo_radial_damping", "Yo-yo Outward Catch Brake", 0.0, 40.0, 0.5, "×", _grapple_feel_tip("yoyo_radial_damping"))
	_create_grapple_slider(yoyo_section, "yoyo_orbit_drag", "Yo-yo Orbit Energy Burn", 0.0, 4.0, 0.05, " /s", _grapple_feel_tip("yoyo_orbit_drag"))
	_create_grapple_slider(yoyo_section, "yoyo_orbit_slack_recovery_speed", "Yo-yo Orbit Slack Recovery", 0.0, 600.0, 5.0, " px/s", _grapple_feel_tip("yoyo_orbit_slack_recovery_speed"))
	_create_grapple_slider(yoyo_section, "yoyo_min_orbit_time", "Yo-yo Hang Time", 0.0, 4.0, 0.05, " s", _grapple_feel_tip("yoyo_min_orbit_time"))
	_create_grapple_slider(yoyo_section, "yoyo_recall_speed_threshold", "Yo-yo Reel Energy Threshold", 0.0, 500.0, 10.0, " px/s", _grapple_feel_tip("yoyo_recall_speed_threshold"))
	_create_grapple_slider(yoyo_section, "yoyo_static_pivot_enabled", "Yo-yo Static Tether Point", 0.0, 1.0, 1.0, "", _grapple_feel_tip("yoyo_static_pivot_enabled"))
	_create_grapple_slider(yoyo_section, "yoyo_boundary_wrap_enabled", "Tether Wrap Enabled", 0.0, 1.0, 1.0, "", _grapple_feel_tip("yoyo_boundary_wrap_enabled"))
	_create_grapple_slider(yoyo_section, "yoyo_wrap_commit_turns", "Wrap Commit Point", 0.10, 1.0, 0.05, " turns", _grapple_feel_tip("yoyo_wrap_commit_turns"))
	_create_grapple_slider(yoyo_section, "yoyo_coil_revolutions", "Automated Coil Revolutions", 1.0, 2.0, 0.1, " turns", _grapple_feel_tip("yoyo_coil_revolutions"))
	_create_grapple_slider(yoyo_section, "yoyo_coil_tangential_speed", "Tangential Coil Speed", 200.0, 1200.0, 20.0, " px/s", _grapple_feel_tip("yoyo_coil_tangential_speed"))
	_create_grapple_slider(yoyo_section, "yoyo_coil_radial_speed", "Radial Cinch Speed", 40.0, 600.0, 10.0, " px/s", _grapple_feel_tip("yoyo_coil_radial_speed"))
	_create_grapple_slider(yoyo_section, "yoyo_coil_speed_gain", "Tightening Speed Gain", 0.0, 1.0, 0.05, "×", _grapple_feel_tip("yoyo_coil_speed_gain"))
	_create_grapple_slider(yoyo_section, "yoyo_coil_hold_duration", "Completed Coil Hold", 0.0, 3.0, 0.05, " s", _grapple_feel_tip("yoyo_coil_hold_duration"))
	_create_grapple_slider(yoyo_section, "yoyo_unwind_speed", "Obstruction Unwind Speed", 60.0, 1000.0, 10.0, " px/s", _grapple_feel_tip("yoyo_unwind_speed"))
	_create_grapple_slider(grapple_section, "directional_transfer_ratio", "Dynamic Target Direction Transfer", 0.0, 1.0, 0.05, "×", _grapple_feel_tip("directional_transfer_ratio"))
	_create_grapple_slider(grapple_section, "radial_yank_ratio", "Dynamic Target Outward Bias", 0.0, 2.0, 0.05, "×", _grapple_feel_tip("radial_yank_ratio"))
	_create_grapple_slider(grapple_section, "player_hand_orbit_strength", "Player Tangential Steering Gain", 0.0, 12.0, 0.25, "×", _grapple_feel_tip("player_hand_orbit_strength"))
	_create_grapple_slider(grapple_section, "player_radial_yank_strength", "Player Outward Pull Gain", 0.0, 8.0, 0.25, "×", _grapple_feel_tip("player_radial_yank_strength"))
	_create_grapple_slider(grapple_section, "hand_velocity_smoothing", "Hand Signal Response", 1.0, 40.0, 1.0, " /s", _grapple_feel_tip("hand_velocity_smoothing"))
	_create_grapple_slider(grapple_section, "hand_velocity_cap", "Hand Signal Speed Ceiling", 300.0, 3000.0, 50.0, " px/s", _grapple_feel_tip("hand_velocity_cap"))
	_create_grapple_slider(grapple_section, "wall_pull_strength", "Terrain Player Pull Force", 250.0, 6000.0, 50.0, " px/s²", _grapple_feel_tip("wall_pull_strength"))
	_create_grapple_slider(grapple_section, "grapple_dash_traction", "Grapple-Dash Steering Retention", 0.0, 1.0, 0.05, "×", _grapple_feel_tip("grapple_dash_traction"))

	var flesh_section: VBoxContainer = _create_section_header(box, "FLESH HIT FEEL (Per Preset)")
	_create_contact_slider(flesh_section, "flesh_hitstop_min", "Weak Hitstop", 0.0, 0.3, 0.01, " s")
	_create_contact_slider(flesh_section, "flesh_hitstop_max", "Strong Hitstop", 0.0, 0.3, 0.01, " s")
	_create_contact_slider(flesh_section, "flesh_stagger_min", "Weak Enemy Stagger", 0.0, 0.8, 0.02, " s")
	_create_contact_slider(flesh_section, "flesh_stagger_max", "Strong Enemy Stagger", 0.0, 1.2, 0.02, " s")
	_create_contact_slider(flesh_section, "flesh_shake_strength", "Screen Shake Strength", 0.0, 15.0, 0.5, " px")
	_create_contact_slider(flesh_section, "flesh_shake_duration", "Screen Shake Duration", 0.0, 0.5, 0.01, " s")
	_create_contact_slider(flesh_section, "flesh_zoom", "Micro Zoom", 0.0, 0.1, 0.005, "×")
	_create_contact_slider(flesh_section, "flesh_zoom_duration", "Zoom Duration", 0.0, 0.5, 0.01, " s")
	_create_contact_slider(flesh_section, "flesh_recoil", "Player Body Recoil", 0.0, 120.0, 5.0, " px")
	_create_contact_slider(flesh_section, "flesh_impact", "Impact / Speed-Line Intensity", 0.0, 2.5, 0.05, "×")
	_create_contact_slider(flesh_section, "flesh_contact_drag", "Contact Drag Dip", 0.0, 0.6, 0.01, "×", "How much the swing's phase-advance rate briefly dips on a clean hit -- the \"shhk\" of cutting through resistance. Replaces the old Bite freeze.")
	_create_contact_slider(flesh_section, "flesh_contact_drag_recovery", "Contact Drag Recovery Time", 0.01, 0.4, 0.01, " s", "Seconds for the dip to fully recover back to full swing speed.")

	var contact_section: VBoxContainer = _create_section_header(box, "BLADE CONTACT FEEL (Per Preset)")
	_create_contact_slider(contact_section, "contact_hitstop", "Glancing Contact Hitstop", 0.0, 0.2, 0.005, " s")
	_create_contact_slider(contact_section, "contact_shake_strength", "Screen Shake Strength", 0.0, 10.0, 0.25, " px")
	_create_contact_slider(contact_section, "contact_shake_duration", "Screen Shake Duration", 0.0, 0.4, 0.01, " s")
	_create_contact_slider(contact_section, "contact_zoom", "Micro Zoom", 0.0, 0.1, 0.005, "×")
	_create_contact_slider(contact_section, "contact_zoom_duration", "Zoom Duration", 0.0, 0.4, 0.01, " s")
	_create_contact_slider(contact_section, "contact_impact", "Impact / Speed-Line Intensity", 0.0, 2.5, 0.05, "×")

	# Slide is shared contact behavior, so its controls stay visible for every form.
	var slide_section: VBoxContainer = _create_section_header(box, "SLIDE FEEL (Per Preset)")
	_create_contact_slider(slide_section, "slide_contact_tolerance", "Contact Tolerance", 2.0, 30.0, 1.0, " px", _form_three_feel_tip("Maximum blade-to-blade distance that may begin a parallel slide.", "Precise contact; slides are rarer and may miss under fast motion.", "Forgiving proximity; slides are easier, but near misses may count.", "This helps achieve a slide; Form III Bind Retention Tolerance controls keeping it."))
	_create_contact_slider(slide_section, "slide_angle", "Angle Tolerance", 5.0, 90.0, 1.0, "°", _form_three_feel_tip("How close to parallel the blades must be for a slide instead of a crossing clash.", "Only nearly parallel blades slide; clear classification but harder entry.", "More diagonal contacts may slide; easier entry but fewer contacts read as clashes.", "Try 40–45° for a forgiving Form III profile without making every crossing a slide."))
	_create_contact_slider(slide_section, "slide_cling", "Cling Duration", 0.0, 2.5, 0.02, " s", _form_three_feel_tip("How long slide friction and sword-speed drag remain available after slide entry.", "Brief scrape that quickly returns to free motion.", "Longer weighted contact that gives Form III more time to capture.", "This is entry assistance, not guaranteed physical contact. The range is extended for longer experiments."))
	_create_contact_slider(slide_section, "slide_friction", "Movement Friction", 0.05, 1.0, 0.05, "×", _form_three_feel_tip("Player body movement multiplier while slide cling is active.", "Strong anchoring; body motion slows heavily around the contact.", "Nearly normal movement; easier repositioning but easier to walk out of the slide.", "This multiplier is inverse-feeling: left means more friction, right means less."))
	_create_contact_slider(slide_section, "slide_speed", "Sword Speed Multiplier", 0.1, 1.0, 0.02, "×", _form_three_feel_tip("Autonomous sword-phase speed during ordinary slide cling and Form III capture.", "Blade becomes heavier and more static, giving contact time to settle.", "Metronome keeps sweeping near full speed and may carry the blade out of contact.", "This affects slide entry; Bound Sword Speed takes over after stable Form III capture."))
	_create_contact_slider(slide_section, "slide_duration", "Visual Duration", 0.05, 2.5, 0.05, " s", _form_three_feel_tip("Lifetime of the slide spark/travel presentation.", "Short, crisp visual confirmation.", "Long visible scrape trail that can outlive the mechanical contact.", "Presentation only: this does not maintain collision or extend a bind."))
	_create_contact_slider(slide_section, "slide_travel", "Spark Travel", 10.0, 100.0, 5.0, " px", _form_three_feel_tip("Distance slide sparks travel along the blade.", "Compact sparks near the contact point.", "Long streaks that communicate blade travel more clearly.", "Presentation only."))
	_create_contact_slider(slide_section, "slide_spread", "Spark Spread", 0.0, 15.0, 0.5, " px", _form_three_feel_tip("Random width around the slide spark path.", "Tight, clean line hugging the blade.", "Broad, rough shower of metal sparks.", "Presentation only."))
	_create_hand_slider(slide_section, "slide_sparks", "Spark Count", 0.0, 20.0, 1.0, "", _form_three_feel_tip("Number of sparks emitted by a slide.", "Subtle or invisible contact feedback.", "Dense, bright scrape feedback.", "Presentation only; high values can obscure blade geometry."))
	_create_contact_slider(slide_section, "slide_hitstop", "Entry Hitstop", 0.0, 0.15, 0.005, " s", _form_three_feel_tip("One-time freeze when a slide first registers.", "Fluid contact with no pause.", "Punchier entry, but long values can make a scrape feel like a clash.", "Keep this much shorter than clash hitstop."))
	_create_contact_slider(slide_section, "slide_shake_strength", "Screen Shake Strength", 0.0, 8.0, 0.25, " px", _form_three_feel_tip("Camera shake distance on slide entry.", "Smooth and controlled.", "Rougher metallic impact.", "Presentation only."))
	_create_contact_slider(slide_section, "slide_shake_duration", "Screen Shake Duration", 0.0, 0.4, 0.01, " s", _form_three_feel_tip("How long entry shake decays.", "Quick pulse.", "Lingering vibration that may muddy sustained binds.", "Tune after shake strength."))
	_create_contact_slider(slide_section, "slide_zoom", "Micro Zoom", 0.0, 0.1, 0.005, "×", _form_three_feel_tip("Brief camera zoom added at slide entry.", "No framing interruption.", "Stronger emphasis on every qualifying scrape.", "Presentation only; stable bind focus has separate zoom."))
	_create_contact_slider(slide_section, "slide_zoom_duration", "Zoom Duration", 0.0, 0.4, 0.01, " s", _form_three_feel_tip("How long slide-entry zoom takes to settle.", "Fast visual pulse.", "Slower cinematic settle.", "Keep this below typical Capture Time if you want bind focus to feel like a second beat."))
	_create_contact_slider(slide_section, "slide_impact", "Presentation Intensity", 0.0, 2.5, 0.05, "×", _form_three_feel_tip("Overall impact/speed-line intensity for slide entry.", "Quiet, readable blade geometry.", "Bold contact accent with more visual energy.", "Presentation only."))

	# Bind remains form-specific and is the only conditional part of this area.
	var unified_bind_content: VBoxContainer = _create_section_header(box, "BIND FEEL (All Weapons)", true)
	var bind_note: Label = Label.new()
	bind_note.text = "One authoritative profile for both legacy Bind IDs and every sword."
	bind_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unified_bind_content.add_child(bind_note)
	var bind_section: VBoxContainer = _create_section_header(unified_bind_content, "STABLE BIND", true)
	# Existing bind slider construction below targets this content variable.
	experimental_bind_section = bind_section
	_create_hand_slider(experimental_bind_section, "bind_enabled", "Bind Enabled", 0.0, 1.0, 1.0, "", _form_three_feel_tip("Master switch for Form III bind capture. Ordinary blade collisions still work while this is off.", "Bind capture is disabled; Form III behaves like its Form II baseline.", "Validated slides can mature into stable binds.", "Use this as an instant A/B comparison without touching the other values."))
	_create_hand_slider(experimental_bind_section, "bind_capture_time", "Capture Time", 0.02, 0.40, 0.01, " s", _form_three_feel_tip("Continuous blade contact and minimum pressure required before focus begins.", "Binds engage quickly and feel eager, but incidental slides may capture.", "Binds require a longer deliberate press and feel more earned, but may be hard to establish.", "Start near 0.10 s; adjust this before changing retention."))
	_create_hand_slider(experimental_bind_section, "bind_contact_tolerance", "Contact Retention Tolerance", 7.0, 30.0, 1.0, " px", _form_three_feel_tip("Maximum blade-edge separation before Release Grace begins. It cannot create the initial slide.", "Precise, brittle contact that releases from small gaps.", "Forgiving, sticky contact that survives wider gaps and rough motion.", "Raise only until normal hand jitter stops breaking good binds; too high can feel magnetic."))
	_create_hand_slider(experimental_bind_section, "bind_pressure_min", "Minimum Pressure", 0.0, 160.0, 2.0, " px/s", _form_three_feel_tip("Relative motion required into the opposing blade normal to capture a bind. Tangential scraping is measured separately.", "Light or nearly passive contact captures easily.", "The player must push decisively into the guard before focus starts.", "If binds trigger while merely brushing past, move right. If they never start, move left."))
	_create_hand_slider(experimental_bind_section, "bind_retention_strength", "Geometric Retention", 0.0, 1.0, 0.05, "×", _form_three_feel_tip("Single-opponent hinge resistance during capture and stable binds. It keeps the blades on their original side and never reacquires a separated weapon.", "Loose, slippery blades that can cross more easily.", "Firm two-doors-on-hinges resistance; pushing through is blocked while opening away remains controllable.", "Only the current bind owner is constrained, so other enemies cannot combine into a multi-sword pin."))
	_create_hand_slider(experimental_bind_section, "bind_sword_speed", "Bound Sword Speed", 0.05, 1.0, 0.05, "×", _form_three_feel_tip("Player sword phase/input speed while bound, compensated against world slowdown.", "Heavy, deliberate blade motion; low values can drift away from the musical cadence.", "Full responsive sword motion and original metronome timing.", "Keep 1.00× when evaluating musical synchronization; lower it only as an intentional feel choice."))
	_create_hand_slider(experimental_bind_section, "bind_release_grace", "Release Grace", 0.0, 0.35, 0.01, " s", _form_three_feel_tip("Short contact memory after geometry separates.", "Immediate, crisp releases that may flicker under noisy contact.", "Forgiving releases that preserve context, but can feel sticky after the blades visibly part.", "Use the lowest value that survives ordinary one-frame collision gaps."))
	_create_hand_slider(experimental_bind_section, "bind_max_duration", "Maximum Bind", 0.2, 3.0, 0.05, " s", _form_three_feel_tip("Hard safety ceiling for one stable bind.", "Short, punchy exchanges that force quick decisions.", "Long blade conversations with more time to slide, wrap, or beat, but greater lock-up risk.", "This is a safety limit, not the normal release mechanism."))
	_create_hand_slider(experimental_bind_section, "bind_rebind_cooldown", "Re-bind Suppression", 0.0, 1.0, 0.02, " s", _form_three_feel_tip("Delay before a released interaction can capture another bind.", "Rapid repeated binds are possible and contact feels permissive.", "Every release creates a clear reset and failed techniques are more costly.", "Raise this if the same two blades chatter between bound and unbound states."))
	_create_hand_slider(experimental_bind_section, "bind_focus_time_scale", "World Speed", 0.2, 1.0, 0.05, "×", _form_three_feel_tip("World speed during a stable bind. Player aim, sword phase, and musical metronome remain real-time.", "More dramatic slow motion; the player sword feels faster relative to enemies.", "Less slowdown; at 1.00× the world runs normally.", "0.60× is the authored starting point. Tune zoom and response after choosing this."))
	_create_hand_slider(experimental_bind_section, "bind_focus_zoom", "Focus Zoom", 0.0, 0.30, 0.01, "+", _form_three_feel_tip("Sustained camera-only zoom while a stable bind is active.", "Wider tactical view with little or no cinematic emphasis.", "Closer, more intimate blade focus with less peripheral visibility.", "0.15 is approximately a fifteen-percent zoom."))
	_create_hand_slider(experimental_bind_section, "bind_focus_bias", "Contact Framing", 0.0, 1.0, 0.05, "×", _form_three_feel_tip("How strongly the camera center favors the live blade contact point over the player.", "Camera stays centered on the player.", "Camera pulls strongly toward the blades and opponent.", "Pair high bias with modest zoom so the player does not feel pushed off-screen."))
	_create_hand_slider(experimental_bind_section, "bind_focus_response", "Focus Response", 1.0, 20.0, 0.5, "×", _form_three_feel_tip("Real-time interpolation speed for focus zoom and contact framing.", "Slow, floaty camera easing with a soft cinematic arrival.", "Fast, snappy focus that locks onto contact immediately.", "If focus feels like a camera jolt, move left; if it arrives after the bind is nearly over, move right."))
	_create_hand_slider(experimental_bind_section, "bind_scrape_interval", "Scrape Interval", 0.08, 0.60, 0.02, " s", _form_three_feel_tip("Minimum spacing between scrape audio pulses during tangential blade travel.", "Frequent, busy metallic chatter.", "Sparse, individually readable scrape accents.", "Move right if the scrape sounds like a loop; move left if long slides feel silent."))
	_create_hand_slider(experimental_bind_section, "bind_disengage_min_time", "Guard-Wrap Contact Time", 0.02, 0.40, 0.01, " s", _form_three_feel_tip("Minimum stable-bind history before endpoint release may qualify as a guard wrap.", "Quick wraps are accepted, including less deliberate ones.", "The player must work the bind longer before a disengagement can be earned.", "Increase this if fast taps are being labeled as guard wraps."))
	_create_hand_slider(experimental_bind_section, "bind_disengage_min_travel", "Guard-Wrap Travel", 2.0, 50.0, 1.0, " px", _form_three_feel_tip("Minimum real tangential travel along the opponent's weapon before release.", "Small slides can qualify and wraps feel accessible.", "A long, clearly visible blade run is required.", "Tune alongside Endpoint Progress: one measures pixels, the other measures blade proportion."))
	_create_hand_slider(experimental_bind_section, "bind_disengage_fraction_delta", "Endpoint Progress", 0.02, 0.50, 0.01, "×", _form_three_feel_tip("Required change in contact fraction toward one end of the opposing blade.", "Minor contact drift can count as endpoint progress.", "The contact must traverse a large portion of the enemy blade.", "Raise this if stationary binds qualify; lower it if short enemy weapons make wraps impossible."))
	_create_hand_slider(experimental_bind_section, "bind_disengage_endpoint", "Endpoint Zone", 0.05, 0.40, 0.01, "×", _form_three_feel_tip("Size of the qualifying zone at each end of the enemy blade.", "Narrow, precise endpoint exits.", "Broad, forgiving endpoint zones that are easier to reach.", "This changes where release qualifies, not how much travel is required."))
	_create_hand_slider(experimental_bind_section, "bind_disengage_leverage", "Disengage Leverage", -0.50, 0.60, 0.02, "×", _form_three_feel_tip("Minimum leverage for a guard wrap. Positive means your contact is closer to your hilt than the enemy's is to theirs.", "Disadvantaged positions may still qualify, making wraps easy but less physical.", "Only strong mechanical advantage qualifies, making wraps rarer and cleaner.", "Watch the live Leverage readout before deciding where this threshold belongs."))
	_create_hand_slider(experimental_bind_section, "bind_reentry_window", "Re-entry Memory", 0.10, 0.60, 0.01, " s", _form_three_feel_tip("Short geometry-memory window after a valid guard wrap. Damage still requires a new swept body hit.", "Fast, demanding re-entry with little stale context.", "Generous follow-up timing that is easier to use but may feel combo-like.", "Keep this short enough that the new hit visibly belongs to the disengagement."))
	_create_hand_slider(experimental_bind_section, "bind_reentry_min_speed", "Re-entry Impact Speed", 50.0, 500.0, 10.0, " px/s", _form_three_feel_tip("Minimum impact speed of the separate re-entry body collision.", "Soft touches receive the re-entry reward.", "Only committed cutting speed qualifies.", "Raise this if slow blade placement is earning bonus damage."))
	_create_hand_slider(experimental_bind_section, "bind_reentry_inward_speed", "Re-entry Inward Speed", 0.0, 300.0, 5.0, " px/s", _form_three_feel_tip("Required blade velocity from the release point back toward the opponent's body.", "Sideways or weakly inward hits qualify more easily.", "The follow-up must drive clearly back into the opponent.", "This is the main protection against a nearby accidental hit consuming re-entry memory."))
	_create_hand_slider(experimental_bind_section, "bind_reentry_damage", "Re-entry Damage", 1.0, 2.0, 0.05, "×", _form_three_feel_tip("Damage multiplier for a qualified re-entry collision.", "Little or no damage reward; technique value stays positional.", "Large payoff for completing the full wrap-and-hit sequence.", "Tune only after qualification feels reliable; this does not make qualification easier."))
	_create_hand_slider(experimental_bind_section, "bind_reentry_stagger", "Re-entry Stagger", 1.0, 2.0, 0.05, "×", _form_three_feel_tip("Enemy stagger multiplier for a qualified re-entry collision.", "Enemy recovers normally and the follow-up stays fluid.", "Re-entry creates a stronger, longer opening.", "High damage plus high stagger can snowball; raise one reward at a time."))
	_create_hand_slider(experimental_bind_section, "bind_beat_pressure", "Beat Pressure", 80.0, 700.0, 10.0, " px/s", _form_three_feel_tip("Player-authored normal pressure required for a weapon beat after the bind is stable.", "Light pushes can beat the guard and may trigger unintentionally.", "A forceful committed strike into the opposing blade is required.", "Enemy or body movement cannot satisfy this by itself."))
	_create_hand_slider(experimental_bind_section, "bind_beat_spike", "Beat Acceleration Spike", 20.0, 400.0, 10.0, " px/s", _form_three_feel_tip("Required frame-to-frame increase in player-authored pressure. Steady pressure cannot repeat beats.", "Smooth pressure ramps can qualify and beats feel easy.", "Only a sharp acceleration spike qualifies, emphasizing a distinct strike.", "Tune this after Beat Pressure: pressure sets force, spike sets suddenness."))
	_create_hand_slider(experimental_bind_section, "bind_beat_leverage", "Beat Leverage", -0.30, 0.60, 0.02, "×", _form_three_feel_tip("Minimum mechanical advantage required to move the enemy weapon instead of rebounding.", "Even poor lever positions can succeed, reducing rejected beats.", "Only favorable hilt geometry succeeds; more attempts recoil the player.", "Use the live Leverage value to separate intentional beats from frontal shoves."))
	_create_hand_slider(experimental_bind_section, "bind_beat_stagger", "Beat Weapon Stagger", 0.05, 0.80, 0.01, " s", _form_three_feel_tip("How long a successful beat displaces the enemy weapon stance. It deals no health damage.", "Brief deflection with a tight follow-up opening.", "Long, obvious weapon displacement with a generous opening.", "This is weapon control, not a free counter or invulnerability window."))
	_create_hand_slider(experimental_bind_section, "bind_beat_recoil", "Beat Weapon Recoil", 20.0, 300.0, 5.0, " px/s", _form_three_feel_tip("Physical enemy recoil after a valid pressure spike and leverage check.", "Subtle guard movement that preserves close distance.", "Strong displacement that visibly wins space but may push the target out of reach.", "If successful beats ruin the follow-up distance, move left."))
	_create_hand_slider(experimental_bind_section, "bind_failed_beat_recoil", "Rejected Beat Recoil", 0.0, 220.0, 5.0, " px/s", _form_three_feel_tip("Player recoil when a high-pressure beat is attempted from bad leverage.", "Little consequence, allowing repeated forceful attempts.", "Strong self-displacement that makes poor leverage clearly costly.", "Raise this to discourage spam; lower it if one mistake breaks combat flow too harshly."))
	# _create_section_header returns its content container; retain the outer
	# section so visibility also hides the header for non-Bind forms.
	experimental_bind_section = unified_bind_content.get_parent() as VBoxContainer

	var clash_section: VBoxContainer = _create_section_header(box, "CLASH FEEL (Per Preset)")
	_create_contact_slider(clash_section, "clash_contact_tolerance", "Contact Tolerance", 2.0, 30.0, 1.0, " px")
	_create_contact_slider(clash_section, "clash_angle_min", "Crossing Angle Min", 10.0, 60.0, 1.0, "°")
	_create_contact_slider(clash_section, "clash_angle_max", "Crossing Angle Max", 45.0, 90.0, 1.0, "°")
	_create_contact_slider(clash_section, "clash_cooldown", "Cooldown / Buffer", 0.0, 1.0, 0.05, " s")
	_create_contact_slider(clash_section, "clash_player_recoil", "Player Recoil", 0.0, 500.0, 10.0, " px")
	_create_contact_slider(clash_section, "clash_enemy_recoil", "Enemy Recoil", 0.0, 500.0, 10.0, " px")
	_create_contact_slider(clash_section, "clash_hitstop", "Hitstop", 0.0, 0.35, 0.01, " s")
	_create_contact_slider(clash_section, "clash_stagger", "Enemy Stagger", 0.0, 0.8, 0.02, " s")
	_create_contact_slider(clash_section, "clash_recovery", "Player Recovery", 0.0, 0.6, 0.02, " s")
	_create_contact_slider(clash_section, "clash_flow", "Flow Penalty", 0.0, 25.0, 1.0, "")
	_create_hand_slider(clash_section, "clash_sparks", "Spark Count", 0.0, 20.0, 1.0, "")
	_create_contact_slider(clash_section, "clash_shake_strength", "Screen Shake Strength", 0.0, 20.0, 0.5, " px")
	_create_contact_slider(clash_section, "clash_shake_duration", "Screen Shake Duration", 0.0, 0.6, 0.01, " s")
	_create_contact_slider(clash_section, "clash_zoom", "Micro Zoom", 0.0, 0.1, 0.005, "×")
	_create_contact_slider(clash_section, "clash_zoom_duration", "Zoom Duration", 0.0, 0.5, 0.01, " s")
	_create_contact_slider(clash_section, "clash_impact", "Impact / Speed-Line Intensity", 0.0, 2.5, 0.05, "×")

	var parry_section: VBoxContainer = _create_section_header(box, "PARRY FEEL (Per Preset)")
	_create_contact_slider(parry_section, "parry_contact_tolerance", "Contact Tolerance", 2.0, 30.0, 1.0, " px")
	_create_contact_slider(parry_section, "parry_rotation_speed", "Enemy Blade Rotation Speed", 1.0, 20.0, 0.5, " rad/s")
	_create_contact_slider(parry_section, "parry_cooldown", "Cooldown", 0.1, 3.0, 0.1, " s")
	_create_contact_slider(parry_section, "parry_player_recoil", "Player Recoil", 0.0, 400.0, 10.0, " px")
	_create_contact_slider(parry_section, "parry_enemy_recoil", "Enemy Recoil", 0.0, 500.0, 10.0, " px")
	_create_contact_slider(parry_section, "parry_hitstop", "Hitstop", 0.0, 0.35, 0.01, " s")
	_create_contact_slider(parry_section, "parry_stagger", "Enemy Stagger", 0.05, 1.5, 0.05, " s")
	_create_contact_slider(parry_section, "parry_recovery", "Player Recovery", 0.0, 0.5, 0.02, " s")
	_create_hand_slider(parry_section, "parry_sparks", "Spark Count", 0.0, 20.0, 1.0, "")
	_create_contact_slider(parry_section, "parry_shake_strength", "Screen Shake Strength", 0.0, 15.0, 0.5, " px")
	_create_contact_slider(parry_section, "parry_shake_duration", "Screen Shake Duration", 0.0, 0.5, 0.01, " s")
	_create_contact_slider(parry_section, "parry_zoom", "Micro Zoom", 0.0, 0.1, 0.005, "×")
	_create_contact_slider(parry_section, "parry_zoom_duration", "Zoom Duration", 0.0, 0.5, 0.01, " s")
	_create_contact_slider(parry_section, "parry_focus", "Focus Vignette Strength", 0.0, 1.0, 0.05, "×")
	_create_contact_slider(parry_section, "parry_focus_duration", "Focus Vignette Duration", 0.0, 0.5, 0.01, " s")
	_create_contact_slider(parry_section, "parry_impact", "Impact / Speed-Line Intensity", 0.0, 2.5, 0.05, "×")

	var strike_section: VBoxContainer = _create_section_header(box, "STRIKE KINETICS & REBOUND (Per Preset)")
	_create_contact_slider(strike_section, "blade_freeze_duration", "Clash/Parry Weapon Freeze Duration", 0.0, 0.25, 0.005, " s", "Locks the blade angle momentarily on a clash or parry (weapon-on-weapon contact only -- flesh and hilt hits use Contact Drag instead, see the Flesh Hit Feel and Hilt Bash sections).")
	_create_contact_slider(strike_section, "bite_velocity_transfer", "Clash/Parry Freeze Momentum Transfer", 0.0, 1.5, 0.05, "×", "How much real body/hilt velocity carries through the blade during and upon release of a clash/parry weapon freeze.")
	_create_contact_slider(strike_section, "blade_recoil_degrees", "Weapon Blade Recoil (Bounce)", 0.0, 60.0, 1.0, "°", "Angular kickback of the sword itself upon striking flesh, clash, or parry, separate from body pushback.")
	_create_contact_slider(strike_section, "blade_recoil_return", "Blade Recoil Return Speed", 100.0, 1500.0, 50.0, "°/s", "How quickly the blade recovers from its angular bounce.")
	_create_contact_slider(strike_section, "rebound_flow_boost", "Rebound Flow Boost (Go With It)", 1.0, 3.5, 0.1, "×", "When you turn your aim WITH the bounce direction during recoil, rotation speed surges into a snappy spin cut.")
	_create_contact_slider(strike_section, "grip_authority_duration", "Grip Authority Duration", 0.0, 0.40, 0.01, " s", "Window immediately after a strike where your wrist has high authority to redirect.")
	_create_contact_slider(strike_section, "grip_turn_speed_mult", "Grip Turn Speed Multiplier", 1.0, 4.0, 0.1, "×", "Multiplier applied to max turn speed during the Grip Authority window.")
	_create_contact_slider(strike_section, "blade_roll_speed", "Blade Roll Speed (Edge Flip)", 1.0, 20.0, 0.5, " /s", "How fast every weapon rolls to keep its edge leading actual travel. Higher = snappier flip. Symmetric weapons may show little visual change, but use the same universal rollover logic.")

	var hilt_section: VBoxContainer = _create_section_header(box, "HILT BASH & POINT-BLANK (Per Preset)")
	_create_contact_slider(hilt_section, "hilt_bash_enabled", "Hilt Bash Enabled (0 = Off, 1 = On)", 0.0, 1.0, 1.0, "", "Master switch. Set to 0 to restore ignored hilt contact; set to 1 to enable bash, shove, stun, and dizzy stars.")
	_create_contact_slider(hilt_section, "hilt_bash_knockback", "Hilt Bash Shove Impulse", 100.0, 600.0, 20.0, " px/s", "Outward knockback applied when an enemy touches your inner hilt deadzone.")
	_create_contact_slider(hilt_section, "hilt_bash_stun", "Hilt Bash Stun Duration", 0.10, 0.80, 0.05, " s", "Duration of stun and dizzy stars/birdies above enemy head.")
	_create_contact_slider(hilt_section, "hilt_bash_damage", "Hilt Bash Chip Damage", 0.0, 20.0, 1.0, "", "Low damage dealt by the pommel strike.")
	_create_contact_slider(hilt_section, "hilt_contact_drag", "Hilt Contact Drag Dip", 0.0, 0.6, 0.01, "×", "Swing phase-advance dip on a hilt bash, same mechanism as Flesh Contact Drag.")
	_create_contact_slider(hilt_section, "hilt_contact_drag_recovery", "Hilt Contact Drag Recovery Time", 0.01, 0.4, 0.01, " s")

	var farmable_section: VBoxContainer = _create_section_header(box, "FARMABLE HARVEST FEEL (Per Preset)")
	_create_contact_slider(farmable_section, "farmable_hitstop", "Harvest Hitstop", 0.0, 0.1, 0.005, " s", "Tiny freeze so cutting a 1-shot farmable (herb, mushroom, shrub, moon flower) registers as something landing. Deliberately much lighter than a real flesh hit -- no shake, sparks, or recoil at all.")
	_create_contact_slider(farmable_section, "farmable_contact_drag", "Harvest Contact Drag Dip", 0.0, 0.3, 0.01, "×", "Swing phase-advance dip on a harvest hit, same mechanism as Flesh Contact Drag but much lighter.")
	_create_contact_slider(farmable_section, "farmable_contact_drag_recovery", "Harvest Contact Drag Recovery Time", 0.01, 0.3, 0.01, " s")

	var p3_section: VBoxContainer = _create_section_header(box, "PRESET 3: DYNAMIC METRONOME FLOW SCALING")
	_create_contact_slider(p3_section, "p3_min_arc_scale", "0% Flow Arc Scale", 0.20, 1.0, 0.05, "×", "At 0% flow the arc shrinks to this fraction of tuned arc (e.g. 0.55 = 55%), opening to 100% at full flow.")
	_create_contact_slider(p3_section, "p3_min_speed_scale", "0% Flow Swing Speed Scale", 0.20, 1.0, 0.05, "×", "At 0% flow cycle frequency slows to this fraction of tuned frequency, opening to 100% at full flow.")
	_create_contact_slider(p3_section, "p3_min_turn_scale", "0% Flow Aim Turn Scale", 0.20, 1.0, 0.05, "×", "At 0% flow turn responsiveness scales down to this fraction, feeling heavier until flow builds.")

	var p4_section: VBoxContainer = _create_section_header(box, "PRESET 4: FORM EVOLUTION")
	_create_contact_slider(p4_section, "p4_stage1_end", "Stage 1 (Thrusting A) End Flow", 10.0, 50.0, 5.0, "%", "Flow percentage where Form II: Thrusting A finishes morphing into Form I: Metronome V.")
	_create_contact_slider(p4_section, "p4_stage2_end", "Stage 2 (Metronome V) End Flow", 40.0, 90.0, 5.0, "%", "Flow percentage where Form I: Metronome V finishes morphing into Form III: Moulinet ∞.")
	_create_contact_slider(p4_section, "form_blend_smoothing", "Form Blend Smoothing Rate", 1.0, 25.0, 0.5, " /s", "Smoothing filter rate for Preset 4 form transitions so sudden flow spikes or drops do not jerk geometry.")

func _build_global_presets_tab(tabs: TabContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Global Presets"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "GLOBAL TUNING PRESETS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Each Global Preset is one complete package: sword/forms, grapple, Beat, camera, forest, and all four day phases. Use LOAD ON LAUNCH here—not inside an individual Forest phase. Bonus ranks are temporary and excluded."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	for slot: int in range(1, GlobalPresetConfig.SLOT_COUNT + 1):
		var row: VBoxContainer = VBoxContainer.new()
		row.name = "GlobalPreset%d" % slot
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(row)
		var title_row: HBoxContainer = HBoxContainer.new()
		title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title_row)
		var slot_label: Label = Label.new()
		slot_label.text = "GLOBAL PRESET %d" % slot
		slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(slot_label)
		var status_label: Label = Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title_row.add_child(status_label)
		var actions: HBoxContainer = HBoxContainer.new()
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_theme_constant_override("separation", 6)
		row.add_child(actions)
		var save_button: Button = Button.new()
		save_button.text = "SAVE ALL"
		save_button.focus_mode = Control.FOCUS_NONE
		save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save_button.pressed.connect(_save_global_preset.bind(slot))
		actions.add_child(save_button)
		var load_button: Button = Button.new()
		load_button.text = "LOAD ALL"
		load_button.focus_mode = Control.FOCUS_NONE
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_button.pressed.connect(_load_global_preset.bind(slot))
		actions.add_child(load_button)
		var launch_button: Button = Button.new()
		launch_button.text = "LOAD ON LAUNCH"
		launch_button.focus_mode = Control.FOCUS_NONE
		launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		launch_button.pressed.connect(_set_global_preset_launch.bind(slot))
		actions.add_child(launch_button)
		var delete_button: Button = Button.new()
		delete_button.text = "DELETE"
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		delete_button.pressed.connect(_request_delete_global_preset.bind(slot))
		actions.add_child(delete_button)
		global_preset_rows[slot] = {"status": status_label, "load": load_button, "launch": launch_button, "delete": delete_button}
	_refresh_global_preset_ui()

func _refresh_global_preset_ui() -> void:
	if global_preset_rows.is_empty():
		return
	var slots: Array[Dictionary] = GlobalPresetConfig.list_slots()
	var active_slot: int = int(main.call("get_global_preset_slot")) if is_instance_valid(main) and main.has_method("get_global_preset_slot") else 0
	for slot: int in range(1, GlobalPresetConfig.SLOT_COUNT + 1):
		var row: Dictionary = global_preset_rows.get(slot, {})
		var state: Dictionary = slots[slot - 1] if slot - 1 < slots.size() else {}
		var status: Label = row.get("status") as Label
		var load_button: Button = row.get("load") as Button
		var launch_button: Button = row.get("launch") as Button
		var delete_button: Button = row.get("delete") as Button
		if state.is_empty():
			status.text = "EMPTY"
			load_button.disabled = true
			launch_button.disabled = true
			delete_button.disabled = true
		else:
			var saved_at: String = str(state.get("saved_at", "saved"))
			var launch_slot: int = int(main.call("get_global_preset_launch_slot")) if is_instance_valid(main) and main.has_method("get_global_preset_launch_slot") else 0
			status.text = ("ACTIVE • " if active_slot == slot else "") + ("LAUNCH • " if launch_slot == slot else "") + saved_at
			load_button.disabled = false
			launch_button.disabled = false
			delete_button.disabled = false

func _save_global_preset(slot: int) -> void:
	if not is_instance_valid(main) or not main.has_method("save_global_preset"):
		return
	var saved: bool = bool(main.call("save_global_preset", slot))
	_set_disk_feedback("Global Preset %d saved: all tuning captured." % slot if saved else "Global Preset %d could not be saved." % slot)
	_refresh_global_preset_ui()
	_sync_combat_controls()

func _load_global_preset(slot: int) -> void:
	if not is_instance_valid(main) or not main.has_method("load_global_preset"):
		return
	var loaded: bool = bool(main.call("load_global_preset", slot))
	_set_disk_feedback("Global Preset %d loaded: all tuning restored." % slot if loaded else "Global Preset %d is empty." % slot)
	_refresh_global_preset_ui()
	_sync_combat_controls()
	_sync_bonus_rows()

func _set_global_preset_launch(slot: int) -> void:
	if not is_instance_valid(main) or not main.has_method("set_global_preset_launch_slot"):
		return
	var saved: bool = bool(main.call("set_global_preset_launch_slot", slot))
	_set_disk_feedback("Global Preset %d is now the complete launch package." % slot if saved else "Global Preset %d could not be set for launch." % slot)
	_refresh_global_preset_ui()
	_sync_combat_controls()

func _request_delete_global_preset(slot: int) -> void:
	var confirmation: ConfirmationDialog = ConfirmationDialog.new()
	confirmation.name = "ConfirmDeleteGlobalPreset%d" % slot
	confirmation.dialog_text = "Delete Global Preset %d?" % slot
	add_child(confirmation)
	confirmation.confirmed.connect(func() -> void:
		var deleted: bool = bool(main.call("delete_global_preset", slot)) if is_instance_valid(main) and main.has_method("delete_global_preset") else false
		_set_disk_feedback("Deleted Global Preset %d." % slot if deleted else "Global Preset %d could not be deleted." % slot)
		_refresh_global_preset_ui()
		confirmation.queue_free()
	)
	confirmation.canceled.connect(func() -> void: confirmation.queue_free())
	confirmation.popup_centered(Vector2(380.0, 150.0))

func _build_saves_tab(tabs: TabContainer) -> void:
	var saves_tab: VBoxContainer = VBoxContainer.new()
	saves_tab.name = "Saves"
	saves_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(saves_tab)

	var title: Label = Label.new()
	title.text = "COMBAT TUNING BACKUPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saves_tab.add_child(title)

	var hint: Label = Label.new()
	hint.text = "Snapshots never overwrite older backups. Every save stores all three presets, every sword style, and the Main Game preset."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saves_tab.add_child(hint)

	var create_row: HBoxContainer = HBoxContainer.new()
	create_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_theme_constant_override("separation", 6)
	saves_tab.add_child(create_row)

	snapshot_name_edit = LineEdit.new()
	snapshot_name_edit.placeholder_text = "Name this backup (e.g. Heavy Clash v3)"
	snapshot_name_edit.max_length = 64
	snapshot_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_name_edit.text_submitted.connect(_create_named_snapshot_from_text)
	create_row.add_child(snapshot_name_edit)

	var create_button: Button = Button.new()
	create_button.text = "Create Safe Save"
	create_button.focus_mode = Control.FOCUS_NONE
	create_button.pressed.connect(_create_named_snapshot)
	create_row.add_child(create_button)

	snapshot_feedback_label = Label.new()
	snapshot_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	snapshot_feedback_label.modulate = Color(0.4, 1.0, 0.4)
	saves_tab.add_child(snapshot_feedback_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	saves_tab.add_child(scroll)

	snapshot_list = VBoxContainer.new()
	snapshot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_list.add_theme_constant_override("separation", 8)
	scroll.add_child(snapshot_list)
	_refresh_snapshot_list()

func _create_named_snapshot_from_text(_submitted_text: String) -> void:
	_create_named_snapshot()

func _create_named_snapshot() -> void:
	var player: Player = _player()
	if player == null or snapshot_name_edit == null:
		return
	var snapshot: Dictionary = CombatSettingsConfig.create_snapshot(snapshot_name_edit.text, main_game_preset, player.combat_contact_preset, player.combat_hand_settings, player.combat_contact_settings, player.blade_profile_settings, player.combat_weapon_hand_settings)
	if snapshot.is_empty():
		_set_snapshot_feedback("Could not create backup.", false)
		return
	snapshot_name_edit.clear()
	_set_snapshot_feedback("Safe save created: %s — %s" % [str(snapshot.get("name", "Combat Backup")), _friendly_timestamp(str(snapshot.get("timestamp", "")))], true)
	_refresh_snapshot_list()

func _refresh_snapshot_list() -> void:
	if snapshot_list == null:
		return
	for child: Node in snapshot_list.get_children():
		snapshot_list.remove_child(child)
		child.queue_free()
	var snapshots: Array[Dictionary] = CombatSettingsConfig.list_snapshots()
	if snapshots.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No safe saves yet. Name one above and create it whenever a setup feels worth protecting."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		snapshot_list.add_child(empty_label)
		return
	for snapshot: Dictionary in snapshots:
		_add_snapshot_row(snapshot)

func _add_snapshot_row(snapshot: Dictionary) -> void:
	var panel_row: PanelContainer = PanelContainer.new()
	panel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_list.add_child(panel_row)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel_row.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)

	var name_label: Label = Label.new()
	name_label.text = str(snapshot.get("name", "Combat Backup"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(name_label)

	var timestamp_label: Label = Label.new()
	timestamp_label.text = "%s  •  Main Preset %d  •  Saved while testing P%d" % [_friendly_timestamp(str(snapshot.get("timestamp", ""))), int(snapshot.get("active_preset", 1)), int(snapshot.get("selected_preset", snapshot.get("active_preset", 1)))]
	timestamp_label.modulate = Color(0.72, 0.78, 0.86)
	timestamp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(timestamp_label)

	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 6)
	row.add_child(btn_container)

	var load_button: Button = Button.new()
	load_button.text = "Load"
	load_button.focus_mode = Control.FOCUS_NONE
	load_button.custom_minimum_size = Vector2(64.0, 44.0)
	load_button.pressed.connect(_load_snapshot.bind(str(snapshot.get("id", ""))))
	btn_container.add_child(load_button)

	var delete_button: Button = Button.new()
	delete_button.text = "🗑"
	delete_button.tooltip_text = "Delete this backup"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.custom_minimum_size = Vector2(44.0, 44.0)
	delete_button.modulate = Color(1.0, 0.5, 0.5)
	btn_container.add_child(delete_button)

	var confirm_container: HBoxContainer = HBoxContainer.new()
	confirm_container.visible = false
	confirm_container.add_theme_constant_override("separation", 4)
	row.add_child(confirm_container)

	var confirm_label: Label = Label.new()
	confirm_label.text = "Delete?"
	confirm_label.modulate = Color(1.0, 0.4, 0.4)
	confirm_container.add_child(confirm_label)

	var yes_btn: Button = Button.new()
	yes_btn.text = "Yes"
	yes_btn.focus_mode = Control.FOCUS_NONE
	yes_btn.custom_minimum_size = Vector2(50.0, 44.0)
	yes_btn.modulate = Color(1.0, 0.3, 0.3)
	yes_btn.pressed.connect(_confirm_delete_snapshot.bind(str(snapshot.get("id", "")), str(snapshot.get("name", "Combat Backup"))))
	confirm_container.add_child(yes_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "No"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.custom_minimum_size = Vector2(50.0, 44.0)
	cancel_btn.pressed.connect(func() -> void:
		confirm_container.visible = false
		btn_container.visible = true
	)
	confirm_container.add_child(cancel_btn)

	delete_button.pressed.connect(func() -> void:
		btn_container.visible = false
		confirm_container.visible = true
	)

func _confirm_delete_snapshot(snapshot_id: String, snapshot_name: String) -> void:
	if CombatSettingsConfig.delete_snapshot(snapshot_id):
		_set_snapshot_feedback("Deleted backup: %s" % snapshot_name, true)
	else:
		_set_snapshot_feedback("Could not delete backup.", false)
	_refresh_snapshot_list()

func _load_snapshot(snapshot_id: String) -> void:
	var player: Player = _player()
	if player == null:
		return
	var snapshot: Dictionary = CombatSettingsConfig.load_snapshot(snapshot_id)
	if snapshot.is_empty():
		_set_snapshot_feedback("That backup could not be loaded.", false)
		return
	main_game_preset = clampi(int(snapshot.get("active_preset", 1)), 1, 4)
	player.set_combat_contact_preset(clampi(int(snapshot.get("selected_preset", main_game_preset)), 1, 4))
	if snapshot.get("hand_settings") is Dictionary:
		player.combat_hand_settings = (snapshot["hand_settings"] as Dictionary).duplicate(true)
	if snapshot.get("contact_settings") is Dictionary:
		player.combat_contact_settings = (snapshot["contact_settings"] as Dictionary).duplicate(true)
	if snapshot.get("weapon_hand_settings") is Dictionary:
		player.combat_weapon_hand_settings = (snapshot["weapon_hand_settings"] as Dictionary).duplicate(true)
	if snapshot.get("blade_settings") is Dictionary:
		player.blade_profile_settings = (snapshot["blade_settings"] as Dictionary).duplicate(true)
	player.ensure_experimental_form_initialized()
	# Loading restores the workspace only. It does not overwrite the active Main Game file until Save Settings or Promote is used.
	_set_snapshot_feedback("Loaded backup: %s (workspace only)" % str(snapshot.get("name", "Combat Backup")), true)
	_sync_combat_controls()
	_refresh_snapshot_list()

func _set_snapshot_feedback(text: String, success: bool) -> void:
	if snapshot_feedback_label != null:
		snapshot_feedback_label.text = text
		snapshot_feedback_label.modulate = Color(0.4, 1.0, 0.4) if success else Color(1.0, 0.45, 0.35)

func _friendly_timestamp(timestamp: String) -> String:
	if timestamp.is_empty():
		return "Unknown time"
	return timestamp.replace("T", " ")

func _create_section_header(parent: VBoxContainer, title_text: String, starts_open: bool = false) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var header: Button = Button.new()
	header.focus_mode = Control.FOCUS_NONE
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.modulate = Color(1.0, 0.85, 0.3)
	header.text = ("▼ " if starts_open else "▶ ") + title_text
	section.add_child(header)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.visible = starts_open
	content.add_theme_constant_override("separation", 8)
	section.add_child(content)
	header.pressed.connect(func() -> void:
		content.visible = not content.visible
		header.text = ("▼ " if content.visible else "▶ ") + title_text
	)
	return content

func _build_combat_sword_selector(parent: VBoxContainer) -> void:
	var live_player: Player = _player()
	if live_player != null:
		selected_combat_sword_id = live_player.equipped_sword_id
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CombatSwordSelector"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = "Equipped sword and tuning profile"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	combat_sword_option = OptionButton.new()
	combat_sword_option.name = "CombatSword"
	combat_sword_option.focus_mode = Control.FOCUS_NONE
	for raw_sword_id: Variant in Player.BLADE_PROFILES.keys():
		var current_sword_id: String = str(raw_sword_id)
		combat_sword_option.add_item(current_sword_id)
		combat_sword_option.set_item_metadata(combat_sword_option.item_count - 1, current_sword_id)
	combat_sword_option.item_selected.connect(_combat_sword_selected)
	row.add_child(combat_sword_option)
	var help: Label = Label.new()
	help.text = "This one selection equips the visual and switches all blade-shape and hand-tuning settings for that sword."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(0.65, 0.75, 0.85)
	parent.add_child(help)
	_sync_combat_sword_selector()

func _combat_sword_selected(index: int) -> void:
	if combat_sword_option == null:
		return
	var metadata: Variant = combat_sword_option.get_item_metadata(index)
	if metadata is String:
		var sword_id: String = str(metadata)
		var player: Player = _player()
		selected_combat_sword_id = sword_id
		if player != null:
			player.set_equipped_sword(sword_id)
	_sync_blade_shape_controls()
	_sync_combat_controls()

func _sync_combat_sword_selector() -> void:
	if combat_sword_option == null:
		return
	for index: int in range(combat_sword_option.item_count):
		if str(combat_sword_option.get_item_metadata(index)) == selected_combat_sword_id:
			combat_sword_option.select(index)
			return

func _create_hand_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, suffix: String, tooltip: String = "") -> void:
	if tooltip.is_empty():
		tooltip = _contact_feel_tip(key)
	var row: VBoxContainer = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)

	var label: Label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(label)

	if not tooltip.is_empty():
		label.tooltip_text = tooltip
		var tip_badge: Label = Label.new()
		tip_badge.text = "[?]"
		tip_badge.tooltip_text = tooltip
		tip_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		tip_badge.modulate = Color(0.45, 0.85, 1.0, 0.9)
		title_row.add_child(tip_badge)

	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = tooltip
	slider.value_changed.connect(_hand_setting_changed.bind(key))
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	hand_controls[key] = {"slider": slider, "label": value_label, "suffix": suffix}

func _create_grapple_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, suffix: String, tooltip: String = "") -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)
	var label: Label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = tooltip
	title_row.add_child(label)
	if not tooltip.is_empty():
		var tip_badge: Label = Label.new()
		tip_badge.text = "[?]"
		tip_badge.tooltip_text = tooltip
		tip_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		tip_badge.modulate = Color(0.45, 0.85, 1.0, 0.9)
		title_row.add_child(tip_badge)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = tooltip
	slider.value_changed.connect(_grapple_setting_changed.bind(key))
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	grapple_controls[key] = {"slider": slider, "label": value_label, "suffix": suffix}

func _create_contact_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, suffix: String, tooltip: String = "") -> void:
	if tooltip.is_empty():
		tooltip = _contact_feel_tip(key)
	var row: VBoxContainer = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)

	var label: Label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(label)

	if not tooltip.is_empty():
		label.tooltip_text = tooltip
		var tip_badge: Label = Label.new()
		tip_badge.text = "[?]"
		tip_badge.tooltip_text = tooltip
		tip_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		tip_badge.modulate = Color(0.45, 0.85, 1.0, 0.9)
		title_row.add_child(tip_badge)

	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = tooltip
	slider.value_changed.connect(_contact_setting_changed.bind(key))
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	contact_controls[key] = {"slider": slider, "label": value_label, "suffix": suffix}

func _rebuild_copy_strip(copy_strip: HBoxContainer) -> void:
	for child: Node in copy_strip.get_children():
		copy_strip.remove_child(child)
		child.queue_free()

	var player: Player = _player()
	if player == null: return

	var label: Label = Label.new()
	label.text = "Copy into P%d from:" % player.combat_contact_preset
	label.modulate = Color(1.0, 0.9, 0.4)
	copy_strip.add_child(label)

	for src_preset: int in [1, 2, 3, 4]:
		if src_preset == player.combat_contact_preset: continue
		var btn: Button = Button.new()
		btn.text = "P%d" % src_preset
		btn.tooltip_text = "Copy all settings from Preset %d into Preset %d" % [src_preset, player.combat_contact_preset]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(44.0, 32.0)
		btn.pressed.connect(func() -> void:
			_copy_preset_settings(src_preset, player.combat_contact_preset)
			copy_strip.visible = false
		)
		copy_strip.add_child(btn)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	close_btn.pressed.connect(func() -> void: copy_strip.visible = false)
	copy_strip.add_child(close_btn)

func _copy_preset_settings(source_preset: int, target_preset: int) -> void:
	var player: Player = _player()
	if player == null: return
	player.copy_preset_settings(source_preset, target_preset)
	_set_disk_feedback("Copied all settings from Preset %d into Preset %d!" % [source_preset, target_preset])
	_sync_combat_controls()

func _select_combat_preset(preset: int) -> void:
	var player: Player = _player()
	if player == null: return
	player.set_combat_contact_preset(preset)
	_sync_combat_controls()

func _promote_active_preset() -> void:
	var player: Player = _player()
	if player == null: return
	main_game_preset = player.combat_contact_preset
	CombatSettingsConfig.save_all(main_game_preset, player.combat_hand_settings, player.combat_contact_settings, player.blade_profile_settings, player.combat_weapon_hand_settings)
	_set_disk_feedback("Preset %d promoted to Main Game & saved!" % main_game_preset)
	_sync_combat_controls()

func _save_all_settings() -> void:
	var player: Player = _player()
	if player == null: return
	CombatSettingsConfig.save_all(main_game_preset, player.combat_hand_settings, player.combat_contact_settings, player.blade_profile_settings, player.combat_weapon_hand_settings)
	_set_disk_feedback("Settings saved successfully!")
	_sync_combat_controls()

func _load_all_settings() -> void:
	var player: Player = _player()
	if player == null: return
	var saved: Dictionary = CombatSettingsConfig.load_all()
	if saved.is_empty():
		_set_disk_feedback("No saved presets found.")
		return
	if saved.has("active_preset"):
		main_game_preset = clampi(int(saved["active_preset"]), 1, 4)
		player.set_combat_contact_preset(main_game_preset)
	if saved.has("hand_settings") and saved["hand_settings"] is Dictionary:
		player.combat_hand_settings = (saved["hand_settings"] as Dictionary).duplicate(true)
	if saved.has("contact_settings") and saved["contact_settings"] is Dictionary:
		player.combat_contact_settings = (saved["contact_settings"] as Dictionary).duplicate(true)
	if saved.has("weapon_hand_settings") and saved["weapon_hand_settings"] is Dictionary:
		player.combat_weapon_hand_settings = (saved["weapon_hand_settings"] as Dictionary).duplicate(true)
	# Older saves predate Blade Shape tuning -- absence just means "keep
	# BLADE_PROFILES hardcoded defaults," never an error.
	if saved.has("blade_settings") and saved["blade_settings"] is Dictionary:
		player.blade_profile_settings = (saved["blade_settings"] as Dictionary).duplicate(true)
	# Legacy imports may not contain the appended style. Materialize it once from
	# their own saved Form II before exposing Form III controls.
	player.ensure_experimental_form_initialized()
	_set_disk_feedback("Settings loaded from disk!")
	_sync_combat_controls()

func _reset_all_defaults() -> void:
	var player: Player = _player()
	if player == null: return
	player.combat_hand_settings.clear()
	player.combat_contact_settings.clear()
	player.combat_weapon_hand_settings.clear()
	player.blade_profile_settings.clear()
	player.ensure_experimental_form_initialized()
	player.set_combat_contact_preset(2)
	main_game_preset = 2
	CombatSettingsConfig.save_all(main_game_preset, player.combat_hand_settings, player.combat_contact_settings, player.blade_profile_settings, player.combat_weapon_hand_settings)
	_set_disk_feedback("Presets reset to shipped defaults. Preset 1 remains available as the safe baseline.")
	_sync_combat_controls()

func _set_disk_feedback(text: String) -> void:
	if disk_feedback_label != null:
		disk_feedback_label.text = text

func _hand_setting_changed(value: float, key: String) -> void:
	var player: Player = _player()
	if player == null:
		return
	player.set_combat_hand_setting_for_sword(selected_combat_sword_id, key, value)
	_update_hand_control_label(key, player.get_combat_hand_setting_for_sword(selected_combat_sword_id, key))

func _update_hand_control_label(key: String, value: float) -> void:
	var row: Dictionary = hand_controls.get(key, {}) as Dictionary
	if row.is_empty():
		return
	var suffix: String = str(row.get("suffix", ""))
	var value_label: Label = row.get("label") as Label
	if value_label == null:
		return
	if key == "max_turn_speed":
		value_label.text = "Unlimited" if is_zero_approx(value) else "%.0f%s" % [value, suffix]
	elif suffix == "°" or suffix == " px" or key.ends_with("sparks") or key == "thrusts_per_cycle":
		value_label.text = "%.0f%s" % [value, suffix]
	else:
		value_label.text = "%.2f%s" % [value, suffix]

func _contact_setting_changed(value: float, key: String) -> void:
	var player: Player = _player()
	if player == null:
		return
	player.set_combat_contact_setting(key, value)
	_update_contact_control_label(key, player.get_base_combat_contact_setting(key))

func _update_contact_control_label(key: String, value: float) -> void:
	var row: Dictionary = contact_controls.get(key, {}) as Dictionary
	if row.is_empty():
		return
	var suffix: String = str(row.get("suffix", ""))
	var value_label: Label = row.get("label") as Label
	if value_label == null:
		return
	if suffix in ["°", " px", " px/s", "°/s"]:
		value_label.text = "%.0f%s" % [value, suffix]
	else:
		value_label.text = "%.2f%s" % [value, suffix]

func _grapple_setting_changed(value: float, key: String) -> void:
	var player: Player = _player()
	if player == null or key not in GrappleController.TUNING_KEYS:
		return
	var grapple: GrappleController = player.grapple_controller
	var current_value: Variant = grapple.get(key)
	if current_value is bool:
		grapple.set(key, value >= 0.5)
	else:
		grapple.set(key, value)
	_sync_grapple_controls()

static func format_grapple_value(value: float, step: float, suffix: String) -> String:
	if step < 1.0:
		return "%.2f%s" % [value, suffix]
	return "%.0f%s" % [value, suffix]

func _sync_grapple_controls() -> void:
	var player: Player = _player()
	if player == null: return
	var grapple: GrappleController = player.grapple_controller
	for key: String in grapple_controls:
		var row: Dictionary = grapple_controls[key]
		var value: float = float(grapple.get(key))
		var suffix: String = str(row.get("suffix", ""))
		var slider: HSlider = row["slider"] as HSlider
		slider.set_value_no_signal(value)
		(row["label"] as Label).text = format_grapple_value(value, slider.step, suffix)
	if grapple_status_label != null:
		if grapple.firing:
			grapple_status_label.text = "LIVE: Hook in flight | Tip (%.0f, %.0f)" % [grapple.hook_position.x, grapple.hook_position.y]
		elif grapple.active:
			var state_text: String = "TAUT" if grapple.tension_ratio > 0.01 else "SLACK"
			grapple_status_label.text = "LIVE: %s | Rope %.0f px | %s | Anchor (%.0f, %.0f)" % [grapple.target_name(), grapple.rope_length, state_text, grapple.anchor_position.x, grapple.anchor_position.y]
			var yoyo_status: String = grapple.yoyo_debug_status()
			if not yoyo_status.is_empty():
				grapple_status_label.text += "\n" + yoyo_status
		else:
			grapple_status_label.text = "RMB: No tether"

func _sync_combat_controls() -> void:
	var player: Player = _player()
	if player == null or combat_status == null: return
	_sync_combat_sword_selector()

	var p_desc: String = "Preset 1: Safe Baseline (Untouched fallback)"
	if player.combat_contact_preset == 2:
		p_desc = "Preset 2: Distinct Contacts (Flat feel • Tuned Metronome V)"
	elif player.combat_contact_preset == 3:
		p_desc = "Preset 3: Dynamic Metronome (Flow-scaled speed, arc & response • Form stays Metronome V)"
	elif player.combat_contact_preset == 4:
		p_desc = "Preset 4: Form Evolution (Thrusting A -> Metronome V -> Moulinet ∞ as Flow rises)"
	combat_status.text = "ACTIVE TESTING: %s\nSword Form: %s" % [p_desc, player._style_name()]
	if experimental_bind_section != null:
		experimental_bind_section.visible = player.is_experimental_bind_form()
	_sync_experimental_bind_status(player)
	if is_instance_valid(main) and main.has_method("get_main_game_preset"):
		main_game_preset = clampi(int(main.call("get_main_game_preset")), 1, 4)
	else:
		var saved: Dictionary = CombatSettingsConfig.load_all()
		main_game_preset = clampi(int(saved.get("active_preset", main_game_preset)), 1, 4)
	if main_preset_status != null:
		main_preset_status.text = "Main Game Setting: Preset %d %s" % [main_game_preset, "(Active in Forest & Boss)" if main_game_preset == player.combat_contact_preset else ""]

	last_hand_key = "%d:%d" % [player.combat_contact_preset, int(player.sword_style)]
	last_contact_key = str(player.combat_contact_preset)

	for key: String in hand_controls:
		var row: Dictionary = hand_controls[key]
		var value: float = player.get_combat_hand_setting_for_sword(selected_combat_sword_id, key)
		var suffix: String = str(row.get("suffix", ""))
		(row["slider"] as HSlider).set_value_no_signal(value)
		if key == "max_turn_speed":
			(row["label"] as Label).text = "Unlimited" if is_zero_approx(value) else "%.0f%s" % [value, suffix]
		elif suffix == "°" or suffix == " px" or key.ends_with("sparks") or key == "thrusts_per_cycle":
			(row["label"] as Label).text = "%.0f%s" % [value, suffix]
		else:
			(row["label"] as Label).text = "%.2f%s" % [value, suffix]

	for key: String in contact_controls:
		var row: Dictionary = contact_controls[key]
		# This section is explicitly Per Preset. Bind A/B may resolve six slide
		# values through their separate Form-Local Slide Entry controls, but that
		# must not make the shared preset slider display a different value than it edits.
		var value: float = player.get_base_combat_contact_setting(key)
		var suffix: String = str(row.get("suffix", ""))
		(row["slider"] as HSlider).set_value_no_signal(value)
		if suffix == "°" or suffix == " px" or suffix == " px/s" or suffix == "°/s":
			(row["label"] as Label).text = "%.0f%s" % [value, suffix]
		else:
			(row["label"] as Label).text = "%.2f%s" % [value, suffix]
	_sync_grapple_controls()
	_sync_blade_shape_controls()
	_sync_visualizer_controls()

func _sync_experimental_bind_status(player_ref: Player) -> void:
	# Detailed Bind evidence is intentionally console-only.
	if player_ref == null:
		return

func _toggle_weapon_collision_zones() -> void:
	var player: Player = _player()
	if player == null:
		return
	player.debug_draw_sword_collision = not player.debug_draw_sword_collision
	_sync_weapon_collision_zones_button(player)

func _sync_weapon_collision_zones_button(player: Player) -> void:
	if weapon_collision_zones_button == null or player == null:
		return
	weapon_collision_zones_button.text = "WEAPON COLLISION ZONES: ON" if player.debug_draw_sword_collision else "WEAPON COLLISION ZONES: OFF"

func open() -> void:
	_bind_forest_visual_settings()
	visible = true
	_apply_training_layout()
	_set_gameplay_input_locked(panel.visible)
	_sync_bonus_rows()
	var live_debug_player: Player = _player()
	_sync_weapon_collision_zones_button(live_debug_player)
	# The selector is only built once, so re-read the live equipped sword every
	# time the menu opens -- otherwise it silently keeps showing whatever sword
	# was equipped at boot instead of what the player is actually holding.
	var live_player: Player = _player()
	if live_player != null and combat_sword_option != null:
		selected_combat_sword_id = live_player.equipped_sword_id
		_sync_combat_sword_selector()
		_sync_blade_shape_controls()
	_sync_combat_controls()
	_refresh_snapshot_list()

func _process(_delta: float) -> void:
	if not visible or not panel.visible: return
	var player: Player = _player()
	if player == null: return

	if event_monitor_label != null:
		if player.sword_event_left > 0.0:
			event_monitor_label.text = "Latest Contact: %s (%.2fs left)" % [player.sword_event_label, player.sword_event_left]
			event_monitor_label.modulate = Color(1.0, 0.9, 0.4)
		else:
			event_monitor_label.modulate = Color(0.7, 0.7, 0.7)

	var active_hand_key: String = "%d:%d" % [player.combat_contact_preset, int(player.sword_style)]
	var active_contact_key: String = str(player.combat_contact_preset)
	if active_hand_key != last_hand_key or active_contact_key != last_contact_key:
		_sync_combat_controls()
	_sync_grapple_controls()
	_sync_experimental_bind_status(player)
	_sync_auto_spawner_controls()
	_sync_training_target_controls()

func close() -> void:
	_set_gameplay_input_locked(false)
	if forest_visual_tuner != null:
		forest_visual_tuner.end_comparison()
	if main != null and main.has_method("set_backyard_wave_spawner_enabled"):
		main.call("set_backyard_wave_spawner_enabled", false)
	if main != null:
		main.call("set_training_dummy_enabled", false)
		main.call("set_test_turkey_enabled", false)
	visible = false

func _exit_tree() -> void:
	# Do not leave a surviving Player locked if the menu is removed on its own.
	if is_instance_valid(main):
		_set_gameplay_input_locked(false)

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_set_gameplay_input_locked(panel.visible and is_visible_in_tree())
	if panel.visible:
		# Rebind node references only. Never change or reload the active day phase
		# as a side effect of opening the tools.
		_bind_forest_visual_settings()
		_apply_training_layout()
		_sync_bonus_rows()
		_sync_combat_controls()
		_refresh_snapshot_list()
	elif forest_visual_tuner != null:
		forest_visual_tuner.end_comparison()

func _toggle_production_spawner() -> void:
	if main == null: return
	var enabled: bool = bool(main.call("is_backyard_wave_spawner_enabled"))
	main.call("set_backyard_wave_spawner_enabled", not enabled)
	_sync_auto_spawner_controls()

func _sync_auto_spawner_controls() -> void:
	if auto_spawner_button == null or auto_spawner_status == null: return
	var enabled: bool = false
	if main != null and main.has_method("is_backyard_wave_spawner_enabled"):
		enabled = bool(main.call("is_backyard_wave_spawner_enabled"))
	auto_spawner_button.text = "PRODUCTION WAVE SPAWNER: %s" % ("ON" if enabled else "OFF")
	auto_spawner_button.modulate = Color(0.55, 1.0, 0.55) if enabled else Color.WHITE
	if enabled and main != null:
		var spawner: WaveSpawner = main.get_node_or_null("WaveSpawner") as WaveSpawner
		auto_spawner_status.text = "Running real config • Wave %d • %d queued • %d alive" % [spawner.current_wave, spawner.enemies_to_spawn, spawner.enemies_alive] if spawner != null else "Running real WaveSpawner configuration"
	else:
		auto_spawner_status.text = "OFF — manual enemy buttons remain available"

func _sync_training_target_controls() -> void:
	if training_dummy_button == null or test_turkey_button == null:
		return
	var dummy_enabled: bool = main != null and main.has_method("is_training_dummy_enabled") and bool(main.call("is_training_dummy_enabled"))
	var turkey_enabled: bool = main != null and main.has_method("is_test_turkey_enabled") and bool(main.call("is_test_turkey_enabled"))
	training_dummy_button.text = "TRAINING DUMMY: %s" % ("ON" if dummy_enabled else "OFF")
	test_turkey_button.text = "TEST TURKEY (REPLACES ON DEATH): %s" % ("ON" if turkey_enabled else "OFF")
	training_dummy_button.modulate = Color(0.55, 1.0, 0.55) if dummy_enabled else Color.WHITE
	test_turkey_button.modulate = Color(0.55, 1.0, 0.55) if turkey_enabled else Color.WHITE

func _toggle_training_dummy() -> void:
	if main != null:
		main.call("set_training_dummy_enabled", not bool(main.call("is_training_dummy_enabled")))
	_sync_training_target_controls()

func _toggle_test_turkey() -> void:
	if main != null:
		main.call("set_test_turkey_enabled", not bool(main.call("is_test_turkey_enabled")))
	_sync_training_target_controls()

func _sync_training_input_lock() -> void:
	# Releasing outside the toggle cancels its click; do not leave input latched.
	_set_gameplay_input_locked(panel.visible and is_visible_in_tree())

func _set_gameplay_input_locked(locked: bool) -> void:
	var player: Player = _player()
	if player != null:
		player.set_training_menu_input_locked(locked)

func _spawn_enemy(enemy_scene: PackedScene) -> void:
	if main != null: main.call("spawn_training_enemy", enemy_scene)

func _spawn_zungar_sword_test() -> void:
	if main != null and main.has_method("spawn_training_zungar"):
		main.call("spawn_training_zungar")

func _bonus_changed(value: float, bonus_id: String) -> void:
	var player: Player = _player()
	if player == null: return
	BonusConfig.set_rank(player, bonus_id, int(value))
	_sync_bonus_rows()

func _player() -> Player:
	return main.get_node_or_null("Player") as Player if main != null else null

func _sync_bonus_rows() -> void:
	var player: Player = _player()
	if player == null: return
	for bonus_id: String in bonus_rows:
		var row: Dictionary = bonus_rows[bonus_id]
		var rank_value: int = BonusConfig.rank(player, bonus_id)
		(row["slider"] as HSlider).set_value_no_signal(float(rank_value))
		(row["value_label"] as Label).text = "%d / %d" % [rank_value, BonusConfig.MAX_RANK]

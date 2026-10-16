class_name EndRunHub extends Panel

const TUTORIAL_GLOW_SCRIPT: Script = preload("res://scripts/ui/tutorial_button_glow.gd")

signal travel_home_requested()
signal adventure_zone_requested(zone_id: String)
signal save_requested(note: String)
signal load_requested()
signal resonance_rush_requested()
signal tab_changed(tab: int)

enum Tab { RUN_REVIEW, SCOREBOARD, HOME, ADVENTURE, SAVE_LOAD, TOWN }

const TOWN_MENU_SCRIPT: Script = preload("res://scripts/ui/town_menu.gd")
var town_menu: TownMenu
var shop_backdrop: KajiStoreBackdrop
var blacksmith_backdrop: BlacksmithStoreBackdrop
var shrine_backdrop: TextureRect
const SHRINE_PAINTING: Texture2D = preload("res://assets/generated/Shrine.png")

func _sync_shop_presentation(_active: bool = false) -> void:
	if not is_instance_valid(town_menu) or not town_menu.is_node_ready(): return
	var general_active: bool = town_menu.shop_is_open()
	var smith_active: bool = town_menu.blacksmith_store_is_open()
	if is_instance_valid(shop_backdrop) and not shop_backdrop.is_queued_for_deletion(): shop_backdrop.visible = general_active
	if is_instance_valid(blacksmith_backdrop) and not blacksmith_backdrop.is_queued_for_deletion(): blacksmith_backdrop.visible = smith_active
	var shrine_active: bool = town_menu.shrine_is_open()
	if is_instance_valid(shrine_backdrop):
		shrine_backdrop.visible = shrine_active
		shrine_backdrop.size = get_viewport_rect().size
		shrine_backdrop.global_position = Vector2.ZERO
	var active: bool = general_active or smith_active or shrine_active
	if active: add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else: remove_theme_stylebox_override("panel")
	for control: Control in [$Title, run_review_tab, scoreboard_tab, home_tab, adventure_tab, save_load_tab]:
		control.visible = not active
	if active:
		# Each shop page extends to viewport margins over its own sibling painting.
		if general_active: town_menu.fit_general_page(get_viewport_rect().size)
		elif smith_active: town_menu.fit_blacksmith_page(get_viewport_rect().size)
		else: town_menu.shrine_page.fit(get_viewport_rect().size)
		town_menu.global_position = Vector2(16, 16)
	else:
		town_menu.position = Vector2(44, 164)

func _attach_shop_backdrop() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not is_instance_valid(shop_backdrop) or shop_backdrop.is_queued_for_deletion(): return
	var parent: Node = get_parent()
	if parent == null or parent.is_queued_for_deletion(): return
	if shop_backdrop.get_parent() == null:
		parent.add_child(shop_backdrop)
		parent.move_child(shop_backdrop, get_index())
	# Opening/hiding the shop before this deferred call must not leave stale state.
	_sync_shop_presentation()

func _attach_blacksmith_backdrop() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not is_instance_valid(blacksmith_backdrop) or blacksmith_backdrop.is_queued_for_deletion(): return
	var parent: Node = get_parent()
	if parent == null or parent.is_queued_for_deletion(): return
	if blacksmith_backdrop.get_parent() == null:
		parent.add_child(blacksmith_backdrop)
		parent.move_child(blacksmith_backdrop, get_index())
	_sync_shop_presentation()

func _attach_shrine_backdrop() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not is_instance_valid(shrine_backdrop) or shrine_backdrop.is_queued_for_deletion(): return
	if shrine_backdrop.get_parent() == null:
		get_parent().add_child(shrine_backdrop)
		get_parent().move_child(shrine_backdrop, get_index())
	_sync_shop_presentation()

func configure_town(progression: HomeProgression, sell_callback: Callable, buy_callback: Callable = Callable(), smith_sell: Callable = Callable(), smith_buy: Callable = Callable(), shrine_exchange: Callable = Callable(), shrine_salvage: Callable = Callable()) -> void:
	town_menu.progression = progression
	town_menu.sell_callback = sell_callback
	town_menu.buy_callback = buy_callback
	town_menu.smith_sell_callback = smith_sell
	town_menu.smith_buy_callback = smith_buy
	town_menu.shrine_page.progression = progression
	town_menu.shrine_page.exchange_callback = shrine_exchange
	town_menu.shrine_page.salvage_callback = shrine_salvage

func _create_town_menu() -> void:
	var town_button: Button = Button.new()
	town_button.name = "TownButton"
	town_button.position = Vector2(76, 412)
	town_button.size = Vector2(504, 44)
	town_button.text = "Town"
	town_button.add_theme_font_size_override("font_size", 22)
	town_button.pressed.connect(show_tab.bind(Tab.TOWN))
	adventure_card.add_child(town_button)
	var future_label: Label = adventure_card.get_node_or_null("FutureZones") as Label
	if future_label != null: future_label.visible = false
	shop_backdrop = KajiStoreBackdrop.new()
	shop_backdrop.name = "KajiStoreBackdrop"
	shop_backdrop.visible = false
	blacksmith_backdrop = BlacksmithStoreBackdrop.new()
	blacksmith_backdrop.name = "BlacksmithStoreBackdrop"
	blacksmith_backdrop.visible = false
	# The parent may still be entering the tree. Only sibling attachment is deferred;
	# callers must be able to configure/open town_menu immediately after _ready.
	tree_exiting.connect(shop_backdrop.queue_free)
	tree_exiting.connect(blacksmith_backdrop.queue_free)
	_attach_shop_backdrop.call_deferred()
	_attach_blacksmith_backdrop.call_deferred()
	shrine_backdrop = TextureRect.new()
	shrine_backdrop.name = "ShrineBackdrop"
	shrine_backdrop.texture = SHRINE_PAINTING
	shrine_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shrine_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shrine_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shrine_backdrop.visible = false
	tree_exiting.connect(shrine_backdrop.queue_free)
	_attach_shrine_backdrop.call_deferred()
	town_menu = TOWN_MENU_SCRIPT.new() as TownMenu
	town_menu.shop_presentation_changed.connect(_sync_shop_presentation)
	town_menu.blacksmith_presentation_changed.connect(_sync_shop_presentation)
	town_menu.shrine_presentation_changed.connect(_sync_shop_presentation)
	get_viewport().size_changed.connect(_sync_shop_presentation)
	town_menu.name = "TownMenu"
	town_menu.position = Vector2(44, 164)
	town_menu.size = Vector2(752, 478)
	add_child(town_menu)
	town_menu.adventure_requested.connect(show_tab.bind(Tab.ADVENTURE))

@onready var run_review_tab: Button = $RunReviewTab
@onready var scoreboard_tab: Button = $ScoreboardTab
@onready var home_tab: Button = $HomeTab
@onready var adventure_tab: Button = $AdventureTab
@onready var run_review: RichTextLabel = $RunReview
@onready var scoreboard: Label = $Scoreboard
@onready var home_card: Panel = $HomeCard
@onready var adventure_card: Panel = $AdventureCard
@onready var travel_home_button: Button = $HomeCard/TravelHomeButton
@onready var forest_button: Button = $AdventureCard/ForestButton

var active_tab: Tab = Tab.RUN_REVIEW
var save_load_tab: Button = null
var save_load_panel: Panel = null
var save_note_input: LineEdit = null
var save_details_label: Label = null
var tutorial_glow: TutorialButtonGlow = null

func _create_save_load_tab() -> void:
	save_load_tab = Button.new()
	save_load_tab.position = Vector2(616.0, 132.0)
	save_load_tab.size = Vector2(190.0, 42.0)
	save_load_tab.text = "SAVE / LOAD"
	save_load_tab.pressed.connect(show_tab.bind(Tab.SAVE_LOAD))
	add_child(save_load_tab)
	save_load_panel = Panel.new()
	save_load_panel.position = Vector2(44.0, 152.0)
	save_load_panel.size = Vector2(752.0, 374.0)
	save_load_panel.visible = false
	add_child(save_load_panel)
	var title: Label = Label.new()
	title.position = Vector2(24.0, 20.0)
	title.size = Vector2(704.0, 38.0)
	title.text = "SAVE / LOAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	save_load_panel.add_child(title)
	var note_label: Label = Label.new()
	note_label.position = Vector2(48.0, 78.0)
	note_label.size = Vector2(650.0, 28.0)
	note_label.text = "Save note (optional):"
	note_label.add_theme_font_size_override("font_size", 18)
	save_load_panel.add_child(note_label)
	save_note_input = LineEdit.new()
	save_note_input.position = Vector2(48.0, 112.0)
	save_note_input.size = Vector2(650.0, 42.0)
	save_note_input.placeholder_text = "Example: Testing Wolf Jerky before the boss"
	save_note_input.add_theme_font_size_override("font_size", 17)
	save_load_panel.add_child(save_note_input)
	var save_button: Button = Button.new()
	save_button.position = Vector2(48.0, 184.0)
	save_button.size = Vector2(300.0, 56.0)
	save_button.text = "SAVE NOW"
	save_button.add_theme_font_size_override("font_size", 19)
	save_button.pressed.connect(func() -> void: save_requested.emit(save_note_input.text))
	save_load_panel.add_child(save_button)
	var load_button: Button = Button.new()
	load_button.position = Vector2(404.0, 184.0)
	load_button.size = Vector2(294.0, 56.0)
	load_button.text = "LOAD LAST SAVE"
	load_button.add_theme_font_size_override("font_size", 19)
	load_button.pressed.connect(func() -> void: load_requested.emit())
	save_load_panel.add_child(load_button)
	save_details_label = Label.new()
	save_details_label.position = Vector2(48.0, 266.0)
	save_details_label.size = Vector2(650.0, 76.0)
	save_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_details_label.add_theme_font_size_override("font_size", 16)
	save_load_panel.add_child(save_details_label)

func _create_backyard_button() -> void:
	_create_chasm_button()
	var backyard_button: Button = Button.new()
	backyard_button.name = "BackyardButton"
	backyard_button.position = Vector2(76.0, 270.0)
	backyard_button.size = Vector2(504.0, 72.0)
	backyard_button.text = "BACKYARD — TRAINING"
	backyard_button.add_theme_font_size_override("font_size", 22)
	backyard_button.pressed.connect(func() -> void: adventure_zone_requested.emit("backyard"))
	adventure_card.add_child(backyard_button)
	# Resonance Rush stays implemented for later, but is intentionally not
	# created here while The Chasm is being validated as the next destination.
	var future_label: Label = adventure_card.get_node_or_null("FutureZones") as Label
	if future_label != null:
		future_label.position.y = 358.0
	adventure_card.size.y = 460.0

func _create_chasm_button() -> void:
	var chasm_button: Button = Button.new()
	chasm_button.name = "ChasmButton"
	chasm_button.position = Vector2(76.0, 186.0)
	chasm_button.size = Vector2(504.0, 72.0)
	chasm_button.text = "THE CHASM — CANYON MINE"
	chasm_button.tooltip_text = "Enter the outdoor canyon mine: windswept trees and iron ore on stone ground."
	chasm_button.add_theme_font_size_override("font_size", 21)
	chasm_button.pressed.connect(func() -> void:
		adventure_zone_requested.emit("chasm"))
	adventure_card.add_child(chasm_button)

func _create_resonance_rush_button() -> void:
	var resonance_rush_button: Button = Button.new()
	resonance_rush_button.name = "ResonanceRushButton"
	resonance_rush_button.position = Vector2(76.0, 270.0)
	resonance_rush_button.size = Vector2(504.0, 72.0)
	resonance_rush_button.text = "RESONANCE RUSH — TRAVEL MINIGAME"
	resonance_rush_button.tooltip_text = "A short dreamy traversal prototype: drive, launch, grapple, and glide across the sky."
	resonance_rush_button.add_theme_font_size_override("font_size", 20)
	resonance_rush_button.pressed.connect(func() -> void: resonance_rush_requested.emit())
	adventure_card.add_child(resonance_rush_button)

<<<<<<< Updated upstream
=======
func _create_px_mode_button() -> void:
	# PX mode is the isolated physics-motor sword lab. This button only OPENS
	# it — the lab shares no game code, so the coupling is a doorway, not a
	# dependency. See blade_dancer_px/tools/px_sword_lab.gd.
	var px_button: Button = Button.new()
	px_button.name = "PXModeButton"
	px_button.visible = false # Adventure doorway hidden; PX machinery stays available elsewhere.
	px_button.position = Vector2(76.0, 350.0)
	px_button.size = Vector2(246.0, 54.0)
	px_button.text = "PX MODE — LAB"
	px_button.tooltip_text = "Standalone physics-motor sword lab (development experiment)."
	px_button.add_theme_font_size_override("font_size", 20)
	px_button.pressed.connect(func() -> void: px_mode_requested.emit())
	adventure_card.add_child(px_button)
	# Reflow the "future destinations" note below the new button.
	var future_label: Label = adventure_card.get_node_or_null("FutureZones") as Label
	if future_label != null:
		future_label.position.y = 414.0
		future_label.size.y = 44.0
	adventure_card.size.y = 478.0

func _create_px_proto_button() -> void:
	# Blade Dancer PX — the playable standalone physics-sword prototype. Also
	# all-new and decoupled: this button only opens it. See blade_dancer_px/scripts/px_game.gd.
	var proto_button: Button = Button.new()
	proto_button.name = "PXProtoButton"
	proto_button.visible = false # Hide only this Adventure doorway.
	proto_button.position = Vector2(334.0, 350.0)
	proto_button.size = Vector2(246.0, 54.0)
	proto_button.text = "PX PROTO — PLAY"
	proto_button.tooltip_text = "Blade Dancer PX — playable standalone physics-sword prototype."
	proto_button.add_theme_font_size_override("font_size", 20)
	proto_button.pressed.connect(func() -> void: px_proto_requested.emit())
	adventure_card.add_child(proto_button)

func _create_chasm_test_button() -> void:
	var button: Button = Button.new()
	button.name = "ChasmTestButton"
	button.position = Vector2(76, 350)
	button.size = Vector2(504, 54)
	button.text = "Chasm test"
	button.tooltip_text = "Experimental Chasm scenery walk: no waves, loot or expedition rewards. Escape → Return to Home."
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void: adventure_zone_requested.emit("chasm_test"))
	adventure_card.add_child(button)

func _create_chasm_test_2_button() -> void:
	var button: Button = Button.new()
	button.name = "ChasmTest2Button"
	button.text = "Chasm Test 2"
	button.tooltip_text = "Single-painting Chasm scenery walk: no waves, loot or expedition rewards. Escape → Return to Home."
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void: adventure_zone_requested.emit("chasm_test_2"))
	adventure_card.add_child(button)
	# Keep all destinations inside the existing 840×560 hub at 1280×720.
	# The two experiments share a row, not a route or presentation.
	adventure_card.position.y = 152
	adventure_card.size.y = 390
	for index: int in range(3):
		var destination: Button = adventure_card.get_node(["ForestButton", "ChasmButton", "BackyardButton"][index])
		destination.position = Vector2(76, 78 + index * 60)
		destination.size = Vector2(504, 52)
	var first: Button = adventure_card.get_node("ChasmTestButton")
	first.position = Vector2(76, 258)
	first.size = Vector2(246, 52)
	button.position = Vector2(334, 258)
	button.size = Vector2(246, 52)
	var town: Button = adventure_card.get_node("TownButton")
	town.position = Vector2(76, 318)
	town.size = Vector2(504, 52)

>>>>>>> Stashed changes
func _create_tutorial_forest_glow() -> void:
	tutorial_glow = TUTORIAL_GLOW_SCRIPT.new() as TutorialButtonGlow
	tutorial_glow.name = "TutorialForestGlow"
	add_child(tutorial_glow)
	tutorial_glow.clear_highlight()

func show_tutorial_forest_guidance() -> void:
	if tutorial_glow == null: _create_tutorial_forest_glow()
	tutorial_glow.highlight(forest_button, "Choose Forest")

func clear_tutorial_guidance() -> void:
	if tutorial_glow != null: tutorial_glow.clear_highlight()

func _ready() -> void:
	_create_save_load_tab()
	_create_tutorial_forest_glow()
	run_review_tab.pressed.connect(show_tab.bind(Tab.RUN_REVIEW))
	scoreboard_tab.pressed.connect(show_tab.bind(Tab.SCOREBOARD))
	home_tab.pressed.connect(show_tab.bind(Tab.HOME))
	adventure_tab.pressed.connect(show_tab.bind(Tab.ADVENTURE))
	travel_home_button.pressed.connect(func() -> void: travel_home_requested.emit())
	forest_button.pressed.connect(func() -> void: adventure_zone_requested.emit("forest"))
	_create_backyard_button()
<<<<<<< Updated upstream
=======
	_create_px_mode_button()
	_create_px_proto_button()
	_create_chasm_test_button()
	_create_town_menu()
	_create_chasm_test_2_button()
>>>>>>> Stashed changes
	show_tab(Tab.RUN_REVIEW)

func open_to_run_review(review_bbcode: String, scoreboard_text: String) -> void:
	run_review.text = review_bbcode
	run_review.scroll_to_line(0)
	scoreboard.text = scoreboard_text
	visible = true
	show_tab(Tab.RUN_REVIEW)

func update_save_details(last_saved_text: String, note: String) -> void:
	if save_details_label != null:
		save_details_label.text = "Last saved: %s\\nNote: %s" % [last_saved_text, note if not note.is_empty() else "(none)"]
	if save_note_input != null and not save_note_input.has_focus(): save_note_input.text = note

func show_tab(tab: Tab) -> void:
	active_tab = tab
	if town_menu != null:
		town_menu.visible = tab == Tab.TOWN
		if tab == Tab.TOWN: town_menu.open_town()
	run_review.visible = tab == Tab.RUN_REVIEW
	scoreboard.visible = tab == Tab.SCOREBOARD
	home_card.visible = tab == Tab.HOME
	adventure_card.visible = tab == Tab.ADVENTURE
	if save_load_panel != null: save_load_panel.visible = tab == Tab.SAVE_LOAD
	var tabs: Array[Button] = [run_review_tab, scoreboard_tab, home_tab, adventure_tab]
	for index: int in range(tabs.size()):
		tabs[index].modulate = Color(1.0, 0.86, 0.45, 1.0) if index == int(tab) else Color.WHITE
	if save_load_tab != null: save_load_tab.modulate = Color(1.0, 0.86, 0.45, 1.0) if tab == Tab.SAVE_LOAD else Color.WHITE
	tab_changed.emit(int(tab))

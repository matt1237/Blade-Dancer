class_name EndRunHub extends Panel

signal travel_home_requested()
signal adventure_zone_requested(zone_id: String)
signal save_requested(note: String)
signal load_requested()
signal resonance_rush_requested()

enum Tab { RUN_REVIEW, SCOREBOARD, HOME, ADVENTURE, SAVE_LOAD }

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
	chasm_button.text = "THE CHASM — CRYSTAL CAVERN"
	chasm_button.tooltip_text = "Enter the first open-concept Chasm arena prototype."
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

func _ready() -> void:
	_create_save_load_tab()
	run_review_tab.pressed.connect(show_tab.bind(Tab.RUN_REVIEW))
	scoreboard_tab.pressed.connect(show_tab.bind(Tab.SCOREBOARD))
	home_tab.pressed.connect(show_tab.bind(Tab.HOME))
	adventure_tab.pressed.connect(show_tab.bind(Tab.ADVENTURE))
	travel_home_button.pressed.connect(func() -> void: travel_home_requested.emit())
	forest_button.pressed.connect(func() -> void: adventure_zone_requested.emit("forest"))
	_create_backyard_button()
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
	run_review.visible = tab == Tab.RUN_REVIEW
	scoreboard.visible = tab == Tab.SCOREBOARD
	home_card.visible = tab == Tab.HOME
	adventure_card.visible = tab == Tab.ADVENTURE
	if save_load_panel != null: save_load_panel.visible = tab == Tab.SAVE_LOAD
	var tabs: Array[Button] = [run_review_tab, scoreboard_tab, home_tab, adventure_tab]
	for index: int in range(tabs.size()):
		tabs[index].modulate = Color(1.0, 0.86, 0.45, 1.0) if index == int(tab) else Color.WHITE
	if save_load_tab != null: save_load_tab.modulate = Color(1.0, 0.86, 0.45, 1.0) if tab == Tab.SAVE_LOAD else Color.WHITE

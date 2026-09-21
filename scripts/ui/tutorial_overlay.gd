class_name TutorialOverlay extends CanvasLayer

signal gathering_started
signal turkey_goal_completed
signal tutorial_completed

const HERB_ITEM: String = "Forest Herb"
const MUSHROOM_ITEM: String = "Mushroom"
const TURKEY_ITEM: String = "Turkey"
const GATHER_GOAL: int = 5

var passive_hits: int = 0
var authored_hits: int = 0
var chakram_bats: int = 0
var dashes_completed: int = 0
var gathered_herbs: int = 0
var gathered_mushrooms: int = 0
var gathered_turkey: int = 0
var tutorial_step: int = 1
var task_label: Label = null
var dialogue_box: BossDialogueBox = null
var skip_button: Button = null

# Tutorial copy lives here so it can be edited without touching UI layout code.
const STEP_ONE_PAGES: Array[String] = [
	"\n\nMove toward the training dummy and point your sword at it.",
	"Let the metronome do the work, simply walk near the dummy and point your mouse at it. Land five hits to continue.",
]
const STEP_TWO_PAGES: Array[String] = [
	"The sword keeps the rhythm, but your movement changes the blade. Move with it for a powerful cleave.",
	"Move against it to pull back into guard and prepare a thrust. You create the attacks.",
	"Play with the motion and bend the sword to your will. You'll notice you are able to create and shape every swing of your blade.",
]
const STEP_TWO_COMPLETE_PAGES: Array[String] = [
	"\n\nYou are conducting the sword now, not merely following it - learn to flow with the sword, if you get into a panic just remember, swing to the rhythm.",
	"Next, learn the Chakram. Click the left mouse button to throw it.",
]
const CHAKRAM_HIT_PAGES: Array[String] = [
	"Guide the Chakram into the training dummy. Damage it once to continue.",
]
const CHAKRAM_BAT_PAGES: Array[String] = [
	"Now strike the flying Chakram with your sword. A clean bat makes it faster and deal more damage.",
]
const GRAPPLE_DUMMY_PAGES: Array[String] = [
	"Use the right mouse button to grapple the training dummy - your grapple may be used to zip to walls and large enemies, grab and whip small enemies and even grab your chakram mid air to redirect it.",
]
const GRAPPLE_CHAKRAM_PAGES: Array[String] = [
	"Move your hand while tethered to whip enemies and certain objects. Your hand directs the force.",
	"Now throw a Chakram if needed, then grapple it with the right mouse button.",
]
const WRAP_DUMMY_PAGES: Array[String] = [
	"Swing the grappled Chakram around the dummy. Complete a wrap around its body - when a target becomes wrapped, they are momentarily stunned and you may move the enemy as if you grappled them.",
]
const DASH_PAGES: Array[String] = [
	"Dashing can help you tie it all together, press spacebar to dash. You may dash while grappled or dash to hit your Chakram.",
	"Dash through an evasive enemy, or reach the back of one that defends itself well.",
	"Be careful: it is only a dash, and you are not invincible. That would be silly.",
]
const GRANDMA_GATHER_PAGES: Array[String] = [
	"Gather me some supplies for supper, won't you, sweetie?",
	"Swipe at bushes and forageables, and even break rocks and trees.",
	"Get me some herbs, mushrooms, and turkey meat. I'll teach you how to make Wild Turkey Stew for your adventures!",
]
const TUTORIAL_COMPLETE_PAGES: Array[String] = [
	"Wonderful, sweetie! That is everything we need for supper.",
]

func _ready() -> void:
	layer = 30
	_build_ui()

func _build_ui() -> void:
	dialogue_box = BossDialogueBox.new()
	dialogue_box.name = "GoodResonanceDialogue"
	dialogue_box.auto_close_delay = 5.0
	dialogue_box.finished.connect(_on_dialogue_finished)
	# BossDialogueBox owns responsive bottom-wide anchors. Keep both horizontal
	# offsets inset from the viewport edges instead of adding a positive right
	# offset, which pushed the panel beyond narrow or zoomed viewports.
	dialogue_box.offset_left = 46.0
	dialogue_box.offset_right = -46.0
	dialogue_box.set_box_height(190.0)
	dialogue_box.set_portrait(load("res://assets/portraits/Good Resonance Entity.png") as Texture2D)
	add_child(dialogue_box)
	dialogue_box.start(STEP_ONE_PAGES)
	var task_panel: Panel = Panel.new()
	task_panel.name = "TutorialTaskWidget"
	task_panel.position = Vector2(1010.0, 270.0)
	task_panel.size = Vector2(230.0, 154.0)
	var task_style: StyleBoxFlat = StyleBoxFlat.new()
	task_style.bg_color = Color(0.04, 0.06, 0.10, 0.94)
	task_style.corner_radius_top_left = 8
	task_style.corner_radius_top_right = 8
	task_style.corner_radius_bottom_left = 8
	task_style.corner_radius_bottom_right = 8
	task_panel.add_theme_stylebox_override("panel", task_style)
	add_child(task_panel)
	task_label = Label.new()
	task_label.position = Vector2(16.0, 14.0)
	task_label.size = Vector2(198.0, 126.0)
	task_label.text = "TUTORIAL\n\nSword contact\n0 / 5 hits"
	task_label.add_theme_font_size_override("font_size", 18)
	task_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 1.0))
	task_panel.add_child(task_label)
	skip_button = Button.new()
	skip_button.name = "SkipTutorialStep"
	skip_button.text = "SKIP STEP"
	skip_button.position = Vector2(1050.0, 410.0)
	skip_button.size = Vector2(150.0, 38.0)
	skip_button.modulate = Color(0.72, 0.88, 1.0, 0.92)
	skip_button.add_theme_font_size_override("font_size", 14)
	skip_button.tooltip_text = "Developer shortcut: advance the current tutorial step."
	skip_button.pressed.connect(skip_current_step)
	add_child(skip_button)

func set_passive_hits(value: int) -> void:
	passive_hits = clampi(value, 0, 5)
	if task_label != null:
		task_label.text = "TUTORIAL\n\nSword contact\n%d / 5 hits" % passive_hits
	if passive_hits >= 5:
		_begin_authored_step()

func register_hit(amount: float) -> void:
	if tutorial_step == 1:
		set_passive_hits(passive_hits + 1)
		return
	if tutorial_step != 2 or amount < 12.0:
		return
	authored_hits = mini(authored_hits + 1, 5)
	if task_label != null:
		task_label.text = "TUTORIAL\n\nAuthored hits\n%d / 5 hits" % authored_hits
	if authored_hits >= 5:
		_set_quest(3, "Throw a Chakram\nLeft mouse button", STEP_TWO_COMPLETE_PAGES)

func _begin_authored_step() -> void:
	if tutorial_step != 1:
		return
	tutorial_step = 2
	if task_label != null:
		task_label.text = "TUTORIAL\n\nAuthored hits\n0 / 5 hits"
	if dialogue_box != null:
		dialogue_box.start(STEP_TWO_PAGES)

func register_action(event_type: String, target_is_dummy: bool = false) -> void:
	match tutorial_step:
		3:
			if event_type == "chakram_thrown":
				_set_quest(4, "Hit the dummy\nwith the Chakram", CHAKRAM_HIT_PAGES)
		4:
			if event_type == "chakram_hit" and target_is_dummy:
				chakram_bats = 0
				_set_quest(5, "Bat the Chakram\n0 / 3 bats", CHAKRAM_BAT_PAGES)
		5:
			if event_type == "chakram_batted":
				chakram_bats = mini(chakram_bats + 1, 3)
				if chakram_bats >= 3:
					_set_quest(6, "Grapple the dummy\nRight mouse button", GRAPPLE_DUMMY_PAGES)
				elif task_label != null:
					task_label.text = "TUTORIAL\n\nBat the Chakram\n%d / 3 bats" % chakram_bats
		6:
			if event_type == "grapple_connected_enemy" and target_is_dummy:
				_set_quest(7, "Grapple a Chakram\nRight mouse button", GRAPPLE_CHAKRAM_PAGES)
		7:
			if event_type == "grapple_connected_chakram":
				_set_quest(8, "Wrap the Chakram\naround the dummy", WRAP_DUMMY_PAGES)
		8:
			if event_type == "chakram_wrapped_enemy" and target_is_dummy:
				dashes_completed = 0
				_set_quest(9, "Dash twice (Space)\n0 / 2", DASH_PAGES)
		9:
			if event_type == "dash_performed":
				dashes_completed = mini(dashes_completed + 1, 2)
				if dashes_completed >= 2:
					_begin_gathering_quest()
				elif task_label != null:
					task_label.text = "TUTORIAL\n\nDash twice (Space)\n%d / 2" % dashes_completed

func _begin_gathering_quest() -> void:
	gathered_herbs = 0
	gathered_mushrooms = 0
	gathered_turkey = 0
	if dialogue_box != null:
		dialogue_box.set_portrait(load("res://assets/portraits/Grandma.png") as Texture2D)
	_set_quest(10, _gathering_tracker_text(), GRANDMA_GATHER_PAGES)
	gathering_started.emit()

func register_material(item_name: String, quantity: int) -> void:
	if tutorial_step != 10 or quantity <= 0:
		return
	var turkey_before: int = gathered_turkey
	match item_name:
		HERB_ITEM:
			gathered_herbs = mini(GATHER_GOAL, gathered_herbs + quantity)
		MUSHROOM_ITEM:
			gathered_mushrooms = mini(GATHER_GOAL, gathered_mushrooms + quantity)
		TURKEY_ITEM:
			gathered_turkey = mini(GATHER_GOAL, gathered_turkey + quantity)
	if turkey_before < GATHER_GOAL and gathered_turkey >= GATHER_GOAL:
		turkey_goal_completed.emit()
	if task_label != null:
		task_label.text = "TUTORIAL\n\n%s" % _gathering_tracker_text()
	if gathered_herbs >= GATHER_GOAL and gathered_mushrooms >= GATHER_GOAL and gathered_turkey >= GATHER_GOAL:
		_set_quest(11, "Supper supplies gathered", TUTORIAL_COMPLETE_PAGES)

func _gathering_tracker_text() -> String:
	return "Mushrooms %d / %d\nHerbs %d / %d\nTurkey %d / %d" % [gathered_mushrooms, GATHER_GOAL, gathered_herbs, GATHER_GOAL, gathered_turkey, GATHER_GOAL]

func skip_current_step() -> void:
	match tutorial_step:
		1:
			passive_hits = 5
			_begin_authored_step()
		2:
			authored_hits = 5
			_set_quest(3, "Throw a Chakram\nLeft mouse button", STEP_TWO_COMPLETE_PAGES)
		3:
			_set_quest(4, "Hit the dummy\nwith the Chakram", CHAKRAM_HIT_PAGES)
		4:
			_set_quest(5, "Bat the Chakram\n0 / 3 bats", CHAKRAM_BAT_PAGES)
		5:
			chakram_bats = 3
			_set_quest(6, "Grapple the dummy\nRight mouse button", GRAPPLE_DUMMY_PAGES)
		6:
			_set_quest(7, "Grapple a Chakram\nRight mouse button", GRAPPLE_CHAKRAM_PAGES)
		7:
			_set_quest(8, "Wrap the Chakram\naround the dummy", WRAP_DUMMY_PAGES)
		8:
			_set_quest(9, "Dash twice (Space)\n0 / 2", DASH_PAGES)
		9:
			dashes_completed = 2
			_begin_gathering_quest()
		10:
			gathered_herbs = GATHER_GOAL
			gathered_mushrooms = GATHER_GOAL
			gathered_turkey = GATHER_GOAL
			_set_quest(11, "Supper supplies gathered", TUTORIAL_COMPLETE_PAGES)
		11:
			tutorial_completed.emit()

func _on_dialogue_finished() -> void:
	if tutorial_step == 11:
		tutorial_completed.emit()

func _set_quest(step: int, quest_text: String, pages: Array[String]) -> void:
	tutorial_step = step
	if task_label != null:
		task_label.text = "TUTORIAL\n\n%s" % quest_text
	if dialogue_box != null and not pages.is_empty():
		dialogue_box.start(pages)

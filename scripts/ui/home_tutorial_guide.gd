class_name HomeTutorialGuide extends CanvasLayer

const GRANDMA_PORTRAIT: Texture2D = preload("res://assets/portraits/Grandma.png")
const GRANDPA_PORTRAIT: Texture2D = preload("res://assets/portraits/Grandpa.png")
const GLOW_SCRIPT: Script = preload("res://scripts/ui/tutorial_button_glow.gd")
const RIPPLE_SCRIPT: Script = preload("res://scripts/ui/resonance_ripple_effect.gd")

enum Stage { INTRO, STORAGE_DOOR, STORAGE_ROOM, KITCHEN_DOOR, KITCHEN_CRAFT_SLOT, RECIPE_SELECT, COOKING_STARTED, BONUS_HEART, BONUS_MEAL, WAITING_FOR_MEAL, MEAL_READY, FOOD_SELECT, GRANDPA_INTRO, GRANDPA_REACTION, PLAYER_RESPONSE, GRANDPA_ASSIGNMENT, ADVENTURE_BUTTON, FOREST_BUTTON, COMPLETE }
const TUTORIAL_RECIPE_ID: String = CookingConfig.WILD_TURKEY_STEW_ID

# Home tutorial copy is intentionally centralized here for easy editing.
const INTRO_PAGES: Array[String] = [
	"Follow me. I'll show you how to store everything nicely.",
	"Don't worry about managing it, sweetie. I'll keep track of everything for you.",
]
const STORAGE_DOOR_PAGES: Array[String] = [
	"Come to the storage room.",
]
const STORAGE_ROOM_PAGES: Array[String] = [
	"Here is where everything you gather for resources will be kept.",
	"You can use them for crafting, or sell them to Kaji at the general store or other merchants in town.",
	"Now let's get cooking.",
]
const KITCHEN_DOOR_PAGES: Array[String] = [
	"Come to the kitchen and I'll show you how we can get this started.",
	"I love cooking for you, darling. Tell me what you want, and if we have the supplies, I will make it for you.",
]
const KITCHEN_COMPLETE_PAGES: Array[String] = [
	"This is my kitchen. Let's make that Wild Turkey Stew.",
]
const KITCHEN_CRAFT_SLOT_PAGES: Array[String] = [
	"That square with the plus is where we choose what to cook.",
]
const RECIPE_SELECT_PAGES: Array[String] = [
	"Choose Wild Turkey Stew from the recipe list.",
]
const STEW_STARTED_PAGES: Array[String] = [
	"Okay! You're all set! When it's done I'll put it in Storage for you to use before you go out on your adventures!",
	"Though I love your help in the kitchen, if you play Cauldron Catch, you can pick a meal and I'll give it an extra touch of love if you do a good job.",
	"Catch at least 60% of the good ingredients and you'll get 2 servings instead of one.",
]
const CAULDRON_SUCCESS_PAGES: Array[String] = [
	"Oh, that is lovely, thank you! I'll give this meal two servings.",
]
const CAULDRON_FAILURE_PAGES: Array[String] = [
	"Oh dear! That's alright—we can always gather more supplies.",
]
const CRAFT_SLOT_PROMPT: String = "Click the + to choose a meal"
const RECIPE_PROMPT: String = "Choose Wild Turkey Stew"
const CAULDRON_PROMPT: String = "Play Cauldron Catch"
const BONUS_HEART_PROMPT: String = "Give this meal extra love"
const BONUS_MEAL_PROMPT: String = "Click the cooking meal"
const CRAFTING_PROMPT: String = "Click Crafting"
const STORAGE_PROMPT: String = "Click Storage"
const KITCHEN_PROMPT: String = "Click Kitchen"
const MEAL_READY_PAGES: Array[String] = [
	"You can eat something before you go out—you'll feel better on a full stomach if you end up getting into trouble!",
	"I think Grandpa wanted you to do some chores for him.",
]
const GRANDPA_INTRO_PAGES: Array[String] = [
	"Ah there you are, boy—enough Turkey-ing around with your Grandmother. I need you to go out to the Forest and gather us some supplies.",
	"They've been off lately, it seems. Something seems strange, but I can't quite place it.",
]
const GRANDPA_REACTION_PAGES: Array[String] = [
	"What was that? Your face went all funny—are you alright?",
	"Hmm, strange... could you... ah, you're fine, aren't ya? Haha!",
]
const PLAYER_RESPONSE_PAGES: Array[String] = [
	"Yes... haha! I think... I am—maybe I thought too hard!",
]
const GRANDPA_ASSIGNMENT_PAGES: Array[String] = [
	"Great! Get out there and gather me 20 Stone, 20 Wood—kill 3 Wolves and 3 Goblins—and see if that starts to scare them off.",
]
const MEAL_PROMPT: String = "Choose a meal before you go"
const GRANDPA_QUEST_TITLE: String = "Grandpa's Chores"

var home_menu: HomeMenu = null
var dialogue: BossDialogueBox = null
var glow: TutorialButtonGlow = null
var skip_button: Button = null
var ripple: ResonanceRippleEffect = null
var stage: Stage = Stage.INTRO
var cauldron_passed: bool = false
var guided_end_run_hub: EndRunHub = null

func setup(menu: HomeMenu) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	home_menu = menu
	layer = 80
	dialogue = BossDialogueBox.new()
	dialogue.name = "GrandmaHomeTutorialDialogue"
	dialogue.auto_close_delay = 5.0
	dialogue.offset_left = 46.0
	dialogue.offset_right = -46.0
	dialogue.set_box_height(190.0)
	# Tutorial copy should never block the Home controls underneath it.
	dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue.set_portrait(GRANDMA_PORTRAIT)
	dialogue.finished.connect(_on_dialogue_finished)
	add_child(dialogue)
	glow = GLOW_SCRIPT.new() as TutorialButtonGlow
	add_child(glow)
	ripple = RIPPLE_SCRIPT.new() as ResonanceRippleEffect
	ripple.name = "GrandpaResonanceRipple"
	add_child(ripple)
	skip_button = Button.new()
	skip_button.name = "SkipHomeTutorialStep"
	skip_button.text = "SKIP STEP"
	skip_button.position = Vector2(1050.0, 570.0)
	skip_button.size = Vector2(150.0, 38.0)
	skip_button.modulate = Color(0.72, 0.88, 1.0, 0.92)
	skip_button.add_theme_font_size_override("font_size", 14)
	skip_button.tooltip_text = "Developer shortcut: advance Grandma's home tutorial."
	skip_button.pressed.connect(skip_current_step)
	add_child(skip_button)
	home_menu.tab_changed.connect(_on_tab_changed)
	home_menu.progression_changed.connect(_on_progression_changed)
	home_menu.recipe_list_opened.connect(_on_recipe_list_opened)
	home_menu.food_list_opened.connect(_on_food_list_opened)
	home_menu.cooking_bonus_selection_started.connect(_on_bonus_selection_started)
	home_menu.cooking_bonus_applied.connect(_on_bonus_applied)
	_start_intro()

func _highlight(control: Control, message: String) -> void:
	glow.highlight(control, message)
	dialogue.avoid_control(control)

func _clear_highlight() -> void:
	glow.clear_highlight()
	dialogue.clear_avoid_control()

func _start_intro() -> void:
	stage = Stage.INTRO
	_highlight(home_menu.crafting_tab, CRAFTING_PROMPT)
	dialogue.start(INTRO_PAGES)

func _on_tab_changed(tab_value: int) -> void:
	match stage:
		Stage.INTRO:
			if tab_value == HomeMenu.Tab.CRAFTING:
				stage = Stage.STORAGE_DOOR
				_highlight(home_menu.storage_crafting_button, STORAGE_PROMPT)
				dialogue.start(STORAGE_DOOR_PAGES)
		Stage.STORAGE_DOOR:
			if tab_value == HomeMenu.Tab.STORAGE:
				stage = Stage.STORAGE_ROOM
				_clear_highlight()
				dialogue.start(STORAGE_ROOM_PAGES)
				_highlight(home_menu.crafting_tab, CRAFTING_PROMPT)
		Stage.STORAGE_ROOM:
			if tab_value == HomeMenu.Tab.CRAFTING:
				stage = Stage.KITCHEN_DOOR
				_highlight(home_menu.kitchen_crafting_button, KITCHEN_PROMPT)
				dialogue.start(KITCHEN_DOOR_PAGES)
		Stage.KITCHEN_DOOR:
			if tab_value == HomeMenu.Tab.KITCHEN:
				stage = Stage.KITCHEN_CRAFT_SLOT
				_highlight(home_menu.crafting_slot, CRAFT_SLOT_PROMPT)
				dialogue.start(KITCHEN_COMPLETE_PAGES + KITCHEN_CRAFT_SLOT_PAGES)

func _on_recipe_list_opened() -> void:
	if stage != Stage.KITCHEN_CRAFT_SLOT: return
	stage = Stage.RECIPE_SELECT
	var recipe_button: Button = home_menu.highlight_recipe(TUTORIAL_RECIPE_ID)
	if recipe_button != null: _highlight(recipe_button, RECIPE_PROMPT)
	dialogue.start(RECIPE_SELECT_PAGES)

func _on_food_list_opened() -> void:
	if stage != Stage.MEAL_READY: return
	stage = Stage.FOOD_SELECT
	var food_button: Button = home_menu.highlight_food(TUTORIAL_RECIPE_ID)
	if food_button != null: _highlight(food_button, "Choose Wild Turkey Stew")
	dialogue.start(["Choose the Wild Turkey Stew Grandma just finished."])

func on_cauldron_started() -> void:
	dialogue.visible = false
	skip_button.visible = false
	_clear_highlight()

func _on_progression_changed(message: String) -> void:
	if message == "craft_started" and stage == Stage.RECIPE_SELECT:
		stage = Stage.COOKING_STARTED
		_clear_highlight()
		_highlight(home_menu.cauldron_catch_button, CAULDRON_PROMPT)
		dialogue.start(STEW_STARTED_PAGES)
	elif message == "craft_completed" and (stage == Stage.COOKING_STARTED or stage == Stage.BONUS_MEAL or stage == Stage.WAITING_FOR_MEAL):
		stage = Stage.MEAL_READY
		home_menu.show_tab(HomeMenu.Tab.STATUS)
		_highlight(home_menu.food_slot, MEAL_PROMPT)
		dialogue.start(MEAL_READY_PAGES)
	elif message == "food_prepared" and stage == Stage.FOOD_SELECT:
		stage = Stage.GRANDPA_INTRO
		_clear_highlight()
		dialogue.set_portrait(GRANDPA_PORTRAIT)
		dialogue.start(GRANDPA_INTRO_PAGES)

func _on_dialogue_finished() -> void:
	match stage:
		Stage.MEAL_READY:
			# Wait for the player to open Prepared Food and choose the stew.
			pass
		Stage.GRANDPA_INTRO:
			stage = Stage.GRANDPA_REACTION
			if ripple != null: ripple.play()
			dialogue.set_portrait(GRANDPA_PORTRAIT)
			dialogue.start(GRANDPA_REACTION_PAGES)
		Stage.GRANDPA_REACTION:
			stage = Stage.PLAYER_RESPONSE
			dialogue.set_portrait(null)
			dialogue.start(PLAYER_RESPONSE_PAGES)
		Stage.PLAYER_RESPONSE:
			stage = Stage.GRANDPA_ASSIGNMENT
			dialogue.set_portrait(GRANDPA_PORTRAIT)
			home_menu.progression.begin_grandpa_chores()
			home_menu.progression_changed.emit("grandpa_chores_started")
			dialogue.start(GRANDPA_ASSIGNMENT_PAGES)
		Stage.GRANDPA_ASSIGNMENT:
			stage = Stage.ADVENTURE_BUTTON
			home_menu.refresh()
			_highlight(home_menu.adventure_button, "Click Adventure")

func on_run_started() -> void:
	if skip_button != null: skip_button.visible = false

func on_adventure_opened(end_run_hub: EndRunHub) -> void:
	if stage != Stage.ADVENTURE_BUTTON: return
	stage = Stage.FOREST_BUTTON
	guided_end_run_hub = end_run_hub
	_clear_highlight()
	if not end_run_hub.tab_changed.is_connected(_on_adventure_hub_tab_changed): end_run_hub.tab_changed.connect(_on_adventure_hub_tab_changed)
	if not end_run_hub.adventure_zone_requested.is_connected(_on_adventure_zone_requested): end_run_hub.adventure_zone_requested.connect(_on_adventure_zone_requested)
	end_run_hub.show_tab(EndRunHub.Tab.ADVENTURE)
	end_run_hub.show_tutorial_forest_guidance()

func _on_adventure_hub_tab_changed(tab_value: int) -> void:
	if stage != Stage.FOREST_BUTTON or tab_value != EndRunHub.Tab.ADVENTURE: return
	if guided_end_run_hub != null: _highlight(guided_end_run_hub.forest_button, "Choose Forest")

func _on_adventure_zone_requested(zone_id: String) -> void:
	if stage != Stage.FOREST_BUTTON or zone_id != "forest": return
	stage = Stage.COMPLETE
	_clear_highlight()
	if guided_end_run_hub != null: guided_end_run_hub.clear_tutorial_guidance()
	home_menu.set_tutorial_star_glow(true)

func on_cauldron_result(passed: bool) -> bool:
	if stage != Stage.COOKING_STARTED: return false
	cauldron_passed = passed
	return true

func on_cauldron_closed() -> void:
	skip_button.visible = true
	if stage != Stage.COOKING_STARTED: return
	# Returning from the tutorial minigame completes Grandma's first stew now;
	# never leave progression waiting on a hidden real-time timer.
	if cauldron_passed and home_menu.progression.cooking_bonus_pending:
		home_menu.progression.apply_cooking_bonus_to_current_meal()
	var completed_recipe_id: String = home_menu.progression.finish_current_crafting_now()
	if not completed_recipe_id.is_empty():
		home_menu.refresh("Grandma finished %s!" % CookingConfig.recipe_name(completed_recipe_id))
	stage = Stage.MEAL_READY
	home_menu.show_tab(HomeMenu.Tab.STATUS)
	_highlight(home_menu.food_slot, MEAL_PROMPT)
	dialogue.start(MEAL_READY_PAGES)

func _on_bonus_selection_started() -> void:
	if stage != Stage.BONUS_HEART: return
	stage = Stage.BONUS_MEAL
	_highlight(home_menu.crafting_slot, BONUS_MEAL_PROMPT)
	dialogue.start(["Now click the meal Grandma is cooking so I can add a little extra love."])

func _on_bonus_applied() -> void:
	if stage != Stage.BONUS_MEAL: return
	stage = Stage.WAITING_FOR_MEAL
	_clear_highlight()
	dialogue.start(["Perfect! Grandma will put two servings in Storage when it is ready."])


func skip_current_step() -> void:
	match stage:
		Stage.INTRO:
			home_menu.show_tab(HomeMenu.Tab.CRAFTING)
		Stage.STORAGE_DOOR:
			home_menu.show_tab(HomeMenu.Tab.STORAGE)
		Stage.STORAGE_ROOM:
			home_menu.show_tab(HomeMenu.Tab.CRAFTING)
		Stage.KITCHEN_DOOR:
			home_menu.show_tab(HomeMenu.Tab.KITCHEN)
		Stage.KITCHEN_CRAFT_SLOT:
			home_menu._open_recipe_list()
		Stage.RECIPE_SELECT:
			home_menu._select_recipe(TUTORIAL_RECIPE_ID)
		Stage.COOKING_STARTED:
			on_cauldron_result(true)
			on_cauldron_closed()
		Stage.BONUS_HEART:
			home_menu._arm_cooking_bonus_selection()
		Stage.BONUS_MEAL:
			home_menu._on_crafting_slot_pressed()
		Stage.WAITING_FOR_MEAL:
			_on_progression_changed("craft_completed")
		Stage.MEAL_READY:
			home_menu._open_food_list()
		Stage.FOOD_SELECT:
			if home_menu.progression.food_count(TUTORIAL_RECIPE_ID) <= 0:
				home_menu.progression.food_inventory[TUTORIAL_RECIPE_ID] = 1
			home_menu._select_prepared_food(TUTORIAL_RECIPE_ID)
		Stage.GRANDPA_INTRO:
			_on_dialogue_finished()
		Stage.GRANDPA_REACTION:
			_on_dialogue_finished()
		Stage.PLAYER_RESPONSE:
			_on_dialogue_finished()
		Stage.GRANDPA_ASSIGNMENT:
			_on_dialogue_finished()
		Stage.ADVENTURE_BUTTON:
			home_menu.adventure_button.emit_signal("pressed")
		Stage.FOREST_BUTTON:
			_on_adventure_zone_requested("forest")
		Stage.COMPLETE:
			glow.clear_highlight()
			dialogue._close()

func is_complete() -> bool:
	return stage == Stage.COMPLETE

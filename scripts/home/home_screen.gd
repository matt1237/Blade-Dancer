## LEGACY COMPATIBILITY UI
## The active Home experience is res://scripts/ui/home_menu.gd and
## res://scenes/ui/home_menu.tscn. Keep this prototype scene until all old tests
## and external references are retired in a deliberate cleanup pass.
class_name HomeScreen extends Control

signal progression_changed(message: String)

@onready var equipment_text: RichTextLabel = $EquipmentText
@onready var storage_text: RichTextLabel = $StorageText
@onready var cooking_text: RichTextLabel = $CookingText
@onready var craft_stew_button: Button = $CraftStewButton
@onready var prepare_stew_button: Button = $PrepareStewButton
@onready var feedback_label: Label = $FeedbackLabel

var progression: HomeProgression = null

func _ready() -> void:
	craft_stew_button.pressed.connect(_craft_stew)
	prepare_stew_button.pressed.connect(_prepare_stew)

func configure(value: HomeProgression) -> void:
	progression = value
	refresh()

func refresh(message: String = "") -> void:
	if progression == null: return
	feedback_label.text = message
	equipment_text.text = "[font_size=21][color=#ffd85a]EQUIPMENT[/color][/font_size]\nSword: %s\nChakram: %s\nArmor: %s\nRing: %s\nFood: [color=#9fe6a0]%s[/color]" % [
		str(progression.equipment["Sword"]), str(progression.equipment["Chakram"]), str(progression.equipment["Armor"]), str(progression.equipment["Ring"]), str(progression.equipment["Food"])
	]
	var material_names: Array[String] = []
	for material_key: Variant in progression.materials.keys(): material_names.append(str(material_key))
	material_names.sort()
	var storage_lines: String = "[font_size=19][color=#8fdcff]STORAGE / MATERIALS[/color][/font_size]"
	for material_name: String in material_names:
		storage_lines += "\n%s: %d" % [material_name, progression.material_count(material_name)]
	storage_text.text = storage_lines
	var ingredients: Dictionary = CookingConfig.recipe_ingredients(CookingConfig.WILD_TURKEY_STEW_ID)
	cooking_text.text = "[font_size=21][color=#ffad68]COOKING[/color][/font_size]\n[b]Wild Turkey Stew[/b]   Pantry: %d\nRequires: %d Turkey + %d Mushroom\nNext expedition: [color=#9fe6a0]+%.0f Max HP[/color]\n[color=#9fe6a0]+%.2f HP/sec[/color] for %d waves" % [
		progression.food_count(CookingConfig.WILD_TURKEY_STEW_ID), int(ingredients[CookingConfig.TURKEY_MATERIAL]), int(ingredients[CookingConfig.MUSHROOM_MATERIAL]), CookingConfig.WILD_TURKEY_STEW_MAX_HEALTH, CookingConfig.WILD_TURKEY_STEW_REGEN_PER_SECOND, CookingConfig.WILD_TURKEY_STEW_WAVE_DURATION
	]
	craft_stew_button.disabled = not progression.can_craft(CookingConfig.WILD_TURKEY_STEW_ID)
	prepare_stew_button.disabled = progression.food_count(CookingConfig.WILD_TURKEY_STEW_ID) <= 0
	prepare_stew_button.text = "PREPARED" if progression.prepared_food_id == CookingConfig.WILD_TURKEY_STEW_ID else "PREPARE FOR NEXT RUN"

func _craft_stew() -> void:
	var crafted: bool = progression != null and progression.craft(CookingConfig.WILD_TURKEY_STEW_ID)
	var message: String = "Cooked Wild Turkey Stew." if crafted else "Need 2 Turkey and 1 Mushroom."
	refresh(message)
	if crafted: progression_changed.emit(message)

func _prepare_stew() -> void:
	var prepared: bool = progression != null and progression.prepare_food(CookingConfig.WILD_TURKEY_STEW_ID)
	var message: String = "Wild Turkey Stew prepared for the next expedition." if prepared else "Cook a stew first."
	refresh(message)
	if prepared: progression_changed.emit(message)

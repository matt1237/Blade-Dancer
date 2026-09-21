class_name HomeMenu extends Control

const HOME_TUTORIAL_GUIDE_SCRIPT: Script = preload("res://scripts/ui/home_tutorial_guide.gd")
const TUTORIAL_GLOW_SCRIPT: Script = preload("res://scripts/ui/tutorial_button_glow.gd")
const RED_HEART_GLOW_SCRIPT: Script = preload("res://scripts/ui/red_heart_glow.gd")
const HEART_CHARGE_TEXTURE: Texture2D = preload("res://assets/generated/ui_heart_charge.png")

signal progression_changed(message: String)
signal recipe_list_opened
signal food_list_opened
signal adventure_requested()
signal tutorial_requested()
signal dev_wave_requested(wave_number: int)
signal dev_unlock_all_requested()
signal input_mode_changed(mode: String)
signal metronome_visualizer_changed(mode: String)
signal visual_style_changed(mode: String)
signal audio_settings_changed(music_volume: float, sfx_volume: float)
signal metronome_color_changed(palette: String)
signal cauldron_catch_requested()
signal forge_requested()
signal grindstone_requested()
signal gem_jam_requested()
signal cooking_bonus_selection_started
signal cooking_bonus_applied
signal tab_changed(tab: int)

enum Tab { STATUS, CRAFTING, STORAGE, KITCHEN, OPTIONS, SETTINGS, DEV_WAVE, ARMORY, TUTORIAL }

@onready var previous_tab_button: Button = $TopBar/PreviousTab
@onready var next_tab_button: Button = $TopBar/NextTab
@onready var status_tab: Button = $TopBar/StatusTab
@onready var crafting_tab: Button = $TopBar/CraftingTab
@onready var storage_tab: Button = $TopBar/StorageTab
@onready var kitchen_tab: Button = $TopBar/KitchenTab
@onready var options_tab: Button = $TopBar/OptionsTab
@onready var adventure_button: Button = $TopBar/AdventureButton
@onready var tutorial_button: Button = $TutorialButton
@onready var tutorial_page: Control = $TutorialPage
@onready var status_page: Control = $StatusPage
@onready var storage_page: Control = $StoragePage
@onready var kitchen_page: Control = $KitchenPage
@onready var crafting_page: Control = $CraftingPage
@onready var storage_crafting_button: Button = $CraftingPage/StorageButton
@onready var kitchen_crafting_button: Button = $CraftingPage/KitchenButton
@onready var forge_button: Button = $CraftingPage/ForgeButton
@onready var grindstone_crafting_button: Button = $CraftingPage/GrindstoneButton
@onready var gem_jam_crafting_button: Button = $CraftingPage/GemJamButton
@onready var armory_crafting_button: Button = $CraftingPage/ArmoryButton
@onready var options_page: Control = $OptionsPage
@onready var settings_page: Control = $SettingsPage
@onready var settings_tab: Button = $TopBar/SettingsTab
@onready var music_volume_slider: HSlider = $SettingsPage/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $SettingsPage/SfxVolumeSlider
@onready var music_volume_value: Label = $SettingsPage/MusicVolumeValue
@onready var sfx_volume_value: Label = $SettingsPage/SfxVolumeValue
@onready var metronome_color_button: Button = $SettingsPage/MetronomeColorButton
@onready var keyboard_mouse_button: Button = $OptionsPage/KeyboardMouse
@onready var controller_button: Button = $OptionsPage/Controller
@onready var metronome_visualizer_button: Button = $OptionsPage/MetronomeVisualizer
@onready var visual_style_button: Button = $OptionsPage/VisualStyle
@onready var control_description: Label = $OptionsPage/ControlDescription
@onready var controller_status: Label = $OptionsPage/ControllerStatus
@onready var equipment_text: RichTextLabel = $StatusPage/EquipmentText
@onready var food_slot: Button = $StatusPage/FoodSlot
@onready var food_list_panel: Panel = $StatusPage/FoodListPanel
@onready var food_buttons: VBoxContainer = $StatusPage/FoodListPanel/FoodButtons
@onready var food_tooltip_panel: Panel = $StatusPage/FoodTooltipPanel
@onready var food_tooltip_text: RichTextLabel = $StatusPage/FoodTooltipPanel/FoodTooltipText
@onready var status_feedback: Label = $StatusPage/StatusFeedback
@onready var storage_text: RichTextLabel = $StoragePage/StorageText
@onready var cooking_text: RichTextLabel = $KitchenPage/CookingText
@onready var crafting_slot: Button = $KitchenPage/CraftingSlot
@onready var craft_progress: ProgressBar = $KitchenPage/CraftProgress
@onready var craft_timer: Label = $KitchenPage/CraftTimer
@onready var recipe_list_panel: Panel = $KitchenPage/RecipeListPanel
@onready var recipe_buttons: VBoxContainer = $KitchenPage/RecipeListPanel/RecipeButtons
@onready var recipe_tooltip_panel: Panel = $KitchenPage/RecipeTooltipPanel
@onready var recipe_tooltip_text: RichTextLabel = $KitchenPage/RecipeTooltipPanel/RecipeTooltipText
@onready var feedback_label: Label = $KitchenPage/FeedbackLabel
@onready var cauldron_catch_button: Button = $KitchenPage/CauldronCatchButton
@onready var cauldron_catch_high_score_label: Label = $KitchenPage/CauldronCatchHighScoreLabel

var progression: HomeProgression = null
var active_tab: Tab = Tab.STATUS
var input_mode: String = "keyboard_mouse"
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var metronome_color: String = "gold"
var metronome_visualizer_mode: String = "player"
var visual_style: String = "classic"
var last_displayed_craft_second: int = -1
var dev_wave_tab: Button = null
var dev_wave_panel: Panel = null
var dev_wave_input: LineEdit = null
var dev_wave_status: Label = null
var dev_unlock_all_button: Button = null
var armory_page: Panel = null
var armory_lists: VBoxContainer = null
var armory_tooltip_panel: Panel = null
var armory_tooltip_text: RichTextLabel = null
var armory_selected_item_id: String = ""
var time_of_day_icon: TextureRect = null
var time_of_day_label: Label = null
var current_time_of_day: String = "Morning"
var home_tutorial_guide: HomeTutorialGuide = null
var quest_tracker_panel: Panel = null
var quest_tracker_label: Label = null
var cooking_bonus_button: Button = null
var cooking_heart_badge: TextureRect = null
var cooking_heart_glow: RedHeartGlow = null
var cooking_bonus_selection_armed: bool = false
var tutorial_star_glow: TutorialButtonGlow = null

## Paths are resolved lazily (ResourceLoader.exists check) so the Home Menu
## keeps working even before/without the art existing yet.
const TIME_OF_DAY_ICON_PATHS: Dictionary = {
	"Morning": "res://assets/generated/day_cycle_icon_morning_frame_0.png",
	"Noon": "res://assets/generated/day_cycle_icon_noon_frame_0.png",
	"Dusk": "res://assets/generated/day_cycle_icon_dusk_frame_0.png",
	"Night": "res://assets/generated/day_cycle_icon_night_frame_0.png",
}

func _create_quest_tracker() -> void:
	quest_tracker_panel = Panel.new()
	quest_tracker_panel.name = "GrandpaQuestTracker"
	quest_tracker_panel.position = Vector2(24.0, 18.0)
	quest_tracker_panel.size = Vector2(320.0, 210.0)
	quest_tracker_panel.visible = false
	status_page.add_child(quest_tracker_panel)
	quest_tracker_label = Label.new()
	quest_tracker_label.position = Vector2(16.0, 12.0)
	quest_tracker_label.size = Vector2(288.0, 186.0)
	quest_tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_tracker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_tracker_label.add_theme_font_size_override("font_size", 17)
	quest_tracker_label.add_theme_color_override("font_color", Color("d7eab5"))
	quest_tracker_panel.add_child(quest_tracker_label)

func _update_quest_tracker() -> void:
	if quest_tracker_panel == null or progression == null: return
	quest_tracker_panel.visible = progression.grandpa_chores_active
	if not progression.grandpa_chores_active: return
	quest_tracker_label.text = "GRANDPA'S CHORES\n\nStone      %d / 20\nWood       %d / 20\nWolves     %d / 3\nGoblins    %d / 3" % [progression.grandpa_stone_gathered, progression.grandpa_wood_gathered, progression.grandpa_wolves_defeated, progression.grandpa_goblins_defeated]

func _create_cooking_bonus_button() -> void:
	cooking_bonus_button = Button.new()
	cooking_bonus_button.name = "CookingBonusHeartButton"
	cooking_bonus_button.position = Vector2(438.0, 350.0)
	cooking_bonus_button.size = Vector2(68.0, 68.0)
	cooking_bonus_button.text = ""
	cooking_bonus_button.icon = HEART_CHARGE_TEXTURE
	cooking_bonus_button.expand_icon = true
	cooking_bonus_button.tooltip_text = "Heart Charge: pass Cauldron Catch, then click this Heart and the cooking meal to make 2 servings."
	cooking_bonus_button.visible = true
	cooking_bonus_button.pressed.connect(_arm_cooking_bonus_selection)
	kitchen_page.add_child(cooking_bonus_button)
	cooking_heart_badge = TextureRect.new()
	cooking_heart_badge.name = "CookingHeartBadge"
	cooking_heart_badge.position = crafting_slot.position + Vector2(crafting_slot.size.x - 38.0, 4.0)
	cooking_heart_badge.size = Vector2(32.0, 32.0)
	cooking_heart_badge.texture = HEART_CHARGE_TEXTURE
	cooking_heart_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cooking_heart_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cooking_heart_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooking_heart_badge.visible = false
	kitchen_page.add_child(cooking_heart_badge)
	cooking_heart_glow = RED_HEART_GLOW_SCRIPT.new() as RedHeartGlow
	cooking_heart_glow.name = "CookingHeartGlow"
	add_child(cooking_heart_glow)

func hide_cooking_bonus_button() -> void:
	if cooking_bonus_button == null: return
	cooking_bonus_selection_armed = false
	_update_cooking_heart_ui()
	_update_crafting_slot()

func show_cooking_bonus_button() -> void:
	if cooking_bonus_button == null: return
	cooking_bonus_button.visible = true
	cooking_bonus_selection_armed = false
	_update_cooking_heart_ui()
	_update_crafting_slot()

func _update_cooking_heart_ui() -> void:
	if cooking_bonus_button == null or progression == null: return
	var charged: bool = progression.cooking_bonus_pending
	var applied: bool = progression.is_crafting() and progression.crafting_servings >= 2
	cooking_bonus_button.disabled = not charged or applied
	cooking_bonus_button.modulate = Color(1.0, 1.0, 1.0, 1.0 if charged else 0.4)
	cooking_bonus_button.tooltip_text = "Heart charged — click it, then click the cooking meal." if charged else "Heart empty — pass Cauldron Catch to charge it."
	if cooking_heart_glow != null: cooking_heart_glow.set_charged(cooking_bonus_button, charged)
	if cooking_heart_badge != null: cooking_heart_badge.visible = applied

func _arm_cooking_bonus_selection() -> void:
	if progression == null or not progression.cooking_bonus_pending: return
	if not progression.is_crafting():
		feedback_label.text = "Start cooking a meal, then use this Heart on it."
		return
	cooking_bonus_selection_armed = true
	feedback_label.text = "Now click the meal Grandma is cooking."
	_update_crafting_slot()
	cooking_bonus_selection_started.emit()

func _on_crafting_slot_pressed() -> void:
	if cooking_bonus_selection_armed:
		if progression != null and progression.apply_cooking_bonus_to_current_meal():
			cooking_bonus_selection_armed = false
			feedback_label.text = "Grandma added the Heart. This meal will make 2 servings."
			_update_crafting_slot()
			cooking_bonus_applied.emit()
		return
	_open_recipe_list()

func _create_tutorial_star_glow() -> void:
	tutorial_star_glow = TUTORIAL_GLOW_SCRIPT.new() as TutorialButtonGlow
	tutorial_star_glow.name = "TutorialStarGlow"
	add_child(tutorial_star_glow)
	tutorial_star_glow.highlight(tutorial_button, "")
	if tutorial_star_glow.prompt_label != null: tutorial_star_glow.prompt_label.visible = false

func set_tutorial_star_glow(enabled: bool) -> void:
	if tutorial_star_glow == null: return
	if enabled:
		tutorial_star_glow.highlight(tutorial_button, "")
		if tutorial_star_glow.prompt_label != null: tutorial_star_glow.prompt_label.visible = false
	else:
		tutorial_star_glow.clear_highlight()

func _create_time_of_day_indicator() -> void:
	time_of_day_icon = TextureRect.new()
	time_of_day_icon.name = "TimeOfDayIcon"
	time_of_day_icon.position = Vector2(1148.0, 18.0)
	time_of_day_icon.size = Vector2(84.0, 84.0)
	time_of_day_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	time_of_day_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	time_of_day_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_of_day_icon)

	time_of_day_label = Label.new()
	time_of_day_label.name = "TimeOfDayLabel"
	time_of_day_label.position = Vector2(1128.0, 102.0)
	time_of_day_label.size = Vector2(124.0, 24.0)
	time_of_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_of_day_label.add_theme_font_size_override("font_size", 14)
	time_of_day_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98, 0.9))
	time_of_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_of_day_label)
	set_time_of_day(current_time_of_day)

## Called by main.gd on boot and every time the day-cycle world clock
## advances (per wave, per minigame closed) -- see Main._advance_forest_time_phase().
func set_time_of_day(phase: String) -> void:
	current_time_of_day = phase if TIME_OF_DAY_ICON_PATHS.has(phase) else "Morning"
	if time_of_day_label != null:
		time_of_day_label.text = current_time_of_day
	if time_of_day_icon == null: return
	var icon_path: String = str(TIME_OF_DAY_ICON_PATHS.get(current_time_of_day, ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		time_of_day_icon.texture = load(icon_path) as Texture2D
		time_of_day_icon.visible = true
	else:
		time_of_day_icon.visible = false

func _create_dev_wave_picker() -> void:
	dev_wave_tab = Button.new()
	dev_wave_tab.position = Vector2(608.0, 0.0)
	dev_wave_tab.size = Vector2(62.0, 50.0)
	dev_wave_tab.text = "DEV"
	dev_wave_tab.tooltip_text = "Developer Wave Picker"
	dev_wave_tab.pressed.connect(show_tab.bind(Tab.DEV_WAVE))
	$TopBar.add_child(dev_wave_tab)
	dev_wave_panel = Panel.new()
	dev_wave_panel.position = Vector2(164.0, 218.0)
	dev_wave_panel.size = Vector2(952.0, 434.0)
	dev_wave_panel.visible = false
	add_child(dev_wave_panel)
	var title: Label = Label.new()
	title.position = Vector2(40.0, 38.0)
	title.size = Vector2(872.0, 42.0)
	title.text = "DEVELOPER WAVE PICKER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ffcf68"))
	dev_wave_panel.add_child(title)
	var explanation: Label = Label.new()
	explanation.position = Vector2(110.0, 108.0)
	explanation.size = Vector2(732.0, 64.0)
	explanation.text = "Choose the wave used the next time you start an adventure.\nThis is a developer tool and is not saved to player progression."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 18)
	dev_wave_panel.add_child(explanation)
	dev_wave_input = LineEdit.new()
	dev_wave_input.name = "DevWaveInput"
	dev_wave_input.position = Vector2(300.0, 204.0)
	dev_wave_input.size = Vector2(160.0, 52.0)
	dev_wave_input.placeholder_text = "Wave number"
	dev_wave_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_wave_input.add_theme_font_size_override("font_size", 22)
	dev_wave_input.text = "1"
	dev_wave_panel.add_child(dev_wave_input)
	var apply_button: Button = Button.new()
	apply_button.name = "ApplyDevWave"
	apply_button.position = Vector2(480.0, 204.0)
	apply_button.size = Vector2(172.0, 52.0)
	apply_button.text = "USE WAVE"
	apply_button.add_theme_font_size_override("font_size", 18)
	apply_button.pressed.connect(_apply_dev_wave)
	dev_wave_panel.add_child(apply_button)
	dev_wave_status = Label.new()
	dev_wave_status.position = Vector2(120.0, 292.0)
	dev_wave_status.size = Vector2(712.0, 40.0)
	dev_wave_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_wave_status.add_theme_font_size_override("font_size", 17)
	dev_wave_panel.add_child(dev_wave_status)
	dev_unlock_all_button = Button.new()
	dev_unlock_all_button.name = "UnlockAll"
	dev_unlock_all_button.position = Vector2(300.0, 350.0)
	dev_unlock_all_button.size = Vector2(352.0, 54.0)
	dev_unlock_all_button.text = "UNLOCK ALL"
	dev_unlock_all_button.tooltip_text = "Unlock every currently gated feature for development testing."
	dev_unlock_all_button.add_theme_font_size_override("font_size", 20)
	dev_unlock_all_button.pressed.connect(_unlock_all_for_dev)
	dev_wave_panel.add_child(dev_unlock_all_button)

func _create_armory_page() -> void:
	armory_page = Panel.new()
	armory_page.name = "ArmoryPage"
	armory_page.position = Vector2(164.0, 218.0)
	armory_page.size = Vector2(952.0, 434.0)
	armory_page.visible = false
	add_child(armory_page)
	var title: Label = Label.new()
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(952.0, 36.0)
	title.text = "ARMORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("d7eab5"))
	armory_page.add_child(title)
	var hint: Label = Label.new()
	hint.position = Vector2(24.0, 50.0)
	hint.size = Vector2(560.0, 24.0)
	hint.text = "Grouped by slot. Click an item to equip it; click it again to unequip."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("9fae94"))
	armory_page.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(24.0, 78.0)
	scroll.size = Vector2(560.0, 340.0)
	armory_page.add_child(scroll)
	armory_lists = VBoxContainer.new()
	armory_lists.add_theme_constant_override("separation", 6)
	armory_lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(armory_lists)
	armory_tooltip_panel = Panel.new()
	armory_tooltip_panel.position = Vector2(604.0, 58.0)
	armory_tooltip_panel.size = Vector2(324.0, 360.0)
	armory_page.add_child(armory_tooltip_panel)
	armory_tooltip_text = RichTextLabel.new()
	armory_tooltip_text.position = Vector2(14.0, 14.0)
	armory_tooltip_text.size = Vector2(296.0, 332.0)
	armory_tooltip_text.bbcode_enabled = true
	armory_tooltip_text.add_theme_font_size_override("normal_font_size", 18)
	armory_tooltip_text.text = "[color=#a9dfa4]Hover or click an item to see its Visual, Stats, and Technique/Rank details here.[/color]"
	armory_tooltip_panel.add_child(armory_tooltip_text)

func _rebuild_armory_list() -> void:
	if armory_lists == null or progression == null: return
	for child: Node in armory_lists.get_children(): child.queue_free()
	for slot: String in ArmoryConfig.GEAR_SLOTS:
		var header: Label = Label.new()
		header.text = slot.to_upper()
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color("f2bd72"))
		armory_lists.add_child(header)
		var equipped_id: String = str(progression.equipped_gear_ids.get(slot, ""))
		var default_row: Button = Button.new()
		default_row.text = "%s  [BASE]" % progression.default_slot_label(slot)
		default_row.custom_minimum_size = Vector2(0.0, 40.0)
		default_row.add_theme_font_size_override("font_size", 16)
		default_row.toggle_mode = true
		default_row.button_pressed = equipped_id.is_empty()
		default_row.add_theme_color_override("font_color", Color("a9dfa4") if equipped_id.is_empty() else Color.WHITE)
		default_row.pressed.connect(_on_armory_row_pressed.bind("", slot))
		default_row.mouse_entered.connect(_show_armory_tooltip.bind({}, slot))
		armory_lists.add_child(default_row)
		var items: Array[Dictionary] = progression.items_for_slot(slot)
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("value", 0)) > int(b.get("value", 0)))
		for item: Dictionary in items:
			var item_id: String = str(item.get("id", ""))
			var is_equipped: bool = item_id == equipped_id
			var row: Button = Button.new()
			row.text = ArmoryConfig.display_label(item)
			row.custom_minimum_size = Vector2(0.0, 40.0)
			row.add_theme_font_size_override("font_size", 16)
			row.toggle_mode = true
			row.button_pressed = is_equipped
			row.add_theme_color_override("font_color", Color("a9dfa4") if is_equipped else Color.WHITE)
			row.pressed.connect(_on_armory_row_pressed.bind(item_id, slot))
			row.mouse_entered.connect(_show_armory_tooltip.bind(item, slot))
			armory_lists.add_child(row)

func _on_armory_row_pressed(item_id: String, slot: String) -> void:
	if progression == null: return
	if item_id.is_empty():
		progression.unequip_gear(slot)
	else:
		progression.equip_gear(item_id)
	refresh("%s equipped." % progression.equipment[slot])
	progression_changed.emit("gear_equipped")

func _show_armory_tooltip(item: Dictionary, slot: String) -> void:
	if armory_tooltip_text == null: return
	if item.is_empty():
		armory_tooltip_text.text = "[font_size=22][b]%s[/b][/font_size]\n[color=#8ea080]%s slot — base item[/color]\n\n[color=#a9dfa4]No techniques. Always available, never lost.[/color]" % [progression.default_slot_label(slot) if progression != null else "", slot]
		return
	var techniques: Dictionary = item.get("techniques", {}) as Dictionary
	var bonus_ids: Array = techniques.keys()
	bonus_ids.sort()
	var technique_lines: String = ""
	for bonus_id: String in bonus_ids:
		var rank_value: int = int(techniques[bonus_id])
		technique_lines += "[b]%s[/b] Rank %d — %s\n" % [BonusConfig.display_name(bonus_id), rank_value, BonusConfig.description(bonus_id)]
	armory_tooltip_text.text = "[font_size=22][b]%s[/b][/font_size]\n[color=#8ea080]%s slot[/color]\n\n[color=#f1cf78]Worth %d Coins[/color]\n\n[b]Techniques[/b]\n%s" % [ArmoryConfig.display_label(item), slot, int(item.get("value", 0)), technique_lines]

func _unlock_all_for_dev() -> void:
	dev_wave_status.text = "All current progression gates unlocked."
	dev_unlock_all_requested.emit()

func _apply_dev_wave() -> void:
	var requested_wave: int = clampi(int(dev_wave_input.text), 1, 100)
	dev_wave_input.text = str(requested_wave)
	dev_wave_status.text = "Next adventure will begin at Wave %d." % requested_wave
	dev_wave_requested.emit(requested_wave)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_dev_wave_picker()
	_create_armory_page()
	_create_time_of_day_indicator()
	_create_quest_tracker()
	_create_cooking_bonus_button()
	_create_tutorial_star_glow()
	armory_crafting_button.pressed.connect(show_tab.bind(Tab.ARMORY))
	previous_tab_button.pressed.connect(_show_previous_section)
	next_tab_button.pressed.connect(_show_next_section)
	status_tab.pressed.connect(show_tab.bind(Tab.STATUS))
	crafting_tab.pressed.connect(show_tab.bind(Tab.CRAFTING))
	# Kept as hidden compatibility controls for existing callers/tests.
	storage_tab.pressed.connect(show_tab.bind(Tab.STORAGE))
	kitchen_tab.pressed.connect(show_tab.bind(Tab.KITCHEN))
	options_tab.pressed.connect(show_tab.bind(Tab.OPTIONS))
	settings_tab.pressed.connect(show_tab.bind(Tab.SETTINGS))
	tutorial_button.pressed.connect(_request_tutorial)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	metronome_color_button.pressed.connect(_cycle_metronome_color)
	storage_crafting_button.pressed.connect(show_tab.bind(Tab.STORAGE))
	kitchen_crafting_button.pressed.connect(show_tab.bind(Tab.KITCHEN))
	_update_forge_button()
	forge_button.tooltip_text = "Rescue the Blacksmith after Mine Wave 10, then buy the Forge."
	forge_button.pressed.connect(_open_forge)
	grindstone_crafting_button.pressed.connect(func() -> void: grindstone_requested.emit())
	gem_jam_crafting_button.pressed.connect(func() -> void: gem_jam_requested.emit())
	keyboard_mouse_button.pressed.connect(_select_input_mode.bind("keyboard_mouse"))
	controller_button.pressed.connect(_select_input_mode.bind("controller"))
	metronome_visualizer_button.pressed.connect(_toggle_metronome_visualizer)
	visual_style_button.pressed.connect(_toggle_visual_style)
	adventure_button.pressed.connect(func() -> void: adventure_requested.emit())
	food_slot.pressed.connect(_open_food_list)
	crafting_slot.pressed.connect(_on_crafting_slot_pressed)
	cauldron_catch_button.pressed.connect(func() -> void: cauldron_catch_requested.emit())
	food_list_panel.visible = false
	food_tooltip_panel.visible = false
	recipe_tooltip_panel.visible = false
	recipe_list_panel.visible = false
	show_tab(Tab.STATUS)
	set_audio_volumes(music_volume, sfx_volume)
	queue_redraw()

func _process(_delta: float) -> void:
	if progression != null: _update_cooking_heart_ui()
	if progression == null or not progression.is_crafting(): return
	craft_progress.value = progression.crafting_progress() * 100.0
	var remaining_second: int = ceili(progression.crafting_remaining_seconds())
	if remaining_second != last_displayed_craft_second:
		last_displayed_craft_second = remaining_second
		_update_crafting_slot()
	var completed_recipe_id: String = progression.update_crafting()
	if not completed_recipe_id.is_empty():
		refresh("Grandma finished %s!" % CookingConfig.recipe_name(completed_recipe_id))
		progression_changed.emit("craft_completed")

func configure(value: HomeProgression) -> void:
	progression = value
	refresh()

func set_input_mode(mode: String) -> void:
	input_mode = "controller" if mode == "controller" else "keyboard_mouse"
	keyboard_mouse_button.modulate = Color(1.0, 0.86, 0.5, 1.0) if input_mode == "keyboard_mouse" else Color.WHITE
	controller_button.modulate = Color(1.0, 0.86, 0.5, 1.0) if input_mode == "controller" else Color.WHITE
	if input_mode == "controller":
		control_description.text = "Xbox Controller\nLeft Stick: Move    Right Stick: Aim    LB: Dash    RB: Chakram    D-Pad Left / Right: Sword Style"
		controller_status.text = "ACTIVE: CONTROLLER"
	else:
		control_description.text = "Keyboard + Mouse\nWASD: Move    Mouse: Aim    Space: Dash    Left Click: Chakram    Hold RMB: Grapple    Z / X: Sword Style"
		controller_status.text = "ACTIVE: KEYBOARD + MOUSE"

func _select_input_mode(mode: String) -> void:
	set_input_mode(mode)
	input_mode_changed.emit(input_mode)

func set_audio_volumes(music_value: float, sfx_value: float) -> void:
	music_volume = clampf(music_value, 0.0, 1.0)
	sfx_volume = clampf(sfx_value, 0.0, 1.0)
	if music_volume_slider != null:
		music_volume_slider.set_value_no_signal(music_volume * 100.0)
	if sfx_volume_slider != null:
		sfx_volume_slider.set_value_no_signal(sfx_volume * 100.0)
	_update_audio_volume_labels()

func _on_music_volume_changed(value: float) -> void:
	music_volume = clampf(value / 100.0, 0.0, 1.0)
	_update_audio_volume_labels()
	audio_settings_changed.emit(music_volume, sfx_volume)

func _on_sfx_volume_changed(value: float) -> void:
	sfx_volume = clampf(value / 100.0, 0.0, 1.0)
	_update_audio_volume_labels()
	audio_settings_changed.emit(music_volume, sfx_volume)

func _update_audio_volume_labels() -> void:
	if music_volume_value != null:
		music_volume_value.text = "%d%%" % roundi(music_volume * 100.0)
	if sfx_volume_value != null:
		sfx_volume_value.text = "%d%%" % roundi(sfx_volume * 100.0)

func set_metronome_color(value: String) -> void:
	metronome_color = value if value in ["gold", "blue", "green"] else "gold"
	var color_label: String = {"gold": "SUN GOLD", "blue": "MYSTIC BLUE", "green": "FOREST GREEN"}.get(metronome_color, "SUN GOLD")
	if metronome_color_button != null:
		metronome_color_button.text = "METRONOME COLOR: %s" % color_label
		metronome_color_button.modulate = Color(1.0, 0.86, 0.5, 1.0) if metronome_color != "gold" else Color.WHITE

func _cycle_metronome_color() -> void:
	var colors: Array[String] = ["gold", "blue", "green"]
	var next_index: int = (colors.find(metronome_color) + 1) % colors.size()
	set_metronome_color(colors[next_index])
	metronome_color_changed.emit(metronome_color)

func set_metronome_visualizer(mode: String) -> void:
	metronome_visualizer_mode = mode if mode in ["player", "top_bar", "beat", "off"] else "player"
	var mode_label: String = {"player": "PLAYER", "top_bar": "TOP BAR", "beat": "BEAT", "off": "OFF"}[metronome_visualizer_mode]
	metronome_visualizer_button.text = "METRONOME VISUALIZER: %s" % mode_label
	metronome_visualizer_button.modulate = Color(1.0, 0.86, 0.5, 1.0) if metronome_visualizer_mode != "off" else Color.WHITE

func _toggle_metronome_visualizer() -> void:
	var modes: Array[String] = ["player", "top_bar", "beat", "off"]
	var next_index: int = (modes.find(metronome_visualizer_mode) + 1) % modes.size()
	set_metronome_visualizer(modes[next_index])
	metronome_visualizer_changed.emit(metronome_visualizer_mode)


func set_visual_style(mode: String) -> void:
	visual_style = mode if mode in ["classic", "hd"] else "classic"
	visual_style_button.text = "VISUAL STYLE: %s" % visual_style.to_upper()
	visual_style_button.modulate = Color(1.0, 0.86, 0.5, 1.0) if visual_style == "hd" else Color.WHITE

func _toggle_visual_style() -> void:
	set_visual_style("hd" if visual_style == "classic" else "classic")
	visual_style_changed.emit(visual_style)

func set_cauldron_catch_high_score(value: int) -> void:
	cauldron_catch_high_score_label.text = "High Score: %d" % value

func show_cauldron_result(passed: bool) -> void:
	if passed:
		feedback_label.text = "Oh, that is lovely, thank you! This meal will make 2 servings."
	else:
		feedback_label.text = "Oh dear! This meal will make 1 serving."
	_update_cauldron_catch_button()

func open_home() -> void:
	visible = true
	show_tab(Tab.STATUS)
	refresh()

func start_post_field_tutorial() -> void:
	set_tutorial_star_glow(false)
	if home_tutorial_guide != null and is_instance_valid(home_tutorial_guide):
		home_tutorial_guide.queue_free()
	home_tutorial_guide = HOME_TUTORIAL_GUIDE_SCRIPT.new() as HomeTutorialGuide
	add_child(home_tutorial_guide)
	home_tutorial_guide.setup(self)

func _request_tutorial() -> void:
	tutorial_requested.emit()

func show_tab(tab: Tab) -> void:
	active_tab = tab
	if tab != Tab.STATUS: _close_food_list()
	if tab != Tab.KITCHEN: _close_recipe_list()
	status_page.visible = tab == Tab.STATUS
	if crafting_page != null: crafting_page.visible = tab == Tab.CRAFTING
	storage_page.visible = tab == Tab.STORAGE
	kitchen_page.visible = tab == Tab.KITCHEN
	options_page.visible = tab == Tab.OPTIONS
	settings_page.visible = tab == Tab.SETTINGS
	if tutorial_page != null:
		tutorial_page.visible = tab == Tab.TUTORIAL
	if dev_wave_panel != null: dev_wave_panel.visible = tab == Tab.DEV_WAVE
	if armory_page != null:
		armory_page.visible = tab == Tab.ARMORY
		if tab == Tab.ARMORY: _rebuild_armory_list()
	var crafting_active: bool = tab == Tab.CRAFTING or tab == Tab.STORAGE or tab == Tab.KITCHEN or tab == Tab.ARMORY
	if status_tab != null: status_tab.modulate = Color(1.0, 0.86, 0.5, 1.0) if tab == Tab.STATUS else Color.WHITE
	if crafting_tab != null: crafting_tab.modulate = Color(1.0, 0.86, 0.5, 1.0) if crafting_active else Color.WHITE
	if options_tab != null: options_tab.modulate = Color(1.0, 0.86, 0.5, 1.0) if tab == Tab.OPTIONS else Color.WHITE
	if settings_tab != null: settings_tab.modulate = Color(1.0, 0.86, 0.5, 1.0) if tab == Tab.SETTINGS else Color.WHITE
	if dev_wave_tab != null: dev_wave_tab.modulate = Color(1.0, 0.86, 0.5, 1.0) if tab == Tab.DEV_WAVE else Color.WHITE
	tab_changed.emit(int(tab))

func _home_sections() -> Array[Tab]:
	return [Tab.STATUS, Tab.CRAFTING, Tab.OPTIONS, Tab.SETTINGS]

func _show_previous_section() -> void:
	var sections: Array[Tab] = _home_sections()
	var current_section: int = 1 if active_tab == Tab.STORAGE or active_tab == Tab.KITCHEN or active_tab == Tab.ARMORY else sections.find(active_tab)
	show_tab(sections[posmod(current_section - 1, sections.size())])

func _show_next_section() -> void:
	var sections: Array[Tab] = _home_sections()
	var current_section: int = 1 if active_tab == Tab.STORAGE or active_tab == Tab.KITCHEN or active_tab == Tab.ARMORY else sections.find(active_tab)
	show_tab(sections[posmod(current_section + 1, sections.size())])

func _cooking_summary_bbcode() -> String:
	var text: String = "[center][font_size=27][color=#f2bd72]GRANDMA'S KITCHEN[/color][/font_size][/center]\n\n"
	for recipe_id: String in CookingConfig.recipe_ids():
		var ingredients: Dictionary = CookingConfig.recipe_ingredients(recipe_id)
		var ingredient_names: Array[String] = []
		for ingredient_key: Variant in ingredients.keys(): ingredient_names.append(str(ingredient_key))
		ingredient_names.sort()
		var requirement_text: String = ""
		for ingredient_name: String in ingredient_names:
			requirement_text += "%d %s" % [int(ingredients[ingredient_name]), ingredient_name]
			if ingredient_name != ingredient_names[ingredient_names.size() - 1]: requirement_text += " + "
		text += "[b]%s[/b]   Pantry: %d\nRequires: %s\n" % [CookingConfig.recipe_name(recipe_id), progression.food_count(recipe_id), requirement_text]
		var recovery_percent: float = CookingConfig.food_recovery_percent(recipe_id)
		if recovery_percent > 0.0:
			text += "[color=#a9dfa4]Restores %.0f%% maximum HP at campfires[/color]\n" % (recovery_percent * 100.0)
		else:
			text += "[color=#a9dfa4]+%.0f maximum HP[/color]\n[color=#a9dfa4]+%.2f HP/sec[/color]\nDuration: %d completed waves\n" % [CookingConfig.food_max_health(recipe_id), CookingConfig.food_regeneration(recipe_id), CookingConfig.food_wave_duration(recipe_id)]
		text += "Crafting Time: %.0f seconds\n\n" % CookingConfig.crafting_time(recipe_id)
	return text

func refresh(message: String = "") -> void:
	if progression == null: return
	_update_quest_tracker()
	feedback_label.text = message
	status_feedback.text = message
	equipment_text.text = "[font_size=25][color=#f1cf78]EQUIPPED GEAR[/color][/font_size]\n\nSword: %s\nChakram: %s\nArmor: %s\nRing: %s" % [str(progression.equipment["Sword"]), str(progression.equipment["Chakram"]), str(progression.equipment["Armor"]), str(progression.equipment["Ring"])]
	food_slot.text = "PREPARED FOOD\n%s" % str(progression.equipment["Food"])
	var material_names: Array[String] = []
	for material_key: Variant in progression.materials.keys(): material_names.append(str(material_key))
	material_names.sort()
	var storage_lines: String = "[center][font_size=27][color=#d7eab5]STORAGE[/color][/font_size][/center]\n\n"
	for material_name: String in material_names:
		storage_lines += "[font_size=20]%s: [color=#f1cf78]%d[/color][/font_size]\n" % [material_name, progression.material_count(material_name)]
	storage_lines += "\n[font_size=22][color=#f2bd72]COOKED MEALS[/color][/font_size]\n"
	var food_ids: Array[String] = CookingConfig.recipe_ids()
	food_ids.sort_custom(func(first_id: String, second_id: String) -> bool: return CookingConfig.recipe_name(first_id).naturalnocasecmp_to(CookingConfig.recipe_name(second_id)) < 0)
	for food_id: String in food_ids:
		storage_lines += "[font_size=20]%s: [color=#f1cf78]%d[/color][/font_size]\n" % [CookingConfig.recipe_name(food_id), progression.food_count(food_id)]
	storage_text.text = storage_lines
	cooking_text.text = _cooking_summary_bbcode()
	_update_crafting_slot()
	_update_cooking_heart_ui()
	_update_cauldron_catch_button()
	_update_forge_button()
	if food_list_panel.visible: _rebuild_food_list()
	if recipe_list_panel.visible: _rebuild_recipe_list()
	if armory_page != null and armory_page.visible: _rebuild_armory_list()

func _open_food_list() -> void:
	if progression == null: return
	if food_list_panel.visible:
		_close_food_list()
		return
	food_list_panel.visible = true
	food_tooltip_panel.visible = false
	equipment_text.visible = false
	_rebuild_food_list()
	food_list_opened.emit()

func highlight_food(food_id: String) -> Button:
	if not food_list_panel.visible: return null
	for child: Node in food_buttons.get_children():
		if child is Button and (child as Button).text.begins_with(CookingConfig.recipe_name(food_id)):
			return child as Button
	return null

func _close_food_list() -> void:
	if food_list_panel == null: return
	food_list_panel.visible = false
	food_tooltip_panel.visible = false
	if equipment_text != null: equipment_text.visible = true

func _rebuild_food_list() -> void:
	for child: Node in food_buttons.get_children(): child.queue_free()
	var food_ids: Array[String] = []
	for candidate_id: String in CookingConfig.recipe_ids():
		if not CookingConfig.is_recovery_food(candidate_id): food_ids.append(candidate_id)
	food_ids.sort_custom(_food_precedes)
	for food_id: String in food_ids:
		var owned: bool = progression.food_count(food_id) > 0
		var food_button: Button = Button.new()
		food_button.text = "%s  x%d" % [CookingConfig.recipe_name(food_id), progression.food_count(food_id)]
		food_button.custom_minimum_size = Vector2(0.0, 48.0)
		food_button.add_theme_font_size_override("font_size", 18)
		food_button.add_theme_color_override("font_color", Color.WHITE if owned else Color("e86969"))
		food_button.pressed.connect(_select_prepared_food.bind(food_id))
		food_button.mouse_entered.connect(_show_food_tooltip.bind(food_id))
		food_button.focus_entered.connect(_show_food_tooltip.bind(food_id))
		food_buttons.add_child(food_button)

func _food_precedes(first_id: String, second_id: String) -> bool:
	var first_owned: bool = progression.food_count(first_id) > 0
	var second_owned: bool = progression.food_count(second_id) > 0
	if first_owned != second_owned: return first_owned
	return CookingConfig.recipe_name(first_id).naturalnocasecmp_to(CookingConfig.recipe_name(second_id)) < 0

func _select_prepared_food(food_id: String) -> void:
	if progression == null or not progression.prepare_food(food_id):
		status_feedback.text = "Cook this meal in Grandma's Kitchen first."
		_show_food_tooltip(food_id)
		return
	_close_food_list()
	refresh("%s prepared for the next expedition." % CookingConfig.recipe_name(food_id))
	progression_changed.emit("food_prepared")

func _show_food_tooltip(food_id: String) -> void:
	if progression == null: return
	food_tooltip_text.text = "[font_size=22][b]%s[/b][/font_size]\n\nIn Storage: [color=#f1cf78]%d[/color]\n\n[color=#a9dfa4]+%.0f maximum HP[/color]\n[color=#a9dfa4]+%.2f HP/sec[/color]\nDuration: %d completed waves" % [CookingConfig.recipe_name(food_id), progression.food_count(food_id), CookingConfig.food_max_health(food_id), CookingConfig.food_regeneration(food_id), CookingConfig.food_wave_duration(food_id)]
	food_tooltip_panel.visible = true

func _open_recipe_list() -> void:
	if progression == null or progression.is_crafting(): return
	if recipe_list_panel.visible:
		_close_recipe_list()
		return
	recipe_list_panel.visible = true
	recipe_tooltip_panel.visible = false
	cooking_text.visible = false
	_rebuild_recipe_list()
	recipe_list_opened.emit()

func highlight_recipe(recipe_id: String) -> Button:
	if not recipe_list_panel.visible: return null
	for child: Node in recipe_buttons.get_children():
		if child is Button and (child as Button).text == CookingConfig.recipe_name(recipe_id):
			return child as Button
	return null

func _close_recipe_list() -> void:
	if recipe_list_panel == null: return
	recipe_list_panel.visible = false
	recipe_tooltip_panel.visible = false
	if cooking_text != null: cooking_text.visible = true

func _rebuild_recipe_list() -> void:
	for child: Node in recipe_buttons.get_children(): child.queue_free()
	var recipe_ids: Array[String] = CookingConfig.recipe_ids()
	recipe_ids.sort_custom(_recipe_precedes)
	for recipe_id: String in recipe_ids:
		var available: bool = progression.has_recipe_ingredients(recipe_id)
		var recipe_button: Button = Button.new()
		recipe_button.text = CookingConfig.recipe_name(recipe_id)
		recipe_button.custom_minimum_size = Vector2(0.0, 48.0)
		recipe_button.add_theme_font_size_override("font_size", 18)
		recipe_button.add_theme_color_override("font_color", Color.WHITE if available else Color("e86969"))
		recipe_button.pressed.connect(_select_recipe.bind(recipe_id))
		recipe_button.mouse_entered.connect(_show_recipe_tooltip.bind(recipe_id))
		recipe_button.focus_entered.connect(_show_recipe_tooltip.bind(recipe_id))
		recipe_buttons.add_child(recipe_button)

func _recipe_precedes(first_id: String, second_id: String) -> bool:
	var first_available: bool = progression.has_recipe_ingredients(first_id)
	var second_available: bool = progression.has_recipe_ingredients(second_id)
	if first_available != second_available: return first_available
	return CookingConfig.recipe_name(first_id).naturalnocasecmp_to(CookingConfig.recipe_name(second_id)) < 0

func _select_recipe(recipe_id: String) -> void:
	if progression == null or not progression.start_crafting(recipe_id):
		feedback_label.text = "Grandma doesn't have all the ingredients yet."
		_show_recipe_tooltip(recipe_id)
		return
	_close_recipe_list()
	last_displayed_craft_second = -1
	refresh("Grandma started %s." % CookingConfig.recipe_name(recipe_id))
	progression_changed.emit("craft_started")

func _show_recipe_tooltip(recipe_id: String) -> void:
	if progression == null: return
	var ingredients: Dictionary = CookingConfig.recipe_ingredients(recipe_id)
	var ingredient_lines: String = ""
	var material_names: Array[String] = []
	for material_key: Variant in ingredients.keys(): material_names.append(str(material_key))
	material_names.sort()
	for material_name: String in material_names:
		ingredient_lines += "%s — %d ([color=#f1cf78]%d[/color])\n" % [material_name, int(ingredients[material_name]), progression.material_count(material_name)]
	var recovery_percent: float = CookingConfig.food_recovery_percent(recipe_id)
	var effect_text: String = "Restores %.0f%% maximum HP at campfires" % (recovery_percent * 100.0) if recovery_percent > 0.0 else "+%.0f maximum HP\\n+%.2f HP/sec\\nDuration: %d completed waves" % [CookingConfig.food_max_health(recipe_id), CookingConfig.food_regeneration(recipe_id), CookingConfig.food_wave_duration(recipe_id)]
	recipe_tooltip_text.text = "[font_size=22][b]%s[/b][/font_size]\\n\\n[color=#a9dfa4]%s[/color]\\nCrafting Time: %.0f seconds\\n\\n[b]Resources Required[/b]\\n%s" % [CookingConfig.recipe_name(recipe_id), effect_text, CookingConfig.crafting_time(recipe_id), ingredient_lines]
	recipe_tooltip_panel.visible = true

func _open_forge() -> void:
	if progression == null or not progression.is_forge_unlocked(): return
	forge_requested.emit()

func _update_forge_button() -> void:
	if forge_button == null: return
	var forge_unlocked: bool = progression != null and progression.is_forge_unlocked()
	forge_button.disabled = not forge_unlocked
	forge_button.text = "FORGE" if forge_unlocked else "FORGE — LOCKED"

func _update_cauldron_catch_button() -> void:
	if cauldron_catch_button == null: return
	if progression != null and progression.is_crafting():
		cauldron_catch_button.text = "♥ %s  •  PLAY CAULDRON CATCH" % CookingConfig.recipe_name(progression.crafting_recipe_id)
	else:
		cauldron_catch_button.text = "🍲 PLAY CAULDRON CATCH"

func _update_crafting_slot() -> void:
	if progression == null: return
	var crafting_active: bool = progression.is_crafting()
	crafting_slot.disabled = crafting_active and not cooking_bonus_selection_armed
	crafting_slot.text = CookingConfig.recipe_name(progression.crafting_recipe_id) if crafting_active else "+"
	craft_progress.visible = crafting_active
	craft_timer.visible = crafting_active
	if crafting_active:
		craft_progress.value = progression.crafting_progress() * 100.0
		craft_timer.text = "%ds" % ceili(progression.crafting_remaining_seconds())
	else:
		craft_progress.value = 0.0
		craft_timer.text = ""

func _draw() -> void:
	var full_size: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, full_size), Color("30271f"))
	# Warm plaster center framed by broad wooden beams.
	draw_rect(Rect2(46.0, 34.0, full_size.x - 92.0, full_size.y - 68.0), Color("5a4734"))
	draw_rect(Rect2(62.0, 50.0, full_size.x - 124.0, full_size.y - 100.0), Color("273c2d"))
	for beam_x: float in [76.0, full_size.x - 94.0]: draw_rect(Rect2(beam_x, 50.0, 18.0, full_size.y - 100.0), Color("79543a"))
	# Hearth glow and simple leafy corners keep the menu decorative but quiet.
	draw_circle(Vector2(full_size.x - 120.0, full_size.y - 92.0), 54.0, Color(0.96, 0.48, 0.16, 0.12))
	draw_circle(Vector2(full_size.x - 120.0, full_size.y - 92.0), 28.0, Color(1.0, 0.66, 0.23, 0.16))
	for leaf_index: int in range(5):
		var leaf_offset: Vector2 = Vector2(float(leaf_index) * 18.0, sin(float(leaf_index)) * 10.0)
		draw_circle(Vector2(92.0, 86.0) + leaf_offset, 8.0, Color("6b8f4e"))
		draw_circle(Vector2(full_size.x - 92.0, 88.0) - leaf_offset, 8.0, Color("6b8f4e"))

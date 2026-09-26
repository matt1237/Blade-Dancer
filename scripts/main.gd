class_name Main extends Node2D

const IMPACT_FX_SCENE: PackedScene = preload("res://scenes/impact_fx.tscn")
const RESONANT_GLYPH_SCENE: PackedScene = preload("res://scenes/resonant_glyph.tscn")
const AUDIO_MANAGER_SCRIPT: Script = preload("res://scripts/audio_manager.gd")
const MUSIC_DIRECTOR_SCRIPT: Script = preload("res://scripts/audio/music_director.gd")
const LOOT_CONFIG_SCRIPT: Script = preload("res://scripts/loot/loot_config.gd")
const ZUNGAR_SCENE: PackedScene = preload("res://scenes/boss/zungar.tscn")
const BOSS_ARENA_BORDER_SCRIPT: Script = preload("res://scripts/boss/boss_arena_border.gd")
const BOSS_DIALOGUE_BOX_SCRIPT: Script = preload("res://scripts/ui/boss_dialogue_box.gd")
const PAUSE_MENU_SCRIPT: Script = preload("res://scripts/ui/pause_menu.gd")
const BACKYARD_TRAINING_MENU_SCRIPT: Script = preload("res://scripts/ui/backyard_training_menu.gd")
const COMBAT_DEBUG_TRACKER_SCRIPT: Script = preload("res://scripts/ui/combat_debug_tracker.gd")
const TUTORIAL_OVERLAY_SCRIPT: Script = preload("res://scripts/ui/tutorial_overlay.gd")
const GLOBAL_PRESET_CONFIG_SCRIPT: Script = preload("res://scripts/global_preset_config.gd")
const SPAWN_WARNING_SCENE: PackedScene = preload("res://scenes/spawn_warning.tscn")
const TRAINING_DUMMY_SCENE: PackedScene = preload("res://scenes/training_dummy.tscn")
const DROP_SCENE: PackedScene = preload("res://scenes/drop_pickup.tscn")
const GEAR_DROP_SCENE: PackedScene = preload("res://scenes/gear_drop_pickup.tscn")
const ArenaObjectScript: Script = preload("res://scripts/terrain/arena_object.gd")
const CAULDRON_CATCH_SCENE: PackedScene = preload("res://scenes/minigames/cauldron_catch.tscn")
const SWORD_SMITHING_SCENE: PackedScene = preload("res://scenes/minigames/sword_smithing.tscn")
const GRINDSTONE_SCENE: PackedScene = preload("res://scenes/minigames/grindstone.tscn")
const GEM_JAM_SCENE: PackedScene = preload("res://scenes/minigames/gem_jam.tscn")
## The authored multi-surface track world (loop, stacked forest/mountain
## platforms, grapple transfers) is now the canonical Resonance Rush launched
## from Adventure — it replaced the earlier procedural height-field prototype,
## which remains in the project only as a standalone reference scene.
const RESONANCE_RUSH_SCENE: PackedScene = preload("res://scenes/minigames/resonance_rush/rush_track_world_proof.tscn")

@export_category("Checkpoint Campfires")
## Every this many cleared waves, offer a safe campfire before continuing.
@export var checkpoint_wave_interval: int = 5
## Fraction of maximum health restored by one Wolf Jerky at a campfire.
## The recipe value is the source of truth; this reminder makes the rule visible here.

@export_category("Audio")
## Linear Forge music volume: 0.6 = 60%. Converted to decibels internally.
@export_range(0.0, 1.0, 0.05) var forge_music_volume: float = 0.60
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const SILENT_AUDIO_DB: float = -80.0

@export_category("Screen Shake")
## Global multiplier for all world shake. Set to 0 to disable screen shake.
@export_range(0.0, 2.0, 0.05) var screen_shake_multiplier: float = .8
## How much of the shake favors the incoming hit direction instead of random jitter.
@export_range(0.0, 1.0, 0.05) var directional_shake_weight: float = 0.35

var hitstop_active: bool = false
var audio_manager: AudioManager = null
var music_director: Node = null
var screen_shake_left: float = 0.0
var screen_shake_duration: float = 0.0
var screen_shake_strength: float = 0.0
var screen_shake_direction: Vector2 = Vector2.ZERO
var screen_shake_rest_position: Vector2 = Vector2.ZERO
var classic_shake_applied: bool = false

@onready var player: Player = $Player
@onready var forest_floor: ForestFloor = $ForestFloor
@onready var forest_ambient_fx: ForestAmbientFX = $ForestAmbientFX
@onready var chasm_stage: ChasmStage = $ChasmStage
@onready var presentation_camera: Camera2D = $PresentationCamera
@onready var presentation_environment: WorldEnvironment = $ForestEnvironment
@onready var combat_presentation_fx: CombatPresentationFX = $CombatPresentationFX
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var arena_generator: ArenaGenerator = $ArenaGenerator
@onready var wave_label: Label = $CanvasLayer/WaveLabel
@onready var wave_timer_label: Label = $CanvasLayer/WaveTimerLabel
var remaining_enemies_label: Label = null
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var style_label: Label = $CanvasLayer/StyleLabel
@onready var flow_bar: ProgressBar = $CanvasLayer/FlowBar
@onready var flow_fill: ColorRect = $CanvasLayer/FlowFill
@onready var flow_label: Label = $CanvasLayer/FlowLabel
@onready var flow_sparkle: Label = $CanvasLayer/FlowSparkle
@onready var dash_bar: ProgressBar = $CanvasLayer/DashBar
@onready var dash_label: Label = $CanvasLayer/DashLabel
@onready var grapple_label: Label = $CanvasLayer/GrappleLabel
@onready var deflect_label: Label = $CanvasLayer/DeflectLabel
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var bonus_panel: Panel = $CanvasLayer/BonusPanel
@onready var bonus_title: Label = $CanvasLayer/BonusPanel/BonusTitle
@onready var bonus_buttons: Array[Button] = [$CanvasLayer/BonusPanel/Bonus1, $CanvasLayer/BonusPanel/Bonus2, $CanvasLayer/BonusPanel/Bonus3]
@onready var bonus_help_buttons: Array[Button] = [$CanvasLayer/BonusPanel/Bonus1Help, $CanvasLayer/BonusPanel/Bonus2Help, $CanvasLayer/BonusPanel/Bonus3Help]
@onready var bonus_detail_labels: Array[RichTextLabel] = [$CanvasLayer/BonusPanel/Bonus1Details, $CanvasLayer/BonusPanel/Bonus2Details, $CanvasLayer/BonusPanel/Bonus3Details]
@onready var bonus_tooltip_panel: Panel = $CanvasLayer/BonusPanel/BonusTooltipPanel
@onready var bonus_tooltip_text: RichTextLabel = $CanvasLayer/BonusPanel/BonusTooltipPanel/TooltipText
@onready var reroll_bonuses_button: Button = $CanvasLayer/BonusPanel/RerollBonuses
@onready var next_wave_button: Button = $CanvasLayer/BonusPanel/StartNextWave
@onready var end_run_button: Button = $CanvasLayer/BonusPanel/EndRun
@onready var end_run_hub: Control = $CanvasLayer/EndRunHub
@onready var home_menu: Control = $CanvasLayer/HomeMenu
@onready var metronome_top_bar: MetronomeTopBar = $CanvasLayer/MetronomeTopBar
@onready var mobile_controls: MobileControls = $MobileControlsLayer/MobileControls
@onready var zone_transition_fade: ColorRect = $CanvasLayer/ZoneTransitionFade
var pickup_feed: PickupFeed = null
var heartbeat_left: float = 0.0
var home_progression: HomeProgression = HomeProgression.new()
var run_over: bool = false
var wave_transition_active: bool = false
## Extra pixels beyond the arena edge used for the short between-wave walk.
const TRANSITION_OFFSCREEN_MARGIN: float = 80.0
## Seconds spent walking from the arena center through the right edge.
const TRANSITION_EXIT_DURATION: float = 1.35
## Seconds spent walking from beyond the left edge to the next arena center.
const TRANSITION_ENTRANCE_DURATION: float = 1.55
## Seconds for each fade to or from black.
const TRANSITION_FADE_DURATION: float = 0.55
## Brief fully-black hold that hides regeneration and guarantees a settled frame.
const TRANSITION_BLACK_HOLD: float = 0.12
## Target spacing between procedural retro footsteps.
const TRANSITION_STEP_INTERVAL: float = 0.24
const DEFAULT_GAMEPLAY_ARENA_RECT: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
const PRESENTATION_MARGIN: Vector2 = Vector2(360.0, 180.0)
var scoreboards: Dictionary = {"The Forest": []}
const SAVE_PATH: String = "user://blade_dancer_save.json"
var save_note: String = ""
var last_saved_at_unix: float = 0.0
var bonus_ids: Array[String] = ["health", "chakram", "pierce", "explosion", "nova", "regen", "magnetic", "defense", "dash", "bash_dash", "grapple_mastery", "resonant_glyph", "voltage", "burning", "deflect", "moon", "flash", "disarm", "void", "chain", "vampirism", "adrenaline"]
var selected_bonus: String = ""
var visible_bonus_choices: Array[String] = []
## Run-only resource: each cleared wave grants one full-choice reroll.
var bonus_reroll_charges: int = 0
## Discarded choices cannot return during the same wave's reroll session.
var rerolled_bonus_exclusions: Array[String] = []
var score: int = 0
## Runtime-only developer override. This is intentionally excluded from saves.
var dev_start_wave: int = 1
## Persistent explicit control choice selected from Home Options.
var input_mode: String = "keyboard_mouse"
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var metronome_visualizer_mode: String = "player"
var metronome_visualizer_palette: String = "gold"
var beat_pulse_percent: float = 50.0
var visualizer_counts: int = 2
var beat_visualizer_size: float = 1.0
## One camera zoom authority shared by Home Settings and Training Tools.
## Smaller native mobile screens begin closer unless a saved preference exists.
var training_camera_zoom: float = 1.45 if OS.has_feature("mobile") else 1.0
var experimental_bind_focus_active: bool = false
var experimental_bind_focus_point: Vector2 = Vector2.ZERO
var experimental_bind_focus_bias: float = 0.0
var experimental_bind_focus_response: float = 8.0
var global_preset_slot: int = 2
var main_game_preset: int = 2
var visual_style: String = "classic"
## Active Adventure destination. Forest and Backyard share the established world;
## Chasm swaps in its illustrated stage and traced invisible boundaries.
var active_adventure_zone: String = "forest"
var cauldron_catch_high_score: int = 0
var cauldron_catch_instance: CauldronCatchGame = null
var sword_smithing_instance: SwordSmithingGame = null
var grindstone_instance: GrindstoneGame = null
var gem_jam_instance: GemJamGame = null
var resonance_rush_instance: ResonanceRushGame = null
var run_elapsed_seconds: float = 0.0
var flow_75_seconds: float = 0.0
var run_damage_dealt: float = 0.0
var run_damage_received: float = 0.0
var run_damage_healed: float = 0.0
var run_damage_mitigated: float = 0.0
var run_bonus_history: Array[String] = []
var last_run_summary: Dictionary = {}
## Run-scoped pity-timer chest chance. +20% each wave without a chest,
## resets to the 20% base value once one spawns. Wave five is guaranteed.
const CHEST_BASE_SPAWN_CHANCE: float = 0.20
var chest_spawn_chance: float = CHEST_BASE_SPAWN_CHANCE
var campfire_panel: Panel = null
var campfire_snack_button: Button = null
var campfire_continue_button: Button = null
var campfire_status_label: Label = null
var campfire_wave: int = 0
var boss_arena_active: bool = false
var zungar_boss: Zungar = null
var boss_dialogue_box: BossDialogueBox = null
var pause_menu: Control = null
var boss_campfire: BossCampfire = null
var boss_cave_backdrop: BossCaveBackdrop = null
var boss_trees: Array[DestructibleTree] = []
var boss_arena_border: BossArenaBorder = null
var boss_title_label: Label = null
var boss_message_tween: Tween = null
var backyard_training_menu: BackyardTrainingMenu = null
## Runtime-only Backyard presentation choice. Adventure always restores Forest.
var backyard_training_layout: String = "forest"
var training_dummy: TrainingDummy = null
var test_turkey: Turkey = null
var test_turkey_enabled: bool = false
var combat_debug_tracker: CombatDebugTracker = null
var tutorial_overlay: TutorialOverlay = null
var forest_visual_settings: ForestVisualSettings = ForestVisualSettings.new()
var forest_visual_settings_persistence_enabled: bool = false
var active_forest_time_phase: String = "Morning"
var active_global_forest_day_presets: Dictionary = {}
## Morning -> Noon -> Dusk -> Night -> loop. One step per wave (after wave 1,
## so Morning is actually seen before the first advance) and one step per
## minigame closed -- see _advance_forest_time_phase() and _on_wave_started().
const DAY_CYCLE_ORDER: Array[String] = ["Morning", "Noon", "Dusk", "Night"]

func get_forest_visual_settings() -> ForestVisualSettings:
	return forest_visual_settings

func _load_forest_visual_settings() -> void:
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	# Load the active visual-only file first, then use it to seed the named
	# Hazey baseline only when an older project has no named baseline yet.
	var preset_error: Error = forest_visual_settings.load_preset()
	var hazey_snapshot: Dictionary = library.find_latest_named_snapshot("Hazey")
	if hazey_snapshot.is_empty():
		var hazey_created: Dictionary = library.create_snapshot("Hazey", forest_visual_settings)
		hazey_snapshot = hazey_created
	# Named visual profiles remain available to the Backyard tuner, but they are
	# not a source for the runtime day cycle. Global Presets own every phase.
	library.ensure_time_of_day_profiles(forest_visual_settings)
	library.ensure_time_of_day_visual_upgrades()
	var startup_snapshot_id: String = library.get_startup_snapshot_id()
	var startup_snapshot: Dictionary = library.get_snapshot(startup_snapshot_id) if not startup_snapshot_id.is_empty() else {}
	if startup_snapshot.is_empty():
		# Preserve the established Hazey startup behavior when no explicit choice
		# exists, while keeping all named variants independent from gameplay saves.
		startup_snapshot = hazey_snapshot
		startup_snapshot_id = str(startup_snapshot.get("id", ""))
		if not startup_snapshot_id.is_empty():
			library.set_startup_snapshot_id(startup_snapshot_id)
	if not startup_snapshot.is_empty():
		var startup_error: Error = forest_visual_settings.apply_snapshot_values(startup_snapshot.get("values", {}) as Dictionary)
		if startup_error == OK:
			forest_visual_settings.save_preset()
			return
	if preset_error != OK and preset_error != ERR_FILE_NOT_FOUND:
		push_warning("Forest visual profile could not load; using clean defaults: " + error_string(preset_error))

func _apply_forest_visual_settings() -> void:
	var settings: Dictionary = forest_visual_settings.get_effective_values()
	forest_floor.apply_visual_settings(settings)
	forest_ambient_fx.apply_visual_settings(settings)
	var night: ForestNightLighting = get_node_or_null("ForestNightLighting") as ForestNightLighting
	if night == null:
		night = preload("res://scripts/forest_night_lighting.gd").new()
		night.setup(self, player, forest_ambient_fx)
		add_child(night)
	night.apply_visual_settings(settings)
	if is_instance_valid(boss_arena_border):
		boss_arena_border.apply_visual_settings(settings)
	combat_presentation_fx.forest_screen_blur_allowed = forest_visual_settings.effect_enabled("blur_enabled")
	combat_presentation_fx._update_blur()
	_update_presentation_environment()
	if forest_visual_settings_persistence_enabled:
		var save_error: Error = forest_visual_settings.save_preset()
		if save_error != OK:
			push_warning("Active forest visual profile could not save: " + error_string(save_error))


func get_gameplay_arena_rect() -> Rect2:
	if arena_generator != null and arena_generator.config != null:
		return arena_generator.config.arena_rect
	return DEFAULT_GAMEPLAY_ARENA_RECT

func get_presentation_rect() -> Rect2:
	var arena_rect: Rect2 = get_gameplay_arena_rect()
	return Rect2(arena_rect.position - PRESENTATION_MARGIN, arena_rect.size + PRESENTATION_MARGIN * 2.0)

func _ready() -> void:
	# Adrenaline never changes global time; only explicit enemy speed multipliers use it.
	Engine.time_scale = 1.0
	pickup_feed = PickupFeed.new()
	pickup_feed.name = "PickupFeed"
	$CanvasLayer.add_child(pickup_feed)
	pickup_feed.anchor_left = 1.0
	pickup_feed.anchor_right = 1.0
	pickup_feed.offset_left = -360.0
	pickup_feed.offset_top = 24.0
	pickup_feed.offset_right = -24.0
	pickup_feed.offset_bottom = 420.0
	pickup_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_campfire_panel()
	# A separate visual-only preset never changes progression or combat tuning.
	_load_forest_visual_settings()
	forest_visual_settings.changed.connect(_apply_forest_visual_settings)
	_apply_forest_visual_settings()
	set_forest_time_phase(active_forest_time_phase)
	_create_backyard_training_menu()
	# Combat diagnostics remain available through Player's concise console log.
	# Do not mount the former player-facing Combat Tracker panel.
	screen_shake_rest_position = position
	_configure_audio_buses()
	audio_manager = AUDIO_MANAGER_SCRIPT.new() as AudioManager
	add_child(audio_manager)
	_configure_music_loop()
	spawner.wave_started.connect(_on_wave_started)
	spawner.cleanup_started.connect(_on_wave_cleanup_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	_create_remaining_enemies_label()
	spawner.boss_wave_started.connect(_on_boss_wave_started)
	spawner.boss_wave_cleared.connect(_on_boss_wave_cleared)
	spawner.enemy_defeated.connect(_on_enemy_defeated)
	spawner.enemy_defeated_with_identity.connect(_on_enemy_defeated_with_identity)
	player.health_changed.connect(_on_health_changed)
	player.flow_changed.connect(_on_flow_changed)
	player.style_changed.connect(_on_style_changed)
	player.player_died.connect(_on_player_died)
	mobile_controls.movement_changed.connect(player.set_mobile_move_input)
	mobile_controls.aim_changed.connect(player.set_mobile_aim_direction)
	mobile_controls.ability_changed.connect(player.set_mobile_ability_held)
	mobile_controls.ability_aim_changed.connect(player.set_mobile_ability_aim)
	mobile_controls.set_gameplay_visible(false)
	player.set_mobile_controls_enabled(false)
	_on_health_changed(player.health, player.max_health)
	_on_flow_changed(player.flow, 100.0)
	score_label.text = "Score: 0"
	_on_style_changed("Metronome")
	for index: int in range(bonus_buttons.size()):
		bonus_buttons[index].pressed.connect(_on_bonus_selected.bind(index))
		bonus_help_buttons[index].mouse_entered.connect(_show_bonus_tooltip.bind(index))
		bonus_help_buttons[index].mouse_exited.connect(_hide_bonus_tooltip)
		bonus_help_buttons[index].focus_entered.connect(_show_bonus_tooltip.bind(index))
		bonus_help_buttons[index].focus_exited.connect(_hide_bonus_tooltip)
	reroll_bonuses_button.pressed.connect(_on_reroll_bonuses)
	next_wave_button.pressed.connect(_on_start_next_wave)
	end_run_button.pressed.connect(_on_end_run)
	end_run_hub.connect("travel_home_requested", Callable(self, "_travel_home"))
	end_run_hub.connect("adventure_zone_requested", Callable(self, "_on_adventure_zone_requested"))
	end_run_hub.connect("resonance_rush_requested", Callable(self, "_on_resonance_rush_requested"))
	end_run_hub.connect("save_requested", Callable(self, "_save_note_from_hub"))
	end_run_hub.connect("load_requested", Callable(self, "_load_from_hub"))
	home_menu.connect("progression_changed", Callable(self, "_on_home_progression_changed"))
	home_menu.connect("adventure_requested", Callable(self, "_return_to_adventure_from_home"))
	home_menu.connect("tutorial_requested", Callable(self, "_start_tutorial"))
	home_menu.connect("dev_wave_requested", Callable(self, "_set_dev_start_wave"))
	home_menu.connect("dev_unlock_all_requested", Callable(self, "_unlock_all_for_dev"))
	home_menu.connect("input_mode_changed", Callable(self, "_on_input_mode_changed"))
	home_menu.connect("metronome_visualizer_changed", Callable(self, "_on_metronome_visualizer_changed"))
	home_menu.connect("visual_style_changed", Callable(self, "_on_visual_style_changed"))
	home_menu.connect("audio_settings_changed", Callable(self, "_on_audio_settings_changed"))
	home_menu.enable_music_requested.connect(_on_enable_music_requested)
	home_menu.connect("metronome_color_changed", Callable(self, "_on_metronome_color_changed"))
	home_menu.connect("camera_zoom_changed", Callable(self, "_on_camera_zoom_changed"))
	home_menu.connect("cauldron_catch_requested", Callable(self, "_on_cauldron_catch_requested"))
	home_menu.connect("forge_requested", Callable(self, "_on_forge_requested"))
	home_menu.connect("grindstone_requested", Callable(self, "_on_grindstone_requested"))
	home_menu.connect("gem_jam_requested", Callable(self, "_on_gem_jam_requested"))
	load_game()
	_apply_audio_settings()
	_initialize_global_presets()
	player.set_input_mode(input_mode)
	_apply_metronome_visualizer_mode()
	player.set_visual_style(visual_style)
	forest_floor.set_presentation_rect(get_presentation_rect())
	forest_floor.set_visual_style(visual_style)
	_update_presentation_camera()
	_update_presentation_environment()
	_on_style_changed(player._style_name())
	home_menu.call("configure", home_progression)
	home_menu.call("set_metronome_visualizer", metronome_visualizer_mode)
	home_menu.call("set_input_mode", input_mode)
	home_menu.call("set_visual_style", visual_style)
	home_menu.call("set_audio_volumes", music_volume, sfx_volume)
	home_menu.call("set_metronome_color", metronome_visualizer_palette)
	home_menu.call("set_camera_zoom", training_camera_zoom)
	home_menu.call("set_cauldron_catch_high_score", cauldron_catch_high_score)
	home_menu.call("set_time_of_day", active_forest_time_phase)
	_create_boss_arena_border()
	# From this point onward, live tuner edits are the active visual baseline.
	# This file remains visual-only and never touches gameplay/progression saves.
	forest_visual_settings_persistence_enabled = true
	zone_transition_fade.modulate.a = 0.0
	end_run_hub.visible = false
	# New sessions begin safely at Home so food and developer tools are available.
	run_over = true
	player.set_physics_process(false)
	spawner.set_process(false)
	get_tree().paused = true
	_set_world_visible(false)
	home_menu.visible = true
	home_menu.call("open_home")
	music_director.enter_home()

func _create_backyard_training_menu() -> void:
	backyard_training_menu = BACKYARD_TRAINING_MENU_SCRIPT.new() as BackyardTrainingMenu
	backyard_training_menu.main = self
	$CanvasLayer.add_child(backyard_training_menu)

func set_backyard_training_layout(layout_id: String) -> void:
	var normalized_layout: String = layout_id.to_lower()
	if normalized_layout != "forest" and normalized_layout != "empty":
		return
	if backyard_training_layout == normalized_layout:
		return
	backyard_training_layout = normalized_layout
	var use_forest: bool = backyard_training_layout == "forest"
	$ForestFloor.visible = use_forest
	$ForestRoad.visible = use_forest
	forest_ambient_fx.visible = use_forest
	arena_generator.visible = use_forest
	arena_generator.set_forest_content_enabled(use_forest)
	if use_forest:
		arena_generator.regenerate()
	refresh_population_navigation()
	combat_presentation_fx._update_blur()

func _create_combat_debug_tracker() -> void:
	combat_debug_tracker = COMBAT_DEBUG_TRACKER_SCRIPT.new() as CombatDebugTracker
	$CanvasLayer.add_child(combat_debug_tracker)
	combat_debug_tracker.setup(player)

## Hides (or restores) the live arena — player, terrain, and Main's own
## always-on HUD labels — whenever a full-screen hub (Home Menu / End Run
## Hub) is the active view. Without this, the paused-but-still-visible arena
## bleeds through behind hub UI, and world-space minigames like Resonance
## Rush (which need their own live Camera2D) end up rendering on top of it.
func _set_world_visible(world_visible: bool) -> void:
	if not world_visible and is_instance_valid(backyard_training_menu): backyard_training_menu.close()
	visible = world_visible
	combat_presentation_fx._update_blur()
	player.visible = world_visible
	var forest_world_visible: bool = world_visible and active_adventure_zone != "chasm"
	var forest_layout_visible: bool = forest_world_visible and backyard_training_layout == "forest"
	$ForestFloor.visible = forest_layout_visible
	$ForestRoad.visible = forest_layout_visible
	forest_ambient_fx.visible = forest_layout_visible
	# Empty remains a playable test room: perimeter collision stays active but
	# has no rendered scenery, props, hazards, or wrap candidates.
	$ArenaBounds.visible = forest_world_visible
	var forest_bounds: StaticBody2D = $ArenaBounds as StaticBody2D
	forest_bounds.collision_layer = 2 if forest_world_visible else 0
	arena_generator.visible = forest_layout_visible
	var chasm_world_visible: bool = world_visible and active_adventure_zone == "chasm"
	chasm_stage.visible = chasm_world_visible
	chasm_stage.set_collision_enabled(chasm_world_visible)
	var trap_overlay: Node = get_node_or_null("TerrainTrapOverlay")
	if is_instance_valid(trap_overlay) and trap_overlay is CanvasItem:
		(trap_overlay as CanvasItem).visible = forest_layout_visible
	var forest_population: ArenaPopulation = get_arena_population()
	if is_instance_valid(forest_population): forest_population.visible = forest_layout_visible
	wave_label.visible = world_visible
	wave_timer_label.visible = world_visible
	health_label.visible = world_visible
	status_label.visible = world_visible
	style_label.visible = false
	flow_bar.visible = world_visible
	$CanvasLayer/FlowTrack.visible = world_visible
	flow_fill.visible = world_visible
	flow_label.visible = world_visible
	flow_sparkle.visible = world_visible
	dash_bar.visible = world_visible
	dash_label.visible = world_visible
	deflect_label.visible = world_visible
	grapple_label.visible = world_visible
	score_label.visible = world_visible
	metronome_top_bar.visible = world_visible
	if is_instance_valid(mobile_controls):
		var mobile_visible: bool = world_visible and not run_over and not wave_transition_active and not bonus_panel.visible
		mobile_controls.set_gameplay_visible(mobile_visible)
		player.set_mobile_controls_enabled(mobile_controls.is_mobile_input_active())
	if is_instance_valid(boss_cave_backdrop): boss_cave_backdrop.visible = world_visible
	if is_instance_valid(boss_campfire): boss_campfire.visible = world_visible
	if is_instance_valid(boss_arena_border): boss_arena_border.visible = world_visible
	if is_instance_valid(zungar_boss): zungar_boss.visible = world_visible
	_update_presentation_camera()
	_update_presentation_environment()
	queue_redraw()

func _create_campfire_panel() -> void:
	campfire_panel = Panel.new()
	campfire_panel.name = "CampfirePanel"
	campfire_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	campfire_panel.position = Vector2(320.0, 190.0)
	campfire_panel.size = Vector2(640.0, 340.0)
	campfire_panel.visible = false
	$CanvasLayer.add_child(campfire_panel)
	var title: Label = Label.new()
	title.position = Vector2(24.0, 22.0)
	title.size = Vector2(592.0, 42.0)
	title.text = "CAMPFIRE CHECKPOINT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ffd66b"))
	campfire_panel.add_child(title)
	campfire_status_label = Label.new()
	campfire_status_label.position = Vector2(40.0, 82.0)
	campfire_status_label.size = Vector2(560.0, 70.0)
	campfire_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	campfire_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campfire_status_label.add_theme_font_size_override("font_size", 18)
	campfire_panel.add_child(campfire_status_label)
	campfire_snack_button = Button.new()
	campfire_snack_button.position = Vector2(68.0, 190.0)
	campfire_snack_button.size = Vector2(240.0, 64.0)
	campfire_snack_button.add_theme_font_size_override("font_size", 19)
	campfire_snack_button.pressed.connect(_eat_checkpoint_snack)
	campfire_panel.add_child(campfire_snack_button)
	campfire_continue_button = Button.new()
	campfire_continue_button.position = Vector2(332.0, 190.0)
	campfire_continue_button.size = Vector2(240.0, 64.0)
	campfire_continue_button.text = "CONTINUE EXPEDITION"
	campfire_continue_button.add_theme_font_size_override("font_size", 17)
	campfire_continue_button.pressed.connect(_continue_from_campfire)
	campfire_panel.add_child(campfire_continue_button)

func _show_campfire(wave_number: int) -> void:
	campfire_wave = wave_number
	campfire_panel.visible = true
	_update_campfire_panel()
	music_director.enter_home()
	_reset_presentation_camera_effects()
	get_tree().paused = true

func _update_campfire_panel() -> void:
	if campfire_panel == null: return
	var snack_count: int = home_progression.food_count(CookingConfig.WOLF_JERKY_ID)
	var missing_health: float = player.max_health - player.health
	campfire_status_label.text = "Wave %d cleared. Rest by the fire before the next battle.\\nWolf Jerky: %d   |   Missing HP: %.0f" % [campfire_wave, snack_count, missing_health]
	campfire_snack_button.text = "EAT WOLF JERKY\\n(+20%% max HP)"
	campfire_snack_button.disabled = snack_count <= 0 or missing_health <= 0.0

func _eat_checkpoint_snack() -> void:
	var heal_amount: float = home_progression.consume_recovery_food(CookingConfig.WOLF_JERKY_ID, player.max_health)
	if heal_amount <= 0.0: return
	player.restore_health(heal_amount)
	save_game()
	_update_campfire_panel()

func _continue_from_campfire() -> void:
	# Resume all simulation clocks before beginning the map transition.
	Engine.time_scale = 1.0
	campfire_panel.visible = false
	music_director.enter_adventure()
	get_tree().paused = false
	_start_next_wave_transition()

func _start_next_wave_transition() -> void:
	if wave_transition_active: return
	wave_transition_active = true
	if is_instance_valid(mobile_controls):
		mobile_controls.set_gameplay_visible(false)
		player.set_mobile_controls_enabled(false)
	spawner.set_process(false)
	player.set_physics_process(false)
	_clear_boss_arena()
	_clear_runtime_entities()
	await _walk_player_to_next_map()
	spawner.continue_to_next_wave()
	spawner.set_process(true)
	player.set_physics_process(true)
	wave_transition_active = false
	if is_instance_valid(mobile_controls) and visible and not run_over and not bonus_panel.visible:
		mobile_controls.set_gameplay_visible(true)
		player.set_mobile_controls_enabled(mobile_controls.is_mobile_input_active())

func _configure_audio_buses() -> void:
	for bus_name: StringName in [MUSIC_BUS, SFX_BUS]:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			AudioServer.add_bus()
			bus_index = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, &"Master")
		AudioServer.set_bus_mute(bus_index, false)

func _audio_volume_db(value: float) -> float:
	return SILENT_AUDIO_DB if value <= 0.0 else linear_to_db(clampf(value, 0.0001, 1.0))

func _apply_audio_settings() -> void:
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	var music_bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	if music_bus_index >= 0: AudioServer.set_bus_volume_db(music_bus_index, _audio_volume_db(music_volume))
	if sfx_bus_index >= 0: AudioServer.set_bus_volume_db(sfx_bus_index, _audio_volume_db(sfx_volume))
	if is_instance_valid(music_director): music_director.call("set_music_volume", music_volume)

func _on_enable_music_requested() -> void:
	if not is_instance_valid(music_director):
		home_menu.set_music_status("Music player unavailable.")
		return
	home_menu.set_music_status(music_director.retry_music_from_button())
	# Playback state is not proof of audible sound, but this helps diagnose
	# browser-only failures without restarting music on every gameplay input.
	await get_tree().create_timer(0.4, true).timeout
	if is_instance_valid(music_director):
		music_director.log_music_diagnostics("0.4s after manual retry")

func _configure_music_loop() -> void:
	music_player.bus = MUSIC_BUS
	music_director = MUSIC_DIRECTOR_SCRIPT.new() as Node
	add_child(music_director)
	music_director.setup(music_player)
	music_director.call("set_forge_volume", forge_music_volume)

func record_damage_dealt(amount: float) -> void:
	run_damage_dealt += maxf(0.0, amount)

func record_damage_received(amount: float) -> void:
	run_damage_received += maxf(0.0, amount)

func record_damage_healed(amount: float) -> void:
	run_damage_healed += maxf(0.0, amount)

func record_damage_mitigated(amount: float) -> void:
	run_damage_mitigated += maxf(0.0, amount)

func play_sfx(sound_name: String, intensity: float = 1.0, pitch_scale: float = 1.0) -> void:
	if audio_manager != null: audio_manager.play_sfx(sound_name, intensity, pitch_scale)

func play_combat_clip(category: String) -> void:
	if audio_manager != null: audio_manager.play_combat_clip(category)

func get_combat_hit_pitch(contact_quality: float) -> float:
	return combat_presentation_fx.hit_pitch_scale(contact_quality)

func request_hitstop(duration: float) -> void:
	if duration <= 0.0 or hitstop_active: return
	hitstop_active = true
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = previous_scale
	hitstop_active = false

func request_screen_shake(strength: float, duration: float, direction: Vector2 = Vector2.ZERO) -> void:
	if screen_shake_multiplier <= 0.0: return
	screen_shake_strength = maxf(screen_shake_strength, strength * screen_shake_multiplier)
	screen_shake_duration = maxf(screen_shake_duration, duration)
	screen_shake_left = maxf(screen_shake_left, duration)
	screen_shake_direction = direction.normalized()

func _update_screen_shake(delta: float) -> void:
	if screen_shake_left <= 0.0:
		_apply_screen_shake_offset(Vector2.ZERO)
		screen_shake_strength = 0.0
		return
	screen_shake_left = maxf(0.0, screen_shake_left - delta)
	var fade: float = screen_shake_left / maxf(screen_shake_duration, 0.001)
	var current_strength: float = screen_shake_strength * fade
	var random_offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * current_strength
	var directional_offset: Vector2 = screen_shake_direction * sin(Time.get_ticks_msec() * 0.06) * current_strength
	_apply_screen_shake_offset(random_offset.lerp(directional_offset, directional_shake_weight))

func _apply_screen_shake_offset(shake_offset: Vector2) -> void:
	if is_instance_valid(presentation_camera) and presentation_camera.enabled:
		# Camera movement is opposite world movement; retain screen-pixel strength.
		presentation_camera.offset = -shake_offset / presentation_camera.zoom
	else:
		position = screen_shake_rest_position + shake_offset
		classic_shake_applied = true

func _reset_presentation_camera_effects() -> void:
	experimental_bind_focus_active = false
	experimental_bind_focus_bias = 0.0
	if is_instance_valid(combat_presentation_fx):
		combat_presentation_fx.reset_micro_zoom()
	screen_shake_left = 0.0
	screen_shake_duration = 0.0
	screen_shake_strength = 0.0
	screen_shake_direction = Vector2.ZERO
	if is_instance_valid(presentation_camera):
		presentation_camera.offset = Vector2.ZERO
	if classic_shake_applied:
		position = screen_shake_rest_position
		classic_shake_applied = false

func _exit_tree() -> void:
	_reset_presentation_camera_effects()

func set_experimental_bind_focus(active: bool, point: Vector2, world_scale: float, zoom_amount: float, framing_bias: float, response: float) -> void:
	experimental_bind_focus_active = active
	experimental_bind_focus_point = point
	experimental_bind_focus_bias = clampf(framing_bias, 0.0, 1.0) if active else 0.0
	experimental_bind_focus_response = clampf(response, 1.0, 20.0)
	if is_instance_valid(combat_presentation_fx):
		combat_presentation_fx.set_bind_focus(active, world_scale, zoom_amount, response)

func spawn_impact_speed_lines(point: Vector2, direction: Vector2, strength: float = 1.0, contact_quality: float = 0.0) -> void:
	combat_presentation_fx.trigger(point, direction, strength, false, contact_quality)

func spawn_tuned_combat_presentation(point: Vector2, direction: Vector2, strength: float, zoom_amount: float, zoom_duration: float, contact_quality: float = 0.0) -> void:
	combat_presentation_fx.trigger_tuned(point, direction, strength, zoom_amount, zoom_duration, false, contact_quality)

func spawn_special_presentation_fx(point: Vector2, direction: Vector2, strength: float = 1.0) -> void:
	combat_presentation_fx.trigger_special_event(point, direction, strength)

func spawn_parry_focus_fx(point: Vector2, direction: Vector2, contact_quality: float) -> void:
	combat_presentation_fx.trigger_parry_focus(point, direction, contact_quality)

func spawn_tuned_parry_focus_fx(point: Vector2, direction: Vector2, contact_quality: float, focus_strength: float, focus_duration: float, zoom_amount: float, zoom_duration: float, impact_strength: float) -> void:
	combat_presentation_fx.trigger_parry_focus_tuned(point, direction, contact_quality, focus_strength, focus_duration, zoom_amount, zoom_duration, impact_strength)

func spawn_enemy_hit_presentation(enemy: Enemy, point: Vector2, impact_velocity: Vector2, cut_direction: Vector2, contact_quality: float, killed: bool, sword_hit: bool = true) -> void:
	combat_presentation_fx.present_enemy_hit(enemy, point, impact_velocity, cut_direction, contact_quality, killed, sword_hit)

func spawn_chakram_bat_presentation(chakram: Chakram, launch_direction: Vector2, contact_quality: float) -> void:
	combat_presentation_fx.present_chakram_bat(chakram, launch_direction, contact_quality)

func spawn_damage_number(world_position: Vector2, damage: float, against_player: bool, contact_quality: float = 0.0) -> void:
	combat_presentation_fx.show_damage_number(world_position, damage, against_player, contact_quality)

func spawn_wrapped_popup(world_position: Vector2) -> void:
	combat_presentation_fx.show_status_text(world_position, "Wrapped!", Color(1.0, 0.82, 0.2, 1.0))

func get_terrain_navigation_direction(from_position: Vector2, target_position: Vector2) -> Vector2:
	if arena_generator == null: return from_position.direction_to(target_position)
	return arena_generator.navigation_direction(from_position, target_position)

func is_terrain_position_clear(world_position: Vector2, clearance: float = 36.0) -> bool:
	return arena_generator == null or arena_generator.is_position_clear(world_position, clearance)

func has_terrain_line_of_sight(start: Vector2, end: Vector2, margin: float = 0.0) -> bool:
	return arena_generator == null or arena_generator.has_line_of_sight(start, end, margin)

func get_terrain_wall_collision(start: Vector2, end: Vector2, radius: float = 0.0) -> Dictionary:
	return {} if arena_generator == null else arena_generator.segment_wall_collision(start, end, radius)

func get_terrain_obstruction_hit(start: Vector2, end: Vector2, radius: float = 0.0) -> Dictionary:
	var population: ArenaPopulation = get_node_or_null("ArenaPopulation") as ArenaPopulation
	return {} if population == null else population.get_obstruction_hit(start, end, radius)

func get_arena_population() -> ArenaPopulation:
	return get_node_or_null("ArenaPopulation") as ArenaPopulation

func get_resonant_glyph_hit(start: Vector2, end: Vector2, radius: float = 0.0, chakram: Chakram = null) -> Dictionary:
	var closest_hit: Dictionary = {}
	var closest_distance: float = INF
	for glyph_node: Node in get_tree().get_nodes_in_group("resonant_glyph"):
		var glyph: ResonantGlyph = glyph_node as ResonantGlyph
		if glyph == null or not is_instance_valid(glyph):
			continue
		if chakram != null and not glyph.can_accept_chakram(chakram):
			continue
		var hit: Dictionary = glyph.segment_hit(start, end, radius)
		if hit.is_empty():
			continue
		var hit_position: Vector2 = hit["position"] as Vector2
		var hit_distance: float = start.distance_to(hit_position)
		if hit_distance < closest_distance:
			closest_distance = hit_distance
			closest_hit = hit
			closest_hit["glyph"] = glyph
	return closest_hit

func try_spawn_resonant_glyph(glyph_rank: int) -> bool:
	if run_over or wave_transition_active or bonus_panel.visible or player == null:
		return false
	var rank_value: int = clampi(glyph_rank, 1, BonusConfig.MAX_RANK)
	var active_glyphs: int = 0
	for glyph_node: Node in get_tree().get_nodes_in_group("resonant_glyph"):
		var existing_glyph: ResonantGlyph = glyph_node as ResonantGlyph
		if existing_glyph == null or not is_instance_valid(existing_glyph):
			continue
		if existing_glyph.lifetime_left <= 0.1:
			existing_glyph.queue_free()
			continue
		active_glyphs += 1
	if active_glyphs >= BonusConfig.resonant_glyph_max_active(rank_value):
		return false
	var spawn_position: Vector2 = player.global_position
	if spawn_position.x < 0.0:
		return false
	if active_adventure_zone == "chasm" and not chasm_stage.is_spawn_position_valid(spawn_position, 52.0):
		return false
	var glyph_instance: ResonantGlyph = RESONANT_GLYPH_SCENE.instantiate() as ResonantGlyph
	if glyph_instance == null:
		return false
	add_child(glyph_instance)
	glyph_instance.global_position = spawn_position
	glyph_instance.setup(player, rank_value)
	return true

func clear_resonant_glyphs() -> void:
	for glyph_node: Node in get_tree().get_nodes_in_group("resonant_glyph"):
		if is_instance_valid(glyph_node):
			glyph_node.queue_free()

func set_forest_time_phase(phase: String) -> void:
	active_forest_time_phase = phase if phase in ["Noon", "Morning", "Dusk", "Night"] else "Noon"
	var population: ArenaPopulation = get_arena_population()
	if population != null:
		population.set_time_phase(active_forest_time_phase)
	if is_instance_valid(home_menu):
		home_menu.call("set_time_of_day", active_forest_time_phase)
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	library.set_current_time_phase(active_forest_time_phase)

func get_forest_time_phase() -> String:
	return active_forest_time_phase

## Steps the day-cycle "world clock" one phase forward (Morning -> Noon ->
## Dusk -> Night -> loop), applying the matching phase from the currently
## loaded Global Preset. Forest phases never choose the launch preset.
## Called once per wave (after wave 1) and once per minigame closed.
func _advance_forest_time_phase() -> void:
	var current_index: int = DAY_CYCLE_ORDER.find(active_forest_time_phase)
	if current_index < 0: current_index = 0
	var next_phase: String = DAY_CYCLE_ORDER[(current_index + 1) % DAY_CYCLE_ORDER.size()]
	var day_preset: Dictionary = active_global_forest_day_presets.get(str(global_preset_slot), {}) as Dictionary
	if day_preset.get(next_phase, null) is Dictionary:
		# The live settings are a temporary view of the selected Global Preset
		# phase. Do not persist them as an independent visual source of truth.
		forest_visual_settings.apply_snapshot_values(day_preset[next_phase] as Dictionary)
		if is_instance_valid(backyard_training_menu) and backyard_training_menu.forest_visual_tuner != null:
			backyard_training_menu.forest_visual_tuner.sync_external_phase(next_phase)
	set_forest_time_phase(next_phase)

func refresh_population_navigation() -> void:
	if arena_generator != null: arena_generator.refresh_population_navigation()

func set_arena_population_density(farmable_value: float, big_things_value: float) -> void:
	var population: ArenaPopulation = get_arena_population()
	if population == null: return
	population.set_farmable_density(farmable_value)
	population.set_big_things_density(big_things_value)
	arena_generator.refresh_population_navigation()

func get_ranged_cover_positions(enemy_position: Vector2, player_position: Vector2, shot_clearance: float = 0.0, peek_distance_past_edge: float = 31.0) -> Dictionary:
	return {} if arena_generator == null else arena_generator.find_cover_positions(enemy_position, player_position, shot_clearance, peek_distance_past_edge)

func spawn_impact_fx(point: Vector2, intensity: float = 1.0, impact_type: int = 0) -> void:
	var effect: ImpactFX = IMPACT_FX_SCENE.instantiate() as ImpactFX
	effect.global_position = point
	effect.intensity = intensity
	effect.impact_type = impact_type as ImpactFX.ImpactType
	add_child(effect)

func _process(_delta: float) -> void:
	_update_presentation_camera_follow(_delta)
	_update_screen_shake(_delta)
	if not run_over:
		run_elapsed_seconds += _delta
		if player.flow >= 75.0: flow_75_seconds += _delta
	heartbeat_left = maxf(0.0, heartbeat_left - _delta)
	if player.health > 0.0 and player.health / player.max_health < 0.3 and heartbeat_left <= 0.0:
		heartbeat_left = 0.72
		play_sfx("heartbeat", 0.65 + (1.0 - player.health / player.max_health) * 0.5)
	var chakram_status: String = "Chakram: READY x%d" % player.chakram_charges if player.active_chakrams.is_empty() else "Chakrams Flying: %d | Stock: %d" % [player.active_chakrams.size(), player.chakram_charges]
	var food_status: String = home_progression.active_food_status()
	var grapple_status: String = "Grapple: READY x%d" % player.grapple_charges if player.grapple_cooldown_left <= 0.0 else "Grapple: %.1fs x%d" % [player.grapple_cooldown_left, player.grapple_charges]
	grapple_label.text = grapple_status
	status_label.text = chakram_status if food_status.is_empty() else "%s | %s" % [chakram_status, food_status]
	if spawner.boss_active or boss_arena_active:
		wave_label.text = "WAVE %d" % ZungarConfig.BOSS_WAVE
		wave_timer_label.text = "ZUNGAR BOSS"
	elif spawner.wave_active:
		wave_label.text = "Wave: %d" % spawner.current_wave
		wave_timer_label.text = "TIME: %.0f" % maxf(0.0, spawner.wave_duration - spawner.wave_elapsed)
	elif not spawner.awaiting_next_wave:
		wave_label.text = "Wave: %d" % (spawner.current_wave + 1)
		wave_timer_label.text = "STARTING: %.0f" % maxf(0.0, spawner.wave_timer)
	var flow_ratio: float = clampf(player.flow / 100.0, 0.0, 1.0)
	var flow_color: Color = Color.WHITE.lerp(Color(1.0, 0.72, 0.08), flow_ratio)
	flow_bar.modulate = flow_color
	flow_fill.color = flow_color
	flow_fill.offset_right = 20.0 + 220.0 * flow_ratio
	var sparkle_ratio: float = clampf((flow_ratio - 0.75) / 0.25, 0.0, 1.0)
	flow_sparkle.modulate = Color(1.0, 0.9, 0.35, sparkle_ratio * (0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))))
	queue_redraw()

func _draw() -> void:
	var presentation_rect: Rect2 = get_presentation_rect()
	draw_rect(presentation_rect, Color("171923"))
	if boss_arena_active and active_adventure_zone != "chasm":
		# The cave is drawn by Main so it stays behind Zungar, trees, and the player.
		draw_rect(Rect2(510.0, 0.0, 260.0, 120.0), Color("241d27"), true)
		draw_arc(Vector2(640.0, 118.0), 130.0, PI, TAU, 32, Color("5b3d35"), 18.0, true)
		draw_arc(Vector2(640.0, 118.0), 105.0, PI, TAU, 32, Color("1b1720"), 12.0, true)
	for x: int in range(floori(presentation_rect.position.x), ceili(presentation_rect.end.x), 32): draw_line(Vector2(x, presentation_rect.position.y), Vector2(x, presentation_rect.end.y), Color(0.2, 0.22, 0.28, 0.16), 1.0)
	for y: int in range(floori(presentation_rect.position.y), ceili(presentation_rect.end.y), 32): draw_line(Vector2(presentation_rect.position.x, y), Vector2(presentation_rect.end.x, y), Color(0.2, 0.22, 0.28, 0.16), 1.0)

func _on_boss_wave_started(number: int) -> void:
	boss_arena_active = true
	wave_label.text = "WAVE %d" % number
	wave_timer_label.text = "ZUNGAR BOSS"
	arena_generator.prepare_boss_arena()
	_clear_runtime_entities()
	if active_adventure_zone != "chasm":
		_create_boss_arena_props()
		_create_boss_arena_border()
	zungar_boss = ZUNGAR_SCENE.instantiate() as Zungar
	zungar_boss.wave_stat_multiplier = spawner.stat_multiplier_for_wave(number)
	zungar_boss.z_index = 4
	var boss_entry_position: Vector2 = Vector2(640.0, 170.0)
	if active_adventure_zone == "chasm":
		boss_entry_position = chasm_stage.get_spawn_rect().get_center()
		zungar_boss.global_position = boss_entry_position
	else:
		zungar_boss.global_position = Vector2(640.0, -90.0)
	var boss_entrance_tween: Tween = create_tween()
	boss_entrance_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if active_adventure_zone != "chasm":
		boss_entrance_tween.tween_property(zungar_boss, "global_position", boss_entry_position, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	zungar_boss.defeated.connect(_on_zungar_defeated)
	add_child(zungar_boss)
	_reset_presentation_camera_effects()
	get_tree().paused = true
	player.set_physics_process(false)
	await _play_zungar_intro()
	if not is_instance_valid(zungar_boss): return
	player.set_physics_process(true)
	# The boss theme starts the instant Zungar stops talking, not before.
	music_director.call("enter_boss")
	zungar_boss.begin_boss_fight()
	get_tree().paused = false

func _create_boss_arena_props() -> void:
	if active_adventure_zone == "chasm": return
	boss_cave_backdrop = BossCaveBackdrop.new()
	add_child(boss_cave_backdrop)
	boss_campfire = BossCampfire.new()
	boss_campfire.z_index = 3
	boss_campfire.global_position = Vector2(640.0, 300.0)
	add_child(boss_campfire)
	boss_trees.clear()
	var tree_positions: Array[Vector2] = [Vector2(250.0, 180.0), Vector2(430.0, 230.0), Vector2(850.0, 220.0), Vector2(1030.0, 180.0), Vector2(640.0, 560.0)]
	for tree_position: Vector2 in tree_positions:
		var tree: DestructibleTree = DestructibleTree.new()
		tree.z_index = 2
		tree.global_position = tree_position
		add_child(tree)
		boss_trees.append(tree)
	queue_redraw()

func spawn_zungar_reinforcements(max_alive: int = ZungarConfig.SUMMON_MAX_ALIVE) -> int:
	if not boss_arena_active or not is_instance_valid(zungar_boss) or not spawner.boss_active:
		return 0
	var living_summons: int = 0
	for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
		var summon: Enemy = summon_node as Enemy
		if summon != null and is_instance_valid(summon) and not summon.death_emitted:
			living_summons += 1
	var available_slots: int = maxi(0, mini(ZungarConfig.SUMMON_MAX_ALIVE, max_alive) - living_summons)
	if available_slots <= 0:
		return 0
	# Named reinforcements preserve the old Goblin/Bug/Wolf/Ogre composition; Turkey is excluded.
	var summon_scenes: Array[PackedScene] = [spawner.GOBLIN_SCENE, spawner.BUG_SCENE, spawner.WOLF_SCENE, spawner.OGRE_SCENE]
	var spawned_count: int = 0
	# The Forest boss arena has a cave mouth for them to file out of; the Chasm
	# arena has none, so it falls back to a random safe spot.
	var use_cave_entrance: bool = active_adventure_zone != "chasm"
	for summon_index: int in range(available_slots):
		var summon_spawn: Vector2
		var summon_walk_target: Vector2
		if use_cave_entrance:
			var lane_offset: float = (float(summon_index) - float(available_slots - 1) * 0.5) * ZungarConfig.SUMMON_ENTRANCE_SPACING
			summon_spawn = ZungarConfig.SUMMON_ENTRANCE_POSITION + Vector2(lane_offset, 0.0)
			summon_walk_target = summon_spawn + Vector2(0.0, ZungarConfig.SUMMON_ENTRANCE_TRAVEL)
		else:
			summon_spawn = _find_zungar_summon_position(summon_index)
			summon_walk_target = summon_spawn
		if summon_spawn.x < 0.0:
			continue
		var summon_scene: PackedScene = summon_scenes[randi_range(0, summon_scenes.size() - 1)]
		var spawned_enemy: Enemy = spawner.spawn_boss_reinforcement(summon_scene, summon_spawn)
		if spawned_enemy == null:
			continue
		if use_cave_entrance:
			# They walk out of the cave before their combat AI engages.
			spawned_enemy.entrance_walk_target = summon_walk_target
			spawned_enemy.entrance_walk_speed = ZungarConfig.SUMMON_ENTRANCE_SPEED
			spawned_enemy.entrance_walk_active = true
		spawned_count += 1
	return spawned_count

func _find_zungar_summon_position(position_index: int) -> Vector2:
	var spawn_rect: Rect2 = arena_generator.config.arena_rect.grow(-76.0)
	if active_adventure_zone == "chasm":
		var chasm_rect: Rect2 = chasm_stage.get_spawn_rect().grow(-34.0)
		if chasm_rect.size.x > 0.0 and chasm_rect.size.y > 0.0:
			spawn_rect = chasm_rect
	for attempt: int in range(28):
		var candidate: Vector2 = Vector2(randf_range(spawn_rect.position.x, spawn_rect.end.x), randf_range(spawn_rect.position.y, spawn_rect.end.y))
		if candidate.distance_to(player.global_position) < 155.0 or candidate.distance_to(zungar_boss.global_position) < 96.0:
			continue
		if is_instance_valid(boss_campfire) and candidate.distance_to(boss_campfire.global_position) < 105.0:
			continue
		if not arena_generator.is_position_clear(candidate, 42.0):
			continue
		if active_adventure_zone == "chasm" and not chasm_stage.is_spawn_position_valid(candidate, 42.0):
			continue
		var separated: bool = true
		for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
			var summon_body: Node2D = summon_node as Node2D
			if summon_body != null and is_instance_valid(summon_body) and candidate.distance_to(summon_body.global_position) < 68.0:
				separated = false
				break
		if separated:
			return candidate
	var fallback_angle: float = TAU * float(position_index) / float(maxi(1, ZungarConfig.SUMMON_MAX_ALIVE))
	var fallback: Vector2 = spawn_rect.get_center() + Vector2.from_angle(fallback_angle) * minf(spawn_rect.size.x, spawn_rect.size.y) * 0.3
	return fallback if arena_generator.is_position_clear(fallback, 36.0) else Vector2(-1.0, -1.0)

func _create_boss_arena_border() -> void:
	if active_adventure_zone == "chasm": return
	if boss_arena_border != null and is_instance_valid(boss_arena_border): boss_arena_border.queue_free()
	boss_arena_border = BOSS_ARENA_BORDER_SCRIPT.new() as BossArenaBorder
	boss_arena_border.arena_rect = arena_generator.config.arena_rect
	boss_arena_border.border_thickness = arena_generator.config.arena_border_thickness
	boss_arena_border.z_index = 1
	add_child(boss_arena_border)
	boss_arena_border.apply_visual_settings(forest_visual_settings.get_effective_values())

func _play_zungar_intro() -> void:
	var dialogue_pages: Array[String] = [
		"These Zungar's woods! And this Zungar's cave!",
		"You looking for fat little beard man? HYUK HYUK HYUK!",
		"Zungar gonna eat him with his pals after he makes us new weapons.",
		"Maybe Zungar make weapon from YOUR BONES!",
	]
	var box: BossDialogueBox = _get_boss_dialogue_box()
	box.start(dialogue_pages)
	await box.finished

func _get_boss_dialogue_box() -> BossDialogueBox:
	if boss_dialogue_box == null or not is_instance_valid(boss_dialogue_box):
		boss_dialogue_box = BOSS_DIALOGUE_BOX_SCRIPT.new() as BossDialogueBox
		$CanvasLayer.add_child(boss_dialogue_box)
	return boss_dialogue_box

func _get_pause_menu() -> Control:
	if pause_menu == null or not is_instance_valid(pause_menu):
		pause_menu = PAUSE_MENU_SCRIPT.new() as Control
		pause_menu.return_home_pressed.connect(_on_pause_return_home)
		$CanvasLayer.add_child(pause_menu)
	return pause_menu

func _on_pause_return_home() -> void:
	if not run_over:
		_finish_run(false)

func _input(event: InputEvent) -> void:
	if OS.has_feature("web") and event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
			if is_instance_valid(music_director):
				music_director.unlock_audio()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		_toggle_pause()

func _toggle_pause() -> void:
	var menu: Control = _get_pause_menu()
	if menu.visible:
		menu.close()
		if is_instance_valid(mobile_controls) and visible and not run_over:
			mobile_controls.set_gameplay_visible(true)
			player.set_mobile_controls_enabled(mobile_controls.is_mobile_input_active())
		return
	# Don't pause if the game is already paused for another reason.
	if get_tree().paused: return
	menu.open()
	if is_instance_valid(mobile_controls):
		mobile_controls.set_gameplay_visible(false)
		player.set_mobile_controls_enabled(false)

func show_boss_message(message: String) -> void:
	if boss_message_tween != null and boss_message_tween.is_valid():
		boss_message_tween.kill()
	if boss_title_label == null:
		boss_title_label = Label.new()
		boss_title_label.position = Vector2(300.0, 500.0)
		boss_title_label.size = Vector2(680.0, 100.0)
		boss_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boss_title_label.add_theme_font_size_override("font_size", 24)
		boss_title_label.add_theme_color_override("font_color", Color("ffe8b0"))
		$CanvasLayer.add_child(boss_title_label)
	boss_title_label.position = Vector2(300.0, 500.0)
	boss_title_label.text = message
	boss_title_label.visible = true
	boss_message_tween = create_tween()
	boss_message_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	boss_message_tween.tween_interval(1.6)
	boss_message_tween.tween_callback(func() -> void: boss_title_label.visible = false)

func show_zungar_title() -> void:
	if boss_title_label == null:
		boss_title_label = Label.new()
		boss_title_label.position = Vector2(300.0, 92.0)
		boss_title_label.size = Vector2(680.0, 90.0)
		boss_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_title_label.add_theme_font_size_override("font_size", 34)
		boss_title_label.add_theme_color_override("font_color", Color("ff5b45"))
		$CanvasLayer.add_child(boss_title_label)
	boss_title_label.text = "ZUNGAR — GUARDIAN OF THE FOREST"
	boss_title_label.visible = true
	var title_tween: Tween = create_tween()
	title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	title_tween.tween_interval(2.0)
	title_tween.tween_callback(func() -> void: boss_title_label.visible = false)

func _on_zungar_defeated(points: int) -> void:
	_on_enemy_defeated(points)
	if boss_arena_active:
		boss_arena_active = false
		for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
			if is_instance_valid(summon_node): summon_node.queue_free()
		spawner.complete_boss_wave()
		home_progression.mines_unlocked = true
		save_game()
		wave_label.text = "ZUNGAR DEFEATED"
		wave_timer_label.text = "MINES UNLOCKED"
		status_label.text = "The Blacksmith is trapped in the Mines. Rescue him to unlock the Forge."

func _on_boss_wave_cleared(_number: int) -> void:
	home_progression.mines_unlocked = true
	save_game()

func _create_remaining_enemies_label() -> void:
	remaining_enemies_label = Label.new()
	remaining_enemies_label.name = "RemainingEnemiesLabel"
	remaining_enemies_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	remaining_enemies_label.offset_top = 92.0
	remaining_enemies_label.offset_bottom = 138.0
	remaining_enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_enemies_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	remaining_enemies_label.add_theme_font_size_override("font_size", 26)
	remaining_enemies_label.add_theme_color_override("font_color", Color("ffe5a0"))
	remaining_enemies_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.02, 0.95))
	remaining_enemies_label.add_theme_constant_override("shadow_offset_x", 3)
	remaining_enemies_label.add_theme_constant_override("shadow_offset_y", 3)
	remaining_enemies_label.text = "DEFEAT THE REMAINING ENEMIES!"
	remaining_enemies_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remaining_enemies_label.visible = false
	$CanvasLayer.add_child(remaining_enemies_label)

func _on_wave_cleanup_started(_remaining_enemies: int) -> void:
	if remaining_enemies_label != null: remaining_enemies_label.visible = true

func _on_wave_started(number: int) -> void:
	if remaining_enemies_label != null: remaining_enemies_label.visible = false
	wave_label.text = "Wave: %d" % number
	wave_timer_label.text = "TIME: %.0f" % spawner.wave_duration
	player.start_resonant_glyph_wave()
	_try_spawn_chest(number)
	# Skip wave 1 specifically so the cycle's starting phase (Morning on a
	# fresh clock) is actually seen before the first advance, not skipped
	# past instantly.
	if number > 1 and active_adventure_zone != "chasm": _advance_forest_time_phase()

func _try_spawn_chest(number: int) -> void:
	if active_adventure_zone == "chasm" or spawner.training_mode or number == ZungarConfig.BOSS_WAVE: return
	if randf() >= chest_spawn_chance:
		chest_spawn_chance = minf(chest_spawn_chance + CHEST_BASE_SPAWN_CHANCE, 1.0)
		return
	if _spawn_chest_at(_random_open_arena_position(60.0)):
		chest_spawn_chance = CHEST_BASE_SPAWN_CHANCE

func _spawn_chest_at(spawn_position: Vector2) -> bool:
	if active_adventure_zone == "chasm" or spawn_position.x < 0.0: return false
	var chest: ArenaObject = ArenaObjectScript.new() as ArenaObject
	chest.object_kind = ArenaObject.ObjectKind.CHEST
	chest.footprint_size = Vector2(56.0, 44.0)
	chest.blocks_navigation = true
	chest.chakram_breakable = true
	chest.sword_harvestable = false
	chest.max_health = 90.0
	add_child(chest)
	chest.global_position = spawn_position
	refresh_population_navigation()
	return true

## Dev/training tool (Backyard > Training Tools > Spawn Items): force-spawns
## a chest immediately near the player, bypassing both the normal per-wave
## chance roll and the training-mode chest gate in _try_spawn_chest().
func spawn_training_chest() -> void:
	if not _spawn_chest_at(_random_open_arena_position(60.0)):
		push_warning("Training chest spawn skipped: no safe location available.")

## Same open-position search WaveSpawner uses for enemy/warning spawns,
## reused here so a chest never lands on top of terrain or the player.
func _random_open_arena_position(clearance: float) -> Vector2:
	var spawn_rect: Rect2 = arena_generator.config.arena_rect if arena_generator != null and arena_generator.config != null else Rect2(0.0, 0.0, 1280.0, 720.0)
	for _attempt: int in range(20):
		var candidate: Vector2 = Vector2(randf_range(spawn_rect.position.x + 48.0, spawn_rect.end.x - 48.0), randf_range(spawn_rect.position.y + 48.0, spawn_rect.end.y - 48.0))
		var chasm_clear: bool = active_adventure_zone != "chasm" or chasm_stage.is_spawn_position_valid(candidate, clearance)
		if is_terrain_position_clear(candidate, clearance) and chasm_clear and candidate.distance_to(player.global_position) > 160.0:
			return candidate
	return Vector2(-1.0, -1.0)

func spawn_chest_loot(drop_position: Vector2) -> void:
	var roll_count: int = 2 if randf() < ArmoryConfig.DOUBLE_ROLL_CHANCE else 1
	for roll_index: int in range(roll_count):
		var item: Dictionary = ArmoryConfig.roll_item(spawner.current_wave, home_progression.generate_gear_id())
		var gear_drop: GearDropPickup = GEAR_DROP_SCENE.instantiate() as GearDropPickup
		add_child(gear_drop)
		gear_drop.global_position = drop_position + Vector2(roll_index * 16.0 - (roll_count - 1) * 8.0, 0.0)
		gear_drop.setup(item)

func collect_gear_drop(item: Dictionary) -> void:
	home_progression.add_gear_item(item)
	pickup_feed.show_pickup(ArmoryConfig.display_label(item), 1, ItemConfig.Rarity.VERY_RARE)
	if is_instance_valid(home_menu): home_menu.call("refresh")
	save_game()

## Applies the sum of every equipped gear item's technique ranks as the
## baseline for the run (see HomeProgression.equipped_technique_ranks), and
## swaps the visible sword/chakram art to match what's equipped.
func _apply_equipped_gear_to_player() -> void:
	var totals: Dictionary = home_progression.equipped_technique_ranks()
	for bonus_id: String in totals:
		BonusConfig.set_rank(player, bonus_id, int(totals[bonus_id]))
	player.reset_resonant_glyph_timer()
	var sword_item: Dictionary = home_progression.equipped_gear_item("Sword")
	var sword_base_name: String = str(sword_item.get("base_name", "Basic Longsword")) if not sword_item.is_empty() else "Basic Longsword"
	player.set_equipped_sword(sword_base_name)
	var armor_item: Dictionary = home_progression.equipped_gear_item("Armor")
	var armor_base_name: String = str(armor_item.get("base_name", "Basic Leather Armor")) if not armor_item.is_empty() else "Basic Leather Armor"
	player.set_equipped_armor(armor_base_name)
func _on_wave_cleared(number: int) -> void:
	if remaining_enemies_label != null: remaining_enemies_label.visible = false
	clear_resonant_glyphs()
	player.reset_resonant_glyph_timer()
	if spawner.training_mode:
		wave_label.text = "WAVE %d TRAINING COMPLETE" % number
		wave_timer_label.text = "NEXT: %.0f" % spawner.wave_interval
		return
	home_progression.complete_wave()
	_grant_bonus_reroll_charge()
	_apply_active_food_to_player()
	wave_label.text = "Wave: %d CLEARED" % number
	wave_timer_label.text = "TIME: 0"
	_show_bonus_screen(number)
	_reset_presentation_camera_effects()
	get_tree().paused = true
func _grant_bonus_reroll_charge() -> void:
	bonus_reroll_charges += 1

func _show_bonus_screen(number: int) -> void:
	bonus_panel.visible = true
	if is_instance_valid(mobile_controls):
		mobile_controls.set_gameplay_visible(false)
		player.set_mobile_controls_enabled(false)
	bonus_tooltip_panel.visible = false
	bonus_title.text = "WAVE %d COMPLETE - CHOOSE A TECHNIQUE" % number
	selected_bonus = ""
	next_wave_button.disabled = true
	rerolled_bonus_exclusions.clear()
	_populate_bonus_choices([])
	_update_reroll_button()

func _eligible_bonus_choices(excluded: Array[String]) -> Array[String]:
	var choices: Array[String] = []
	for bonus_id: String in bonus_ids:
		if not excluded.has(bonus_id) and BonusConfig.can_upgrade(player, bonus_id): choices.append(bonus_id)
	return choices

func _populate_bonus_choices(excluded: Array[String]) -> void:
	visible_bonus_choices.clear()
	var choices: Array[String] = _eligible_bonus_choices(excluded)
	choices.shuffle()
	for index: int in range(bonus_buttons.size()):
		var has_choice: bool = index < choices.size()
		bonus_buttons[index].visible = has_choice
		bonus_help_buttons[index].visible = has_choice
		bonus_detail_labels[index].visible = has_choice
		if not has_choice: continue
		var bonus_id: String = choices[index]
		visible_bonus_choices.append(bonus_id)
		bonus_buttons[index].text = BonusConfig.choice_title(bonus_id, player)
		bonus_buttons[index].set_meta("bonus_id", bonus_id)
		bonus_buttons[index].modulate = Color.WHITE
		bonus_detail_labels[index].text = BonusConfig.comparison_bbcode(bonus_id, player)

func _can_reroll_all_bonuses() -> bool:
	if bonus_reroll_charges <= 0 or visible_bonus_choices.is_empty(): return false
	var exclusions: Array[String] = rerolled_bonus_exclusions.duplicate()
	for bonus_id: String in visible_bonus_choices:
		if not exclusions.has(bonus_id): exclusions.append(bonus_id)
	return _eligible_bonus_choices(exclusions).size() >= visible_bonus_choices.size()

func _update_reroll_button() -> void:
	reroll_bonuses_button.text = "REROLL ALL BONUSES — %d %s" % [bonus_reroll_charges, "CHARGE" if bonus_reroll_charges == 1 else "CHARGES"]
	reroll_bonuses_button.disabled = not _can_reroll_all_bonuses()

func _on_reroll_bonuses() -> void:
	if not _can_reroll_all_bonuses(): return
	for bonus_id: String in visible_bonus_choices:
		if not rerolled_bonus_exclusions.has(bonus_id): rerolled_bonus_exclusions.append(bonus_id)
	bonus_reroll_charges -= 1
	selected_bonus = ""
	next_wave_button.disabled = true
	bonus_tooltip_panel.visible = false
	_populate_bonus_choices(rerolled_bonus_exclusions)
	_update_reroll_button()

func _bonus_title(bonus_id: String) -> String:
	return BonusConfig.choice_title(bonus_id, player)

func _show_bonus_tooltip(index: int) -> void:
	if index < 0 or index >= visible_bonus_choices.size(): return
	bonus_tooltip_text.text = BonusConfig.tooltip_bbcode(visible_bonus_choices[index], player)
	bonus_tooltip_text.scroll_to_line(0)
	bonus_tooltip_panel.visible = true

func _hide_bonus_tooltip() -> void:
	bonus_tooltip_panel.visible = false

func _on_bonus_selected(index: int) -> void:
	selected_bonus = str(bonus_buttons[index].get_meta("bonus_id"))
	for button: Button in bonus_buttons: button.modulate = Color.WHITE
	bonus_buttons[index].modulate = Color(1.0, 0.85, 0.35, 1.0)
	next_wave_button.disabled = false

func _on_start_next_wave() -> void:
	if selected_bonus.is_empty() or wave_transition_active: return
	var picked_bonus_title: String = BonusConfig.title(selected_bonus, player)
	run_bonus_history.append(picked_bonus_title)
	player.apply_bonus(selected_bonus)
	bonus_tooltip_panel.visible = false
	bonus_panel.visible = false
	if is_instance_valid(mobile_controls) and visible and not run_over:
		mobile_controls.set_gameplay_visible(true)
		player.set_mobile_controls_enabled(mobile_controls.is_mobile_input_active())
	for button: Button in bonus_buttons: button.modulate = Color.WHITE
	if checkpoint_wave_interval > 0 and spawner.current_wave != ZungarConfig.BOSS_WAVE and spawner.current_wave % checkpoint_wave_interval == 0:
		_show_campfire(spawner.current_wave)
		return
	get_tree().paused = false
	music_director.enter_adventure()
	await _start_next_wave_transition()

func _clear_boss_arena() -> void:
	if is_instance_valid(boss_campfire): boss_campfire.queue_free()
	boss_campfire = null
	if is_instance_valid(boss_cave_backdrop): boss_cave_backdrop.queue_free()
	boss_cave_backdrop = null
	for tree: DestructibleTree in boss_trees:
		if is_instance_valid(tree): tree.queue_free()
	boss_trees.clear()
	# The perimeter belongs to every Forest arena, so it survives boss cleanup.
	if boss_title_label != null: boss_title_label.visible = false
	queue_redraw()

func _clear_runtime_entities() -> void:
	player.clear_active_chakrams(true)
	for group_name: String in ["enemies", "enemy_projectiles", "spawn_warnings"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node): node.queue_free()
	for node: Node in get_children():
		if node is DropPickup or node is GearDropPickup or node is VoidWell or node is ImpactFX or node is ArenaObject:
			node.queue_free()
	clear_resonant_glyphs()

func _walk_player_to_next_map() -> void:
	player.set_transition_facing(1.0)
	player.prepare_for_map_transition()
	var arena_rect: Rect2 = arena_generator.config.arena_rect
	var walk_y: float = clampf(player.global_position.y, arena_rect.position.y + 48.0, arena_rect.end.y - 48.0)
	var exit_position: Vector2 = Vector2(arena_rect.end.x + TRANSITION_OFFSCREEN_MARGIN, walk_y)
	await _walk_player_to(exit_position, TRANSITION_EXIT_DURATION)
	await _fade_zone_transition(1.0, TRANSITION_FADE_DURATION)
	arena_generator.regenerate()
	player.global_position = Vector2(arena_rect.position.x - TRANSITION_OFFSCREEN_MARGIN, walk_y)
	player.prepare_for_map_transition()
	_update_presentation_camera()
	# Keep the teleport and terrain rebuild entirely behind a fully opaque frame.
	await get_tree().process_frame
	await get_tree().create_timer(TRANSITION_BLACK_HOLD, false, false, true).timeout
	await _fade_zone_transition(0.0, TRANSITION_FADE_DURATION)
	# The player is still genuinely outside the left edge when the forest returns.
	await get_tree().process_frame
	await _walk_player_to(arena_rect.get_center(), TRANSITION_ENTRANCE_DURATION)
	player.prepare_for_map_transition()
	player.set_transition_facing(0.0)

func _fade_zone_transition(target_alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(zone_transition_fade, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(duration, false, false, true).timeout
	zone_transition_fade.modulate.a = target_alpha

func _walk_player_to(destination: Vector2, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(player, "global_position", destination, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var step_count: int = maxi(1, ceili(duration / TRANSITION_STEP_INTERVAL))
	var step_interval: float = duration / float(step_count)
	for step_index: int in range(step_count):
		play_sfx("forest_step", 0.58, 0.9 + float(step_index % 2) * 0.11)
		await get_tree().create_timer(step_interval, false, false, true).timeout

func _on_end_run() -> void:
	_finish_run(false)

func _on_health_changed(current: float, maximum: float) -> void: health_label.text = "HP: %.0f / %.0f" % [current, maximum]
func _on_flow_changed(current: float, _maximum: float) -> void:
	flow_bar.value = current
	flow_label.text = "Flow: %.0f%%" % player.flow
	dash_bar.max_value = float(player.max_dash_charges)
	dash_bar.value = float(player.dash_charges)
	dash_label.text = "Dash: %d / %d" % [player.dash_charges, player.max_dash_charges]
	deflect_label.text = "Deflect: %d / %d" % [player.deflect_charges, BonusConfig.deflect_max_charges(player.deflect_rank)] if player.deflect_rank > 0 else "Deflect: -"

func _on_enemy_defeated_with_identity(enemy_identity: StringName, _points: int) -> void:
	if home_progression != null:
		home_progression.record_grandpa_enemy_defeat(enemy_identity)
		if is_instance_valid(home_menu): home_menu.call("refresh")

func _on_enemy_defeated(points: int) -> void:
	player.heal_from_kill()
	var multiplier: float = 1.0
	if player.flow >= 100.0: multiplier = 2.0
	elif player.flow >= 75.0: multiplier = 1.75
	elif player.flow >= 50.0: multiplier = 1.5
	elif player.flow >= 25.0: multiplier = 1.25
	score += int(roundi(float(points) * multiplier))
	score_label.text = "Score: %d" % score

func _on_style_changed(_style_name: String) -> void:
	# Sword form is an internal development identity, not player-facing HUD.
	style_label.text = ""
	style_label.visible = false
func _on_player_died() -> void:
	_finish_run(true)

func _finish_run(player_was_defeated: bool) -> void:
	_record_and_reset_run()
	bonus_panel.visible = false
	if player_was_defeated: wave_label.text = "GAME OVER"
	run_over = true
	player.set_physics_process(false)
	spawner.set_process(false)
	# Every other reset path (_start_forest_run, _start_backyard_run, wave
	# transitions) clears leftover enemies/projectiles/pickups/boss remnants
	# before continuing — _finish_run() was the one path that skipped this,
	# only hiding a fixed node list via _set_world_visible(). Anything not on
	# that list (dynamically spawned Enemy nodes, chakrams, drops, impact FX,
	# boss arena set pieces) stayed alive and rendering in shared world space
	# for the rest of the Adventure Hub session — including behind Resonance
	# Rush, which is why it could look like "overlapping the arena framework."
	_clear_boss_arena()
	_clear_runtime_entities()
	_show_run_summary()
	get_tree().paused = true
	_set_world_visible(false)

func _record_and_reset_run() -> void:
	last_run_summary = {
		"wave": spawner.current_wave,
		"score": score,
		"completed_at_unix": Time.get_unix_time_from_system(),
		"duration": run_elapsed_seconds,
		"flow_75_duration": flow_75_seconds,
		"damage_dealt": run_damage_dealt,
		"damage_received": run_damage_received,
		"damage_healed": run_damage_healed,
		"damage_mitigated": run_damage_mitigated,
		"bonuses": run_bonus_history.duplicate()
	}
	var zone_scores: Array = scoreboards.get("The Forest", [])
	zone_scores.append(last_run_summary.duplicate(true))
	zone_scores.sort_custom(_sort_score_entries)
	if zone_scores.size() > 10: zone_scores.resize(10)
	scoreboards["The Forest"] = zone_scores
	score = 0
	score_label.text = "Score: 0"
	home_progression.end_expedition()
	player.reset_run_bonuses()
	save_game()

func _sort_score_entries(first: Dictionary, second: Dictionary) -> bool:
	return int(first.get("score", 0)) > int(second.get("score", 0))

func _format_run_time(seconds: float) -> String:
	var minutes: int = int(floorf(seconds / 60.0))
	var remaining_seconds: int = int(floorf(seconds)) % 60
	return "%02d:%02d" % [minutes, remaining_seconds]

func _show_run_summary() -> void:
	home_menu.visible = false
	var summary_text: String = _run_review_bbcode()
	end_run_hub.call("open_to_run_review", summary_text, _scoreboard_text())
	end_run_hub.call("update_save_details", _format_date_time(last_saved_at_unix), save_note)

func _run_review_bbcode() -> String:
	var bonuses: Array = last_run_summary.get("bonuses", [])
	var bonus_text: String = "[color=#9cb4cc]No bonuses selected.[/color]"
	if not bonuses.is_empty():
		bonus_text = ""
		for index: int in range(bonuses.size()): bonus_text += "%d. %s\n" % [index + 1, str(bonuses[index])]
	var summary_text: String = "[center][font_size=26][color=#ffd94d]RUN REVIEW[/color][/font_size][/center]\n\n"
	summary_text += "[font_size=22]Score: [color=#ffd94d]%d[/color]    Wave Reached: %d    Run Time: %s\nFlow at 75%%+: [color=#ffe77a]%s[/color][/font_size]\n\n" % [int(last_run_summary.get("score", 0)), int(last_run_summary.get("wave", 0)), _format_run_time(float(last_run_summary.get("duration", 0.0))), _format_run_time(float(last_run_summary.get("flow_75_duration", 0.0)))]
	summary_text += "[font_size=22][color=#ff9f72]COMBAT STATISTICS[/color][/font_size]\nDamage Dealt: %.0f    Damage Received: %.0f\nDamage Healed: %.0f    Damage Mitigated: %.0f\n\n" % [float(last_run_summary.get("damage_dealt", 0.0)), float(last_run_summary.get("damage_received", 0.0)), float(last_run_summary.get("damage_healed", 0.0)), float(last_run_summary.get("damage_mitigated", 0.0))]
	summary_text += "[font_size=22][color=#8fdcff]BONUSES ACQUIRED[/color][/font_size]\n%s" % bonus_text
	return summary_text

func _scoreboard_text() -> String:
	var entries: Array = scoreboards.get("The Forest", [])
	var text: String = "SCOREBOARD — THE FOREST\n\n"
	if entries.is_empty(): return text + "No completed runs yet."
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		text += "%d. %s    Wave %d    Score %d    Run %s\n" % [index + 1, _format_date_time(float(entry.get("completed_at_unix", 0.0))), int(entry.get("wave", 0)), int(entry.get("score", 0)), _format_run_time(float(entry.get("duration", 0.0)))]
	return text

func _save_note_from_hub(note: String) -> void:
	save_note = note
	save_game()
	end_run_hub.call("update_save_details", _format_date_time(last_saved_at_unix), save_note)

func _load_from_hub() -> void:
	load_game()
	end_run_hub.call("update_save_details", _format_date_time(last_saved_at_unix), save_note)
	if is_instance_valid(home_menu): home_menu.call("set_cauldron_catch_high_score", cauldron_catch_high_score)

func _format_date_time(unix_time: float) -> String:
	if unix_time <= 0.0: return "No timestamp recorded"
	var date_parts: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%04d-%02d-%02d %02d:%02d" % [int(date_parts.get("year", 0)), int(date_parts.get("month", 0)), int(date_parts.get("day", 0)), int(date_parts.get("hour", 0)), int(date_parts.get("minute", 0))]

func _merge_global_dictionaries(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in overlay.keys():
		var incoming: Variant = overlay[key]
		if result.get(key) is Dictionary and incoming is Dictionary:
			result[key] = _merge_global_dictionaries(result[key] as Dictionary, incoming as Dictionary)
		else:
			result[key] = incoming
	return result

func _global_grapple_state(grapple: GrappleController) -> Dictionary:
	var state: Dictionary = {}
	for key: String in GrappleController.TUNING_KEYS:
		state[key] = grapple.get(key)
	return state

func _materialize_combat_settings() -> Dictionary:
	var saved_preset: int = player.combat_contact_preset
	var saved_style: Player.SwordStyle = player.sword_style
	var hand_settings: Dictionary = player.combat_hand_settings.duplicate(true)
	var contact_settings: Dictionary = player.combat_contact_settings.duplicate(true)
	var hand_keys: Array[String] = ["windup_profile", "windup_fraction", "recovery_fraction", "windup_speed", "strike_speed", "recovery_speed", "forward_impulse", "forward_impulse_timing", "backstep_impulse", "backstep_impulse_timing", "action_commitment_strength", "action_commitment_start", "action_commitment_end", "mouse_drag", "rotation", "max_turn_speed", "strike_commitment", "swing_commitment", "swing_commitment_duration", "tempo_assist_enabled", "directional_arc_opening_enabled", "authored_step_enabled", "swing_gesture_gearing_degrees", "radial_response", "scale", "min", "max", "arc", "frequency", "thrusts_per_cycle", "moulinet_aim_smoothing", "slide_sparks", "clash_sparks", "parry_sparks", "bind_enabled", "bind_capture_time", "bind_contact_tolerance", "bind_pressure_min", "bind_retention_strength", "bind_sword_speed", "bind_release_grace", "bind_max_duration", "bind_rebind_cooldown", "bind_focus_time_scale", "bind_focus_zoom", "bind_focus_bias", "bind_focus_response", "bind_scrape_interval", "bind_disengage_min_time", "bind_disengage_min_travel", "bind_disengage_fraction_delta", "bind_disengage_endpoint", "bind_disengage_leverage", "bind_reentry_window", "bind_reentry_min_speed", "bind_reentry_inward_speed", "bind_reentry_damage", "bind_reentry_stagger", "bind_beat_pressure", "bind_beat_spike", "bind_beat_leverage", "bind_beat_stagger", "bind_beat_recoil", "bind_failed_beat_recoil", "bind_debug"]
	var contact_keys: Array[String] = ["flesh_hitstop_min", "flesh_hitstop_max", "flesh_stagger_min", "flesh_stagger_max", "flesh_shake_strength", "flesh_shake_duration", "flesh_zoom", "flesh_zoom_duration", "flesh_recoil", "flesh_impact", "flesh_contact_drag", "flesh_contact_drag_recovery", "contact_hitstop", "contact_shake_strength", "contact_shake_duration", "contact_zoom", "contact_zoom_duration", "contact_impact", "slide_contact_tolerance", "slide_angle", "slide_cling", "slide_friction", "slide_speed", "slide_duration", "slide_travel", "slide_spread", "slide_hitstop", "slide_shake_strength", "slide_shake_duration", "slide_zoom", "slide_zoom_duration", "slide_impact", "clash_contact_tolerance", "clash_angle_min", "clash_angle_max", "clash_cooldown", "clash_player_recoil", "clash_enemy_recoil", "clash_hitstop", "clash_stagger", "clash_recovery", "clash_flow", "clash_shake_strength", "clash_shake_duration", "clash_zoom", "clash_zoom_duration", "clash_impact", "parry_contact_tolerance", "parry_rotation_speed", "parry_cooldown", "parry_player_recoil", "parry_enemy_recoil", "parry_hitstop", "parry_stagger", "parry_recovery", "parry_shake_strength", "parry_shake_duration", "parry_zoom", "parry_zoom_duration", "parry_focus", "parry_focus_duration", "parry_impact", "blade_freeze_duration", "bite_velocity_transfer", "blade_recoil_degrees", "blade_recoil_return", "rebound_flow_boost", "grip_authority_duration", "grip_turn_speed_mult", "apex_hang_time", "apex_hang_duration", "blade_roll_speed", "hilt_bash_enabled", "hilt_bash_knockback", "hilt_bash_stun", "hilt_bash_damage", "hilt_contact_drag", "hilt_contact_drag_recovery", "farmable_hitstop", "farmable_contact_drag", "farmable_contact_drag_recovery", "p3_min_arc_scale", "p3_min_speed_scale", "p3_min_turn_scale", "p4_stage1_end", "p4_stage2_end", "form_blend_smoothing", "charged_guard_enabled"]
	contact_keys.append_array(CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS)
	contact_keys.append_array(CombatSettingsConfig.AUTHORED_METRONOME_TUNING_KEYS)
	for preset: int in range(1, 5):
		var contact_key: String = str(preset)
		var raw_contact: Variant = contact_settings.get(contact_key, {})
		var contact_values: Dictionary = (raw_contact as Dictionary).duplicate(true) if raw_contact is Dictionary else {}
		player.combat_contact_preset = preset
		for key: String in contact_keys:
			contact_values[key] = player.get_combat_contact_setting(key)
		contact_settings[contact_key] = contact_values
		for style_index: int in range(Player.SwordStyle.size()):
			player.sword_style = style_index as Player.SwordStyle
			var hand_key: String = "%d:%d" % [preset, style_index]
			var raw_hand: Variant = hand_settings.get(hand_key, {})
			var hand_values: Dictionary = (raw_hand as Dictionary).duplicate(true) if raw_hand is Dictionary else {}
			for legacy_bind_key: String in Player.EXPERIMENTAL_BIND_SETTING_KEYS + Player.LEGACY_BIND_SLIDE_SETTING_KEYS:
				if style_index != int(Player.SwordStyle.METRONOME_BIND_B):
					hand_values.erase(legacy_bind_key)
			for key: String in hand_keys:
				if key.begins_with("bind_") and style_index != int(Player.SwordStyle.METRONOME_BIND_B):
					continue
				hand_values[key] = player.get_combat_hand_setting(key)
			hand_settings[hand_key] = hand_values
	player.combat_contact_preset = saved_preset
	player.sword_style = saved_style
	return {"hand": hand_settings, "contact": contact_settings}

func _normalize_global_forest_day_presets(raw_presets: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var defaults: ForestVisualSettings = ForestVisualSettings.new()
	for slot: int in range(1, 4):
		var raw_phases: Variant = raw_presets.get(str(slot), {})
		var phases: Dictionary = {}
		for phase: String in ["Noon", "Morning", "Dusk", "Night"]:
			var raw_values: Variant = raw_phases.get(phase, {}) if raw_phases is Dictionary else {}
			var profile: ForestVisualSettings = ForestVisualSettings.new()
			var source: Dictionary = raw_values as Dictionary if raw_values is Dictionary else defaults.values
			profile.apply_snapshot_values(source)
			phases[phase] = profile.values.duplicate(true)
		result[str(slot)] = phases
	return result

func capture_global_preset_state() -> Dictionary:
	var materialized: Dictionary = _materialize_combat_settings()
	var grapple: GrappleController = player.grapple_controller
	var population: ArenaPopulation = get_arena_population()
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	var day_presets: Dictionary = {}
	if is_instance_valid(backyard_training_menu) and backyard_training_menu.forest_visual_tuner != null:
		day_presets = backyard_training_menu.forest_visual_tuner.get_global_day_presets()
	for slot: int in range(1, 4):
		if not day_presets.has(str(slot)):
			day_presets[str(slot)] = library.get_day_preset(slot)
	day_presets = _normalize_global_forest_day_presets(day_presets)
	return {
		"schema": GlobalPresetConfig.VERSION,
		"selected_combat_preset": player.combat_contact_preset,
		"main_game_preset": main_game_preset,
		"combat_hand_settings": materialized["hand"] as Dictionary,
		"combat_contact_settings": materialized["contact"] as Dictionary,
		"combat_weapon_hand_settings": player.combat_weapon_hand_settings.duplicate(true),
		"blade_profile_settings": player.blade_profile_settings.duplicate(true),
		"grapple": _global_grapple_state(grapple),
		"metronome_visualizer_mode": metronome_visualizer_mode,
		"beat_pulse_percent": beat_pulse_percent,
		"visualizer_counts": visualizer_counts, "beat_visualizer_size": beat_visualizer_size,
		"training_camera_zoom": training_camera_zoom,
		"visual_style": visual_style,
		"input_mode": input_mode,
		"forest_values": forest_visual_settings.values.duplicate(true),
		"forest_bypass_all": forest_visual_settings.bypass_all,
		"forest_day_presets": day_presets,
		"forest_startup_day_preset": library.get_startup_day_preset_slot(),
		"forest_time_phase": active_forest_time_phase,
		"farmable_density": population.farmable_density if population != null else 0.3,
		"big_things_density": population.big_things_density if population != null else 0.75
	}

func _default_global_preset_state() -> Dictionary:
	var defaults: ForestVisualSettings = ForestVisualSettings.new()
	var saved_hand_settings: Dictionary = player.combat_hand_settings
	var saved_contact_settings: Dictionary = player.combat_contact_settings
	var saved_preset: int = player.combat_contact_preset
	var saved_style: Player.SwordStyle = player.sword_style
	# Empty overrides force Player's authored Classic fallback values for every
	# combat preset/style instead of copying the legacy tuned Preset 2 profile.
	player.combat_hand_settings = {}
	player.combat_contact_settings = {}
	var materialized_defaults: Dictionary = _materialize_combat_settings()
	player.combat_hand_settings = saved_hand_settings
	player.combat_contact_settings = saved_contact_settings
	player.combat_contact_preset = saved_preset
	player.sword_style = saved_style
	var day_presets: Dictionary = {}
	for slot: int in range(1, 4):
		var phases: Dictionary = {}
		for phase: String in ["Noon", "Morning", "Dusk", "Night"]:
			phases[phase] = defaults.values.duplicate(true)
		day_presets[str(slot)] = phases
	return {
		"schema": GlobalPresetConfig.VERSION,
		"selected_combat_preset": 1,
		"main_game_preset": 1,
		"combat_hand_settings": materialized_defaults["hand"] as Dictionary,
		"combat_contact_settings": materialized_defaults["contact"] as Dictionary,
		"combat_weapon_hand_settings": {},
		"blade_profile_settings": CombatSettingsConfig.built_in_blade_settings(),
		"grapple": GrappleController.default_tuning_state(),
		"metronome_visualizer_mode": "player",
		"beat_pulse_percent": 50.0,
		"visualizer_counts": 2,
		"beat_visualizer_size": 1.0,
		"training_camera_zoom": 1.0,
		"visual_style": "classic",
		"input_mode": "keyboard_mouse",
		"forest_values": defaults.values.duplicate(true),
		"forest_bypass_all": false,
		"forest_day_presets": day_presets,
		"forest_startup_day_preset": 1,
		"forest_time_phase": "Morning",
		"farmable_density": 0.3,
		"big_things_density": 0.75
	}

func _latest_legacy_combat_snapshot() -> Dictionary:
	var snapshots: Array[Dictionary] = CombatSettingsConfig.list_snapshots()
	for snapshot: Dictionary in snapshots:
		if int(snapshot.get("selected_preset", snapshot.get("active_preset", 0))) == 2:
			return snapshot
	return snapshots[0] if not snapshots.is_empty() else {}

func _latest_legacy_forest_snapshot() -> Dictionary:
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	var startup_id: String = library.get_startup_snapshot_id()
	if not startup_id.is_empty():
		var startup_snapshot: Dictionary = library.get_snapshot(startup_id)
		if not startup_snapshot.is_empty():
			return startup_snapshot
	var moonlight: Dictionary = library.find_latest_named_snapshot("Moonlight!")
	if not moonlight.is_empty():
		return moonlight
	var hazey: Dictionary = library.find_latest_named_snapshot("Hazey")
	return hazey

func _migrate_global_preset_two() -> Dictionary:
	var state: Dictionary = capture_global_preset_state()
	var legacy_combat: Dictionary = CombatSettingsConfig.load_all()
	var named_combat: Dictionary = _latest_legacy_combat_snapshot()
	if legacy_combat.get("hand_settings", null) is Dictionary:
		state["combat_hand_settings"] = _merge_global_dictionaries(state["combat_hand_settings"] as Dictionary, legacy_combat["hand_settings"] as Dictionary)
	if legacy_combat.get("contact_settings", null) is Dictionary:
		state["combat_contact_settings"] = _merge_global_dictionaries(state["combat_contact_settings"] as Dictionary, legacy_combat["contact_settings"] as Dictionary)
	if legacy_combat.get("weapon_hand_settings", null) is Dictionary:
		state["combat_weapon_hand_settings"] = _merge_global_dictionaries(state["combat_weapon_hand_settings"] as Dictionary, legacy_combat["weapon_hand_settings"] as Dictionary)
	if legacy_combat.get("blade_settings", null) is Dictionary:
		state["blade_profile_settings"] = _merge_global_dictionaries(state["blade_profile_settings"] as Dictionary, legacy_combat["blade_settings"] as Dictionary)
	if not named_combat.is_empty():
		state["combat_hand_settings"] = _merge_global_dictionaries(state["combat_hand_settings"] as Dictionary, named_combat.get("hand_settings", {}) as Dictionary)
		state["combat_contact_settings"] = _merge_global_dictionaries(state["combat_contact_settings"] as Dictionary, named_combat.get("contact_settings", {}) as Dictionary)
		state["combat_weapon_hand_settings"] = _merge_global_dictionaries(state["combat_weapon_hand_settings"] as Dictionary, named_combat.get("weapon_hand_settings", {}) as Dictionary)
		state["blade_profile_settings"] = _merge_global_dictionaries(state["blade_profile_settings"] as Dictionary, named_combat.get("blade_settings", {}) as Dictionary)
	state["main_game_preset"] = clampi(int(legacy_combat.get("active_preset", 2)), 1, 4)
	var named_forest: Dictionary = _latest_legacy_forest_snapshot()
	var moonlight_day_presets: Dictionary = state.get("forest_day_presets", {}) as Dictionary
	var moonlight_slot: Dictionary = moonlight_day_presets.get("2", {}) as Dictionary
	var moonlight_noon: Variant = moonlight_slot.get("Noon", null)
	if moonlight_noon is Dictionary:
		# The existing Moonlight day-cycle bundle is canonical. Noon is the
		# safe Backyard starting view; later phases stay isolated in their slots.
		state["forest_values"] = (moonlight_noon as Dictionary).duplicate(true)
		state["forest_startup_day_preset"] = 2
		state["forest_time_phase"] = "Noon"
	elif not named_forest.is_empty() and named_forest.get("values", null) is Dictionary:
		state["forest_values"] = (named_forest["values"] as Dictionary).duplicate(true)
	return state

func _global_state_complete(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	var hand_settings: Dictionary = state.get("combat_hand_settings", {}) as Dictionary
	var contact_settings: Dictionary = state.get("combat_contact_settings", {}) as Dictionary
	var weapon_hand_settings: Dictionary = state.get("combat_weapon_hand_settings", {}) as Dictionary
	var forest_values: Dictionary = state.get("forest_values", {}) as Dictionary
	var grapple: Dictionary = state.get("grapple", {}) as Dictionary
	return int(state.get("schema", 0)) == GlobalPresetConfig.VERSION and hand_settings.size() >= Player.SwordStyle.size() * 4 and contact_settings.size() >= 4 and weapon_hand_settings.has("Basic Longsword") and weapon_hand_settings.has("Basic Curved Sword") and forest_values.size() >= ForestVisualSettings.SPECS.size() and grapple.size() >= 10 and state.has("forest_day_presets") and state.has("forest_bypass_all")

func _repair_global_preset_two_day_phases(state: Dictionary) -> bool:
	var day_presets: Dictionary = state.get("forest_day_presets", {}) as Dictionary
	var slot_two: Dictionary = day_presets.get("2", {}) as Dictionary
	var noon: Dictionary = slot_two.get("Noon", {}) as Dictionary
	var night: Dictionary = slot_two.get("Night", {}) as Dictionary
	var noon_is_night: bool = float(noon.get("night_strength", 0.0)) > 0.5 or bool(noon.get("moon_glow_enabled", false))
	var night_is_day: bool = float(night.get("night_strength", 0.0)) <= 0.05 and not bool(night.get("moon_glow_enabled", false))
	if not noon_is_night and not night_is_day:
		return false
	var library: ForestVisualProfileLibrary = ForestVisualProfileLibrary.new()
	var repaired_slot: Dictionary = {}
	for phase: String in DAY_CYCLE_ORDER:
		var profile: ForestVisualSettings = ForestVisualSettings.new()
		var snapshot_name: String = "Hazey" if phase == "Noon" else phase + " v2"
		var snapshot: Dictionary = library.find_latest_named_snapshot(snapshot_name)
		if not snapshot.is_empty():
			profile.apply_snapshot_values(snapshot.get("values", {}) as Dictionary)
		if phase == "Night":
			profile.set_value("night_strength", 0.84)
			profile.set_value("moon_glow_enabled", true)
			profile.set_value("moon_beams_enabled", true)
			profile.set_value("moon_beam_strength", 0.12)
		else:
			profile.set_value("night_strength", 0.0)
			profile.set_value("moon_glow_enabled", false)
		repaired_slot[phase] = profile.values.duplicate(true)
	day_presets["2"] = repaired_slot
	state["forest_day_presets"] = day_presets
	state["forest_values"] = (repaired_slot.get("Morning", {}) as Dictionary).duplicate(true)
	state["forest_time_phase"] = "Morning"
	return true

func _load_baked_global_preset() -> Dictionary:
	var file: FileAccess = FileAccess.open("res://data/default_global_preset.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary and _global_state_complete(parsed as Dictionary) else {}

func _initialize_global_presets() -> void:
	# A user's saved Global Preset 2 is their live authoring package and must
	# survive relaunch. The shipped baked package is only the first-run fallback.
	if GlobalPresetConfig.has_library() and _global_state_complete(GlobalPresetConfig.get_slot(2)):
		global_preset_slot = 2
		GlobalPresetConfig.set_launch_slot(2)
		var saved_user_default: Dictionary = GlobalPresetConfig.get_slot(2)
		if _repair_global_preset_two_day_phases(saved_user_default):
			GlobalPresetConfig.save_slot(2, saved_user_default, 2)
		_apply_global_preset_state(saved_user_default)
		return
	var baked_game_default: Dictionary = _load_baked_global_preset()
	if not baked_game_default.is_empty():
		global_preset_slot = 2
		_apply_global_preset_state(baked_game_default)
		return
	var baked_default: Dictionary = _load_baked_global_preset()
	if not baked_default.is_empty():
		var baked_classic: Dictionary = _default_global_preset_state()
		GlobalPresetConfig.save_slot(1, baked_classic, 2)
		GlobalPresetConfig.save_slot(2, baked_default, 2)
		GlobalPresetConfig.save_slot(3, _default_global_preset_state(), 2)
		global_preset_slot = 2
		_apply_global_preset_state(baked_default)
		return
	var old_library: Dictionary = GlobalPresetConfig.load_raw_library()
	var old_slots: Dictionary = old_library.get("slots", {}) as Dictionary
	var old_preset_two: Variant = old_slots.get("2", {})
	var classic_state: Dictionary = _default_global_preset_state()
	var current_state: Dictionary = _migrate_global_preset_two()
	var canonical_moonlight_day: Dictionary = (current_state.get("forest_day_presets", {}) as Dictionary).duplicate(true)
	# Preserve any values from the previous global file while filling its older
	# partial schema from the current legacy sources and materialized defaults.
	if old_preset_two is Dictionary:
		current_state = _merge_global_dictionaries(current_state, old_preset_two as Dictionary)
	if not canonical_moonlight_day.is_empty():
		current_state["forest_day_presets"] = canonical_moonlight_day
		var canonical_slot: Dictionary = canonical_moonlight_day.get("2", {}) as Dictionary
		var canonical_noon: Variant = canonical_slot.get("Noon", null)
		if canonical_noon is Dictionary:
			current_state["forest_values"] = (canonical_noon as Dictionary).duplicate(true)
			current_state["forest_startup_day_preset"] = 2
			current_state["forest_time_phase"] = "Noon"
	var weapon_hand_settings: Dictionary = current_state.get("combat_weapon_hand_settings", {}) as Dictionary
	if weapon_hand_settings.is_empty():
		var classic_hand: Dictionary = classic_state.get("combat_hand_settings", {}) as Dictionary
		var curved_hand: Dictionary = current_state.get("combat_hand_settings", {}) as Dictionary
		var longsword_form: Dictionary = classic_hand.get("2:0", {}) as Dictionary
		var curved_form: Dictionary = curved_hand.get("2:0", {}) as Dictionary
		weapon_hand_settings = {
			"Basic Longsword": {"2:0": longsword_form.duplicate(true)},
			"Basic Curved Sword": {"2:0": curved_form.duplicate(true)}
		}
	current_state["combat_weapon_hand_settings"] = weapon_hand_settings
	current_state["schema"] = GlobalPresetConfig.VERSION
	var empty_state: Dictionary = _default_global_preset_state()
	GlobalPresetConfig.save_slot(1, classic_state, 2)
	GlobalPresetConfig.save_slot(2, current_state, 2)
	GlobalPresetConfig.save_slot(3, empty_state, 2)
	global_preset_slot = 2
	_apply_global_preset_state(current_state)

func _apply_global_preset_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	main_game_preset = clampi(int(state.get("main_game_preset", 2)), 1, 4)
	player.set_combat_contact_preset(clampi(int(state.get("selected_combat_preset", 2)), 1, 4))
	if state.get("combat_hand_settings", null) is Dictionary:
		player.combat_hand_settings = (state["combat_hand_settings"] as Dictionary).duplicate(true)
	if state.get("combat_contact_settings", null) is Dictionary:
		player.combat_contact_settings = (state["combat_contact_settings"] as Dictionary).duplicate(true)
	if state.get("combat_weapon_hand_settings", null) is Dictionary:
		player.combat_weapon_hand_settings = (state["combat_weapon_hand_settings"] as Dictionary).duplicate(true)
	if state.get("blade_profile_settings", null) is Dictionary:
		player.blade_profile_settings = (state["blade_profile_settings"] as Dictionary).duplicate(true)
	# A pre-Form-III global preset gets its own one-time clone of the Form II
	# values it just imported. Existing Form III values are never overwritten.
	player.ensure_experimental_form_initialized()
	var grapple_data: Dictionary = state.get("grapple", {}) as Dictionary
	var grapple: GrappleController = player.grapple_controller
	for key: String in GrappleController.TUNING_KEYS:
		if not grapple_data.has(key):
			continue
		var current_value: Variant = grapple.get(key)
		if current_value is bool:
			grapple.set(key, bool(grapple_data[key]))
		else:
			grapple.set(key, float(grapple_data[key]))
	metronome_visualizer_mode = str(state.get("metronome_visualizer_mode", "player"))
	beat_pulse_percent = clampf(float(state.get("beat_pulse_percent", 50.0)), 0.0, 100.0)
	visualizer_counts = clampi(int(state.get("visualizer_counts", 2)), 1, 4)
	beat_visualizer_size = clampf(float(state.get("beat_visualizer_size", 1.0)), 0.5, 2.5)
	training_camera_zoom = clampf(float(state.get("training_camera_zoom", 1.0)), 1.0, 2.0)
	visual_style = "hd" if str(state.get("visual_style", "classic")) == "hd" else "classic"
	input_mode = "controller" if str(state.get("input_mode", "keyboard_mouse")) == "controller" else "keyboard_mouse"
	var population: ArenaPopulation = get_arena_population()
	if population != null:
		population.set_farmable_density(clampf(float(state.get("farmable_density", population.farmable_density)), 0.0, 1.0))
		population.set_big_things_density(clampf(float(state.get("big_things_density", population.big_things_density)), 0.0, 1.0))
	var day_presets: Dictionary = state.get("forest_day_presets", {}) as Dictionary
	active_global_forest_day_presets = day_presets.duplicate(true)
	var phase: String = str(state.get("forest_time_phase", "Noon"))
	var selected_phases: Dictionary = day_presets.get(str(global_preset_slot), {}) as Dictionary
	var selected_values: Variant = selected_phases.get(phase, null)
	if selected_values is Dictionary:
		forest_visual_settings.apply_snapshot_values(selected_values as Dictionary)
	elif state.get("forest_values", null) is Dictionary:
		forest_visual_settings.apply_snapshot_values(state["forest_values"] as Dictionary)
	set_forest_time_phase(phase)
	if is_instance_valid(backyard_training_menu) and backyard_training_menu.forest_visual_tuner != null:
		backyard_training_menu.forest_visual_tuner.apply_global_day_presets(day_presets, global_preset_slot, phase)
	# Applying a phase snapshot resets the visual bypass flag internally. Restore
	# the saved bypass state only after the phase workspace has been materialized.
	forest_visual_settings.set_bypass(bool(state.get("forest_bypass_all", false)))
	player.set_input_mode(input_mode)
	player.set_visual_style(visual_style)
	_apply_metronome_visualizer_mode()
	_update_presentation_camera()
	_update_presentation_environment()
	if is_instance_valid(backyard_training_menu):
		backyard_training_menu.main_game_preset = main_game_preset
		backyard_training_menu.call("_sync_combat_controls")

func save_global_preset(slot: int) -> bool:
	var target_slot: int = clampi(slot, 1, GlobalPresetConfig.SLOT_COUNT)
	# Capture while the currently loaded global slot still owns the live Forest
	# workspace. Changing global_preset_slot first used to make SAVE ALL select a
	# different nested phase bundle and silently lose Night edits.
	var state: Dictionary = capture_global_preset_state()
	var saved_day_presets: Dictionary = state.get("forest_day_presets", {}) as Dictionary
	var source_day_bundle: Variant = saved_day_presets.get(str(global_preset_slot), null)
	if source_day_bundle is Dictionary:
		# A Global Preset owns one complete day-cycle bundle. When saving to a
		# different slot, copy the live source bundle into that slot instead of
		# leaving the edited Night phase stranded under the previous slot number.
		saved_day_presets[str(target_slot)] = (source_day_bundle as Dictionary).duplicate(true)
	state["forest_day_presets"] = saved_day_presets
	state["forest_time_phase"] = active_forest_time_phase
	var saved: bool = GlobalPresetConfig.save_slot(target_slot, state, target_slot)
	if not saved:
		return false
	global_preset_slot = target_slot
	active_global_forest_day_presets = (state.get("forest_day_presets", {}) as Dictionary).duplicate(true)
	if is_instance_valid(backyard_training_menu) and backyard_training_menu.forest_visual_tuner != null:
		backyard_training_menu.forest_visual_tuner.mark_global_save_complete()
	return true

func load_global_preset(slot: int) -> bool:
	var clean_slot: int = clampi(slot, 1, GlobalPresetConfig.SLOT_COUNT)
	var state: Dictionary = GlobalPresetConfig.get_slot(clean_slot)
	if state.is_empty():
		return false
	global_preset_slot = clean_slot
	_apply_global_preset_state(state)
	GlobalPresetConfig.set_active_slot(clean_slot)
	return true

func delete_global_preset(slot: int) -> bool:
	var deleted: bool = GlobalPresetConfig.delete_slot(slot)
	if deleted and global_preset_slot == clampi(slot, 1, GlobalPresetConfig.SLOT_COUNT):
		global_preset_slot = 2
	return deleted

func get_global_preset_slot() -> int:
	return global_preset_slot

func get_global_preset_launch_slot() -> int:
	return GlobalPresetConfig.launch_slot()

func set_global_preset_launch_slot(slot: int) -> bool:
	var clean_slot: int = clampi(slot, 1, GlobalPresetConfig.SLOT_COUNT)
	if GlobalPresetConfig.get_slot(clean_slot).is_empty():
		return false
	var saved: bool = GlobalPresetConfig.set_launch_slot(clean_slot)
	if saved:
		load_global_preset(clean_slot)
	return saved

func get_active_global_forest_day_presets() -> Dictionary:
	return active_global_forest_day_presets.duplicate(true)

func get_main_game_preset() -> int:
	return main_game_preset

func save_game() -> void:
	last_saved_at_unix = Time.get_unix_time_from_system()
	var save_data: Dictionary = {"home_progression": home_progression.to_save_data(), "scoreboards": scoreboards, "settings": {"input_mode": input_mode, "metronome_visualizer_mode": metronome_visualizer_mode, "beat_pulse_percent": beat_pulse_percent, "visualizer_counts": visualizer_counts, "beat_visualizer_size": beat_visualizer_size, "training_camera_zoom": training_camera_zoom, "visual_style": visual_style, "music_volume": music_volume, "sfx_volume": sfx_volume, "metronome_color": metronome_visualizer_palette}, "minigames": {"cauldron_catch_high_score": cauldron_catch_high_score}, "save_metadata": {"last_saved_at_unix": last_saved_at_unix, "note": save_note}}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(save_data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return
	var data: Dictionary = parsed as Dictionary
	if data.has("home_progression") and data["home_progression"] is Dictionary:
		home_progression.load_save_data(data["home_progression"] as Dictionary)
	elif data.has("inventory") and data["inventory"] is Dictionary:
		# One-time migration from saves created before the Home progression model.
		home_progression.load_save_data({"materials": data["inventory"] as Dictionary})
	if data.has("scoreboards") and data["scoreboards"] is Dictionary: scoreboards = data["scoreboards"]
	if data.has("settings") and data["settings"] is Dictionary:
		var settings: Dictionary = data["settings"] as Dictionary
		input_mode = "controller" if str(settings.get("input_mode", "keyboard_mouse")) == "controller" else "keyboard_mouse"
		if settings.has("metronome_visualizer_mode"):
			var saved_mode: String = str(settings.get("metronome_visualizer_mode", "player"))
			metronome_visualizer_mode = saved_mode if saved_mode in ["player", "top_bar", "beat", "off"] else "player"
			beat_pulse_percent = clampf(float(settings.get("beat_pulse_percent", 50.0)), 0.0, 100.0)
			visualizer_counts = clampi(int(settings.get("visualizer_counts", 2)), 1, 4)
			beat_visualizer_size = clampf(float(settings.get("beat_visualizer_size", 1.0)), 0.5, 2.5)
		else:
			# Migrate the original boolean option to the player visualizer.
			metronome_visualizer_mode = "player" if bool(settings.get("metronome_visualizer_enabled", true)) else "off"
		training_camera_zoom = clampf(float(settings.get("training_camera_zoom", training_camera_zoom)), 1.0, 2.0)
		var saved_visual_style: String = str(settings.get("visual_style", "classic"))
		visual_style = saved_visual_style if saved_visual_style in ["classic", "hd"] else "classic"
		music_volume = clampf(float(settings.get("music_volume", 1.0)), 0.0, 1.0)
		sfx_volume = clampf(float(settings.get("sfx_volume", 1.0)), 0.0, 1.0)
		var saved_metronome_color: String = str(settings.get("metronome_color", "gold"))
		metronome_visualizer_palette = saved_metronome_color if saved_metronome_color in ["gold", "blue", "green"] else "gold"
	if data.has("minigames") and data["minigames"] is Dictionary:
		var minigames: Dictionary = data["minigames"] as Dictionary
		cauldron_catch_high_score = int(minigames.get("cauldron_catch_high_score", 0))
	if data.has("save_metadata") and data["save_metadata"] is Dictionary:
		var metadata: Dictionary = data["save_metadata"] as Dictionary
		last_saved_at_unix = float(metadata.get("last_saved_at_unix", 0.0))
		save_note = str(metadata.get("note", ""))
	var offline_completed_recipe: String = home_progression.update_crafting()
	if is_instance_valid(home_menu): home_menu.call("configure", home_progression)
	if not offline_completed_recipe.is_empty(): save_game()

func spawn_boss_projectile(origin: Vector2, direction: Vector2, damage: float, source_enemy: Node2D = null, damages_summons: bool = false) -> void:
	var projectile_scene: PackedScene = load("res://scenes/enemy_projectile.tscn") as PackedScene
	if projectile_scene == null:
		push_error("Boss projectile scene is unavailable; skipping spear throw safely.")
		return
	var projectile: EnemyProjectile = projectile_scene.instantiate() as EnemyProjectile
	if projectile == null:
		push_error("Boss projectile scene failed to instantiate; skipping spear throw safely.")
		return
	projectile.global_position = origin + direction * EnemyProjectile.MUZZLE_OFFSET
	projectile.damage = damage
	projectile.spear_visual = true
	projectile.damages_boss_summons = damages_summons
	projectile.boss_summon_damage = ZungarConfig.FRIENDLY_SPEAR_DAMAGE if damages_summons else 0.0
	add_child(projectile)
	projectile.launch(direction, source_enemy)

func try_spawn_drop(drop_position: Vector2, enemy: Enemy) -> void:
	var material_name: String = LOOT_CONFIG_SCRIPT.material_drop_for_enemy(enemy, randf())
	if not material_name.is_empty():
		_spawn_drop_pickup(drop_position + Vector2(-12.0, 0.0), material_name, 1)
	if randf() > 0.28: return
	if randf() < 0.65:
		_spawn_drop_pickup(drop_position + Vector2(12.0, 0.0), "Coins", randi_range(1, 5) + spawner.current_wave)
	else:
		var items: Array[String] = ["Forest Herb", "Iron Shard", "Moon Petal"]
		var item_name: String = items[randi_range(0, items.size() - 1)]
		_spawn_drop_pickup(drop_position + Vector2(12.0, 0.0), item_name, randi_range(1, 2) + mini(2, int(floor(float(spawner.current_wave) / 3.0))))

func _spawn_drop_pickup(drop_position: Vector2, item_name: String, quantity: int) -> void:
	var drop: DropPickup = DROP_SCENE.instantiate() as DropPickup
	add_child(drop)
	drop.global_position = drop_position
	drop.setup(item_name, quantity, spawner.current_wave)

func spawn_terrain_drop(drop_position: Vector2, item_name: String, quantity: int) -> void:
	_spawn_drop_pickup(drop_position, item_name, quantity)

func collect_drop(item_name: String, quantity: int) -> void:
	home_progression.add_material(item_name, quantity)
	if is_instance_valid(home_menu): home_menu.call("refresh")
	pickup_feed.show_pickup(item_name, quantity, ItemConfig.rarity(item_name))
	if tutorial_overlay != null and is_instance_valid(tutorial_overlay):
		tutorial_overlay.register_material(item_name, quantity)
	save_game()

func _on_home_progression_changed(_message: String) -> void:
	save_game()

func _set_dev_start_wave(wave_number: int) -> void:
	dev_start_wave = clampi(wave_number, 1, 100)

func _unlock_all_for_dev() -> void:
	# Keep all development-only progression shortcuts in one explicit handler.
	# These flags are saved so the tester can leave and re-enter Home safely.
	home_progression.mines_unlocked = true
	home_progression.mines_wave_10_cleared = true
	home_progression.blacksmith_rescued = true
	home_progression.forge_purchased = true
	home_menu.call("refresh", "DEV: All current progression gates unlocked.")
	save_game()

func _on_audio_settings_changed(music_value: float, sfx_value: float) -> void:
	music_volume = clampf(music_value, 0.0, 1.0)
	sfx_volume = clampf(sfx_value, 0.0, 1.0)
	_apply_audio_settings()
	save_game()

func _on_metronome_color_changed(palette: String) -> void:
	metronome_visualizer_palette = palette if palette in ["gold", "blue", "green"] else "gold"
	player.set_metronome_visualizer_palette(metronome_visualizer_palette)
	metronome_top_bar.set_visualizer_palette(metronome_visualizer_palette)
	save_game()

func _on_input_mode_changed(mode: String) -> void:
	input_mode = "controller" if mode == "controller" else "keyboard_mouse"
	player.set_input_mode(input_mode)
	_on_style_changed(player._style_name())
	save_game()

func _apply_metronome_visualizer_mode() -> void:
	player.show_metronome_indicator = metronome_visualizer_mode == "player"
	player.set_metronome_visualizer_counts(visualizer_counts)
	player.set_metronome_visualizer_beat_percent(beat_pulse_percent)
	player.metronome_visualizer_palette = metronome_visualizer_palette
	player.set_metronome_visualizer_palette(metronome_visualizer_palette)
	if player.metronome_visualizer != null:
		player.metronome_visualizer.set_display_enabled(player.show_metronome_indicator)
	metronome_top_bar.configure(player, metronome_visualizer_mode, beat_pulse_percent, beat_visualizer_size, visualizer_counts)
	metronome_top_bar.set_visualizer_palette(metronome_visualizer_palette)
	player.queue_redraw()

func _on_metronome_visualizer_changed(mode: String) -> void:
	metronome_visualizer_mode = mode if mode in ["player", "top_bar", "beat", "off"] else "player"
	_apply_metronome_visualizer_mode()
	save_game()

func get_visualizer_counts() -> int:
	return visualizer_counts

func set_visualizer_counts_from_training(value: int) -> void:
	visualizer_counts = clampi(value, 1, 4)
	player.set_metronome_visualizer_counts(visualizer_counts)
	metronome_top_bar.set_visualizer_counts(visualizer_counts)
	save_game()

func get_beat_pulse_percent() -> float:
	return beat_pulse_percent

func get_beat_visualizer_size() -> float:
	return beat_visualizer_size

func set_beat_pulse_percent_from_training(percent: float) -> void:
	beat_pulse_percent = clampf(percent, 0.0, 100.0)
	player.set_metronome_visualizer_beat_percent(beat_pulse_percent)
	metronome_top_bar.set_beat_pulse_percent(beat_pulse_percent)
	save_game()

func set_beat_visualizer_size_from_training(size_multiplier: float) -> void:
	beat_visualizer_size = clampf(size_multiplier, 0.5, 2.5)
	metronome_top_bar.set_beat_visualizer_size(beat_visualizer_size)
	save_game()

func _on_camera_zoom_changed(value: float) -> void:
	set_training_camera_zoom_from_training(value)

func get_training_camera_zoom() -> float:
	return training_camera_zoom

func set_training_camera_zoom_from_training(value: float) -> void:
	training_camera_zoom = clampf(value, 1.0, 2.0)
	if is_instance_valid(home_menu): home_menu.call("set_camera_zoom", training_camera_zoom)
	if is_instance_valid(presentation_camera) and presentation_camera.enabled:
		presentation_camera.zoom = Vector2.ONE * training_camera_zoom
		combat_presentation_fx.camera_rest_zoom = presentation_camera.zoom
		_update_presentation_camera_follow(0.0, false)
		presentation_camera.force_update_scroll()
	save_game()

func _update_presentation_camera() -> void:
	if presentation_camera == null: return
	# Lifecycle reset: menus/minigames and Classic never retain an HD view.
	_reset_presentation_camera_effects()
	var base_zoom: float = training_camera_zoom if visual_style == "hd" else 1.0
	presentation_camera.zoom = Vector2.ONE * base_zoom
	combat_presentation_fx.camera_rest_zoom = presentation_camera.zoom
	presentation_camera.position_smoothing_enabled = false # Smoothed and clamped below.
	presentation_camera.position = get_gameplay_arena_rect().get_center()
	presentation_camera.enabled = visual_style == "hd" and visible
	if presentation_camera.enabled:
		_update_presentation_camera_follow(0.0, true)
		presentation_camera.make_current()
		presentation_camera.force_update_scroll()

func _clamp_presentation_camera_center(center: Vector2) -> Vector2:
	# The illustrated Chasm plate is exactly one viewport wide and tall. Keep its
	# camera centered so movement never reveals the hidden Forest fallback beyond
	# the plate edges; Forest retains its larger presentation margin and camera travel.
	var bounds: Rect2 = get_gameplay_arena_rect() if active_adventure_zone == "chasm" else get_presentation_rect()
	# Use the visible world footprint, reserving the normal-zoom footprint during
	# micro zoom so the boundary cannot breathe or leak as an impact decays.
	var bounds_zoom: Vector2 = presentation_camera.zoom.min(Vector2.ONE).max(Vector2(0.001, 0.001))
	var half_view: Vector2 = get_viewport_rect().size / bounds_zoom * 0.5
	var travel: Vector2 = (bounds.size * 0.5 - half_view).max(Vector2.ZERO)
	# Oversized viewports lock only the oversized axis to the presentation center.
	return center.clamp(bounds.get_center() - travel, bounds.get_center() + travel)

func _update_presentation_camera_follow(delta: float, snap: bool = false) -> void:
	if not is_instance_valid(presentation_camera) or not presentation_camera.enabled or not visible: return
	if not is_instance_valid(player): return
	# Modest movement lookahead, including a hard cap for dash/grapple velocities.
	var lookahead: Vector2 = (player.velocity * 0.12).limit_length(80.0) if not snap else Vector2.ZERO
	var target: Vector2 = player.position + lookahead
	if experimental_bind_focus_active and not snap:
		target = target.lerp(experimental_bind_focus_point, experimental_bind_focus_bias)
	target = _clamp_presentation_camera_center(target)
	var follow_rate: float = experimental_bind_focus_response if experimental_bind_focus_active else 7.0
	var follow_delta: float = delta / maxf(Engine.time_scale, 0.001) if experimental_bind_focus_active else delta
	var center: Vector2 = target if snap else presentation_camera.position.lerp(target, 1.0 - exp(-follow_rate * follow_delta))
	if active_adventure_zone == "chasm":
		# Chasm is a single full-viewport illustration, so do not pan away from
		# its 1280x720 plate while the player moves around the arena.
		presentation_camera.position = get_gameplay_arena_rect().get_center()
		return
	presentation_camera.position = _clamp_presentation_camera_center(center)
	# Shake stays exclusively in Camera2D.offset; zoom is owned by combat FX.

func _update_presentation_environment() -> void:
	if presentation_environment == null: return
	var mood_active: bool = not forest_visual_settings.bypass_all and (
		not is_equal_approx(float(forest_visual_settings.get_value("world_brightness")), 1.0)
		or not is_equal_approx(float(forest_visual_settings.get_value("world_contrast")), 1.0)
		or not is_equal_approx(float(forest_visual_settings.get_value("world_saturation")), 1.0)
	)
	var bloom_active: bool = forest_visual_settings.effect_enabled("bloom_enabled")
	if visual_style != "hd" or not visible or (not bloom_active and not mood_active):
		presentation_environment.environment = null
		return
	# Native LDR Canvas glow and restrained BCS mood grading. The environment
	# only reaches canvas layer 0, leaving combat overlays and the HUD crisp.
	var environment: Environment = presentation_environment.environment
	if environment == null:
		environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = 0
	environment.glow_enabled = bloom_active
	for level: int in range(7):
		environment.set_glow_level(level, 0.0)
	environment.set_glow_level(0, 0.6)
	environment.set_glow_level(1, 0.3)
	environment.set_glow_level(2, 0.1)
	environment.glow_intensity = float(forest_visual_settings.get_value("bloom_strength"))
	environment.glow_strength = 0.65
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.65
	environment.glow_hdr_scale = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.adjustment_enabled = mood_active
	environment.adjustment_brightness = float(forest_visual_settings.get_value("world_brightness"))
	environment.adjustment_contrast = float(forest_visual_settings.get_value("world_contrast"))
	environment.adjustment_saturation = float(forest_visual_settings.get_value("world_saturation"))
	presentation_environment.environment = environment

func _on_visual_style_changed(mode: String) -> void:
	visual_style = mode if mode in ["classic", "hd"] else "classic"
	player.set_visual_style(visual_style)
	forest_floor.set_presentation_rect(get_presentation_rect())
	forest_floor.set_visual_style(visual_style)
	_update_presentation_camera()
	_apply_forest_visual_settings()
	for terrain: Node in get_tree().get_nodes_in_group("terrain_modules"):
		if terrain is CanvasItem:
			(terrain as CanvasItem).queue_redraw()
	$ForestRoad.queue_redraw()
	save_game()

func _on_forge_requested() -> void:
	if is_instance_valid(sword_smithing_instance): return
	home_menu.visible = false
	music_director.call("enter_forge")
	sword_smithing_instance = SWORD_SMITHING_SCENE.instantiate() as SwordSmithingGame
	$CanvasLayer.add_child(sword_smithing_instance)
	sword_smithing_instance.closed.connect(_on_forge_closed)

func _on_forge_closed() -> void:
	if is_instance_valid(sword_smithing_instance): sword_smithing_instance.queue_free()
	sword_smithing_instance = null
	music_director.call("enter_home")
	_advance_forest_time_phase()
	home_menu.call("configure", home_progression)
	home_menu.call("open_home")

func _on_grindstone_requested() -> void:
	if is_instance_valid(grindstone_instance): return
	home_menu.visible = false
	# Grindstone plays its own dedicated music, so the shared Home/Forge
	# player must go fully silent rather than continue underneath it.
	music_director.call("enter_silence")
	grindstone_instance = GRINDSTONE_SCENE.instantiate() as GrindstoneGame
	$CanvasLayer.add_child(grindstone_instance)
	grindstone_instance.closed.connect(_on_grindstone_closed)

func _on_grindstone_closed() -> void:
	if is_instance_valid(grindstone_instance): grindstone_instance.queue_free()
	grindstone_instance = null
	music_director.call("enter_home")
	_advance_forest_time_phase()
	home_menu.call("configure", home_progression)
	home_menu.call("open_home")

func _on_gem_jam_requested() -> void:
	if is_instance_valid(gem_jam_instance): return
	home_menu.visible = false
	music_director.call("enter_silence")
	gem_jam_instance = GEM_JAM_SCENE.instantiate() as GemJamGame
	$CanvasLayer.add_child(gem_jam_instance)
	gem_jam_instance.closed.connect(_on_gem_jam_closed)

func _on_gem_jam_closed() -> void:
	if is_instance_valid(gem_jam_instance): gem_jam_instance.queue_free()
	gem_jam_instance = null
	music_director.call("enter_home")
	_advance_forest_time_phase()
	home_menu.call("configure", home_progression)
	home_menu.call("open_home")

func _on_resonance_rush_requested() -> void:
	if is_instance_valid(resonance_rush_instance): return
	end_run_hub.visible = false
	music_director.call("enter_silence")
	resonance_rush_instance = RESONANCE_RUSH_SCENE.instantiate() as ResonanceRushGame
	# The tree is paused whenever a hub (End Run Hub / Home Menu) is showing —
	# Resonance Rush is reached from the Adventure tab of that hub, so without
	# this it inherits the pause, generates its course once, then never
	# processes another frame (the "freeze" this fixes).
	resonance_rush_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	# Parented directly under the SceneTree root — a SIBLING of Main, not a
	# descendant — rather than under Main itself. Resonance Rush authors its
	# own world in absolute coordinates (e.g. the track world's course starts
	# around x=200). Main is also a plain Node2D whose position gets shifted
	# for screen-shake and can be paused mid-shake (e.g. right as a run ends
	# in `_finish_run()`), which would silently offset every child added
	# under Main by that leftover shake amount. Being a Main child was never
	# required for Resonance Rush to work — it drives its own Camera2D via
	# make_current() and its own CanvasLayer HUD — so parenting under the
	# tree root removes that whole class of "spawned mid-air off the track"
	# bug at the source instead of trying to zero Main's transform in time.
	get_tree().root.add_child(resonance_rush_instance)
	resonance_rush_instance.closed.connect(_on_resonance_rush_closed)

func _on_resonance_rush_closed() -> void:
	if is_instance_valid(resonance_rush_instance): resonance_rush_instance.queue_free()
	resonance_rush_instance = null
	music_director.call("enter_adventure")
	_advance_forest_time_phase()
	end_run_hub.visible = true
	end_run_hub.call("show_tab", 3)

func _on_cauldron_catch_requested() -> void:
	if is_instance_valid(cauldron_catch_instance): return
	if is_instance_valid(home_menu):
		home_menu.hide_cooking_bonus_button()
		if home_menu.home_tutorial_guide != null:
			home_menu.home_tutorial_guide.on_cauldron_started()
	cauldron_catch_instance = CAULDRON_CATCH_SCENE.instantiate() as CauldronCatchGame
	$CanvasLayer.add_child(cauldron_catch_instance)
	cauldron_catch_instance.set_high_score(cauldron_catch_high_score)
	cauldron_catch_instance.round_finished.connect(_on_cauldron_round_finished)
	cauldron_catch_instance.closed.connect(_on_cauldron_catch_closed)
	cauldron_catch_instance.quality_result.connect(_on_cauldron_quality_result)

func _on_cauldron_quality_result(passed: bool, _catch_rate: float) -> void:
	if passed and home_progression != null:
		home_progression.arm_cooking_bonus()
	if not is_instance_valid(home_menu): return
	home_menu.show_cooking_bonus_button()
	var tutorial_handled: bool = false
	if home_menu.home_tutorial_guide != null and is_instance_valid(home_menu.home_tutorial_guide):
		tutorial_handled = home_menu.home_tutorial_guide.on_cauldron_result(passed)
	if not tutorial_handled:
		home_menu.show_cauldron_result(passed)

func _on_cauldron_round_finished(final_score: int, _is_new_high_score: bool) -> void:
	if final_score > cauldron_catch_high_score:
		cauldron_catch_high_score = final_score
		if is_instance_valid(home_menu): home_menu.call("set_cauldron_catch_high_score", cauldron_catch_high_score)
	save_game()

func _on_cauldron_catch_closed(final_score: int, _is_new_high_score: bool) -> void:
	_on_cauldron_round_finished(final_score, false)
	cauldron_catch_instance = null
	if is_instance_valid(home_menu) and home_menu.home_tutorial_guide != null:
		home_menu.home_tutorial_guide.on_cauldron_closed()
	save_game()
	_advance_forest_time_phase()

func _begin_prepared_expedition() -> void:
	home_progression.begin_expedition()
	_apply_active_food_to_player()
	save_game()

func _apply_active_food_to_player() -> void:
	player.set_expedition_food_bonuses(home_progression.active_health_bonus(), home_progression.active_regeneration())

func _travel_home() -> void:
	end_run_hub.visible = false
	home_menu.call("configure", home_progression)
	home_menu.call("open_home")
	music_director.enter_home()

func _start_tutorial() -> void:
	home_menu.visible = false
	end_run_hub.visible = false
	get_tree().paused = false
	_start_backyard_run()
	# The tutorial lives in the forest presentation, but begins before arena
	# modules, hazards, harvestables, and population props are introduced.
	backyard_training_layout = "forest"
	$ForestFloor.visible = true
	$ForestRoad.visible = true
	forest_ambient_fx.visible = true
	arena_generator.visible = true
	arena_generator.set_forest_content_enabled(false)
	spawner.set_process(false)
	_clear_runtime_entities()
	set_training_dummy_enabled(true)
	if is_instance_valid(training_dummy):
		training_dummy.global_position = Vector2(640.0, 360.0)
		training_dummy.lock_world_position()
		training_dummy.hit_registered.connect(_on_tutorial_dummy_hit)
	player.global_position = Vector2(430.0, 360.0)
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()
	tutorial_overlay = TUTORIAL_OVERLAY_SCRIPT.new() as TutorialOverlay
	add_child(tutorial_overlay)
	if not player.tutorial_action.is_connected(_on_tutorial_action):
		player.tutorial_action.connect(_on_tutorial_action)
	tutorial_overlay.gathering_started.connect(_on_tutorial_gathering_started)
	tutorial_overlay.turkey_goal_completed.connect(_on_tutorial_turkey_goal_completed)
	tutorial_overlay.tutorial_completed.connect(_on_tutorial_completed)

func _on_tutorial_gathering_started() -> void:
	var population: ArenaPopulation = get_arena_population()
	if population != null:
		population.populate_tutorial_gathering()
	refresh_population_navigation()
	spawner.begin_tutorial_turkeys()

func _on_tutorial_turkey_goal_completed() -> void:
	spawner.end_tutorial_turkeys()

func _on_tutorial_completed() -> void:
	# Let the player move in the completed clearing for a final beat before Home.
	var completed_overlay: TutorialOverlay = tutorial_overlay
	await get_tree().create_timer(5.0).timeout
	if completed_overlay != tutorial_overlay or not is_instance_valid(completed_overlay):
		return
	# Never tear physics bodies down from the same callback/frame that may still
	# be resolving a sword, Chakram, or pickup contact.
	call_deferred("_return_home_after_tutorial")

func _return_home_after_tutorial() -> void:
	# Presentation changes first: stop simulation and cover the world before any
	# physics-bearing tutorial content is queued for deletion.
	player.set_physics_process(false)
	player.grapple_controller.release_tether()
	spawner.end_tutorial_turkeys()
	run_over = true
	end_run_hub.visible = false
	_set_world_visible(false)
	home_menu.call("configure", home_progression)
	home_menu.visible = true
	home_menu.call("open_home")
	home_menu.call("start_post_field_tutorial")
	music_director.enter_home()
	save_game()
	# Wait until both physics and process callbacks that observed the old world
	# have retired. Cleanup uses queue_free exclusively after this point.
	await get_tree().physics_frame
	await get_tree().process_frame
	var population: ArenaPopulation = get_arena_population()
	if population != null:
		population.stop_tutorial_gathering()
	arena_generator.set_forest_content_enabled(false)
	_clear_runtime_entities()
	if tutorial_overlay != null and is_instance_valid(tutorial_overlay):
		tutorial_overlay.queue_free()
	tutorial_overlay = null
	get_tree().paused = true

func _on_tutorial_action(event_type: String, target: Node) -> void:
	if tutorial_overlay == null or not is_instance_valid(tutorial_overlay):
		return
	var target_is_dummy: bool = target != null and target.is_in_group("training_dummy")
	tutorial_overlay.register_action(event_type, target_is_dummy)

func _on_tutorial_dummy_hit(_amount: float) -> void:
	if tutorial_overlay == null or not is_instance_valid(tutorial_overlay):
		return
	tutorial_overlay.register_hit(_amount)

func _return_to_adventure_from_home() -> void:
	home_menu.visible = false
	end_run_hub.visible = true
	end_run_hub.call("show_tab", 3)
	if home_menu.home_tutorial_guide != null and is_instance_valid(home_menu.home_tutorial_guide):
		home_menu.home_tutorial_guide.on_adventure_opened(end_run_hub)
	music_director.enter_adventure()

func _on_adventure_zone_requested(zone_id: String) -> void:
	if is_instance_valid(home_menu) and home_menu.home_tutorial_guide != null and is_instance_valid(home_menu.home_tutorial_guide):
		home_menu.home_tutorial_guide.on_run_started()
	if zone_id == "forest": _start_forest_run()
	elif zone_id == "chasm": _start_chasm_run()
	elif zone_id == "backyard": _start_backyard_run()

func _start_forest_run() -> void:
	_start_arena_run("forest")

func _start_chasm_run() -> void:
	_start_arena_run("chasm")

func _start_arena_run(zone_id: String) -> void:
	backyard_training_layout = "forest"
	active_adventure_zone = "chasm" if zone_id == "chasm" else "forest"
	spawner.set_chasm_stage(chasm_stage if active_adventure_zone == "chasm" else null)
	arena_generator.set_forest_content_enabled(active_adventure_zone != "chasm")
	# A run must always leave menus, hit-stop, and pause state behind.
	Engine.time_scale = 1.0
	get_tree().paused = false
	spawner.end_training_test()
	spawner.normal_spawning_suspended = false
	spawner.boss_active = false
	boss_arena_active = false
	if is_instance_valid(backyard_training_menu): backyard_training_menu.close()
	music_director.call("set_adventure_zone", active_adventure_zone)
	music_director.enter_adventure()
	get_tree().paused = false
	_set_world_visible(true)
	if is_instance_valid(pause_menu): pause_menu.visible = false
	_clear_boss_arena()
	_clear_runtime_entities()
	wave_transition_active = false
	zone_transition_fade.modulate.a = 0.0
	player.prepare_for_map_transition()
	player.set_transition_facing(0.0)
	end_run_hub.visible = false
	home_menu.visible = false
	run_over = false
	run_elapsed_seconds = 0.0
	flow_75_seconds = 0.0
	run_damage_dealt = 0.0
	run_damage_received = 0.0
	run_damage_healed = 0.0
	run_damage_mitigated = 0.0
	run_bonus_history.clear()
	bonus_reroll_charges = 0
	rerolled_bonus_exclusions.clear()
	chest_spawn_chance = CHEST_BASE_SPAWN_CHANCE
	player.global_position = Vector2(640.0, 360.0)
	if active_adventure_zone != "chasm":
		arena_generator.regenerate()
	# Re-apply visibility after Forest regeneration; Chasm deliberately skips
	# regeneration because its only live world content should be enemies.
	_set_world_visible(true)
	_update_presentation_camera()
	_begin_prepared_expedition()
	player.reset_run_bonuses()
	player.health = player.max_health
	player.flow = 0.0
	player.health_changed.emit(player.health, player.max_health)
	player.flow_changed.emit(player.flow, 100.0)
	_apply_equipped_gear_to_player()
	player.set_physics_process(true)
	var requested_start_wave: int = clampi(dev_start_wave, 1, 100)
	if requested_start_wave <= 1:
		spawner.current_wave = 1
		spawner.enemies_to_spawn = spawner.base_enemy_count
		spawner.enemies_alive = 0
		spawner.wave_duration = spawner.wave_duration_start
		spawner.wave_elapsed = 0.0
		spawner.spawn_timer = 0.0
		spawner.wave_active = true
		spawner.awaiting_next_wave = false
	else:
		spawner.current_wave = requested_start_wave - 1
		spawner.wave_active = false
		spawner.awaiting_next_wave = false
		spawner.wave_timer = 0.0
		spawner._start_wave()
	spawner.set_process(true)
	if requested_start_wave <= 1:
		player.start_resonant_glyph_wave()

func is_backyard_wave_spawner_enabled() -> bool:
	return spawner.training_mode and spawner.is_processing()

func set_backyard_wave_spawner_enabled(enabled: bool) -> void:
	if enabled:
		spawner.begin_training_test()
	else:
		spawner.end_training_test()

func is_training_dummy_enabled() -> bool:
	return is_instance_valid(training_dummy)

func set_training_dummy_enabled(enabled: bool) -> void:
	if enabled:
		if is_instance_valid(training_dummy):
			return
		var spawn_position: Vector2 = spawner._random_position()
		if spawn_position.x < 0.0:
			push_warning("Training dummy spawn skipped: no safe location available.")
			return
		training_dummy = TRAINING_DUMMY_SCENE.instantiate() as TrainingDummy
		if training_dummy == null:
			return
		training_dummy.global_position = spawn_position
		training_dummy.set_meta("training_no_drops", true)
		add_child(training_dummy)
	else:
		if is_instance_valid(training_dummy):
			training_dummy.queue_free()
		training_dummy = null

func is_test_turkey_enabled() -> bool:
	return test_turkey_enabled

func set_test_turkey_enabled(enabled: bool) -> void:
	test_turkey_enabled = enabled
	if enabled:
		if not is_instance_valid(test_turkey):
			_spawn_test_turkey()
	else:
		if is_instance_valid(test_turkey):
			test_turkey.queue_free()
		test_turkey = null

func _spawn_test_turkey() -> void:
	if not test_turkey_enabled or is_instance_valid(test_turkey):
		return
	var spawn_position: Vector2 = spawner._random_position()
	if spawn_position.x < 0.0:
		push_warning("Test turkey spawn skipped: no safe location available.")
		return
	var turkey: Turkey = spawner.instantiate_enemy(WaveSpawner.TURKEY_SCENE) as Turkey
	if turkey == null:
		return
	test_turkey = turkey
	turkey.global_position = spawn_position
	turkey.set_meta("training_no_drops", true)
	turkey.defeated.connect(_on_test_turkey_defeated)
	add_child(turkey)

func _on_test_turkey_defeated(_points: int) -> void:
	test_turkey = null
	if test_turkey_enabled:
		_spawn_test_turkey.call_deferred()

func spawn_training_enemy(enemy_scene: PackedScene) -> void:
	var spawn_position: Vector2 = spawner._random_position()
	if spawn_position.x < 0.0:
		push_warning("Training enemy spawn skipped: no safe location available.")
		return
	var warning: SpawnWarning = SPAWN_WARNING_SCENE.instantiate() as SpawnWarning
	warning.global_position = spawn_position
	warning.finished.connect(_spawn_training_enemy_at.bind(enemy_scene))
	add_child(warning)

func spawn_training_zungar() -> void:
	var spawn_position: Vector2 = spawner._random_position()
	if spawn_position.x < 0.0:
		push_warning("Training Zungar spawn skipped: no safe location available.")
		return
	var boss: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	if boss == null:
		return
	boss.training_mode = true
	boss.wave_stat_multiplier = 1.0
	boss.z_index = 4
	boss.global_position = spawn_position
	boss.set_meta("training_no_drops", true)
	add_child(boss)
	boss.begin_boss_fight()

func _spawn_training_enemy_at(spawn_position: Vector2, enemy_scene: PackedScene) -> void:
	if active_adventure_zone == "chasm" and not chasm_stage.is_spawn_position_valid(spawn_position, spawner.chasm_spawn_clearance):
		return
	var enemy: Enemy = spawner.instantiate_enemy(enemy_scene)
	if enemy == null: return
	enemy.global_position = spawn_position
	enemy.set_meta("training_no_drops", true)
	add_child(enemy)

func _start_backyard_run() -> void:
	backyard_training_layout = "forest"
	active_adventure_zone = "backyard"
	spawner.set_chasm_stage(null)
	arena_generator.set_forest_content_enabled(true)
	# Keep a previous paused/hit-stop state from carrying into a new run.
	Engine.time_scale = 1.0
	get_tree().paused = false
	music_director.enter_adventure()
	get_tree().paused = false
	_set_world_visible(true)
	if is_instance_valid(pause_menu): pause_menu.visible = false
	_clear_boss_arena()
	_clear_runtime_entities()
	wave_transition_active = false
	zone_transition_fade.modulate.a = 0.0
	player.prepare_for_map_transition()
	player.set_transition_facing(0.0)
	end_run_hub.visible = false
	home_menu.visible = false
	run_over = false
	run_elapsed_seconds = 0.0
	flow_75_seconds = 0.0
	run_damage_dealt = 0.0
	run_damage_received = 0.0
	run_damage_healed = 0.0
	run_damage_mitigated = 0.0
	run_bonus_history.clear()
	bonus_reroll_charges = 0
	chest_spawn_chance = CHEST_BASE_SPAWN_CHANCE
	score = 0
	score_label.text = "Score: 0"
	player.global_position = Vector2(640.0, 360.0)
	arena_generator.regenerate()
	_update_presentation_camera()
	player.reset_run_bonuses()
	_apply_equipped_gear_to_player()
	player.health = player.max_health
	player.flow = 0.0
	player.health_changed.emit(player.health, player.max_health)
	player.flow_changed.emit(player.flow, 100.0)
	player.set_physics_process(true)
	spawner.end_training_test()
	if is_instance_valid(backyard_training_menu): backyard_training_menu.open()
	wave_label.text = "BACKYARD — Training"

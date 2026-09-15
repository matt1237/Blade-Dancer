class_name ForestVisualsLiveHarness extends Node
## Visual QA only. Does not write production saves or presets.
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
var game: Node2D = null
var profile: ForestVisualSettings = null
var ready_for_input: bool = false
var runtime: float = 0.0
var printed: bool = false

func _ready() -> void:
	game = MAIN_SCENE.instantiate() as Node2D
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	get_tree().current_scene = game
	profile = game.get("forest_visual_settings") as ForestVisualSettings
	profile.reset_defaults()
	game.set("visual_style", "hd")
	(game.get_node("Player") as Player).set_visual_style("hd")
	(game.get_node("ForestFloor") as ForestFloor).set_visual_style("hd")
	game.call("_start_backyard_run")
	game.call("_apply_forest_visual_settings")
	ready_for_input = true
	print("VISUAL QA ready. Enter: shadows/rays/dapple/haze. B: bloom. Space: bypass. C: Classic. H: hidden world. T: tuner.")

func _process(delta: float) -> void:
	if not ready_for_input: return
	runtime += delta
	if not printed and runtime > 5.0:
		printed = true
		print("Visual QA fps=", Engine.get_frames_per_second(), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_for_input or not event is InputEventKey: return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo: return
	match key.keycode:
		KEY_ENTER:
			for effect: String in ["clouds_enabled", "rays_enabled", "dapple_enabled", "haze_enabled"]:
				profile.set_value(effect, not bool(profile.get_value(effect)))
			print("Atmosphere effects=", profile.get_value("clouds_enabled"))
		KEY_B:
			profile.set_value("bloom_enabled", not bool(profile.get_value("bloom_enabled")))
			print("Bloom=", profile.get_value("bloom_enabled"), " environment=", (game.get_node("ForestEnvironment") as WorldEnvironment).environment)
		KEY_SPACE:
			profile.set_bypass(not profile.bypass_all)
			print("Bypass=", profile.bypass_all)
		KEY_C:
			var mode: String = "classic" if str(game.get("visual_style")) == "hd" else "hd"
			game.set("visual_style", mode)
			(game.get_node("Player") as Player).set_visual_style(mode)
			(game.get_node("ForestFloor") as ForestFloor).set_visual_style(mode)
			game.call("_update_presentation_camera")
			game.call("_apply_forest_visual_settings")
			for terrain: Node in get_tree().get_nodes_in_group("terrain_modules"):
				(terrain as CanvasItem).queue_redraw()
			print("Style=", mode)
		KEY_H:
			game.call("_set_world_visible", not game.visible)
			print("World visible=", game.visible)
		KEY_T:
			var menu: BackyardTrainingMenu = game.get("backyard_training_menu") as BackyardTrainingMenu
			menu._toggle_panel()
			menu.training_tabs.current_tab = menu.forest_visual_tuner.get_index()
	get_viewport().set_input_as_handled()

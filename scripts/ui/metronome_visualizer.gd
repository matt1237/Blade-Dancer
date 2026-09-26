class_name MetronomeVisualizer extends Node2D

## Motion is sampled from the combat stroke, never a separate clock.
const GOLD_TEXTURE: Texture2D = preload("res://assets/generated/metronome_gold_corona.png")
const EFFECT_SHADER: Shader = preload("res://shaders/metronome_visualizer.gdshader")
const CORE_SHADER: Shader = preload("res://shaders/metronome_core.gdshader")
const PALETTE_COLORS: Dictionary = {
	"gold": Color(1.0, 0.65, 0.12),
	"blue": Color(0.12, 0.48, 1.0),
	"green": Color(0.12, 1.0, 0.32),
}
var player_ref: Player = null
var beat_percent: float = 50.0
var visualizer_counts: int = 2
var palette: String = "gold"
var display_enabled: bool = true
var _core: Sprite2D = null
var _energy: Sprite2D = null
var _core_material: ShaderMaterial = null
var _energy_material: ShaderMaterial = null
var _last_progress: float = 0.0

func _ready() -> void:
	z_as_relative = true
	z_index = -1
	_energy = _create_layer("SolarEnergy", false)
	_core = _create_layer("Core", true)
	_energy_material = _energy.material as ShaderMaterial
	_core_material = _core.material as ShaderMaterial
	set_palette(palette)
	_update_visual(_last_progress)

func _create_layer(layer_name: String, core_layer: bool) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = layer_name
	sprite.texture = GOLD_TEXTURE
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * (32.0 if core_layer else 176.0) / 512.0
	var material_instance: ShaderMaterial = ShaderMaterial.new()
	material_instance.shader = CORE_SHADER if core_layer else EFFECT_SHADER
	material_instance.set_shader_parameter("core_layer", core_layer)
	sprite.material = material_instance
	add_child(sprite)
	return sprite

func configure(player: Player, pulse_percent: float = 50.0, palette_name: String = "gold", counts: int = 2) -> void:
	player_ref = player
	beat_percent = clampf(pulse_percent, 0.0, 100.0)
	visualizer_counts = clampi(counts, 1, 4)
	set_palette(palette_name)
	_update_visual(Player.metronome_stroke_progress(player.sword_phase) if is_instance_valid(player) else 0.0)

func set_beat_percent(value: float) -> void:
	beat_percent = clampf(value, 0.0, 100.0)
	_update_visual(_last_progress)

func set_palette(value: String) -> void:
	palette = value if value in PALETTE_COLORS else "gold"
	var selected_color: Color = PALETTE_COLORS[palette]
	for material_instance: ShaderMaterial in [_core_material, _energy_material]:
		if material_instance != null:
			material_instance.set_shader_parameter("selected_color", selected_color)
	if _energy_material != null:
		_energy_material.set_shader_parameter("preserve_gold", palette == "gold")

func set_display_enabled(value: bool) -> void:
	display_enabled = value
	visible = value and is_instance_valid(player_ref)

func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		visible = false
		return
	var style_active: bool = player_ref.sword_style in [Player.SwordStyle.METRONOME, Player.SwordStyle.METRONOME_WINDUP] or player_ref.is_experimental_bind_form()
	visible = display_enabled and player_ref.visible and not get_tree().paused and style_active
	if visible:
		_update_visual(Player.metronome_stroke_progress(player_ref.sword_phase))

func set_visualizer_counts(value: int) -> void:
	visualizer_counts = clampi(value, 1, 4)
	_update_visual(_last_progress)

## The Nth authoritative stroke peaks at beat_percent. Both eased halves last N/2 strokes.
## No local clock or wrap detector: TAU wraps do not add strokes, and player resets
## immediately sample their own count without stale accumulated state.
func sample_envelope(progress: float, stroke_count: int = 0) -> Dictionary:
	var span: float = float(visualizer_counts)
	var selected_peak: float = span - 1.0 + beat_percent / 100.0
	var cycle_position: float = float(stroke_count % visualizer_counts) + clampf(progress, 0.0, 1.0)
	var cycle: float = wrapf(cycle_position - selected_peak + span * 0.5, 0.0, span) / span
	var before: bool = cycle < 0.5
	var windup: float = smoothstep(0.0, 0.5, cycle)
	var release: float = smoothstep(0.5, 1.0, cycle)
	var charge: float = windup if before else 1.0 - release
	return {"charge": charge, "energy": charge, "windup": windup, "release": release, "before": before}

func _update_visual(swing_progress: float) -> void:
	_last_progress = clampf(swing_progress, 0.0, 1.0)
	if _core_material == null:
		return
	var state: Dictionary = sample_envelope(_last_progress, player_ref.swing_count if is_instance_valid(player_ref) else 0)
	for material_instance: ShaderMaterial in [_core_material, _energy_material]:
		material_instance.set_shader_parameter("charge", float(state["charge"]))
		material_instance.set_shader_parameter("energy", float(state["energy"]))
		material_instance.set_shader_parameter("windup", float(state["windup"]))
		material_instance.set_shader_parameter("release_progress", float(state["release"]))
		material_instance.set_shader_parameter("before_beat", bool(state["before"]))
